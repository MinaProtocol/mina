# mina-graphql-mock

A canned-persona GraphQL server that mirrors the Mina daemon's GraphQL schema
shape but returns documented, deterministic responses. Intended for:

- Powering the interactive GraphQL playground in `MinaProtocol/docs2`.
- Functional tests that exercise GraphQL clients without needing a live daemon.
- Local development of tools (Rosetta, MCP server, explorer integrations) that
  consume daemon GraphQL.

This is **not** a daemon simulator. There is no chain, no ledger, no SNARK
machinery. Every query has a fixed answer; every mutation returns a
documented canned response without applying state changes.

## The persona

The mock represents a single canonical world, defined in [`persona.json`](./persona.json):

- **You are** block producer `B62qpge4uMq...` (Alice). The local node has been
  running for 2h 14m, blockchain length 4567, sync status `SYNCED`.
- **Three accounts** exist on chain: Alice (block producer, 1000 MINA),
  Bob (recipient, 10 MINA), Carol (delegate target, 0 MINA + delegated stake).
- **Five recent blocks** at heights 4563–4567, all produced by Alice for
  determinism, with one payment tx per block.
- **Mempool**: two transactions.
  - `5JuV3...pending` — payment Alice → Bob, 1 MINA, status `PENDING`.
  - `5JuV3...failed`  — payment Bob → Alice, 99999 MINA, status `INCLUDED`
    with failure `Source_insufficient_balance`.
- **One zkApp account** at `B62qzkapp...` with three-field app state and a
  pinned verification key (the `MyZkApp` example from the docs tutorials).

Every mutation returns a static synthetic transaction hash:

- `sendPayment` → `5JmoOck...payment`
- `sendDelegation` → `5JmoOck...delegation`
- `sendZkappCommand` → `5JmoOck...zkapp`

## Drift detection

The mock's schema is hand-written and parallel to `Mina_graphql.schema`. Two
checks in CI keep them honest, with **subset semantics** so the mock can grow
incrementally:

1. **Regeneration check** — `make update-mock-graphql` runs the
   `mina-mock-schema-dump` executable through the dune rule
   `(rule (target mock_schema.json) (mode promote) ...)` in the root `dune`
   file. The committed `mock_schema.json` must equal the regenerated output;
   `git diff --exit-code mock_schema.json` fails CI if a contributor edited
   the schema without re-dumping.
2. **Subset check** — `scripts/check-mock-schema-subset.py` verifies that
   every type, field, argument, input field, and enum value in
   `mock_schema.json` exists in `graphql_schema.json` with matching shape.
   The real schema is allowed to have extras. This catches "I added a field
   that doesn't exist in the real daemon" without forcing the mock to mirror
   the entire ~3600-line real schema upfront.

Both run in the **CheckMockGraphQLSchema** Buildkite step
(`buildkite/src/Jobs/Test/CheckMockGraphQLSchema.dhall`), modeled on the
existing `CheckGraphQLSchema` step that does the same thing for the real
schema.

### First-time setup

`mock_schema.json` is intentionally not committed in the initial scaffold —
it can only be generated once the OCaml builds. After the first successful
`dune build`:

```sh
make update-mock-graphql      # regenerates mock_schema.json
git add mock_schema.json
git commit -m "Add mock_schema.json baseline"
```

After that, every PR touching `src/test/daemon/graphql_mock/` (or
`src/lib/graphql/mina_graphql/`) re-runs both checks.

## Coverage (v0.1)

Hand-written resolvers cover the queries/mutations that `docs2` examples
exercise. Anything outside this list returns a documented GraphQL error
(`MOCK_NOT_IMPLEMENTED`).

| Query                       | Status       |
|-----------------------------|--------------|
| `daemonStatus`              | implemented  |
| `account(publicKey)`        | implemented  |
| `bestChain(maxLength)`      | implemented  |
| `pooledUserCommands`        | implemented  |
| `transactionStatus(hash)`   | implemented  |
| `block(stateHash)`          | TODO         |
| `version`                   | TODO         |

| Mutation                    | Status       |
|-----------------------------|--------------|
| `sendPayment`               | implemented  |
| `sendDelegation`            | implemented  |
| `sendZkappCommand`          | TODO         |

## Usage

Two binaries are produced, both packaged into `mina-test-suite.deb`:

| Binary                    | Purpose                                    |
|---------------------------|--------------------------------------------|
| `mina-graphql-mock`       | Long-running HTTP server (the actual mock) |
| `mina-mock-schema-dump`   | Introspect the schema, print JSON; used by the dune rule |

```sh
# Run the server (defaults to bundled persona.json relative to repo root)
mina-graphql-mock --port 3085

# Or from a dev tree
dune exec src/test/daemon/graphql_mock/graphql_mock.exe -- --port 3085

# Override the persona
mina-graphql-mock --port 3085 --persona /path/to/custom-persona.json

# Regenerate mock_schema.json (run after editing the schema)
make update-mock-graphql
```

The server listens for `POST /graphql` with `Content-Type: application/json`
or `application/graphql`, identical to the real daemon. Health probe at
`GET /health` returns `200 OK`.

## Extending

Adding a new query:

1. Define the resolver in `mock_resolvers/queries.ml` next to its peers.
2. Wire it into `Mock_schema.queries` list.
3. If a new GraphQL output type is needed, add it to `mock_types.ml`.
4. Add a row to the coverage table above and an entry to `persona.json` if
   the response references new persona data.
5. `dune build src/test/daemon/graphql_mock/mock_schema.json` to refresh the
   generated schema, then `git diff graphql_schema.json mock_schema.json` —
   any new diverged field is a hint that the real schema also needs the same
   shape (or your mock signature is off).

## Why a parallel schema instead of reusing `Mina_graphql.schema`?

`Mina_graphql.schema` is parameterized over the daemon's full runtime type
`Mina_lib.t`, which is a concrete OCaml type with ~30 wired-in subsystems
(mempool, network controller, ledger, transaction pool, daemon config…).
Reusing the schema would require either constructing a real `Mina_lib.t`
(weeks of work) or refactoring `Mina_graphql` upstream to accept a
module-type interface (a bigger change than the mock itself).

A parallel schema with hand-written resolvers is small, reviewable, and
caught at compile time when its shape drifts from the real schema (via the
`graphql_schema.json` ↔ `mock_schema.json` diff).
