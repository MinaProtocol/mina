open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      { id :
          [ `Single of Id.Single.Stable.V1.t
          | `Sub_zkapp of Id.Sub_zkapp.Stable.V1.t ]
      ; data :
          ( Mina_stdlib.Time.Span.Stable.V1.t
          , Ledger_proof.Stable.V2.t )
          Proof_carrying_data.Stable.V1.t
      }
    [@@deriving to_yojson]

    val id_to_json : t -> Yojson.Safe.t

    val to_latest : t -> t
  end
end]

type t =
  { id : [ `Single of Id.Single.t | `Sub_zkapp of Id.Sub_zkapp.t ]
  ; data : (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t
  }

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
