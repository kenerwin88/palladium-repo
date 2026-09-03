"""HTTP endpoints that demonstrate deploy-time metadata and health behavior."""

import os
from datetime import UTC, datetime

from flask import Blueprint, jsonify
from flask.typing import ResponseReturnValue

from palladium.database import read_status

api = Blueprint("api", __name__)


def runtime_metadata() -> dict[str, str]:
    """Return non-secret metadata useful for smoke tests and support."""
    return {
        "environment": os.getenv("APP_ENV", "local"),
        "version": os.getenv("APP_VERSION", "dev"),
    }


@api.get("/healthz")
def health() -> ResponseReturnValue:
    """Keep the platform health check cheap and dependency-free."""
    return jsonify(status="ok", **runtime_metadata()), 200


@api.get("/api/greeting")
def greeting() -> ResponseReturnValue:
    """Return a tiny example payload for the Angular UI."""
    database = read_status()
    return (
        jsonify(
            database_schema_version=database.schema_version,
            message=database.message,
            generated_at=datetime.now(UTC).isoformat(),
            **runtime_metadata(),
        ),
        200,
    )
