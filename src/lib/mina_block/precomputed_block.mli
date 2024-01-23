open Core_kernel
open Mina_base
open Mina_state

module Proof : sig
  (* Proof with overridden base64-encoding *)
  type t = Proof.t [@@deriving sexp, yojson]

  val to_bin_string : t -> string

  val of_bin_string : string -> t
end

type t =
  { scheduled_time : Block_time.Time.t
  ; protocol_state : Protocol_state.value
  ; protocol_state_proof : Proof.t
  ; staged_ledger_diff : Staged_ledger_diff.t
  ; delta_transition_chain_proof :
      Frozen_ledger_hash.t * Frozen_ledger_hash.t list
  }
[@@deriving sexp, yojson]

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type nonrec t = t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V1.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V1.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      }

    val to_latest : t -> t
  end
end]

val of_block : scheduled_time:Block_time.Time.t -> Block.t -> t
