def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_readyz_without_redis(client):
    res = client.get("/readyz")
    assert res.status_code == 200
    assert res.json()["checks"] == {"database": "ok"}


def test_create_and_follow_link(client):
    res = client.post("/api/links", json={"url": "https://example.com/some/long/path"})
    assert res.status_code == 201
    body = res.json()
    assert len(body["code"]) == 7
    assert body["short_url"].endswith("/" + body["code"])
    assert body["clicks"] == 0

    redirect = client.get("/" + body["code"])
    assert redirect.status_code == 307
    assert redirect.headers["location"] == "https://example.com/some/long/path"

    stats = client.get(f"/api/links/{body['code']}")
    assert stats.json()["clicks"] == 1


def test_head_redirects_without_counting(client):
    code = client.post("/api/links", json={"url": "https://example.com"}).json()["code"]
    res = client.head("/" + code)
    assert res.status_code == 307
    assert client.get(f"/api/links/{code}").json()["clicks"] == 0


def test_custom_code(client):
    res = client.post("/api/links", json={"url": "https://example.com", "custom_code": "my-link"})
    assert res.status_code == 201
    assert res.json()["code"] == "my-link"


def test_duplicate_custom_code_conflicts(client):
    payload = {"url": "https://example.com", "custom_code": "taken"}
    assert client.post("/api/links", json=payload).status_code == 201
    assert client.post("/api/links", json=payload).status_code == 409


def test_reserved_code_rejected(client):
    res = client.post("/api/links", json={"url": "https://example.com", "custom_code": "metrics"})
    assert res.status_code == 400


def test_invalid_url_rejected(client):
    assert client.post("/api/links", json={"url": "not a url"}).status_code == 422
    assert client.post("/api/links", json={"url": "javascript:alert(1)"}).status_code == 422


def test_invalid_custom_code_rejected(client):
    res = client.post("/api/links", json={"url": "https://example.com", "custom_code": "a b"})
    assert res.status_code == 422


def test_unknown_code_404(client):
    assert client.get("/doesnotexist").status_code == 404
    assert client.get("/api/links/doesnotexist").status_code == 404


def test_recent_links_newest_first(client):
    for i in range(3):
        client.post("/api/links", json={"url": f"https://example.com/{i}"})
    links = client.get("/api/links?limit=2").json()
    assert [link["target_url"] for link in links] == [
        "https://example.com/2",
        "https://example.com/1",
    ]


def test_metrics_exposed(client):
    client.post("/api/links", json={"url": "https://example.com"})
    res = client.get("/metrics")
    assert res.status_code == 200
    assert "shortener_links_created_total" in res.text


def test_index_page(client):
    res = client.get("/")
    assert res.status_code == 200
    assert "Shortly" in res.text


def test_init_db_retries_until_database_is_ready(monkeypatch):
    from sqlalchemy.exc import OperationalError

    from app import main

    calls = []

    def flaky_create_all(_engine):
        calls.append(1)
        if len(calls) < 3:
            raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    monkeypatch.setattr(main.Base.metadata, "create_all", flaky_create_all)
    main.init_db(attempts=5, delay=0)
    assert len(calls) == 3


def test_init_db_gives_up_after_max_attempts(monkeypatch):
    import pytest
    from sqlalchemy.exc import OperationalError

    from app import main

    def always_down(_engine):
        raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    monkeypatch.setattr(main.Base.metadata, "create_all", always_down)
    with pytest.raises(OperationalError):
        main.init_db(attempts=2, delay=0)
