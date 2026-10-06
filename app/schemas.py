from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, HttpUrl

CODE_PATTERN = r"^[A-Za-z0-9_-]{3,32}$"


class LinkCreate(BaseModel):
    url: HttpUrl
    custom_code: str | None = Field(default=None, pattern=CODE_PATTERN)


class LinkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    target_url: str
    short_url: str
    clicks: int
    created_at: datetime
