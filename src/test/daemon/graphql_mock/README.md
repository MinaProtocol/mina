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
- `sendZkapp` → `5JmoOck...zkapp`

## Drift detection

The mock's schema is parallel to `Mina_graphql.schema`, except the
`daemonStatus` subtree, which is the daemon's own
`Mina_graphql.Types.Make_daemon_status` functor instantiated over the mock
context and so cannot drift.

The rest is kept honest by a **subset check**:
`scripts/check-mock-schema-subset.py` verifies that every type, field,
argument, input field, and enum value in the mock's introspection exists in
`graphql_schema.json` with matching shape. The real schema may have extras,
so the mock does not have to mirror the whole real schema.

`make build-mock-graphql` writes the introspection to
`_build/default/mock_schema.json` through the rule in the root `dune` file
(it is not committed). The **CheckMockGraphQLSchema** Buildkite step
(`buildkite/src/Jobs/Test/CheckMockGraphQLSchema.dhall`) builds it and runs
the subset check on every change to `src/test/daemon/graphql_mock/` or
`src/lib/graphql/mina_graphql/`.

## Coverage

A query or mutation the mock does not define fails GraphQL validation, as an
unknown field would on the real daemon.

| Queries |
|---------|
| `syncStatus`, `daemonStatus`, `version`, `timeOffset`, `networkID`, `signatureKind` |
| `account`, `wallet`, `accounts`, `tokenAccounts`, `tokenOwner` |
| `bestChain`, `block`, `genesisBlock`, `protocolState` |
| `transactionStatus`, `pooledUserCommands`, `snarkPool` |
| `genesisConstants`, `runtimeConfig`, `blockchainVerificationKey`, `threadGraph` |
| `currentSnarkWorker`, `trustStatus`, `trustStatusAll` |

| Mutations |
|-----------|
| `sendPayment`, `sendDelegation`, `sendZkapp` |
| `setSnarkWorker`, `setSnarkWorkFee`, `setCoinbaseReceiver` |
| `lockAccount`, `unlockAccount`, `startFilteredLog` |

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

# Build the introspection into _build/default/mock_schema.json
make build-mock-graphql
```

The server listens for `POST /graphql` with `Content-Type: application/json`
or `application/graphql`. Health probe at `GET /health` returns `200 OK`.

## Extending

Adding a new query:

1. Define the resolver in `mock_schema.ml` and add it to the `queries` list.
2. If a new GraphQL output type is needed, add it to `mock_types.ml`.
3. Add it to the coverage table above, and to `persona.json` if the response
   references new persona data.
4. `make build-mock-graphql`, then
   `python3 scripts/check-mock-schema-subset.py _build/default/mock_schema.json graphql_schema.json`.

## Why a parallel schema instead of reusing `Mina_graphql.schema`?

`Mina_graphql.schema` is parameterized over the daemon's full runtime type
`Mina_lib.t`, which is a concrete OCaml type with ~30 wired-in subsystems
(mempool, network controller, ledger, transaction pool, daemon config…).
Reusing the whole schema would require either constructing a real
`Mina_lib.t` or making `Mina_graphql` accept a module-type interface.

Instead, subtrees whose only context dependency is small are lifted into
context-polymorphic functors in `Mina_graphql.Types` and shared
(`daemonStatus`); the rest is a parallel schema with hand-written
resolvers, kept in line by the subset check.
