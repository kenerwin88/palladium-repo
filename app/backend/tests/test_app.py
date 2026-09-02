from pathlib import Path

import pytest
from flask.testing import FlaskClient

from palladium import create_app


def test_health_exposes_runtime_metadata(
    client: FlaskClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("APP_VERSION", "2026.09.02.1")

    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.get_json() == {
        "environment": "test",
        "status": "ok",
        "version": "2026.09.02.1",
    }


def test_greeting_is_api_payload(client: FlaskClient) -> None:
    response = client.get("/api/greeting")

    assert response.status_code == 200
    payload = response.get_json()
    assert payload["message"] == "Your trunk is healthy and ready to ship."
    assert payload["generated_at"].endswith("+00:00")


def test_spa_fallback_serves_index(tmp_path: Path) -> None:
    (tmp_path / "index.html").write_text("<h1>Angular</h1>", encoding="utf-8")
    (tmp_path / "asset.txt").write_text("asset", encoding="utf-8")
    client = create_app(static_folder=tmp_path).test_client()

    assert client.get("/orders/42").text == "<h1>Angular</h1>"
    assert client.get("/asset.txt").text == "asset"


def test_local_root_explains_split_dev_server(tmp_path: Path) -> None:
    response = create_app(static_folder=tmp_path).test_client().get("/")

    assert response.status_code == 200
    assert "served separately" in response.text


@pytest.fixture
def client(tmp_path: Path) -> FlaskClient:
    return create_app(static_folder=tmp_path).test_client()
