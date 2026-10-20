# Overriding Genesis Constants

Mina genesis constants consist of constants for the consensus algorithm,
sizes for various data structures (transaction pool, scan state, ledger,
etc.), and other protocol parameters.

All the constants can be set at compile time. A subset of the
compile-time constants can be overridden when generating the genesis
state using `runtime_genesis_ledger.exe`. A subset of those constants
can again be overridden at runtime by passing the new values to the
daemon.

The compile-time constants are set for different configurations using
optional compilation. This is how integration tests and builds with
multiple profiles are produced. Some of the constants defined in
[`mina_compile_config.ml`](../src/lib/mina_compile_config/mina_compile_config.ml)
cannot be changed after building and require creating a new build
profile (under `src/lib/node_config/profiled/`) for any change in their
values. For an explanation of build profiles in general, see
[`GLOSSARY.md` § Profiles](./GLOSSARY.md#profiles-dev-devnet-mainnet-lightnet)
once it lands.

## 1. Constants overridable at genesis-state generation time

These can be passed to `runtime_genesis_ledger.exe`:

- `k` (consensus constant)
- `delta` (consensus constant)
- `genesis_state_timestamp`
- transaction pool max size

To override, pass a JSON file with this format:

```json
{
  "k": 10,
  "delta": 3,
  "txpool_max_size": 3000,
  "genesis_state_timestamp": "2020-04-20 11:00:00-07:00"
}
```

The exe then packages the overridden constants along with the genesis
ledger and the genesis proof for the daemon to consume.

## 2. Constants overridable at runtime

The daemon accepts a smaller subset of overrides via the
`--genesis-constants` flag:

- `genesis_state_timestamp`
- transaction pool max size

Pass a JSON file in this format:

```json
{
  "txpool_max_size": 3000,
  "genesis_state_timestamp": "2020-04-20 11:00:00-07:00"
}
```

The daemon log reflects these changes, and `mina client status` displays
some of the constants.
