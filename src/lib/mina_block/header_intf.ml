(** {1 Block Header Interface}

    This module defines the interface for Mina block headers. The header
    interface abstracts the core functionality needed to work with headers while
    allowing different implementations for different protocol versions.

    {2 Why an Interface?}

    The header interface allows:
    - Different serialization formats across protocol versions
    - Type safety when working with headers
    - Clear separation between header data and its operations
    - Extensibility for future protocol upgrades

    {2 Core Header Components}

    A Mina header contains several critical pieces:
    - {b Protocol State}: The complete blockchain state after this block
    - {b Protocol State Proof}: zkSNARK proving the state is valid
    - {b Delta Block Chain Proof}: Links to establish block ordering
    - {b Protocol Versions}: Current and proposed protocol versions

    The protocol state includes account balances, validator information, consensus
    data, and everything else needed to represent the blockchain's current state.
*)

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

  (** The main header type *)
  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  (** A header paired with its computed state hashes for efficient lookups *)
  type with_hash = t State_hash.With_state_hashes.t [@@deriving sexp]

  (** Create a new header from its components.

      This is the primary constructor for headers. The protocol state contains
      the complete blockchain state, while the proof validates that this state
      is the correct result of applying the block's transactions to the previous
      state.

      The delta block chain proof establishes the ordering relationship with
      previous blocks, ensuring the header fits correctly in the blockchain. *)
  val create :
       protocol_state:Protocol_state.Value.t
    -> protocol_state_proof:Proof.t
    -> delta_block_chain_proof:State_hash.t * State_body_hash.t list
    -> ?proposed_protocol_version_opt:Protocol_version.t
    -> ?current_protocol_version:Protocol_version.t
    -> unit
    -> t

  (** Get the protocol state from a header.

      The protocol state represents the complete state of the blockchain after
      applying this block. This includes account balances, the validator set,
      consensus state, and other global blockchain parameters. *)
  val protocol_state : t -> Protocol_state.Value.t

  (** Get the zkSNARK proof that validates the protocol state.

      This proof is the heart of Mina's succinctness. It cryptographically
      proves that:
      1. The previous state was valid
      2. All transactions in the block are valid
      3. The new state is the correct result of applying those transactions

      Because the proof is recursive, it validates the entire blockchain
      history, not just the current block. *)
  val protocol_state_proof : t -> Proof.t

  (** Get the proof that links this block to previous blocks.

      This establishes the ordering of blocks in the chain. The first hash is
      the state hash of the previous block, and the list contains additional
      hashes needed to prove the block's position in the chain. *)
  val delta_block_chain_proof : t -> State_hash.t * State_body_hash.t list

  (** Get the protocol version this block was created under *)
  val current_protocol_version : t -> Protocol_version.t

  (** Get the protocol version proposed for future use (if any).

      Blocks can propose protocol upgrades. If this returns [Some version],
      the block producer is signaling support for upgrading to that version. *)
  val proposed_protocol_version_opt : t -> Protocol_version.t option

  (** Information about the validity of protocol versions in this header *)
  type protocol_version_status =
    { valid_current : bool  (** Is the current protocol version valid? *)
    ; valid_next : bool     (** Is the proposed version valid? *)
    ; matches_daemon : bool (** Does this match our daemon's version? *)
    }

  (** Check the validity of protocol versions in this header *)
  val protocol_version_status : t -> protocol_version_status

  (** Get the blockchain length (block height) from this header *)
  val blockchain_length : t -> Mina_numbers.Length.t
end
