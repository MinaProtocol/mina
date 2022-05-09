open Core_kernel
open Mina_base
open Mina_state
open Signature_lib

module type External_transition_common_intf = sig
  type t

  type protocol_version_status =
    { valid_current : bool; valid_next : bool; matches_daemon : bool }

  val protocol_version_status : t -> protocol_version_status

  val protocol_state : t -> Protocol_state.Value.t

  val protocol_state_proof : t -> Proof.t

  val blockchain_state : t -> Blockchain_state.Value.t

  val blockchain_length : t -> Unsigned.UInt32.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t

  val state_hashes : t -> State_hash.State_hashes.t

  val parent_hash : t -> State_hash.t

  val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

  val block_producer : t -> Public_key.Compressed.t

  val block_winner : t -> Public_key.Compressed.t

  val coinbase_receiver : t -> Public_key.Compressed.t

  val supercharge_coinbase : t -> bool

  val transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> t
    -> Transaction.t With_status.t list

  val commands : t -> User_command.t With_status.t list

  val payments : t -> Signed_command.t With_status.t list

  val completed_works : t -> Transaction_snark_work.t list

  val global_slot : t -> Unsigned.uint32

  val delta_transition_chain_proof : t -> State_hash.t * State_body_hash.t list

  val current_protocol_version : t -> Protocol_version.t

  val proposed_protocol_version_opt : t -> Protocol_version.t option
end

module type External_transition_base_intf = sig
  type t = Block.t [@@deriving sexp, to_yojson]

  module Raw : sig
    type t [@@deriving sexp]

    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V1 : sig
        type nonrec t = t [@@deriving sexp]
      end
    end]
  end

  include External_transition_common_intf with type t := t
end

module type S = sig
  include External_transition_base_intf

  type external_transition = Raw.t

  module Precomputed_block : sig
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
              Frozen_ledger_hash.Stable.V1.t
              * Frozen_ledger_hash.Stable.V1.t list
          }

        val to_latest : t -> t
      end
    end]

    val of_external_transition :
      scheduled_time:Block_time.Time.t -> external_transition -> t
  end

  val timestamp : external_transition -> Block_time.t

  val compose : t -> external_transition

  val decompose : external_transition -> t

  module Validated : sig
    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V2 : sig
        type t [@@deriving sexp, to_yojson]
      end

      module V1 : sig
        type t [@@deriving sexp, to_yojson]

        val to_latest : t -> V2.t

        val of_v2 : V2.t -> t
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]

    val lift : Mina_block.Validated.t -> t

    val lower : t -> Mina_block.Validated.t
  end
end
