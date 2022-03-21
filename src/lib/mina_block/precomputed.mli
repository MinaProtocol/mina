open Mina_base
open Mina_state

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V1.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V1.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
      ; delta_block_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      }
    [@@deriving sexp, to_yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, to_yojson]
