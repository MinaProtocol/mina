# Proposal: Decouple `mina_graphql_client` from Server-Side Dependencies

## Problem

The `mina_graphql_client` library (a *client* that makes HTTP requests to a running daemon) has a direct dependency on `mina_graphql` (the *server-side* GraphQL schema implementation). This single dependency edge pulls in **100+ transitive libraries** including the entire SNARK system, cryptographic backends, consensus, and the full daemon coordinator --- none of which are needed to make HTTP calls.

This makes every binary that uses `mina_graphql_client` enormous and slow to start, even though the client code only needs to construct HTTP requests and parse JSON responses.

## Root Cause

In `src/lib/mina_graphql_client/client.ml`, the dependency on `mina_graphql` exists for exactly **3 call sites**:

```ocaml
(* line 395 *)
Mina_graphql.Types.Input.SendPaymentInput.make_input ~from:sender_pub_key
  ~to_:receiver_pub_key ~amount ~fee ()

(* line 528 *)
Mina_graphql.Types.Input.SendDelegationInput.make_input
  ~from:sender_pub_key ~to_:receiver_pub_key ~fee ()

(* line 567 *)
Mina_graphql.Types.Input.SendPaymentInput.make_input ~from:sender_pub_key
  ~to_:receiver_pub_key ~amount ~fee ~memo ~nonce ~valid_until:(...) ()
```

These three calls use `SendPaymentInput.make_input` and `SendDelegationInput.make_input`, which are defined in `src/lib/graphql/mina_graphql/types.ml` (lines ~2992-3080). These are simple record constructors --- they don't use any daemon internals. But because they live inside the `mina_graphql` module, the entire server-side dependency tree comes along.

## The Dependency Chain Today

```
mina_graphql_client (should be lightweight)
  ├── mina_graphql (SERVER-SIDE --- the problem)
  │     ├── mina_lib (entire daemon coordinator)
  │     ├── pickles, pickles.backend, pickles_types (recursive zk-SNARKs)
  │     ├── kimchi_backend, kimchi_pasta (Rust FFI crypto)
  │     ├── transaction_snark (SNARK circuits)
  │     ├── blockchain_snark (blockchain proofs)
  │     ├── block_producer
  │     ├── consensus, consensus.vrf
  │     ├── staged_ledger
  │     ├── transition_frontier, transition_frontier_base
  │     ├── snark_params, verifier
  │     ├── coda_genesis_proof, precomputed_values
  │     ├── network_pool, mina_networking, gossip_net
  │     └── ... ~90 more libraries
  ├── mina_base (reasonable --- core types)
  ├── signature_lib (reasonable --- public keys)
  ├── currency (reasonable --- amounts/fees)
  └── generated_graphql_queries (reasonable --- PPX-generated query types)
```

## Proposed Fix

### Step 1: Extract shared input types into a new lightweight library

Create `src/lib/graphql/mina_graphql_input_types/`:

```
mina_graphql_input_types (NEW)
├── dune
├── send_payment_input.ml    (* moved from mina_graphql/types.ml *)
└── send_delegation_input.ml (* moved from mina_graphql/types.ml *)
```

**dune file:**
```
(library
 (name mina_graphql_input_types)
 (public_name mina_graphql_input_types)
 (libraries
  mina_base
  currency
  signature_lib
  mina_numbers
  graphql_lib))
```

This library depends only on core Mina types --- no SNARK code, no daemon internals.

### Step 2: Update `mina_graphql` to use the extracted types

In `src/lib/graphql/mina_graphql/dune`, replace the internal definitions with re-exports:

```ocaml
(* In mina_graphql/types.ml, replace the definitions with: *)
module Input = struct
  module SendPaymentInput = Mina_graphql_input_types.Send_payment_input
  module SendDelegationInput = Mina_graphql_input_types.Send_delegation_input
  (* ... other input types unchanged ... *)
end
```

This preserves backward compatibility --- all existing code using `Mina_graphql.Types.Input.SendPaymentInput` continues to work.

### Step 3: Update `mina_graphql_client` to depend on the extracted types

In `src/lib/mina_graphql_client/dune`, replace:
```
mina_graphql
```
with:
```
mina_graphql_input_types
```

In `client.ml`, change:
```ocaml
(* Before *)
Mina_graphql.Types.Input.SendPaymentInput.make_input ...

(* After *)
Mina_graphql_input_types.Send_payment_input.make_input ...
```

### Result: Clean Dependency Chain

```
mina_graphql_client (NOW actually lightweight)
  ├── mina_graphql_input_types (NEW --- tiny, ~5 deps)
  │     ├── mina_base
  │     ├── currency
  │     ├── signature_lib
  │     ├── mina_numbers
  │     └── graphql_lib
  ├── mina_base
  ├── signature_lib
  ├── currency
  └── generated_graphql_queries
```

**No more**: pickles, kimchi, transaction_snark, mina_lib, consensus, block_producer, staged_ledger, transition_frontier, snark_params, verifier, or any of the other ~90 server-side dependencies.

## Impact

### Direct beneficiaries

| Binary/Library | Before | After |
|---|---|---|
| `mina-graphql-client` (standalone app) | Links entire daemon | Lightweight (~5-10MB) |
| `mina_graphql_client` (library) | Pulls 100+ transitive deps | Pulls ~10 deps |
| `mina-health-check` (proposed) | Must use raw HTTP to avoid bloat | Can use typed client library |
| Integration test libs | Carry full daemon weight | Much lighter |

### Build time improvement

Anything that depends on `mina_graphql_client` currently triggers recompilation of the full daemon dependency tree when those deps change. After the refactor, client-only code is insulated from server-side changes.

### Enables future lightweight tooling

With a properly lightweight `mina_graphql_client`, new operator tools can use typed, retrying GraphQL queries without paying the daemon dependency cost:
- `mina-health-check` (Proposal 12)
- Future monitoring agents
- Future delegation tracking tools
- Future block production alerting tools

## Backward Compatibility

**Fully backward compatible.** The `Mina_graphql.Types.Input.SendPaymentInput` module path continues to work via re-export. No consumer code needs to change unless it wants to opt into the lighter dependency.

## Risk Assessment

**Low risk.** This is a mechanical refactor:
1. Move two module definitions to a new library
2. Add re-exports in the original location
3. Swap one dependency in `mina_graphql_client/dune`
4. Update 3 lines in `client.ml`

The types themselves don't change. The module paths are preserved. The build system handles the rest.

## Files to Modify

| File | Change |
|---|---|
| `src/lib/graphql/mina_graphql_input_types/dune` | **New** --- library definition |
| `src/lib/graphql/mina_graphql_input_types/send_payment_input.ml` | **New** --- extracted from `types.ml` |
| `src/lib/graphql/mina_graphql_input_types/send_delegation_input.ml` | **New** --- extracted from `types.ml` |
| `src/lib/graphql/mina_graphql/types.ml` | Replace definitions with re-exports |
| `src/lib/graphql/mina_graphql/dune` | Add `mina_graphql_input_types` dep |
| `src/lib/mina_graphql_client/dune` | Replace `mina_graphql` with `mina_graphql_input_types` |
| `src/lib/mina_graphql_client/client.ml` | Update 3 module references |

## Implementation Order

**This refactor should be done BEFORE building `mina-health-check` (Proposal 12).** Once the client library is lightweight, the health check app can use it directly instead of reimplementing HTTP/GraphQL plumbing with raw `cohttp-async`.

## Effort Estimate

Small --- 1-2 days. Mechanical refactor with no protocol or behavioral changes.
