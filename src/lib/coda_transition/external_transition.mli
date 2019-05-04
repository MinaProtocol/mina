open Core_kernel
open Coda_base
open Coda_state

module type Base_intf = sig
  (* TODO: delegate forget here *)
  type t [@@deriving sexp, compare, to_yojson]

  include Comparable.S with type t := t

  type staged_ledger_diff

  val protocol_state : t -> Protocol_state.Value.t

  val protocol_state_proof : t -> Proof.t

  val staged_ledger_diff : t -> staged_ledger_diff

  val parent_hash : t -> State_hash.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t
end

module type S = sig
  type staged_ledger_diff

  include Base_intf with type staged_ledger_diff := staged_ledger_diff

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, eq, bin_io, to_yojson, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  module Proof_verified :
    Base_intf with type staged_ledger_diff := staged_ledger_diff

  module Verified :
    Base_intf with type staged_ledger_diff := staged_ledger_diff

  val create :
       protocol_state:Protocol_state.Value.t
    -> protocol_state_proof:Proof.t
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  val timestamp : t -> Block_time.t

  val to_proof_verified :
    t -> [`I_swear_this_is_safe_see_my_comment of Proof_verified.t]

  val to_verified : t -> [`I_swear_this_is_safe_see_my_comment of Verified.t]

  val of_verified : Verified.t -> t

  val of_proof_verified : Proof_verified.t -> t

  val forget_consensus_state_verification : Verified.t -> Proof_verified.t
end

module Make (Staged_ledger_diff : sig
  type t [@@deriving bin_io, sexp, version]
end) : S with type staged_ledger_diff := Staged_ledger_diff.t

include S with type staged_ledger_diff := Staged_ledger_diff.t
