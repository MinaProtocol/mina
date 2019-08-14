# Generalized accounts and their specialization to normal accounts and tokens

This is a proposal for generalized accounts which is conceptually simple and
specializes to the case of normal Coda accounts as well as other token accounts.

The idea is that each account will contain a state as well as a program which approves
or rejects updates to that state, given also the state of other accounts involved in a transaction.
I will use type-theory pseduocode to express the idea.

The general framework is the following. We'll have a limited "programming language" 
which I'll described as

- a type family `predicate : (witness : type) (input : type) -> type`
- a function `eval : forall (w a : type), (p : predicate w a) -> global_state -> w -> a -> bool`.

where `global_state` is TBD, but should at least contain the current consensus state and a counter.

Accounts will be described by a type family
```ocaml
let product : list type -> type = fold ( * ) unit

type account_data (s : type) =
  { state : s
  ; balance : amount
  ; nonce : nonce
  }

type account_type =
  { witness : type
  ; state   : type
  ; others  : list type
  }

type account ({ witness; state; others } : account_type) =
  { data : account_data state
  ; can_update :
    predicate witness
      { before : product (map account_data (state :: others))
      ; after  : product (map account_data (state :: others))
      }
  }
```

Let's also assume addresses are parametrized by the state type of the corresponding account.
```ocaml
type address (at : account_type) = ...
```

A transaction will be described by a type
```ocaml
type transaction =
  list 
    { at         : account_type (* This account_type should have its "others"
                                   as the other elts of this list but it is
                                   too annoying to type that properly *)
    ; address    : address at
    ; witness    : at.witness
    ; next_state : at.state
    }
```

Fudging the types a bit at this point, the apply function will look like 
```ocaml
let lookup_exn : forall at, account_address at -> account at = ...
let set_exn : forall at, account_address at -> account at -> unit = ...

let apply (t : transaction) =
  let before = map t (fun a -> lookup_exn a.address) in
  let after = map2 t before (fun a acct_before ->
    { acct_before
      with data.state = a.next_state;
           data.nonce += 1
    })
  in
  (* To handle fees, you can check that the total balance change is equal to negative
    the fee associated with the transaction *)
  check_sum_of_balances_unchanged
    before
    after;
  iter2 before t (fun acct {witness; _} ->
    assert (
      eval
        acct.predicate
        witness
        { before
        ; after
        }));
  iter2 after t (fun acct {address; _} ->
    set_exn address acct)
```

So this is the general framework. In practice we will specialize and squash through the abstraction,
but this is the "ideal" starting point.

## A few examples

I think in practice we should additionally 

To get a feel for how this framework works, we can fit normal payment accounts into
this framework with the predicate
```
type predicate _ _ =
  | ...
  | Payment_account :
    predicate signature 
      { before : account_data public_key * account_data public_key
      , after : account_data public_key * account_data public_key
      }

let eval = function
  | ...
  | Payment_account ->
    fun (sig : signature) { before; after } ->
      (* The sender should be a payment account. *)
      assert (before[sender] == Payment_account && after[sender] == Payment_account);
      let sender, receiver =
        (* The sender is the one whose balance decreases. *)
        if after[0].balance <= before[0].balance
        then (0, 1)
        else (1, 0)
      in
      (* The sender public key shouldn't change. *)
      assert (before[sender].state == after[sender].state);
      (* The receiver public key shouldn't change unless the account was previously empty. *)
      assert (
           before[receiver].state == after[receiver].state
        || before[receiver].state == null);
      signature_verifies sig
        { amount= before[sender].balance - after[sender].balance
        ; nonce= before[sender].nonce
        ; receiver = after[receiver].state
        })
```

# Avoiding sending the whole new state
Although this framework is described in terms of *checking* a state update,
in practice, we will want to *compute* the state update so that we can send less
data. For example, in the "payment transaction" case, we only need to send the
amount of the transaction, rather than the entire accounts (which include public keys, nonces, etc).

Clearly if we can compute, we can also check, so we can have a predicate variant like
```ocaml
type predicate _ _ =
  | Compute_to_check : compute w a b -> predicate w { before: a, after: b }

type compute _ _ _ =
  | ...

let eval_compute (c : compute w a b) (x : a) : b = ...

let eval = function
  | ...
  | Compute_to_check c ->
    fun w { before; after } ->
      after == eval_compute c w before
```

# Tokens in particular
For token accounts, we can have the state be a record

```ocaml
type token_state = 
  { token_id   : string
  ; balance    : amount
  ; public_key : public_key
  }
```
and have the predicate basically do a swap between 2 input and 2 output token accounts.

## Issuance
I neglected to explain how creating new accounts should work. But nonetheless, here is
a proposal (not inside any described framework) for how issuance of tokens should work.

Basically, we add a new user-transaction
```ocaml
  | Create_token of { receiver : Public_key.t; total_supply : amount }
```
which creates a new account with token ID equal to 
```
hash (sender_public_key @ sender_merkle_index @ sender_nonce)
```
with the given total supply, and public-key.

# Unresolved questions

- Should all accounts have coda balances? This makes fees a bit simpler but is probably a weird UX since
  coda would need to be split amongst a bunch of token-wallets.
- In this proposal, all state is in the same Merkle tree. I think this is good from a simplicity of implementation
  perspective at this point. Are there any signifcant drawbacks to this approach.

