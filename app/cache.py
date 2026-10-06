"""Optional Redis cache for code -> target URL lookups.

If REDIS_URL is unset or Redis is unreachable, the app keeps working
straight from the database; cache errors are never fatal.
"""

import logging

import redis

from app.config import settings

log = logging.getLogger(__name__)

_client: redis.Redis | None = (
    redis.Redis.from_url(settings.redis_url, socket_timeout=0.5, decode_responses=True)
    if settings.redis_url
    else None
)


def _key(code: str) -> str:
    return f"link:{code}"


def get(code: str) -> str | None:
    if _client is None:
        return None
    try:
        return _client.get(_key(code))
    except redis.RedisError as exc:
        log.warning("cache get failed: %s", exc)
        return None


def set(code: str, url: str) -> None:
    if _client is None:
        return
    try:
        _client.set(_key(code), url, ex=settings.cache_ttl_seconds)
    except redis.RedisError as exc:
        log.warning("cache set failed: %s", exc)


def ping() -> bool | None:
    """True/False if Redis is configured, None if caching is disabled."""
    if _client is None:
        return None
    try:
        return bool(_client.ping())
    except redis.RedisError:
        return False
