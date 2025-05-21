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

  module V1 : sig
    type t =
      ( Transaction_witness.Stable.V3.t
      , Ledger_proof.Stable.V2.t )
      Poly.Stable.V2.t
    [@@deriving sexp, yojson]

    val to_latest : t -> t
  end
end]

type t = (Transaction_witness.t, Ledger_proof.Cached.t) Poly.t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
