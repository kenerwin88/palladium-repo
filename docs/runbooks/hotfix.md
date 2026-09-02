# Hotfix runbook

1. Branch from current `main` and make the smallest safe forward fix.
2. Open a PR with the incident reference. Do not use a special branch type or bypass label.
3. Run the normal checks, review all three “if merged” Terraform plans, and verify the preview.
4. Obtain normal approval and squash through the merge queue.
5. Observe the same digest through development and staging; review and approve the exact production
   plan; verify production health.
6. Link the resulting CalVer release manifest from the incident record.

If impact cannot wait for this path, the incident commander may first use the application-only
[rollback runbook](rollback.md). The hotfix still follows every step above.
