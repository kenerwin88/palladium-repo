# Rollback runbook

Roll forward through the normal PR path whenever possible. Use **Rollback** only when an active
incident can be relieved more safely by immediately restoring a retained application version. It
does not revert Terraform, data migrations, configuration, or external side effects.

Before restoring an older image, confirm it is compatible with the current forward-only database
schema. If compatibility is uncertain, roll forward instead.

1. Identify the last healthy calendar version in GitHub Releases.
2. Run **Rollback**, select the affected environment, and enter the version without `v`.
3. Approve the protected environment job when prompted.
4. Confirm the workflow's `/healthz` response reports that version, then verify the user symptom.
5. Open a forward-fix pull request. Do not force-push or rewrite `main`.

The workflow verifies the immutable `release-<version>` ECR tag and retained Lambda version agree,
then moves only the Lambda `live` alias. Terraform is intentionally not run. This produces temporary
intentional alias drift; the required forward-fix release reconciles it. Production protection and
deployment concurrency still apply.
