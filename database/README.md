# Database migrations

Flyway owns the PostgreSQL schema history in this directory. Migrations are immutable, ordered,
forward-only SQL files using `V<version>__<description>.sql` names. After a migration reaches any
shared environment, never edit, rename, delete, or reorder it; add another migration instead.

The repository uses Flyway Community. Rather than pretending that `info` is an executable plan, the
pipeline creates a schema review bundle containing:

- Flyway's target-specific pending migration inventory;
- the exact ordered SQL files and their SHA-256 hashes;
- a fingerprint of the target's current Flyway history;
- an aggregate hash of the complete migration set; and
- a normalized PostgreSQL schema diff produced by actually applying the pending files to a
  disposable database built from the merge base.

Before a shared database is migrated, automation regenerates the plan and compares the target
history, pending set, and migration-set hash with the reviewed artifact. Flyway then validates and
migrates while holding its normal database lock.

Placeholders, callbacks, Java migrations, `repair`, `clean`, and out-of-order migration are disabled
on the delivery path. Those constraints make the reviewed SQL files the application statements that
Flyway will execute. Flyway's internal locking and schema-history statements are intentionally not
represented in the bundle.

The delivery wrapper rejects symlinks, subdirectories, callbacks, repeatable/undo files, and any
filename outside the fixed `V001__lower_snake_case.sql` convention before Flyway starts.

Application code never queries `flyway_schema_history`, which is a tool-owned implementation detail.
The sample API instead reads an application-owned schema-contract marker created by the migration;
future incompatible contract changes update that marker explicitly.
