# External modules

This folder consists of all external dependencies to our dhall framework. In order to preserve network throughput and protect ourselves from intermitted network failure or various protection in
github from too many requests

### Automated update (recommended)

Use the updater script from the repo root:

```
./buildkite/scripts/dhall/update_external_deps.sh
```

Examples:

```
# Update both Prelude and Buildkite (defaults)
./buildkite/scripts/dhall/update_external_deps.sh

# Update Prelude only (optional repo + version override)
./buildkite/scripts/dhall/update_external_deps.sh --only prelude --prelude-repo dhall-lang/dhall-lang --prelude-version v15.0.0

# Update Buildkite only (override S3 release version)
./buildkite/scripts/dhall/update_external_deps.sh --only buildkite --buildkite-release 0.0.1
```

### Prelude

Prelude module contains dhall standard library.
Current version is v15.0.0.

### Buildkite

Buildkite module contains all buildkite bindings which serves the purpose of delivering buildkite primitives which we are using to express pipelines and steps in dhall.

We are hosting them at: s3://dhall.packages.minaprotocol.com/buildkite/releases. Newest version 0.0.1.
