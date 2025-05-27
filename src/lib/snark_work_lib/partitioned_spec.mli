open Core_kernel

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('witness, 'ledger_proof, 'sub_zkapp_spec, 'data) t =
        | Single of
            { job :
                ( ('witness, 'ledger_proof) Single_spec.Poly.Stable.V2.t
                , Id.Single.Stable.V1.t )
                With_job_meta.Stable.V1.t
            ; data : 'data
            }
        | Sub_zkapp_command of
            { job :
                ( 'sub_zkapp_spec
                , Id.Sub_zkapp.Stable.V1.t )
                With_job_meta.Stable.V1.t
            ; data : 'data
            }
      [@@deriving sexp, yojson]
    end
  end]

  val drop_data : ('a, 'b, 'c, 'd) t -> ('a, 'b, 'c, unit) t

  val map :
       f_witness:('a -> 'b)
    -> f_subzkapp_spec:('c -> 'd)
    -> f_proof:('e -> 'f)
    -> f_data:('g -> 'h)
    -> ('a, 'e, 'c, 'g) t
    -> ('b, 'f, 'd, 'h) t

  val sok_message : ('a, 'b, 'c, 'd) t -> Mina_base.Sok_message.t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      ( Transaction_witness.Stable.V2.t
      , Ledger_proof.Stable.V2.t
      , Sub_zkapp_spec.Stable.V1.t
      , unit )
      Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    val to_latest : t -> t

    val statement : t -> Transaction_snark.Statement.t
  end
end]

type t =
  (Transaction_witness.t, Ledger_proof.Cached.t, Sub_zkapp_spec.t, unit) Poly.t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
