import os

# Must be set before the app is imported: in-memory SQLite, no Redis.
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["REDIS_URL"] = ""

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture
def client():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with TestClient(app, follow_redirects=False) as c:
        yield c
