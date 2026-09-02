# Release manifest

Every production release attaches `release-manifest.json` and `palladium-sbom.cdx.json` to its
GitHub release. The manifest is the compact audit answer to “what source, run, attempt, image, plan,
and environment proof produced this release?” See the machine contract in
[`release-manifest.schema.json`](release-manifest.schema.json) and a representative instance in
[`examples/release-manifest.json`](examples/release-manifest.json).

The CalVer label is for people. The manifest's full Git SHA, CI and delivery run IDs and attempts, ECR digest,
SBOM checksum, Terraform state keys, exact production plan artifact name, and verified environment
URLs are the evidence. FLCM accepts only a release whose manifest digest equals the permanent ECR
release tag.

The first successful delivery creates the canonical manifest. A later delivery workflow rerun first
verifies that canonical source and digest, then appends a uniquely named
`release-manifest-delivery-<run-id>-a<attempt>.json`; it never overwrites audit evidence. FLCM uses
the canonical manifest while the appended files preserve the full execution history.
