import os
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from flask.testing import FlaskClient

from palladium import create_app
from palladium.database import read_status


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


def test_greeting_is_api_payload(client: FlaskClient, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    response = client.get("/api/greeting")

    assert response.status_code == 200
    payload = response.get_json()
    assert payload["message"] == "Your trunk is healthy and ready to ship."
    assert payload["database_schema_version"] == "not-configured"
    assert payload["generated_at"].endswith("+00:00")


@pytest.mark.database
@pytest.mark.skipif(not os.getenv("DATABASE_URL"), reason="DATABASE_URL is not configured")
def test_greeting_reads_the_flyway_schema(client: FlaskClient) -> None:
    response = client.get("/api/greeting")

    assert response.status_code == 200
    payload = response.get_json()
    assert payload["database_schema_version"] == "001"
    assert payload["message"] == (
        "Your trunk, application, and schema are healthy and ready to ship."
    )


def test_database_status_uses_the_configured_schema(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    connect = MagicMock()
    connection = connect.return_value.__enter__.return_value
    cursor = connection.cursor.return_value.__enter__.return_value
    cursor.fetchone.side_effect = [("Database-backed greeting",), ("002",)]
    monkeypatch.setenv("DATABASE_URL", "postgresql://example.invalid/palladium")
    monkeypatch.setenv("DATABASE_SCHEMA", "customer_one")
    monkeypatch.setattr("palladium.database.psycopg.connect", connect)

    status = read_status()

    assert status.message == "Database-backed greeting"
    assert status.schema_version == "002"
    connect.assert_called_once_with("postgresql://example.invalid/palladium", connect_timeout=3)


def test_database_status_rejects_an_unsafe_schema(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql://example.invalid/palladium")
    monkeypatch.setenv("DATABASE_SCHEMA", "public;drop schema public")

    with pytest.raises(RuntimeError, match="simple lowercase PostgreSQL identifier"):
        read_status()


def test_database_status_requires_seed_and_contract_rows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    connect = MagicMock()
    connection = connect.return_value.__enter__.return_value
    cursor = connection.cursor.return_value.__enter__.return_value
    cursor.fetchone.side_effect = [None, ("001",)]
    monkeypatch.setenv("DATABASE_URL", "postgresql://example.invalid/palladium")
    monkeypatch.delenv("DATABASE_SCHEMA", raising=False)
    monkeypatch.setattr("palladium.database.psycopg.connect", connect)

    with pytest.raises(RuntimeError, match="required seed data is missing"):
        read_status()


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
