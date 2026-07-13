open Core_kernel
open Mina_base
open Mina_state

(** {1 Precomputed Blocks}

    A precomputed block is a fully processed Mina block that includes all the
    information needed to apply the block to the ledger and verify its validity.
    This is the "complete" representation of a block after all proofs have been
    generated and all state transitions computed.

    {2 What Makes It "Precomputed"?}

    In Mina's architecture, block production and proof generation can happen
    asynchronously. A precomputed block contains:
    1. The original block data (header + body)
    2. All zkSNARK proofs needed for validation
    3. Computed account state changes
    4. Token operation records

    {2 SNARK Workers and the Snarketplace}

    To maximize throughput, Mina separates block production from proof generation:
    - Block producers create blocks with transactions
    - SNARK workers generate the cryptographic proofs in parallel
    - The "Snarketplace" coordinates this work through economic incentives
    - Precomputed blocks represent the final result with all proofs included

    This design allows the network to process more transactions by parallelizing
    the computationally expensive proof generation.
*)

(** {1 Proof Module}

    This module defines a specialized proof type with overridden
    base64-encoding.

    {2 Differences from standard `Mina_base.Proof.t`}
    - The base64-encoding implementation has been customized to align with Mina's
      cryptographic proof serialization format.
      Base64 with the uri-safe alphabet is used to ensure that encoding and
      decoding is cheap, and that the proof can be easily sent over http
      etc. without escaping or re-encoding.
    - This ensures that proofs can be efficiently serialized and deserialized
      within the Mina protocol while maintaining integrity and compatibility.
*)
module Proof : sig
  (* Proof with overridden base64-encoding *)
  type t = Proof.t [@@deriving sexp, yojson]

  (** Converts the proof to a binary string representation using base64
      encoding *)
  val to_bin_string : t -> string

  (** [of_bin_string str] parses a binary string back into a proof using base64
      encoding *)
  val of_bin_string : string -> t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  [@@@with_versioned_json]

  module V3 : sig
    (** The complete precomputed block structure containing all necessary
        information for block validation and ledger updates. *)
    type nonrec t =
      { scheduled_time : Block_time.Stable.V1.t
          (** When this block was scheduled to be produced *)
      ; protocol_state : Protocol_state.Value.Stable.V2.t
          (** The blockchain state after applying this block *)
      ; protocol_state_proof : Mina_base.Proof.Stable.V2.t
          (** zkSNARK proof that validates the entire blockchain history *)
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V2.t
          (** Changes to the ledger from processing this block's transactions *)
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
          (** Proof linking this block to previous blocks in the chain *)
      ; protocol_version : Protocol_version.Stable.V2.t
          (** The protocol version this block was created under *)
      ; proposed_protocol_version : Protocol_version.Stable.V2.t option
          (** Optional proposed upgrade to a new protocol version *)
      ; accounts_accessed : (int * Account.Stable.V2.t) list
          (** Accounts that were read from or modified, with their indices *)
      ; accounts_created :
          (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
          (** New accounts created during block processing and their fees *)
      ; tokens_used :
          (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
          (** Token operations that occurred in this block *)
      }
  end
end]

type t = Stable.Latest.t =
  { scheduled_time : Block_time.Time.t
  ; protocol_state : Protocol_state.value
  ; protocol_state_proof : Proof.t
  ; staged_ledger_diff : Staged_ledger_diff.Stable.Latest.t
  ; delta_transition_chain_proof :
      Frozen_ledger_hash.t * Frozen_ledger_hash.t list
  ; protocol_version : Protocol_version.t
  ; proposed_protocol_version : Protocol_version.t option
  ; accounts_accessed : (int * Account.t) list
  ; accounts_created : (Account_id.t * Currency.Fee.t) list
  ; tokens_used : (Token_id.t * Account_id.t option) list
  }
[@@deriving sexp, yojson]

(** Convert a regular block into a precomputed block.

    This function takes a basic block and computes all the additional information
    needed for a precomputed block, including:
    - Determining which accounts were accessed or created
    - Recording token operations
    - Applying the staged ledger diff to compute state changes

    This is typically called after SNARK workers have generated the necessary
    proofs for the block's transactions. *)
val of_block :
     logger:Logger.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> scheduled_time:Block_time.Time.t
  -> staged_ledger:Staged_ledger.t
  -> accounts_created:Account_id.t list
  -> (Block.t, Mina_base.State_hash.State_hashes.t) With_hash.t
  -> t
