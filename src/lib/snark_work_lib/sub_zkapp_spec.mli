open Core_kernel

module SegmentSpec : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t =
        { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
        ; witness : Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
        ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      val to_latest : t -> t
    end
  end]
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      | Segment of SegmentSpec.Stable.V1.t
      | Merge of
          { proof1 : Ledger_proof.Stable.V2.t
          ; proof2 : Ledger_proof.Stable.V2.t
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
      }
  | Merge of { proof1 : Ledger_proof.Cached.t; proof2 : Ledger_proof.Cached.t }
