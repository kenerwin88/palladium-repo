# ADR 0003: Automatic lower environments, approved production

Status: accepted

## Decision

A successful merge to `main` automatically deploys and smoke-tests development, then staging. The
same workflow proceeds to a protected `production` GitHub Environment, where a production owner
reviews the already-generated Terraform diff and approves or rejects it. The protected job applies
that exact binary plan. There are no cherry-picks or environment branches.

## Consequences

Staging reflects the next production candidate rather than becoming a manually curated museum.
Production preserves separation of duties. Because deployments serialize per environment, a slow
release cannot be overtaken by a newer one. A rejected production job leaves the artifact available
for inspection; the next merge starts a new candidate.

Legacy pinned environments are not on the automatic path. Each pins an operator-selected,
already-published release after a separate exact plan, protected approval, and change-record entry.
They never build an artifact.
