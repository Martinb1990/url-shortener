"""Application settings, read from environment variables (12-factor style)."""

import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Settings:
    database_url: str = field(
        default_factory=lambda: os.getenv("DATABASE_URL", "sqlite:///./shortener.db")
    )
    # Empty string disables the Redis cache (handy for tests and local dev).
    redis_url: str = field(default_factory=lambda: os.getenv("REDIS_URL", ""))
    cache_ttl_seconds: int = field(
        default_factory=lambda: int(os.getenv("CACHE_TTL_SECONDS", "3600"))
    )
    code_length: int = field(default_factory=lambda: int(os.getenv("CODE_LENGTH", "7")))


settings = Settings()
