# Shortly: URL Shortener (a DevOps showcase project)

[![CI](https://github.com/Martinb1990/url-shortener/actions/workflows/ci.yml/badge.svg)](https://github.com/Martinb1990/url-shortener/actions/workflows/ci.yml)

A small URL shortener used to demonstrate a complete DevOps toolchain built only from free, open-source tools, running on a single VM (`gcp-devops01`).

## Roadmap

| Phase | Scope | Tools | Status |
|---|---|---|---|
| 1 | App + containers | FastAPI, PostgreSQL, Redis, Docker, Compose | ✅ |
| 2 | CI + DevSecOps | GitHub Actions, Ruff, pytest, Trivy, gitleaks, Semgrep, GHCR, Dependabot, pre-commit | ✅ |
| 3 | IaC + config management | OpenTofu (GCS state), Ansible | ✅ |
| 4 | Kubernetes + GitOps CD | k3s, Helm, Flux CD, Sealed Secrets | ⏳ |
| 5 | Observability | Prometheus, Grafana, Loki, Alertmanager | ⏳ |
| 6 | Polish | Traefik + cert-manager (TLS), k6 load tests, OWASP ZAP, runbook | ⏳ |

## Architecture (phase 1)

```
browser ──► app (FastAPI :8000) ──► Redis   (cache: code → URL)
                     │
                     └──────────► PostgreSQL (links, click counts)
```

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/links` | Create a link: `{"url": "https://…", "custom_code": "optional"}` |
| `GET` | `/api/links?limit=10` | Most recent links |
| `GET` | `/api/links/{code}` | Stats for one link |
| `GET` | `/{code}` | 307 redirect to the target (counts a click; `HEAD` doesn't count) |
| `GET` | `/healthz` | Liveness probe |
| `GET` | `/readyz` | Readiness probe (checks DB + Redis) |
| `GET` | `/metrics` | Prometheus metrics |
| `GET` | `/docs` | Interactive OpenAPI docs |

## Quick start

### Run with Docker (full stack)

```bash
make infra-venv && make ansible-apply   # one time: Docker, swap, SSH tunnel (see infra/README.md)
make up                            # builds the image, starts app + Postgres + Redis
open http://localhost:8000
```

### Local development (no Docker)

```bash
make venv   # virtualenv + dev dependencies
make test   # pytest + coverage
make lint   # ruff
make run    # http://127.0.0.1:8000, uses SQLite, no Redis
```

## CI/CD

Every push and pull request runs lint, tests, secret scanning, static analysis and dependency/Dockerfile scanning in parallel. The image is then built, scanned, smoke-tested against the full compose stack and, on `main` only, published to `ghcr.io/martinb1990/url-shortener` with an SBOM and provenance. See [CONTRIBUTING.md](CONTRIBUTING.md) for the stage-by-stage breakdown.

```bash
docker pull ghcr.io/martinb1990/url-shortener:latest
```

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./shortener.db` | SQLAlchemy URL |
| `REDIS_URL` | *(empty, cache disabled)* | Redis URL for the lookup cache |
| `CACHE_TTL_SECONDS` | `3600` | Cache entry lifetime |
| `CODE_LENGTH` | `7` | Length of generated codes |

## Design notes

- **12-factor config:** settings come from environment variables only.
- **Cache is optional:** if Redis is unreachable, lookups fall back to Postgres and `/readyz` reports it.
- **Container hardening:** multi-stage build, slim base image, non-root UID 10001, healthcheck, memory limits.
- **Metrics:** HTTP latency and counts come from `prometheus-fastapi-instrumentator`; business metrics are `shortener_links_created_total` and `shortener_redirects_total{result,source}`.
