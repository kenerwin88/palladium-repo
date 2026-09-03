# Legacy pinned environment runbook

1. Select a successfully published GitHub release; do not select a candidate, SHA, or branch.
2. Run **Pin legacy environment release**, enter its CalVer without prefixes, and provide the
   audit/change record.
3. Review the workflow summary. It verifies the GitHub release manifest digest against the shared
   ECR `release-<CalVer>` tag, verifies the immutable migration bundle, and shows the exact database
   and Terraform plans for the legacy environment.
4. An authorized reviewer approves the protected `legacy` environment.
5. Automation applies only that plan and verifies `/healthz` reports the selected version.
6. Attach the workflow URL, release manifest, reviewed schema plan, and schema deployment receipt to
   the audit record. The receipt includes the change record and before/after history fingerprints.

The legacy environment remains pinned until this procedure is intentionally repeated. Routine `main`
delivery does not touch it. Because release tags have no ECR expiry rule, cleanup cannot invalidate
its pin. Its database schema is monotonic: selecting an older application release does not reverse
migrations. Flyway validation therefore blocks a release whose migration bundle is not a superset of
the environment's applied history; promote the same or a newer compatible release instead of
downgrading the database.
