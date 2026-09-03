# ADR 0006: Forward-only database migrations with a reviewed Community plan

Status: accepted

## Context

Flyway Community executes and validates versioned SQL migrations, but the vendor dry-run output is a
licensed feature. `flyway info` is useful inventory; it is not an executable plan and must not be
presented as one. Database delivery also has a different recovery boundary from the stateless
application: a previous image can be selected again, but an applied schema migration cannot safely
be assumed reversible.

## Decision

All schema changes are immutable, forward-only `V<version>__<description>.sql` files in
`database/migrations`. Placeholder substitution, out-of-order execution, skipped execution, repair,
callbacks, and Java migrations are outside this reference model. Applied migration files are never
edited or deleted.

The repository builds its own review contract around Flyway Community:

1. run Flyway `validate` and collect `info -outputType=json`;
2. bind the database/schema name and a one-way connection fingerprint, then fingerprint the target
   schema history and every migration file;
3. emit ordered pending SQL, per-file SHA-256 values, an aggregate migration-set SHA-256, source SHA,
   run ID, and run attempt in machine-readable JSON and human-readable Markdown;
4. immediately before apply, regenerate that contract against the target and byte-compare its
   consequential fields with the approved plan;
5. run `migrate`, validate again, require zero pending migrations, and write a deployment receipt.

Pull-request CI additionally creates a disposable PostgreSQL database, migrates it to the merge-base
state, applies the proposed migration set, and publishes a normalized before/after schema dump diff.
This proves the actual Community migrations execute in order and exposes their resulting DDL.

Production and legacy-environment reviewers see both the exact Terraform plan and the database plan
before the protected apply job begins. Development, staging, and previews create and apply the same
contract without a manual gate. Preview schemas use `pr_<number>` and are removed only by guarded
cleanup.

Every environment uses the same migration bundle from the successful CI run. A production release
attaches that deterministic bundle, its checksum, the reviewed production schema plan, and the
deployment receipt. A legacy pinned environment verifies the bundle against the release manifest
before planning its own target-specific migration.

## Consequences

This approaches the useful review and audit properties of licensed dry-run output without claiming
feature parity. It does not predict database-engine internal statements, Flyway locking/history-table
statements, data-dependent DML results, query plans, lock duration, or production data volume effects.
Destructive or high-volume changes therefore require an explicit expand-and-contract sequence,
representative-data rehearsal, and an operational runbook.

Database rollback is not supported. Recovery is a new forward migration. The application-only
rollback workflow may select an older compatible image, which is why schema changes must remain
backward compatible through the deployment window.
