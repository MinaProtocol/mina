open Core_kernel
open Mina_base
open Mina_state

module Proof : sig
  (* Proof with overridden base64-encoding *)
  type t = Proof.t [@@deriving sexp, yojson]

  val to_bin_string : t -> string

  val of_bin_string : string -> t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V3 : sig
    type nonrec t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V2.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V2.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V2.t
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      ; accounts_accessed : (int * Account.Stable.V2.t) list
      ; accounts_created :
          (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
      ; tokens_used :
          (Token_id.Stable.V1.t * Account_id.Stable.V2.t option) list
      ; body_reference : Body_reference.Stable.V2.t
      }
  end
end]

type t = Stable.Latest.t =
  { scheduled_time : Block_time.Time.t
  ; protocol_state : Protocol_state.value
  ; protocol_state_proof : Proof.t
  ; staged_ledger_diff : Staged_ledger_diff.t
  ; delta_transition_chain_proof :
      Frozen_ledger_hash.t * Frozen_ledger_hash.t list
  ; accounts_accessed : (int * Account.t) list
  ; accounts_created : (Account_id.t * Currency.Fee.t) list
  ; tokens_used : (Token_id.t * Account_id.t option) list
  ; body_reference : Body_reference.t
  }
[@@deriving sexp, yojson]

val of_block :
     logger:Logger.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> scheduled_time:Block_time.Time.t
  -> staged_ledger:Staged_ledger.t
  -> (Block.t, Mina_base.State_hash.State_hashes.t) With_hash.t
  -> t
