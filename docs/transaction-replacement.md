# Transaction Replacement

Mina supports replacing a pending transaction in the transaction pool with a
new one. This is useful when a transaction is stuck due to a low fee, or when
you want to cancel a transaction that has not yet been included in a block.

## Overview

A transaction is replaced by submitting a new transaction with the **same
nonce** as the pending transaction you want to replace, but with a **higher
fee**. The new transaction must pay at least `1 nanomina` more than the
transaction it replaces.

When a replacement is accepted by the node, the original transaction is removed
from the pool and the new transaction takes its place.

## When to Use Transaction Replacement

- **Stuck transaction** – the fee was set too low, causing block producers to
  deprioritize it. Submit a replacement with a higher fee to speed up
  inclusion.
- **Cancel a transaction** – if you no longer want a pending transaction
  executed, replace it with a zero-amount payment to yourself (or to the
  original recipient) using the same nonce. The Mina CLI has a dedicated
  command that handles this for you (see below).

## Cancelling a Transaction with the CLI

The easiest way to cancel a pending transaction is the `cancel-transaction`
command:

```
mina client cancel-transaction --id <TRANSACTION_ID>
```

where `<TRANSACTION_ID>` is the ID printed when you originally sent the
transaction (e.g. the value returned by `mina client send-payment`).

The command:

1. Looks up the original transaction by ID.
2. Calculates the minimum replacement fee (`original_fee + 1 nanomina`).
3. Submits a new zero-amount payment to the same recipient using the same
   nonce and the higher fee.

On success you will see output similar to:

```
Fee to cancel transaction is 0.001 mina.
🛑 Cancelled transaction! Cancel ID: <NEW_TRANSACTION_ID>
```

Keep the new transaction ID — it is the replacement that will be included in
the blockchain instead of the original.

## Replacing a Transaction Manually

If you want to replace a transaction with something other than a cancellation
(for example, resend the same payment with a higher fee), submit a new
transaction with:

- **Sender** – the same account.
- **Nonce** – the same nonce as the pending transaction you want to replace.
- **Fee** – strictly greater than the fee of the transaction being replaced
  (by at least `1 nanomina`).

You can look up the nonce of a pending transaction via GraphQL or with:

```
mina client get-nonce --address <PUBLIC_KEY>
```

> **Note:** `get-nonce` returns the *committed* nonce (the nonce of the last
> transaction included in the best tip). Pending transactions in the pool
> occupy subsequent nonces sequentially. Use `mina client status` or the
> GraphQL field `inferredNonce` to find the highest nonce currently in the
> pool for your account.

## Fee Requirements

| Scenario | Minimum new fee |
|---|---|
| Replace a single pending transaction | `old_fee + 1 nanomina` |
| Replace a transaction that has N later transactions queued behind it | `old_fee + (1 nanomina × (N + 1))` |

The `(N + 1)` factor accounts for the replaced transaction itself (`1`) plus
each of the N dependent transactions queued after it. Each slot in the queue
consumes `1 nanomina` of the fee increment, so dropping more dependent
transactions requires a proportionally larger fee increase.

When a transaction in the middle of a queue is replaced, all later
transactions from the same sender that were queued behind it are temporarily
removed from the pool. The node then attempts to re-add them in order; each
re-added transaction consumes `1 nanomina` from the fee increment. Any
transaction whose fee cannot be covered by the remaining increment is dropped
and must be resubmitted separately.

### Why is an increment required?

Without a mandatory fee increase, an attacker could repeatedly replace
transactions at no extra cost, forcing nodes to validate and gossip an
unbounded number of transactions while paying only a single fee. Requiring a
fee increment ensures the extra work imposed on the network is paid for.

## Error: Insufficient Replace Fee

If the replacement fee is not high enough, the node rejects the transaction
with an error like:

```
rejecting command because of insufficient replace fee (rfee > fee)
```

In this case, increase the fee of your replacement transaction and try again.

## Related Resources

- RFC 0011 – [Mitigations for DOS attacks based on bogus transactions](../rfcs/0011-txpool-dos-mitigation.md) – the design document that introduced transaction replacement in Mina.
- `src/lib/network_pool/indexed_pool.ml` – the implementation of replacement logic, including the `replace_fee` constant (`1 nanomina`).
