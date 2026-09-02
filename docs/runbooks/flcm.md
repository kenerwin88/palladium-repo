# FLCM release pinning runbook

1. Select a successfully published GitHub release; do not select a candidate, SHA, or branch.
2. Run **Pin FLCM release**, enter its CalVer without prefixes, and provide the audit/change record.
3. Review the workflow summary. It verifies the GitHub release manifest digest against the shared
   ECR `release-<CalVer>` tag and shows the exact FLCM Terraform plan.
4. An authorized reviewer approves the protected `flcm` environment.
5. Automation applies only that plan and verifies `/healthz` reports the selected version.
6. Attach the workflow URL and release manifest to the audit record.

FLCM remains pinned until this procedure is intentionally repeated. Routine `main` delivery does not
touch it. Because release tags have no ECR expiry rule, an FLCM pin is not invalidated by cleanup.
