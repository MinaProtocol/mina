# Mina Tests

This document describes the different kinds of tests that exist in the Mina codebase and how to run them.

## Table of Contents

- [Overview](#overview)
- [Unit Tests](#unit-tests)
  - [Inline Tests](#inline-tests)
  - [Standalone Test Executables](#standalone-test-executables)
  - [Profile-dependent Tests](#profile-dependent-tests)
  - [PPX Tests](#ppx-tests)
  - [ZkApps Examples Unit Tests](#zkapps-examples-unit-tests)
  - [Archive Node Unit Tests](#archive-node-unit-tests)
- [Command-line / Single-node Tests](#command-line--single-node-tests)
- [Integration Tests (Lucy)](#integration-tests-lucy)
- [End-to-end Tests](#end-to-end-tests)
  - [Rosetta Tests](#rosetta-tests)
  - [Replayer Test](#replayer-test)
  - [Fuzzy ZkApp Tests](#fuzzy-zkapp-tests)
- [Coverage Testing](#coverage-testing)
- [Running Tests in CI](#running-tests-in-ci)

---

## Overview

The Mina codebase has several categories of tests that range from fast in-process unit tests to full end-to-end integration tests that spin up a real network of nodes. The table below gives a high-level view:

| Category | Scope | Can run locally? | Tool |
|---|---|---|---|
| Inline unit tests | Single library | ✅ | `dune runtest` |
| Standalone test executables | One or more libraries | ✅ | `dune runtest` |
| Profile-dependent tests | One or more libraries | ✅ | `dune runtest` |
| PPX tests | `ppx_mina` extension | ✅ | `make test-ppx` |
| ZkApps examples unit tests | `zkapps_examples` app | ✅ (nightly in CI) | `dune runtest` |
| Archive node unit tests | `archive` app | ✅ (needs PostgreSQL) | `dune runtest` |
| Command-line / single-node tests | Daemon CLI | ✅ (needs app built) | `mina-command-line-tests` |
| Integration tests (Lucy) | Full multi-node network | ✅ (needs Docker) | `mina-test-executive` |
| Rosetta tests | Rosetta API + daemon | ⚠️ (CI recommended) | custom scripts |
| Replayer test | Archive replayer | ⚠️ (needs PostgreSQL) | `mina-replayer` |
| Fuzzy ZkApp tests | ZkApp logic | ✅ | `dune exec` |
| Coverage tests | Unit tests with coverage | ✅ | `make test-coverage` |

---

## Unit Tests

### Inline Tests

The most common form of testing. Many OCaml library modules include inline tests written with [`ppx_inline_test`](https://github.com/janestreet/ppx_inline_test). These are declared with `let%test`, `let%test_unit`, or `let%test_module` inside the source files, and are compiled and run by dune when the `(inline_tests ...)` stanza is present in the library's `dune` file.

**Run all unit tests under `src/lib`:**

```bash
dune runtest src/lib --profile=dev
```

**Run unit tests for a specific library:**

```bash
dune runtest src/lib/<library-name> --profile=dev
```

**Run a single inline test case** (using the helper script):

```bash
./scripts/testone.sh src/lib/<library-name>/<file>.ml [<test-name>]
```

**Tips:**
- The default build profile is `dev`. Use `--profile=devnet` or `--profile=mainnet` when you need a profile that matches a deployed network.
- Set `DUNE_PROFILE` in the environment to avoid repeating `--profile=...` on every command.
- Dune caches test results; use `--force` to re-run all tests even if sources have not changed.
- Running tests modifies resource limits: the scripts typically call `ulimit -s 65532` and `ulimit -n 10240`.
- On retry after failure, dune will only re-run the failing tests, which saves time.

### Standalone Test Executables

Some tests are compiled as standalone executables (using the dune `(tests ...)` or `(executable ...)` stanza) and are also invoked via `dune runtest`. This includes tests in `src/test/archive/` and `src/lib/` subdirectories that have their own `tests/` folder.

These are run the same way as inline tests:

```bash
dune runtest src/test/archive --profile=dev
```

To run tests for a whole subtree:

```bash
dune runtest src/ --profile=dev
```

### Profile-dependent Tests

Some tests have expected values that vary depending on the build profile (e.g. `dev`, `devnet`, `lightnet`, `mainnet`). These tests must be run once per profile that you want to validate.

**Run profile-dependent tests:**

```bash
export DUNE_PROFILE=dev   # or devnet, lightnet, mainnet
dune build --force src/lib/node_config   # rebuild node_config for the chosen profile
dune runtest \
    src/lib/blockchain_snark/tests \
    src/lib/transaction_snark/test/constraint_count \
    src/lib/transaction_snark/test/print_transaction_snark_vk
```

In CI these are run for each profile separately by `buildkite/scripts/profile-dependent-tests.sh`.

### PPX Tests

The `ppx_mina` preprocessor extension has its own test suite that verifies that the PPX behaves correctly (e.g. that `[@@deriving version]` attributes compile or fail in expected ways).

```bash
make test-ppx
```

This runs `make` inside `src/lib/ppx_mina/tests/`.

### ZkApps Examples Unit Tests

The `src/app/zkapps_examples` application contains runnable ZkApp examples that double as integration-style unit tests. In CI these only run during nightly builds (`NIGHTLY=true`), but they can be run locally at any time:

```bash
dune build --profile=dev src/app/zkapps_examples
dune runtest --profile=dev src/app/zkapps_examples
```

### Archive Node Unit Tests

The archive application (`src/app/archive`) has its own unit test suite that requires a running PostgreSQL instance.

**Prerequisites:** PostgreSQL must be installed and a test database must be created. The helper script `buildkite/scripts/setup-database-for-archive-node.sh` will configure it:

```bash
source ./buildkite/scripts/setup-database-for-archive-node.sh <user> <password> <db>
```

This sets the `MINA_TEST_POSTGRES` environment variable. After setup:

```bash
dune runtest src/app/archive --profile=dev
```

In CI this is handled by `buildkite/scripts/tests/archive-node-unit-tests.sh`.

---

## Command-line / Single-node Tests

The `mina-command-line-tests` binary (`src/test/command_line_tests/`) tests the Mina daemon CLI in a single-node configuration. The test runner uses `mina_automation`, which automatically locates the Mina daemon binary — first in `_build/default/` (local build), then in system paths such as `/usr/local/bin`.

**Build and run locally:**

```bash
# Build the daemon and the test runner
dune build src/app/cli/src/mina.exe src/test/command_line_tests/command_line_tests.exe --profile=dev

# Run all tests
export MINA_LIBP2P_PASS="naughty blue worm"
export MINA_PRIVKEY_PASS="naughty blue worm"
./_build/default/src/test/command_line_tests/command_line_tests.exe test -v
```

In CI this is handled by `buildkite/scripts/single-node-tests.sh`, which installs the `mina-test-suite` and `mina-testnet-generic-lightnet` debian packages and then runs `mina-command-line-tests test -v`.

---

## Integration Tests (Lucy)

"Lucy" is Mina's end-to-end integration testing framework. It spins up a complete multi-node Mina testnet using Docker Swarm and runs test logic against the live network.

Lucy tests are found in `src/app/test_executive/` and use a custom OCaml DSL defined in `src/lib/integration_test_lib/`. See [`src/app/test_executive/README.md`](../src/app/test_executive/README.md) for the full guide.

**Prerequisites:**
- Docker with Swarm mode enabled (`docker swarm init --advertise-addr 127.0.0.1`)
- A `mina-daemon` Docker image URL
- A `mina-archive` Docker image URL

**Compile from source and run locally (recommended for development):**

```bash
make build
dune build src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
```

The compiled binaries will be at:
- `./_build/default/src/app/test_executive/test_executive.exe`
- `./_build/default/src/app/logproc/logproc.exe`

You can add optional shell aliases for convenience (in `~/.bashrc` or `~/.bash_aliases`):

```bash
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe
```

Then run a test the same way as with the installed binary:

```bash
export TEST_NAME=<test>
export MINA_IMAGE=<url-to-mina-daemon-image>
export ARCHIVE_IMAGE=<url-to-mina-archive-image>

test_executive docker "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --debug \
  | tee "$TEST_NAME.local.test.log" \
  | logproc -i inline -f '!(.level in ["Spam", "Debug"])'
```

**Alternatively, install the `mina-test-executive` debian package:**

```bash
echo "deb [trusted=yes] http://packages.o1test.net $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/o1.list
apt-get update && apt-get install -y mina-test-executive
```

Then invoke the installed binary directly:

```bash
mina-test-executive docker "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --debug \
  | tee "$TEST_NAME.local.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Spam", "Debug"])'
```

**Available tests** (as of this writing):

| Test name | Branch |
|---|---|
| `peers-reliability` | all |
| `chain-reliability` | all |
| `payments` | all |
| `delegation` | all |
| `archive-node` | `compatible` |
| `gossip-consis` | all |
| `medium-bootstrap` | all |
| `block-prod-prio` | all |
| `zkapps` | `develop` |
| `zkapps-timing` | `develop` |
| `snarkyjs` | `develop` |

In CI the integration tests are driven by `buildkite/scripts/run-test-executive-docker.sh`. The `--debug` flag keeps the testnet alive after the test completes, which is useful for post-mortem inspection of node logs via `docker logs`.

#### Native engine (no Docker)

The `native` engine runs the same tests against bare `mina` / `mina-archive`
binaries on the host instead of Docker containers. Here `--mina-image` /
`--archive-image` are paths to those binaries rather than image identifiers:

```bash
mina-test-executive native "$TEST_NAME" \
  --mina-image /usr/local/bin/mina \
  --archive-image /usr/local/bin/mina-archive
```

Tests that run archive nodes need a PostgreSQL **server**. The engine does not
start one; it connects to the server given by `--postgres-uri` (env
`MINA_TEST_POSTGRES_URI`, default `postgres://postgres:password@127.0.0.1:5432`)
and, for each archive node, **creates a per-test `test_archive_<id>` database**
on that server, loads the archive schema into it, and **drops it** when the node
stops. The flag is optional and only relevant for archive tests — tests without
archive nodes never touch PostgreSQL, so the default is fine for them.

In CI the native engine is driven by
`buildkite/scripts/run-test-executive-native.sh`, which starts the environment's
PostgreSQL server before invoking the test.

---

## End-to-end Tests

### Rosetta Tests

The Rosetta API has multiple test suites:

1. **Indexer test** — Validates that the Rosetta indexer produces correct output. Requires a running PostgreSQL instance with archive data (`$PG_CONN`):

   ```bash
   mina-rosetta-indexer-test --archive_uri "$PG_CONN"
   ```

   In CI this is handled by `buildkite/scripts/rosetta-indexer-test.sh`.

2. **Block race test** — Races the Mina daemon, archive, and Rosetta to check for block consistency under load. Requires the daemon, archive, and Rosetta binaries and a PostgreSQL connection:

   ```bash
   ./scripts/rosetta/test-block-race.sh \
     --mina-exe /usr/local/bin/mina \
     --archive-exe /usr/local/bin/mina-archive \
     --rosetta-exe /usr/local/bin/mina-rosetta \
     --postgres-uri "$PG_CONN" \
     --ledger <path-to-ledger>
   ```

   In CI this is handled by `buildkite/scripts/tests/rosetta-block-race-test.sh`.

3. **Rosetta integration tests** — Spins up a daemon with archive and Rosetta and runs end-to-end API validation. Requires all Mina service binaries and a PostgreSQL instance. In CI this is handled by `buildkite/scripts/tests/rosetta-integration-tests.sh`.

### Replayer Test

The archive replayer (`mina-replayer`) replays historical blockchain transactions against an archive database and verifies that the resulting ledger state matches expectations.

**Prerequisites:** A PostgreSQL instance with archive data and `$PG_CONN` set to the connection URI.

```bash
./scripts/replayer-test.sh \
  -i src/test/archive/sample_db/replayer_input_file.json \
  -p "$PG_CONN" \
  -a mina-replayer
```

In CI this is handled by `buildkite/scripts/replayer-test.sh`.

### Fuzzy ZkApp Tests

Property-based / fuzzy tests for ZkApp transaction logic. These run a ZkApp transaction generator with a random seed and validate the results.

```bash
dune exec <path-to-fuzzy-test-exe> --profile=<profile> \
  -- --timeout <seconds> \
     --individual-test-timeout <seconds> \
     --seed $RANDOM
```

The exact path and profile are configured per CI step; see `buildkite/scripts/fuzzy-zkapp-test.sh` for the invocation used in CI.

---

## Coverage Testing

To measure code coverage of the unit test suite, use the bisect_ppx-instrumented test run:

**Run all unit tests with coverage instrumentation:**

```bash
make test-coverage
```

This calls `scripts/create_coverage_profiles.sh`, which runs:

```bash
dune runtest --instrument-with bisect_ppx --force src/lib --profile=dev
```

**Run coverage for a specific library only:**

```bash
scripts/create_coverage_profiles.sh <library-name>
```

**Generate reports after running tests with coverage:**

```bash
# HTML report
make coverage-html
# open _coverage/index.html in a browser

# Text summary
make coverage-summary
```

---

## Running Tests in CI

The CI system (Buildkite) runs tests automatically on each pull request. The following environment variables influence test behaviour:

| Variable | Description |
|---|---|
| `DUNE_PROFILE` | Dune build profile (`dev`, `devnet`, `lightnet`, `mainnet`). Defaults to `dev`. |
| `NPROC` | Number of parallel jobs for `dune runtest`. Defaults to the number of logical CPU cores. |
| `ERROR_ON_PROOF` | Set to `true` in CI to fail if proof cache needs updating. |
| `NIGHTLY` | Set to `true` to enable nightly-only tests (e.g. ZkApps examples). |
| `MINA_LIBP2P_PASS` | Passphrase for libp2p keys used during tests. |
| `MINA_PRIVKEY_PASS` | Passphrase for private keys used during tests. |
| `PG_CONN` | PostgreSQL connection URI for tests that require an archive database. |

Some tests are designed to run exclusively in CI because they require large amounts of resources, cloud credentials, or specific infrastructure (e.g. Docker Swarm, pre-built Debian packages). These include the Rosetta integration tests, the archive upgrade test, and the Debian upgrade test.

Tests that can be run locally are primarily unit tests (via `dune runtest`) and integration tests via Lucy (provided Docker is installed and a suitable daemon image is available).
