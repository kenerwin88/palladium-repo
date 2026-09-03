# GitHub repository setup

## Ruleset for `main`

Create a branch ruleset targeting the default branch with:

- pull requests required, one approval, stale approvals dismissed, and code-owner review required;
- required status checks `Backend`, `Frontend`, `Database`, `Terraform`, `Workflow security`,
  `Immutable artifact`, both `CodeQL` jobs, and `Dependency review`;
- merge queue required with **squash merge as the only enabled merge method** (disable merge commits
  and rebase merging);
- conversation resolution and linear history required;
- force pushes, deletions, direct pushes, and bypasses blocked;
- administrators included, with a separately audited emergency bypass role;
- **Automatically delete head branches** and auto-merge enabled at repository level.

The required workflows subscribe to `merge_group` as well as pull requests, so the queue tests the
synthetic merge commit rather than reusing stale branch evidence.

Do not require a preview deployment to merge: CI is the deterministic gate, while the preview is an
acceptance aid. Requiring cloud availability would turn an AWS incident into a source-control outage.

Replace the example teams in `.github/CODEOWNERS` with real organization teams before enabling its
rule. Keep platform ownership on `.github/` and `terraform/`; application teams own their directories.

## Environments

Create `development`, `preview`, `staging`, `production`, `plan`, and `legacy`. Add these variables using the
values printed by **Platform bootstrap**:

| Variable | Example |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/palladium-github-development` |
| `AWS_REGION` | `us-east-2` |
| `ECR_REPOSITORY` | `palladium` |
| `TF_STATE_BUCKET` | `palladium-123456789012-us-east-2-tfstate` |

When database delivery is enabled, add these values to each deploy environment:

| Name | Kind | Purpose |
|---|---|---|
| `DATABASE_SCHEMA` | variable | Stable schema name; defaults to `palladium` |
| `FLYWAY_URL` | secret | JDBC PostgreSQL URL reachable from the runner |
| `FLYWAY_USER` | secret | Migration principal for that environment |
| `FLYWAY_PASSWORD` | secret | Migration-principal credential |

The `preview` environment points at the preview database; automation ignores `DATABASE_SCHEMA` and
uses isolated `pr_<number>` schemas. The close workflow and TTL reaper can clean only names matching
that shape. Development, staging, production, and the legacy environment should use separate
databases or separately owned schemas and separate migration principals. Do not give the application
runtime schema-owner credentials.

The `plan` environment also needs target-specific, read-only connection secrets so approval shows the
actual target history without granting write access:

| Secret | Target |
|---|---|
| `FLYWAY_PRODUCTION_URL`, `FLYWAY_PRODUCTION_USER`, `FLYWAY_PRODUCTION_PASSWORD` | production |
| `FLYWAY_LEGACY_URL`, `FLYWAY_LEGACY_USER`, `FLYWAY_LEGACY_PASSWORD` | legacy environment |

Add `DATABASE_SCHEMA` and `LEGACY_DATABASE_SCHEMA` variables to `plan` with the corresponding target
schema names. The plan principal needs only connectivity and read access to catalog metadata, the
target schema, and Flyway's history table. The deploy principal needs the narrowly scoped DDL/DML
rights required by reviewed migrations. Prefer short-lived identity-issued database credentials when
the platform supports them; this portable example uses environment secrets because database IAM
integration is platform-specific.

For production, require at least one reviewer, prevent self-review, restrict deployments to `main`,
and use a small wait timer only if the organization needs a scheduled change window. Staging should
remain automatic; otherwise approval fatigue begins before the consequential production decision.

All six environments must contain the same `AWS_REGION`, `ECR_REPOSITORY`, and `TF_STATE_BUCKET`.
There is one ECR repository for the entire system. `preview`, `development`, `staging`, `production`,
and `legacy` use their matching environment-scoped deploy role. `plan` alone uses the bootstrap output `plan_role_arn`, which can read
state and cloud resources but cannot apply changes. Protect `legacy` like production and require the
operator to supply a change-record identifier.

After all environments and variables exist, create the repository variable
`DEPLOYMENTS_ENABLED=true`. This is the final commissioning switch for automatic previews and the
development-to-production delivery path. Leave it unset while copying or experimenting with this
example so green CI is not obscured by predictable missing-AWS-configuration failures.

Create `DATABASE_DEPLOYMENTS_ENABLED=true` only after every runner can reach its target PostgreSQL
endpoint and the environment values above have been tested. Leaving it unset retains all local and CI
rehearsal proof while skipping persistent-environment schema changes. Flyway images and migration
bundles remain identical across environments; credentials and schema selection are runtime inputs.

Build provenance attestations are automatic for public repositories. For a private organization
repository whose GitHub plan supports artifact attestations, create the repository variable
`ATTESTATIONS_ENABLED=true`. Leave it unset for user-owned private repositories, where GitHub does
not provide attestation persistence; the signed workflow run, immutable artifact, digest, SBOM, and
release manifest still provide the delivery evidence chain.

CodeQL always performs both Python and JavaScript/TypeScript analysis and preserves each SARIF result
as a 14-day workflow artifact. Public repositories also publish those results to GitHub code
scanning automatically. For a private organization repository with GitHub Advanced Security, set
`GHAS_ENABLED=true` after enabling code scanning. That publishes CodeQL results as alerts and uses
GitHub's dependency-diff and license review. Without GHAS, CodeQL still analyzes and retains SARIF,
while the stable `Dependency review` check performs a full Trivy scan of the repository lockfiles.

Limit Actions to selected actions and reusable workflows. Every action in this example is pinned to
a full commit SHA; enforce that through organization policy. Dependabot keeps those pins fresh.
Grant the default workflow token read-only access. Each workflow declares its narrow write permissions.

## Operational ownership

- The platform team owns failed delivery or drift workflows.
- The change author owns failed CI and preview acceptance.
- The incident commander normally chooses roll-forward. The protected `Rollback` workflow is an
  exceptional application-only alias restore to a prior GitHub release version.
- Preview spend has two cleanup paths: PR close and the daily TTL reaper.
