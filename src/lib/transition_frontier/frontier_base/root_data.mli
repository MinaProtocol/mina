open Mina_base

module Common : sig
  [%%versioned:
  module Stable : sig
    module V3 : sig
      type t
    end

    module V2 : sig
      type t

      val to_latest : t -> V3.t
    end
  end]

  val create :
       scan_state:Staged_ledger.Scan_state.t
    -> pending_coinbase:Pending_coinbase.t
    -> block_data_opt:Block_data.t option
    -> t
end

(* Historical root data is similar to Limited root data, except that it also
 * contains a recording of some extra computed staged ledger properties that
 * were available on a breadcrumb in the transition frontier when this was
 * created. *)
module Historical : sig
  type t

  val staged_ledger_aux_and_pending_coinbases :
    t -> Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag

  val required_state_hashes : t -> State_hash.Set.t

  val protocol_state : t -> Mina_state.Protocol_state.Value.t

  val protocol_state_with_hashes :
    t -> Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t

  val block_tag : t -> Network_types.Block.data_tag

  val create :
       block_tag:Network_types.Block.data_tag
    -> staged_ledger_aux_and_pending_coinbases:
         Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag
    -> required_state_hashes:State_hash.Set.t
    -> protocol_state_with_hashes:
         Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t
    -> t
end

(* Limited root data is similar to Minimal root data, except that it contains
 * the full validated transition at a root instead of just a pointer to one and protocol states for the root scan state *)
module Limited : sig
  type t [@@deriving to_yojson, bin_io]

  val block_tag : t -> Mina_block.Stable.Latest.t State_hash.File_storage.tag

  val state_hash : t -> State_hash.t

  val scan_state : t -> Staged_ledger.Scan_state.t

  val pending_coinbase : t -> Pending_coinbase.t

  val protocol_states_for_scan_state :
    t -> Mina_state.Protocol_state.value State_hash.With_state_hashes.t list

  val protocol_state : t -> Mina_state.Protocol_state.value

  val create :
       block_tag:Mina_block.Stable.Latest.t State_hash.File_storage.tag
    -> state_hash:State_hash.t
    -> scan_state:Staged_ledger.Scan_state.t
    -> pending_coinbase:Pending_coinbase.t
    -> protocol_states_for_scan_state:
         Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
    -> protocol_state:Mina_state.Protocol_state.value
    -> t
end

(* Minimal root data contains the smallest amount of information about a root.
 * It contains a hash pointing to the root transition, and the auxiliary data
 * needed to reconstruct the staged ledger at that point (scan_state,
 * pending_coinbase).
 *)
module Minimal : sig
  [%%versioned:
  module Stable : sig
    module V3 : sig
      type t
    end

    module V2 : sig
      type t

      val to_latest : t -> V3.t
    end
  end]

  val common : t -> Common.t

  val state_hash : t -> State_hash.t

  val scan_state : t -> Staged_ledger.Scan_state.t

  val pending_coinbase : t -> Pending_coinbase.t

  val of_common : state_hash:State_hash.t -> Common.t -> t

  val block_data_opt : t -> Block_data.t option

  val upgrade :
       t
    -> protocol_states_for_scan_state:
         (State_hash.t * Mina_state.Protocol_state.value) list
    -> protocol_state:Mina_state.Protocol_state.Value.t
    -> block_tag:Mina_block.Stable.Latest.t State_hash.File_storage.tag
    -> Limited.t

  val create :
       state_hash:State_hash.t
    -> scan_state:Staged_ledger.Scan_state.t
    -> pending_coinbase:Pending_coinbase.t
    -> block_tag:Mina_block.Stable.Latest.t State_hash.File_storage.tag
    -> protocol_state:Mina_state.Protocol_state.Value.t
    -> delta_block_chain_proof:State_hash.t Mina_stdlib.Nonempty_list.t
    -> t
end

type t =
  { block_tag : Mina_block.Stable.Latest.t Mina_base.State_hash.File_storage.tag
  ; state_hash : State_hash.t
  ; protocol_state : Mina_state.Protocol_state.Value.t
  ; scan_state : Staged_ledger.Scan_state.t
  ; pending_coinbase : Pending_coinbase.t
  ; protocol_states_for_scan_state :
      Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
      list
  ; delta_block_chain_proof : State_hash.t Mina_stdlib.Nonempty_list.t
  }

val minimize : t -> Minimal.t

val limit : t -> Limited.t

val to_common : t -> Common.t
