open Core

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V3 : sig
      type ('witness, 'ledger_proof) t =
        | Transition of Transaction_snark.Statement.Stable.V3.t * 'witness
        | Merge of
            Transaction_snark.Statement.Stable.V3.t
            * 'ledger_proof
            * 'ledger_proof
      [@@deriving sexp, yojson]
    end
  end]

  val map :
    f_witness:('a -> 'b) -> f_proof:('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t

  val witness : ('witness, _) t -> 'witness option

  val statement : (_, _) t -> Mina_state.Snarked_ledger_state.t

  val gen :
       'witness Base_quickcheck.Generator.t
    -> 'ledger_proof Base_quickcheck.Generator.t
    -> ('witness, 'ledger_proof) t Base_quickcheck.Generator.t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V4 : sig
    type t =
      ( Transaction_witness.Stable.V4.t
      , Ledger_proof.Stable.V4.t )
      Poly.Stable.V3.t
    [@@deriving sexp, yojson]

    val to_latest : t -> t

    val transaction : t -> Mina_transaction.Transaction.Stable.V3.t option
  end
end]

type t = (Transaction_witness.t, Ledger_proof.Cached.t) Poly.t

val read_all_proofs_from_disk : t -> Stable.Latest.t
