# CI proof

CI is deliberately a ladder: each layer answers a different failure question, and delivery consumes
the already-proved artifact.

| Proof | What it establishes |
|---|---|
| Ruff formatting/lint + mypy | Python style and static contracts |
| pytest + Angular Vitest | Backend and frontend behavior in isolation |
| Flyway validate + PostgreSQL rehearsal | Migration history is valid and every pending SQL file executes in order |
| Migration hashes + schema dump diff | Reviewers see the exact SQL inputs and resulting DDL before merge |
| Plan-contract tamper test | Apply refuses a migration file changed after plan review |
| Prettier + Angular production build | Reproducible, budgeted browser bundle |
| Terraform format/validate + Trivy config | Valid IaC and no high/critical detected misconfiguration |
| zizmor + ShellCheck | Workflow and delivery-script safety |
| Dependency review | No newly introduced high-severity dependency advisory or denied license |
| CodeQL for Python and JS/TS | Semantic source vulnerability analysis |
| Production image Trivy scan | No detected high/critical fixed image vulnerability |
| CycloneDX SBOM + provenance attestation | Inventory and build-origin evidence |
| Container health + SPA deep link | The actual packaged Flask/Angular image boots and routes correctly |
| Preview Playwright, desktop + mobile | The deployed PR UI, API, console, and deep links behave together |
| Three PR Terraform plans | Visible “if merged” effect on each long-lived environment |
| Staging Playwright, desktop + mobile | The exact candidate behaves in a production-shaped environment |
| Production schema contract + Terraform plan | Target history still matches and only reviewed database/IaC inputs apply |
| Production smoke + release manifest | Approved plans ran, expected version is live, evidence is durable |

Fork PRs receive all unprivileged source checks but not a cloud preview or state-backed plan. A
same-repository PR receives only the dedicated read-only plan role. The deterministic CI checks—not
cloud availability—are branch requirements, so an AWS outage cannot prevent source recovery work.

The database proof intentionally exceeds `flyway info`: it executes the migration set against a
merge-base database. It is not the licensed Flyway dry-run feature and cannot predict production
data-dependent DML, lock duration, query plans, or Flyway internal history/locking statements.
