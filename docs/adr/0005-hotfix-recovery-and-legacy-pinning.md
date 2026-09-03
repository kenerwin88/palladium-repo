# ADR 0005: One change path, roll-forward recovery, and legacy pinning

Status: accepted

## Decision

Hotfixes use the exact same short-lived branch, PR proof, squash merge, and environment promotion as
every other change. Urgency changes review priority, not controls. There is no hotfix branch or
direct deployment path.

Roll-forward is the default recovery strategy. The exceptional **Rollback** workflow is retained for
application incidents only: it switches the Lambda alias to a previously published function version
after protected approval. It never applies Terraform or claims to reverse stateful side effects.

A legacy pinned environment is a protected, manually managed audit target. An operator supplies a
published CalVer and change record. Automation verifies its release manifest against
`release-<CalVer>` in the same ECR, plans against that environment's state, records the diff, and
applies that exact plan after approval. It never follows `main` automatically and never rebuilds or
copies an image.
