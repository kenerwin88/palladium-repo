# Contributing

This repository practices trunk-based development. `main` is the only permanent branch and is
always releasable. Create a short-lived branch, open a pull request early, use a feature flag for
incomplete behavior, and merge through the queue after the required checks pass.

Name branches `<type>/<issue>-<short-description>` when an issue exists—for example
`fix/184-health-timeout`. The name is for navigation only; the squash-merged PR title becomes history.

## Normal change

1. Run `make setup` once and `make dev` while working.
2. Keep the branch under one day old; rebase on `main` instead of creating integration branches.
3. Run `make check`, push, and exercise the PR preview linked by the bot.
4. Use squash merge. The merge automatically promotes one artifact through all environments.

The repository automatically deletes a branch after its squash merge. Do not reuse merged branches;
start the next change from current `main`.

## Hotfixes and recovery

A hotfix is a small, urgent normal change—not a second delivery system. Branch from `main`, open a
PR, satisfy the same proof, squash through the merge queue, and promote through development,
staging, the production plan, and production approval. There are no `hotfix/*` exceptions, direct
production builds, skipped tests, cherry-picks, or manual cloud deployments.

Prefer a forward fix even during an incident. If immediate application restoration is safer than
waiting for a fix, an incident commander may run the protected **Rollback** workflow. It only moves
the Lambda `live` alias to a retained published version; it never runs Terraform, reverts data, or
changes infrastructure. A forward-fix PR is still required.

Do not commit secrets, generated build output, Terraform state, environment-specific application
builds, or long-lived cloud credentials. Do not deploy from a laptop.

## Commit and PR shape

Prefer a PR that can be reviewed in under 20 minutes. Separate refactors from behavioral changes.
Use Conventional Commit-style PR titles (`feat:`, `fix:`, `chore:`, `docs:`); squash merging turns
that title into the permanent history and produces useful release notes.
