# ADR 0002: Calendar version the service

Status: accepted

## Decision

Production releases use `YYYY.MM.DD.<GitHub CI run number>`. A release also records the OCI digest,
full Git SHA, GitHub run ID, and run attempt in a release manifest. Pull-request versions use
`pr-<number>-<short SHA>` and never become Git tags.

## Why not SemVer

This repository deploys an application continuously; it is not a package resolver choosing among
compatible versions. Deciding whether every internal change is “major” or “minor” adds ceremony
without giving operators useful information. The run number is monotonically unique, while the date
makes incidents and support conversations immediately legible.

A GitHub rerun keeps the same human CalVer because it is still the same source release, but gets a
new `run_attempt`, artifact name, and ECR candidate tag. An immutable release tag may be reused only
when it already resolves to the identical digest; otherwise delivery fails closed.

If a stable public API or SDK is introduced, it gets its own explicit compatibility contract and
SemVer lifecycle. That is independent of the service deployment identifier.
