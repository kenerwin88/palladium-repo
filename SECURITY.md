# Security policy

Report vulnerabilities privately through GitHub Security Advisories. Do not open a public issue.

The delivery system uses GitHub OIDC and environment-scoped AWS roles. The only static cloud
credentials are temporary credentials used for the first account bootstrap; remove them as soon
as the workflow prints the OIDC role. Pull-request code never receives deployment credentials: CI
builds without privileges and trusted `workflow_run` code performs deployment. Same-repository PR
Terraform plans receive a separate read-only role so they can compare against real state; forks are
excluded and that role cannot mutate state, ECR, Lambda, IAM, logs, or alarms.
