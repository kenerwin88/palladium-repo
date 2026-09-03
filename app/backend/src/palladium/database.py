"""Small PostgreSQL adapter used to prove that the Flyway-managed schema is live."""

import os
import re
from dataclasses import dataclass

import psycopg
from psycopg import sql

DEFAULT_MESSAGE = "Your trunk is healthy and ready to ship."


@dataclass(frozen=True)
class DatabaseStatus:
    """Non-secret database metadata safe to expose in a demo response."""

    message: str
    schema_version: str


def read_status() -> DatabaseStatus:
    """Read the example row and Flyway version, or use a local-free fallback."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return DatabaseStatus(message=DEFAULT_MESSAGE, schema_version="not-configured")
    schema = os.getenv("DATABASE_SCHEMA", "public")
    if re.fullmatch(r"[a-z][a-z0-9_]*", schema) is None:
        raise RuntimeError("DATABASE_SCHEMA must be a simple lowercase PostgreSQL identifier")

    with (
        psycopg.connect(database_url, connect_timeout=3) as connection,
        connection.cursor() as cursor,
    ):
        cursor.execute(
            sql.SQL(
                "SELECT message_text FROM {}.application_message WHERE message_key = 'home'"
            ).format(sql.Identifier(schema))
        )
        message_row = cursor.fetchone()
        cursor.execute(
            sql.SQL(
                "SELECT metadata_value FROM {}.application_metadata "
                "WHERE metadata_key = 'schema_contract_version'"
            ).format(sql.Identifier(schema))
        )
        version_row = cursor.fetchone()

    if message_row is None or version_row is None:
        raise RuntimeError("Flyway schema is present but its required seed data is missing")
    return DatabaseStatus(message=str(message_row[0]), schema_version=str(version_row[0]))
