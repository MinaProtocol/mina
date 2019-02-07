# Staged Ledger

## Background

Glossary of some important terms

**Transition**: Block

**Ledger**: A ledger is a merkle tree of accounts.

**Transaction**: Transactions in Coda are of two types based on who makes them:

    1. user : These are payments or stake delegations made by a user [user_command.ml][Add link]
    2. system(Protocol?): Coinbase and fee-transfers

**Coinbase**: Block reward paid to the proposers

**Fee-transfers**: A transaction that pays payment fees to the proposer and proof fees to the provers(explained later)

**Ledger proof** (also called a **transaction snark**): A snark (or a succint proof) that certifies the current state of the ledger derived from a certain initial state (genesis ledger) by applying a sequence of transactions. This is one type of snark in Coda, the other being a blockchain snark. Snarks and proofs are used interchangeably.

**snark** (*v*) : The act of generating a snark

**Snarked ledger**: A ledger that has been certified by a ledger proof. The genesis ledger is always a snarked ledger.

**Transaction snark work** or proof bundles: A Transaction snark work has two transaction snarks (It can have one snark when there is just one statement in the scan state to be proved, explained later) along with the prover pk and fees for the proofs.

**Why do we have this?**
A block or a transition in Coda consists of:

1.User commands
2.Coinbase
3.List of transaction snark work (proof bundles)
4.Ledger proof
5.Other things that are not relevant here (Should I still add it?.)

The ledger proof in a block is of the ledger after applying all the user commands, coinbase, and fee transfers. But generating snarks is a time consuming process and so each time a block is created, the snark for the updated ledger would also have to be generated. This increases the block creation time (TODO: some numbers here?).
What we do instead is, create a block without a ledger proof for the updated ledger and let the snark get generated in parallel to the block production. When the proof becomes available, include it in the very next block. A ledger proof in a block would now be of a ledger from a certain previous block. This process of keeping track of multiple ledger states and their proofs is performed in staged ledger

A staged ledger, at any given block(or blockchain-state) can be viewed as a ledger that hasn't been certified yet and has a staging area where proofs for all the to-be-snarked ledgers are tracked. It conists of two components: A ledger and a #scan-state.

The ledger in a staged ledger has all the transactions until a certain block/blockchain-state applied to it. For instance, consider a staged ledger at the latest block/blockchain state. The ledger in it will have all the "accepted" transactions applied.

The second component called the #scan-state [transaction_snark_scan_state.ml](../transaction_snark_scan_state/transaction_snark_scan_state.ml) can be viewed as a pool of ledgers that need to be snarked. [TODO: fit this in: We don't store the entire ledger, we just need these things to generate a snark] But really, it is a pool of a thing called statement that inlcudes merkle roots of the source and target ledgers, #fee-excess, and #supply-increase. A statement, therefore is the thing that a snark certifies which along with the ledger includes information about #fee-excess and #supply-increase of the entire system. There is another piece of information required to generate a snark which is a list of merkle paths to the accounts involved in the transactions. So, a scan-state is a now pool of statements+ which is available for the world to look at and for the #snark-workers to query and prove. The snark workers submit the generated snarks to the snark pool which makes it available for the proposer to purchase and include them in the next block. [TODO: More information about the two orders (FIFO and statement) in scan-state]. Read #scan-state for a detailed overview on how a ledger proof is actually staged.

The Staged ledger module has the following interface:

```ocaml
module type Staged_ledger_intf = sig
  type t [@@deriving sexp]

  module Scan_state : sig
    type t [@@deriving bin_io, sexp]
  end

  val ledger : t -> ledger

  val scan_state : t -> Scan_state.t

  module Staged_ledger_error : sig
    type t =
      | Bad_signature of user_command
      | Coinbase_error of string
      | Bad_prev_hash of staged_ledger_hash * staged_ledger_hash
      | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
      | Unexpected of Error.t
    [@@deriving sexp]
  end

  val create : ledger:ledger -> t

  val of_scan_state_and_ledger :
       snarked_ledger_hash:frozen_ledger_hash
    -> ledger:ledger
    -> scan_state:Scan_state.t
    -> t Or_error.t Deferred.t

  val apply :
       t
    -> diff
    -> logger:Logger.t
    -> ( [`Hash_after_applying of staged_ledger_hash]
         * [`Ledger_proof of ledger_proof option]
         * [`Staged_ledger of t]
       , Staged_ledger_error.t )
       Deferred.Result.t

  val apply_diff_unchecked :
       t
    -> valid_diff
    -> ( [`Hash_after_applying of staged_ledger_hash]
       * [`Ledger_proof of ledger_proof option]
       * [`Staged_ledger of t] )
       Deferred.Or_error.t

  val create_diff :
       t
    -> self:public_key
    -> logger:Logger.t
    -> transactions_by_fee:user_command_with_valid_signature Sequence.t
    -> get_completed_work:(statement -> completed_work_checked option)
    -> valid_diff

  val all_work_pairs_exn :
       t
    -> ( ( ledger_proof_statement
         , transaction
         , sparse_ledger
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
       * ( ledger_proof_statement
         , transaction
         , sparse_ledger
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list

  val statement_exn : t -> [`Non_empty of ledger_proof_statement | `Empty]
end

```

Description of some of the functions in the staged ledger module.

1. create_diff

The `create_diff` function produces a diff which when appplied to the correct state of the blockchain, would satisfy all the invariants of the scan state.
Some of the fields in the block are combined to form a `Staged_ledger_diff`. It consists of 

    1. User commands included in the block
    2. A list of proof bundles that prove some of the transactions (user-commands, coinbase, and fee-transfers) from previous blocks
    3. Coinbase

The `create_diff` function produces a diff which when appplied to the "correct" state of the blockchain, would satisfy all the invariants of the scan state.

When the proposer wins a block, the user-commands read from the transaction pool are sent to the staged ledger to create a diff.

There are two primary operations in staged ledger:

1. Creating a diff :
    To include a payment from the transaction pool, the proposer needs to include snarks generated by its own snark-workers (or buy it from someone) which certifies some of the transactions added in previous blocks. The number of snarks needs to be twice the number of transactions being included in the block (an invariant of the aux data structure). These proofs are included in the diff along with the payments and coinbase.
    The diff is then included in the external transition and  broadcasted to the network.

2. Applying a diff: Diffs from the node itself (Internal transitions) or from the network (External transitions) are then used to update the staged ledger by applying the payments to the ledger and updating the parallel scan state with the proofs. Applying a difsf may produce a proof for a sequence of transactions that were included in the previous blocks. ]]]

## scan-state

Scan state

## fee-excess

Every user command is charged a fee which the proposer of a block that includes the transaction gets.

Invariant:

The statement of the ledger proof emitted by the parallel scan will have zero fee excess.To achieve this, the total fee excess on every level of the (parallel scan) tree should be zero. For example, fee excess in a tree of depth 3 would be:

                        0
                2               -2
            1      1        -1     -1
         1   1  1   -3      1   1  -1 -1

In a block, when new transactions are added, the total fee excess (after including fee transfers) is always zero. However, the total fee excess on each level could be a non-zero value if some of the super transactions (transactions, fee transfers for the proofs) added to the tree occupy the "next" tree's leaves. For example:

                        2
                1                1
           2       -1      -1        2
        1   1  -2    1    1   -2   1    1                  1 -3   _   _   _   _   _   _

In this case, the total fee excess at the root of the tree is not zero (the total fee excess in system, however, is zero.)

This occurs when some of the transactions or fee transfers occupy the next tree's leaves (as a result of varying number of leaves being filled)

To fix this, the diff consisting of transactions and prover fees is split into two parts (pre_diffs) where the first part has transactions and fee transfers occupying only current tree and the second part consisting of transactions and fee transfers that occupy the second tree. If all the transactions and fee transfers fit in the first tree then the second part of the diff will be empty. The example will now look like:

                         0
               1                -1
          2     -1          -1         0
       1   1  -2   1     1    -2    1    -1                1  1  -2  _   _   _   _   _

## supply-increase

    Supply increase keeps track of the total currency generated. Currency is generated by creating coinbase. (Any other form? what about initial balances. Are they included in supply-increase? )

## snark-work-policy

    how much work? This should probably be in create diff or apply diff invariants

## extra-invariants

1. Coinbase splitting:
    A coinbase is included in a block if there is enough work available for one slot
Each coinbase consists of a fee transfer to pay the prover for the work (deducted from the coinbase itself.)

There is however, a case when coinbase could be split into two parts:
When the diff is split into two prediffs and if after  adding transactions, the first prediff has two slots remaining which cannot not accommodate transactions (why? The minimum number of slots required to add a single transaction is three (at worst case number of provers: when each pair of proofs is from a different prover). One slot for the transaction and two slots for fee transfers.), then those slots are filled by splitting the coinbase into two parts.
If it has one slot, then we simply add one coinbase. It is also possible that the first prediff may have no slots left after adding transactions (For example, when there are three slots and maximum number of provers), in which case, we simply add one coinbase as part of the second prediff.

It could happen that after adding transactions, there is not enough work for the coinbase, in which case, the two prediffs are discarded and a single diff is created with coinbase added before adding any transaction (just like when the diff is not split into two prediffs)

Some junk that can be used later:
[[[  (*that has transactions(payments, coinbase, and proof-fees) applied for which there are no snarks available yet*) for which there hasn't been a proof/snark generated yet. A ledger for which has been certified by a snark is called a *snarked ledger*.

A staged ledger consists of the accounts state (what we currently call ledger) and a data structure called [parallel_scan.ml](../src/lib/parallel_scan/parallel_scan.ml). It keeps track of all the transactions that need to be snarked (grep for `Available_job.t`) to produce a single transaction snark that certifies a set of transactions. This is exposed as Aux in the staged ledger.
Parallel scan is a tree like structure that stores statements needed to be proved. A statement can be of applying a single transaction `Base` or of composing other statements `Merge`. Snarking of these statements is delegated to snark-workers. The snark workers submit snarks for the corresponding statements which are used by the proposer to update the parallel scan state.