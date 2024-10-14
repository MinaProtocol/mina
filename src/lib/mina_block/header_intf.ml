module type Full = sig
  open Mina_base
  open Mina_state

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t [@@deriving sexp, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  type with_hash = t State_hash.With_state_hashes.t [@@deriving sexp]

  val create :
       protocol_state:Protocol_state.Value.t
    -> protocol_state_proof:Proof.t
    -> delta_block_chain_proof:State_hash.t * State_body_hash.t list
    -> ?proposed_protocol_version_opt:Protocol_version.t
    -> ?current_protocol_version:Protocol_version.t
    -> unit
    -> t

  val protocol_state : t -> Protocol_state.Value.t

  val protocol_state_proof : t -> Proof.t

  val delta_block_chain_proof : t -> State_hash.t * State_body_hash.t list

  val current_protocol_version : t -> Protocol_version.t

  val proposed_protocol_version_opt : t -> Protocol_version.t option

  type protocol_version_status =
    { valid_current : bool; valid_next : bool; matches_daemon : bool }

  val protocol_version_status : t -> protocol_version_status

  val blockchain_length : t -> Mina_numbers.Length.t
end
