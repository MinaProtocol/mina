# Mina Custom Tokens Specification

## Overview

Mina supports custom fungible tokens in addition to the native MINA token. Custom tokens are managed entirely through zkApp (zero-knowledge application) smart contracts, using a **caller-is-manager** security model that leverages the hierarchical structure of zkApp transactions.

**Table of Contents**

- [1. Concepts](#1-concepts)
  - [1.1 Token ID](#11-token-id)
  - [1.2 Token Owner](#12-token-owner)
  - [1.3 Token Accounts](#13-token-accounts)
  - [1.4 Token Symbol](#14-token-symbol)
- [2. Token ID Derivation](#2-token-id-derivation)
  - [2.1 Default Token](#21-default-token)
  - [2.2 Custom Token Derivation](#22-custom-token-derivation)
- [3. Account Structure](#3-account-structure)
  - [3.1 Account ID](#31-account-id)
  - [3.2 Token-related Account Fields](#32-token-related-account-fields)
- [4. Token Authorization Model](#4-token-authorization-model)
  - [4.1 May-use-token Permission](#41-may-use-token-permission)
  - [4.2 Caller-is-Manager Security](#42-caller-is-manager-security)
  - [4.3 Token Owner Not Caller Check](#43-token-owner-not-caller-check)
- [5. zkApp Transaction Structure for Tokens](#5-zkapp-transaction-structure-for-tokens)
  - [5.1 Call Forest and Caller Identity](#51-call-forest-and-caller-identity)
  - [5.2 Caller ID Computation](#52-caller-id-computation)
- [6. Token Operations](#6-token-operations)
  - [6.1 Creating a Custom Token (Deployment)](#61-creating-a-custom-token-deployment)
  - [6.2 Minting Tokens](#62-minting-tokens)
  - [6.3 Transferring Tokens](#63-transferring-tokens)
  - [6.4 Burning Tokens](#64-burning-tokens)
- [7. Failure Modes](#7-failure-modes)
- [8. Example: Reference Token Implementation](#8-example-reference-token-implementation)

---

## 1. Concepts

### 1.1 Token ID

A **token ID** is a field element (a point on the Pasta Fp curve) that uniquely identifies a token type within the Mina protocol. Every account on the Mina ledger is associated with exactly one token ID.

There are two categories of token IDs:

- **Default token ID**: Represents the native MINA token. Its value is the field element `1`.
- **Custom token IDs**: Derived deterministically from the public key and token ID of the account that owns (manages) the token. See [Section 2.2](#22-custom-token-derivation).

Token IDs are encoded as Base58Check strings when serialized (e.g., in GraphQL or JSON). The version byte used is `token_id_key`.

### 1.2 Token Owner

Every custom token is associated with a **token owner** — a specific account (identified by its `Account_id`, which is a `(public_key, token_id)` pair) whose zkApp smart contract is responsible for authorizing all operations on that token.

The token owner account:
- Holds the zkApp verification key that governs token operations.
- Is the entity whose `Account_id` was used to derive the custom token ID.
- Must appear as an ancestor in the account-update call tree whenever a non-default token account is accessed.

### 1.3 Token Accounts

A **token account** is any account on the Mina ledger whose `token_id` field is not the default token ID. Each token account is associated with:

- A specific public key (the account holder).
- A specific token type (identified by its token ID).

The combination `(public_key, token_id)` forms the globally unique `Account_id` for a token account.

A single public key can hold balances of multiple tokens by having separate accounts for each token ID.

### 1.4 Token Symbol

A token owner account may optionally set a **token symbol** — a short human-readable label for the token it manages. This symbol:

- Is stored in the `token_symbol` field of the token owner account.
- Has a maximum length of **6 bytes** (ASCII characters).
- Is an empty string by default.
- Is distinct from the token ID (which is a cryptographic value).

Note: The `token_symbol` field on an account describes the token *owned* by that account (i.e., the custom token whose ID was derived from this account), not the token *used* by the account itself.

---

## 2. Token ID Derivation

### 2.1 Default Token

The default token ID is the field element `1` (`Snark_params.Tick.Field.one`). All standard MINA payments use this token ID.

### 2.2 Custom Token Derivation

A custom token ID is derived deterministically from an **owner account ID** using the Poseidon hash function:

```
token_id = Poseidon("MinaDeriveTokenId" || pack(owner_public_key) || owner_token_id)
```

Where:
- `"MinaDeriveTokenId"` is the domain-separation string (hash prefix).
- `owner_public_key` is the compressed public key of the token owner account (encoded as a `Random_oracle_input`).
- `owner_token_id` is the token ID of the token owner account (as a field element).
- `pack(·)` refers to packing the combined input into field elements as defined by `Random_oracle.pack_input`.

In OCaml (see `src/lib/mina_base/account_id.ml`):

```ocaml
let derive_token_id ~(owner : t) : Digest.t =
  Random_oracle.hash ~init:Hash_prefix.derive_token_id
    (Random_oracle.pack_input (to_input owner))
```

This derivation means that for each account `(pk, token_id)`, there is exactly one deterministic custom token ID. A single public key can therefore create multiple custom tokens by deploying separate token-owner accounts with different token IDs.

---

## 3. Account Structure

### 3.1 Account ID

An `Account_id` is the pair `(public_key, token_id)` where:

- `public_key : Public_key.Compressed.t` — the compressed public key of the account holder.
- `token_id : Token_id.t` — the token ID this account operates in.

Two accounts are distinct if they have different public keys, different token IDs, or both.

### 3.2 Token-related Account Fields

| Field | Type | Description |
|---|---|---|
| `token_id` | `Token_id.t` | The token type held by this account. Default is `1` (MINA). |
| `token_symbol` | `string` (max 6 bytes) | A human-readable symbol for the custom token *owned* by this account. Applies only to token-owner accounts. Empty string by default. |

The `token_symbol` field on an account is the symbol for the custom token that this account owns (i.e., the custom token derived from this account's `Account_id`), not the token used by this account.

---

## 4. Token Authorization Model

### 4.1 May-use-token Permission

Every account update in a zkApp transaction contains a `may_use_token` field that controls how the account update interacts with custom tokens:

| Value | Description |
|---|---|
| `No` | The account update may only interact with accounts using the default MINA token. This is the default. |
| `Parents_own_token` | The account update may interact with accounts using the token owned by its direct parent account update. The permission may be inherited by child account updates. |
| `Inherit_from_parent` | The account update inherits whatever token permission its parent account update had. |

This field is stored in `Account_update.Body.may_use_token`.

### 4.2 Caller-is-Manager Security

The Mina custom token system enforces a **caller-is-manager** security model: every account update that accesses a non-default token account must have the token owner as an ancestor in the account-update call tree.

This ensures that:
1. The token owner's zkApp proof is always executed before any child account update can access custom token accounts.
2. The token owner controls what operations are permissible on the token (minting, transferring, burning) through its zkApp circuit logic.
3. No account update can access a custom token account without the explicit approval of the token owner.

The protocol enforces this by computing a **caller ID** for each account update and checking it against the account's token ID (see [Section 4.3](#43-token-owner-not-caller-check)).

### 4.3 Token Owner Not Caller Check

During transaction application, the protocol checks:

```
account_update.token_id == default_token_id
  OR
account_update.token_id == caller_id
```

Where `caller_id` is the token ID derived from the parent account update's `Account_id` (see [Section 5.2](#52-caller-id-computation)).

If this check fails, the transaction fails with the `Token_owner_not_caller` error.

This guarantees that any account update affecting a non-default token account must have been explicitly authorized by the token owner (the parent in the call tree).

---

## 5. zkApp Transaction Structure for Tokens

### 5.1 Call Forest and Caller Identity

zkApp transactions are organized as a **call forest** — a forest of account-update trees. Each tree node consists of:

- An `account_update` (with a `may_use_token` field).
- A `calls` sub-forest of child account updates.

The hierarchical call structure determines the **caller identity** of each account update: the token ID of the direct parent account update becomes the caller ID for the child, which in turn determines which custom token accounts the child may access.

### 5.2 Caller ID Computation

The caller ID for an account update is determined by its `may_use_token` field and the caller context of its parent:

```
caller_id =
  if may_use_token == Inherit_from_parent then
    parent.caller_caller   (* inherit the grandparent's token *)
  else if may_use_token == Parents_own_token then
    parent.caller           (* use the parent's own token *)
  else
    default_token_id        (* No: use the default MINA token *)
```

Where:
- `parent.caller` is the token ID derived from the parent account update's `Account_id`: `derive_token_id(parent.account_id)`.
- `parent.caller_caller` is the caller ID that the parent itself received from *its* parent.

The top-level account updates in a transaction have `caller = default_token_id` and `caller_caller = default_token_id`.

This is implemented in `src/lib/transaction_logic/zkapp_command_logic.ml` in the `get_next_account_update` function.

---

## 6. Token Operations

All token operations are implemented as zkApp transactions. The token owner's zkApp verification key controls what operations are allowed. Below are the standard operations.

### 6.1 Creating a Custom Token (Deployment)

To create a custom token:

1. **Deploy** a zkApp to an account `(owner_pk, MINA_token_id)` with a verification key that implements the desired token policy.
2. **Initialize** the token owner's app state (e.g., setting supply, configuration flags, etc.).
3. The custom token ID is automatically derived as `derive_token_id(owner_pk, MINA_token_id)`.
4. Optionally set the `token_symbol` on the owner account to provide a human-readable label.

The token owner account may itself hold MINA (default token), while the *custom token accounts* are separate accounts with the derived `token_id`.

### 6.2 Minting Tokens

Minting creates new custom token supply by increasing the balance of a custom token account:

1. The token owner's account update appears in the call forest.
2. A child account update under the token owner targets a custom token account (using `may_use_token: Parents_own_token`).
3. The child account update increases the balance of the target custom token account.
4. The token owner's zkApp circuit validates the mint (e.g., enforcing supply caps, authorization checks, recording the mint in the action state).

The token owner's zkApp proof guarantees that minting is only performed when its circuit allows it. Without the token owner's proof executing as a parent, the `Token_owner_not_caller` check would fail and the transaction would be rejected.

### 6.3 Transferring Tokens

Transferring custom tokens between accounts:

1. The token owner's account update acts as the top-level authorizer in the call forest.
2. Child account updates modify custom token account balances (one decreasing, one increasing), each using `may_use_token: Parents_own_token` or `Inherit_from_parent`.
3. The token owner's zkApp circuit checks that the sum of balance changes among custom token accounts within its scope is zero (conservation of custom token supply).

Because all custom token account updates must be children of the token owner, the token owner's zkApp can enforce any transfer policy (e.g., KYC checks, transfer limits, whitelist enforcement).

### 6.4 Burning Tokens

Burning reduces custom token supply by decreasing the balance of a custom token account without a corresponding increase elsewhere. The mechanism is the same as minting, but with a negative balance change on the target account. The token owner's zkApp circuit governs what burn conditions are permitted.

---

## 7. Failure Modes

| Failure | Description |
|---|---|
| `Token_owner_not_caller` | An account update attempts to access a non-default token account, but the token owner is not the caller (parent) in the call tree. The `may_use_token` field did not correctly establish the caller context. |
| `Update_not_permitted_token_symbol` | An account update attempts to update the `token_symbol` field of an account, but the account's permissions do not allow it. |

---

## 8. Example: Reference Token Implementation

The directory `src/app/zkapps_examples/tokens/` contains a reference zkApp implementation of a custom token, demonstrating:

- **Initialize**: Deploys and initializes the token owner zkApp, setting initial app state.
- **Mint**: Creates new tokens for a given recipient account.
- **Transfer** (`child_forest`): Authorizes a set of balance-change account updates for the custom token, enforcing that the sum of all custom token balance changes is zero (except for minting operations which are excluded from the sum check).

The reference implementation uses Pickles recursive proofs and illustrates how the `may_use_token` field and the call forest hierarchy together implement secure, programmable token authorization.

For tests demonstrating various scenarios (successful transfers, rejected unauthorized accesses, recursive delegation), see `src/app/zkapps_examples/test/tokens/tokens.ml`.
