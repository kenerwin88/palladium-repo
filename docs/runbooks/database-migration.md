# Database migration runbook

## Normal migration

1. Add a new forward-only SQL file under `database/migrations`; do not modify prior versions.
2. Run `make db-reset`, `make db-plan`, and `make check`.
3. Open a normal pull request. Review the sticky database-plan comment, exact ordered SQL, hashes,
   and rehearsed PostgreSQL schema diff alongside the application and Terraform changes.
4. Squash through the merge queue. The same migration bundle advances development and staging.
5. Review the production database plan and Terraform plan in the delivery summary. Approval applies
   those reviewed inputs, migrates before application deployment, validates the result, and records
   the before/after history fingerprints.
6. Keep the GitHub release manifest, migration bundle, schema plan, deployment receipt, and workflow
   URL as the audit record.

## Failure or recovery

- Before execution, a history or file mismatch aborts safely. Investigate drift; never use `repair`
  merely to bypass the guard.
- During execution, stop promotion. Preserve logs and inspect the Flyway history state. Correct the
  problem with a new, reviewed migration and follow the normal path.
- Do not run a database down migration. The protected Rollback workflow is application-only and is
  safe only while the older application remains compatible with the expanded schema.
- A hotfix receives no database exception: branch from `main`, add a forward migration if needed,
  pass the same proof, squash merge, and promote through every environment.

For high-volume DDL or backfills, add a change-specific runbook covering estimated rows, lock and
timeout behavior, restartability, monitoring queries, abort criteria, and the follow-up contraction.
