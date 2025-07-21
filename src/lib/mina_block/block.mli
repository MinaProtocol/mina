open Mina_base
open Mina_transaction

(** {1 Mina Block Structure}

    A Mina block is the fundamental unit of the Mina blockchain. Unlike
    traditional blockchains that grow linearly with transaction history, Mina
    blocks are designed to maintain a constant size through the use of
    recursive zkSNARKs.

    {2 Block Architecture Overview}

    Each Mina block consists of two main components:
    - {b Header}: Contains metadata, protocol state, and cryptographic proofs
    - {b Body}: Contains the actual transaction data and ledger state changes

    Mina blocks include succinct proofs (zkSNARKs) that validate the entire
    blockchain history, allowing nodes to verify the complete chain state with
    just a few hundred bytes of data.

    {2 zkSNARK Integration}

    Mina uses recursive zkSNARKs to achieve "succinctness":
    - Each block includes a proof that validates all previous blocks
    - Proofs are recursively composed, maintaining constant size
    - Full blockchain verification requires only the latest proof.
    - Verification time is fast and can run on mobile devices

    {2 For Newcomers}

    If you're new to Mina, think of blocks as:
    1. A container for transactions (like other blockchains)
    2. A cryptographic proof that the entire blockchain is valid
    3. A way to update the global ledger state

    The key difference from other blockchains is that Mina blocks don't require
    you to download the entire transaction history to verify the chain's validity.
*)

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t [@@deriving sexp, equal]

    val header : t -> Header.Stable.V2.t

    val body : t -> Staged_ledger_diff.Body.Stable.V1.t

    val transactions :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Transaction.Stable.V2.t With_status.t list
  end
end]

(** The main block type containing a header and body *)
type t

val to_logging_yojson : Header.t -> Yojson.Safe.t

(** A block paired with its computed state hashes *)
type with_hash = t State_hash.With_state_hashes.t

(* TODO: interface for both unchecked and checked construction of blocks *)
(* check version needs to run following checks:
     - Header.verify (could be separated into header construction)
     - Consensus.Body_reference.verify_reference header.body_reference body
     - Staged_ledger_diff.Body.verify (cannot be put into body construction as
       we should do the reference check first, but could be separated) *)

(** {2 Block Construction and Access} *)

(** Attach computed state hashes to a block *)
val wrap_with_hash : t -> with_hash

(** Create a new block from a header and body.

    This is the primary constructor for blocks. The header contains the protocol
    state and proofs, while the body contains the transaction data that updates
    the ledger. *)
val create : header:Header.t -> body:Staged_ledger_diff.Body.t -> t

(** Extract the header from a block.

    The header contains:
    - Protocol state (current blockchain state)
    - zkSNARK proof validating the entire chain
    - Consensus information
    - Protocol version information *)
val header : t -> Header.t

(** Extract the body from a block.

    The body contains:
    - User transactions (payments, stake delegations, etc.)
    - Internal transactions (coinbase, fee transfers)
    - Account creation and modification data *)
val body : t -> Staged_ledger_diff.Body.t

(** Get the timestamp when this block was created *)
val timestamp : t -> Block_time.t

(** Extract all transactions from a block.

    This includes both user commands (payments, delegations) and internal
    transactions (coinbase rewards, fee transfers). Each transaction is
    paired with its execution status. *)
val transactions :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> Transaction.t With_status.t list

(** Get all account IDs that were accessed during block execution.

    This is useful for understanding which accounts were read from or
    modified when processing the block's transactions. *)
val account_ids_accessed :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> (Account_id.t * [ `Accessed | `Not_accessed ]) list

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t

val read_all_proofs_from_disk : t -> Stable.Latest.t
