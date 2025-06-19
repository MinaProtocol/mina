open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      | Segment of
          { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
          ; witness :
              Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
          ; which_segment : int
          }
      | Merge of
          { proof1 : Ledger_proof.Stable.V2.t
          ; proof2 : Ledger_proof.Stable.V2.t
          ; first_segment_of_proof1 : int
          ; last_segment_of_proof2 : int
          }
    [@@deriving sexp, yojson]

    val statement : t -> Transaction_snark.Statement.t

    val to_latest : t -> t
  end
end]

type t =
  | Segment of
      { statement : Transaction_snark.Statement.With_sok.t
      ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
      ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
      ; which_segment : int
      }
  | Merge of
      { proof1 : Ledger_proof.Cached.t
      ; proof2 : Ledger_proof.Cached.t
      ; first_segment_of_proof1 : int
      ; last_segment_of_proof2 : int
      }

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
