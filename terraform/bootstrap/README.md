# Platform bootstrap

Run this stack once in the shared deployment AWS account through the `Platform bootstrap` GitHub
Actions workflow. It creates the encrypted Terraform state bucket, the one immutable ECR repository
used by every environment, one least-privilege deployment role per environment, and a separate read-only planning role.
Terraform state keys and named resources isolate environments without copying the artifact.

The first run uses short-lived bootstrap credentials because trust cannot create itself. The
workflow first creates the state bucket locally, activates `backend.tf.example`, migrates its own state into that bucket, and then
creates OIDC. Delete the bootstrap credentials from GitHub immediately afterward; all subsequent
deployments use keyless OIDC.
