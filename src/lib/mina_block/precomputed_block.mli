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

  [@@@with_versioned_json]

  module V4 : sig
    type nonrec t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V3.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V2.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V3.t
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      ; protocol_version : Protocol_version.Stable.V2.t
      ; proposed_protocol_version : Protocol_version.Stable.V2.t option
      ; accounts_accessed : (int * Account.Stable.V3.t) list
      ; accounts_created :
          (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
      ; tokens_used :
          (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
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

val of_block :
     logger:Logger.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> scheduled_time:Block_time.Time.t
  -> staged_ledger:Staged_ledger.t
  -> accounts_created:Account_id.t list
  -> (Block.t, Mina_base.State_hash.State_hashes.t) With_hash.t
  -> t

(** A precomputed block of version 3, written between the Berkeley and Mesa
    hard forks. Its protocol state has the same type as version 4's: the
    Mesa version bump renamed it without changing it, so its state hash is
    computed the same way. Its transactions and accounts are Berkeley's. *)
module V3 : sig
  type t =
    { scheduled_time : Block_time.Stable.V1.t
    ; protocol_state : Protocol_state.Value.Stable.V3.t
    ; protocol_state_proof : Proof.t
    ; staged_ledger_diff : Berkeley_types.Diff.t
    ; delta_transition_chain_proof :
        Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
    ; protocol_version : Protocol_version.Stable.V2.t
    ; proposed_protocol_version : Protocol_version.Stable.V2.t option
    ; accounts_accessed : (int * Berkeley_types.Account.Stable.V2.t) list
    ; accounts_created :
        (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
    ; tokens_used : (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
    }

  (** The data of the versioned JSON, without its version tag. *)
  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end

(** A precomputed block in the version it was written in.

    Converting an older block to the latest version changes what hashing it
    gives, so anything that derives an identity from a block it did not
    produce itself, such as its state hash or its transactions' hashes,
    should work from this type and derive that identity by the rules of the
    block's own version. *)
module Versioned : sig
  type t = V3 of V3.t | V4 of Stable.V4.t

  val version : t -> int

  val of_latest : Stable.Latest.t -> t

  (** Writes the version's own versioned JSON. *)
  val to_yojson : t -> Yojson.Safe.t

  (** Reads versioned JSON of any version listed in [t], dispatching on its
      version tag. *)
  val of_yojson : Yojson.Safe.t -> (t, string) Result.t

  (** The hashes of the block's protocol state, by its version's rules. *)
  val state_hashes : t -> Mina_base.State_hash.State_hashes.t
end
