"""Palladium Flask application factory."""

from pathlib import Path

from flask import Flask, send_from_directory
from flask.typing import ResponseReturnValue

from palladium.routes import api


def create_app(*, static_folder: Path | None = None) -> Flask:
    """Create an environment-neutral application instance."""
    resolved_static = Path(static_folder) if static_folder else Path(__file__).parents[2] / "static"
    app = Flask(__name__, static_folder=None)
    app.config.from_prefixed_env()
    app.register_blueprint(api)

    @app.get("/")
    @app.get("/<path:path>")
    def spa(path: str = "") -> ResponseReturnValue:
        """Serve Angular routes in the production image without affecting API routes."""
        requested = resolved_static / path
        if path and requested.is_file():
            return send_from_directory(resolved_static, path)
        index = resolved_static / "index.html"
        if index.is_file():
            return send_from_directory(resolved_static, "index.html")
        return ("Frontend is served separately during local development.", 200)

    return app
