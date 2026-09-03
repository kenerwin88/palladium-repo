# Schema delivery

Flyway Community owns migration ordering and schema history. The repository adds a deterministic,
reviewable plan and an execution rehearsal around it.

## What reviewers receive

`scripts/db/plan.sh` produces:

- `schema-plan.json`: target environment, hashed connection identity, database/schema name,
  source/run identity, pinned Flyway image, current version, schema-history fingerprint, full
  migration inventory and hashes, and ordered pending migrations;
- `schema-plan.json.sha256`: checksum of the complete plan; and
- `schema-plan.md`: the inventory plus the exact pending SQL in Flyway order.

On a pull request, `scripts/db/ci-proof.sh` first restores the merge-base migration set into disposable
PostgreSQL. It then applies the proposed set and appends a normalized `pg_dump --schema-only` diff to
the Markdown plan. The sticky **Database migration plan** PR comment links back to the authoritative
workflow run; the complete JSON, SQL, diff, and receipt remain downloadable artifacts named with the
run ID and attempt.

At production and each legacy pinned environment, the plan is generated against that exact target
with read-only plan credentials. The protected apply job downloads the reviewed plan and the
CI-produced migration bundle. `apply-plan.sh` regenerates the target contract immediately before
migration and fails closed if source, schema history, pending SQL, or any checksum differs.

## Authoring rules

1. Add one new file such as `V002__add_message_category.sql`. Never edit an applied file.
2. Make the first change backward compatible. Add nullable columns or new tables before requiring
   them; deploy compatible application code; backfill separately; remove old structures in a later
   release.
3. Use explicit SQL and deterministic ordering. Do not use Flyway placeholders, callbacks,
   out-of-order migrations, `repair`, Java migrations, or `skipExecutingMigrations` in this model.
   The guarded migration directory accepts only `V001__lower_snake_case.sql`-shaped regular files.
4. Keep large backfills out of a blocking schema migration. Give them a restartable, observable job
   and a separately reviewed operational plan.
5. Treat a failed migration as an incident. Preserve the failure evidence, correct the cause with a
   new migration, and roll forward. Do not mutate history to make validation green.

## Local commands

```bash
make dev       # PostgreSQL -> Flyway -> Flask -> Angular, all with health checks
make db-info   # current and pending Flyway state
make db-plan   # local target fingerprint, exact SQL, and hashes
make db-migrate
make db-reset  # destructive only to the disposable local Docker volume
```

The plan is intentionally not called a Flyway dry run. It cannot report data-dependent effects,
production cardinality, locks, execution time, engine query plans, or Flyway's own internal
history/locking statements. For those risks, clone representative sanitized data and run the same
migration bundle under production-like monitoring before approval.
