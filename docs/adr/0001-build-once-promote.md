# ADR 0001: Build once and promote by digest

Status: accepted

## Decision

CI creates one OCI archive after application and infrastructure checks pass. Environment jobs load
that archive, push it once to a shared ECR repository, and deploy the resolved digest everywhere.
No environment recompiles application source.

Pull-request CI is unprivileged. Preview deployment uses a `workflow_run` workflow loaded from the
default branch, so PR-authored workflow changes cannot obtain AWS credentials. Fork previews are
skipped. Infrastructure code also comes from trusted `main`; only the already-scanned application
artifact comes from the pull request.

## Consequences

One registry makes artifact equality directly observable and removes cross-account copy ambiguity.
Environment isolation is provided by state keys, resources, concurrency, and GitHub protection. The
archive is larger than a source artifact, but it provides reproducible promotion and provenance.
CI artifacts live seven days; published releases remain tagged in ECR and carry a GitHub release
manifest and SBOM.
