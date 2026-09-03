# ADR 0004: Artifact naming and one-repository retention

Status: accepted

## Decision

All environments pull digest-addressed images from one immutable ECR repository. Names encode their
purpose, not their destination:

| Name | Meaning | Retention |
|---|---|---|
| `deployable-<run-id>-<run-attempt>` | GitHub Actions archive + SBOM | 7 days |
| `database-migrations-<run-id>-<run-attempt>` | Exact CI migration input | 14 days; copied into a release when production succeeds |
| `schema-plan-<run-id>-<run-attempt>` | PR plan, hashes, rehearsal diff, and receipt | 14 days |
| `schema-deployment-<environment>-<run-id>-<run-attempt>` | Lower-environment plan/apply evidence | 14 days |
| `production-plan-<run-id>-<run-attempt>` | Exact Terraform and schema plans awaiting approval | 7 days; consequential schema evidence is copied into the release |
| `legacy-schema-deployment-<run-id>-<run-attempt>` | Legacy-environment receipt tied to a change record | 90 days and attached to the external audit record |
| `preview-pr-<n>-run-<run-id>-a<attempt>` | Temporary push handle | Removed after deploy; untagged digest expires after 14 days |
| `candidate-<CalVer>-run-<run-id>-a<attempt>` | One digest moving through dev/stage/prod | Removed after release; abandoned candidates expire after 30 days |
| `release-<CalVer>` | Audited production release and legacy-environment pin | Indefinite; no lifecycle rule matches it |
| `v<CalVer>` | GitHub release/tag | Indefinite under repository retention policy |

The runtime always receives an `@sha256:...` URI. Tags are lookup and audit labels, never deployment
identity. Once a release tag exists, it may identify only that digest.

## Reruns

GitHub `run_id` identifies the logical CI run and `run_attempt` identifies its execution. Including
both prevents artifact conflicts and makes partial job reruns unambiguous. CalVer retains the CI run
number because humans can map it directly to the source pipeline; the manifest carries the run ID,
attempt, SHA, digest, plan, SBOM checksum, and environment verification.

Delivery reruns append `release-manifest-delivery-<run-id>-a<attempt>.json` to the GitHub release.
The original canonical manifest is verified and preserved, never overwritten. Published releases
also retain `database-migrations.tar.gz`, `production-schema-plan.json`, and
`schema-deployment.json`; their hashes are fields in the canonical manifest.

ECR lifecycle matching is intentionally disjoint. Production removes the candidate tag after adding
the permanent release tag, avoiding multi-tag lifecycle surprises. Preview tags are removed after
deployment, and a 14-day tagged rule exists only as cleanup failure insurance.
