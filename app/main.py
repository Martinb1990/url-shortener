import logging
import secrets
import string
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import select, text, update
from sqlalchemy.exc import IntegrityError, OperationalError, ProgrammingError
from sqlalchemy.orm import Session

from app import __version__, cache
from app.config import settings
from app.db import Base, engine, get_session
from app.models import Link
from app.schemas import LinkCreate, LinkOut

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("shortener")

STATIC_DIR = Path(__file__).parent / "static"
ALPHABET = string.ascii_letters + string.digits
RESERVED_CODES = {"api", "static", "healthz", "readyz", "metrics", "docs", "openapi.json"}

LINKS_CREATED = Counter("shortener_links_created_total", "Short links created")
REDIRECTS = Counter("shortener_redirects_total", "Redirect lookups", ["result", "source"])


def init_db(attempts: int = 30, delay: float = 2.0) -> None:
    """Create tables, waiting for the database to accept connections.

    Retries cover two startup races in Kubernetes:
    - the app starts before Postgres accepts connections (OperationalError);
    - replicas starting together both run CREATE TABLE and the loser hits a
      duplicate-type/relation error (IntegrityError/ProgrammingError). On the
      next attempt the table exists and create_all skips it.
    """
    # Schema management stays simple for now; Alembic migrations can replace this later.
    for attempt in range(1, attempts + 1):
        try:
            Base.metadata.create_all(engine)
            return
        except (OperationalError, IntegrityError, ProgrammingError) as exc:
            if attempt == attempts:
                raise
            log.warning("database not ready (attempt %d/%d): %s", attempt, attempts, exc.orig)
            time.sleep(delay)


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="URL Shortener", version=__version__, lifespan=lifespan)

# Browser security headers (flagged by the OWASP ZAP baseline scan).
SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=(), payment=()",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
}
# The frontend uses only same-origin scripts and styles, no inline code.
STRICT_CSP = (
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
    "connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
)
# FastAPI's /docs and /redoc load Swagger/ReDoc from a CDN with inline scripts.
DOCS_PATHS = ("/docs", "/redoc", "/openapi.json")


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers.update(SECURITY_HEADERS)
    path = request.url.path
    if not path.startswith(DOCS_PATHS):
        response.headers["Content-Security-Policy"] = STRICT_CSP
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
    # API responses and redirects must not be cached: stale data, uncounted clicks.
    if path.startswith("/api/") or 300 <= response.status_code < 400:
        response.headers["Cache-Control"] = "no-store"
    return response


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
Instrumentator(excluded_handlers=["/metrics", "/healthz", "/readyz"]).instrument(app).expose(
    app, include_in_schema=False
)


def _to_out(link: Link, request: Request) -> LinkOut:
    return LinkOut(
        code=link.code,
        target_url=link.target_url,
        short_url=f"{str(request.base_url).rstrip('/')}/{link.code}",
        clicks=link.clicks,
        created_at=link.created_at,
    )


def _random_code() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(settings.code_length))


@app.get("/", include_in_schema=False)
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/healthz", include_in_schema=False)
def healthz() -> dict:
    """Liveness: the process is up."""
    return {"status": "ok", "version": __version__}


@app.get("/readyz", include_in_schema=False)
def readyz(session: Session = Depends(get_session)) -> JSONResponse:
    """Readiness: dependencies are reachable."""
    checks: dict[str, str] = {}
    try:
        session.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception as exc:  # noqa: BLE001
        log.error("readiness db check failed: %s", exc)
        checks["database"] = "fail"
    redis_ok = cache.ping()
    if redis_ok is not None:
        checks["redis"] = "ok" if redis_ok else "fail"
    ready = all(v == "ok" for v in checks.values())
    return JSONResponse(
        {"status": "ready" if ready else "not ready", "checks": checks},
        status_code=status.HTTP_200_OK if ready else status.HTTP_503_SERVICE_UNAVAILABLE,
    )


@app.post("/api/links", response_model=LinkOut, status_code=status.HTTP_201_CREATED)
def create_link(
    payload: LinkCreate, request: Request, session: Session = Depends(get_session)
) -> LinkOut:
    target = str(payload.url)
    if payload.custom_code:
        if payload.custom_code.lower() in RESERVED_CODES:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "That code is reserved")
        candidates = [payload.custom_code]
    else:
        candidates = [_random_code() for _ in range(5)]

    for code in candidates:
        link = Link(code=code, target_url=target, clicks=0)
        session.add(link)
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            continue
        LINKS_CREATED.inc()
        cache.set(code, target)
        log.info("created link code=%s", code)
        return _to_out(link, request)

    if payload.custom_code:
        raise HTTPException(status.HTTP_409_CONFLICT, "That code is already taken")
    raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Could not allocate a code")


@app.get("/api/links", response_model=list[LinkOut])
def recent_links(
    request: Request, limit: int = 10, session: Session = Depends(get_session)
) -> list[LinkOut]:
    limit = max(1, min(limit, 50))
    links = session.scalars(select(Link).order_by(Link.id.desc()).limit(limit))
    return [_to_out(link, request) for link in links]


@app.get("/api/links/{code}", response_model=LinkOut)
def link_stats(code: str, request: Request, session: Session = Depends(get_session)) -> LinkOut:
    link = session.scalar(select(Link).where(Link.code == code))
    if link is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Link not found")
    return _to_out(link, request)


@app.api_route("/{code}", methods=["GET", "HEAD"], include_in_schema=False)
def follow(
    code: str, request: Request, session: Session = Depends(get_session)
) -> RedirectResponse:
    target = cache.get(code)
    source = "cache"
    if target is None:
        source = "db"
        target = session.scalar(select(Link.target_url).where(Link.code == code))
        if target is None:
            REDIRECTS.labels(result="not_found", source=source).inc()
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Link not found")
        cache.set(code, target)

    # HEAD requests (link checkers, unfurlers) resolve but don't count as clicks.
    if request.method == "GET":
        session.execute(update(Link).where(Link.code == code).values(clicks=Link.clicks + 1))
        session.commit()
        REDIRECTS.labels(result="hit", source=source).inc()
    return RedirectResponse(target, status_code=status.HTTP_307_TEMPORARY_REDIRECT)
