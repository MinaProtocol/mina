open Core

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V3 : sig
    type t =
      | Segment of
          { statement : Transaction_snark.Statement.Stable.V2.t
          ; witness :
              Transaction_snark.Zkapp_command_segment.Witness.Stable.V2.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
          }
      | Merge of
          { proof1 : Ledger_proof.Stable.V3.t
          ; proof2 : Ledger_proof.Stable.V3.t
          }
    [@@deriving sexp, yojson]

    val statement : t -> Transaction_snark.Statement.t

    val to_latest : t -> t
  end

  module V2 : sig
    type t =
      | Segment of
          { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
          ; witness :
              Transaction_snark.Zkapp_command_segment.Witness.Stable.V2.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
          }
      | Merge of
          { proof1 : Ledger_proof.Stable.V3.t
          ; proof2 : Ledger_proof.Stable.V3.t
          }
    [@@deriving sexp, yojson]

    val statement : t -> Transaction_snark.Statement.t

    (** Upgrade. Discards the embedded digest, which is a placeholder. *)
    val to_latest : t -> V3.t

    (** Downgrade, for serving a pre-V3 worker. [sok_digest] should come from
        the enclosing job's sok message. *)
    val of_v3 : sok_digest:Mina_base.Sok_message.Digest.t -> V3.t -> t
  end
end]

type t =
  | Segment of
      { statement : Transaction_snark.Statement.t
      ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
      ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
      }
  | Merge of { proof1 : Ledger_proof.Cached.t; proof2 : Ledger_proof.Cached.t }
