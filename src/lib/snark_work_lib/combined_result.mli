open Core_kernel

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('single_spec, 'proof) t =
        { data :
            ('single_spec, 'proof) Single_result.Poly.Stable.V1.t
            One_or_two.Stable.V1.t
        ; fee : Currency.Fee.Stable.V1.t
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
    end
  end]

  val map :
    f_single_spec:('a -> 'b) -> f_proof:('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      (Single_spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Poly.Stable.V1.t

    val to_latest : t -> t
  end
end]

type t = (Single_spec.t, Ledger_proof.Cached.t) Poly.t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
