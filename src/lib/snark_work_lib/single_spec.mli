(** Single job specification for SNARK workers.

    Handles non-zkApp transactions: payments, delegations, fee transfers, and
    coinbase. zkApp commands use {!Sub_zkapp_spec} instead.

    Defines the two fundamental job types:
    - [Transition]: Prove a single transaction (base case in the scan tree)
    - [Merge]: Combine two existing proofs into one (internal node)
*)

open Core_kernel

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type ('witness, 'ledger_proof) t =
        | Transition of Transaction_snark.Statement.Stable.V2.t * 'witness
        | Merge of
            Transaction_snark.Statement.Stable.V2.t
            * 'ledger_proof
            * 'ledger_proof
      [@@deriving sexp, yojson]
    end
  end]

  (** Transform witness and proof types. *)
  val map :
    f_witness:('a -> 'b) -> f_proof:('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t

  (** Extract the witness from a Transition spec. Returns [None] for Merge. *)
  val witness : ('witness, _) t -> 'witness option

  (** Get the SNARK statement (source/target ledger hashes, etc). *)
  val statement : (_, _) t -> Mina_state.Snarked_ledger_state.t

  (** QuickCheck generator for testing. *)
  val gen :
       'witness Base_quickcheck.Generator.t
    -> 'ledger_proof Base_quickcheck.Generator.t
    -> ('witness, 'ledger_proof) t Base_quickcheck.Generator.t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      ( Transaction_witness.Stable.V2.t
      , Ledger_proof.Stable.V2.t )
      Poly.Stable.V2.t
    [@@deriving sexp, yojson]

    val to_latest : t -> t

    val transaction : t -> Mina_transaction.Transaction.Stable.V2.t option
  end
end]

type t = (Transaction_witness.t, Ledger_proof.Cached.t) Poly.t

(** Load any cached proofs from disk into memory. *)
val read_all_proofs_from_disk : t -> Stable.Latest.t
