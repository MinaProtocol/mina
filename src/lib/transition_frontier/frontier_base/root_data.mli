open Mina_base

module Common : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t
    end
  end]

  module Serializable_type : sig
    type raw_serializable := Stable.Latest.t

    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t
      end
    end]

    val to_raw_serializable : t -> raw_serializable
  end

  type t

  val read_all_proofs_from_disk : t -> Stable.V2.t

  val to_serializable_type : t -> Serializable_type.t
end

(* Historical root data is similar to Limited root data, except that it also
 * contains a recording of some extra computed staged ledger properties that
 * were available on a breadcrumb in the transition frontier when this was
 * created. *)
module Historical : sig
  type t

  val transition : t -> Mina_block.Validated.t

  val scan_state : t -> Staged_ledger.Scan_state.t

  val pending_coinbase : t -> Pending_coinbase.t

  val staged_ledger_target_ledger_hash : t -> Ledger_hash.t

  val of_breadcrumb : Breadcrumb.t -> t
end

(* Limited root data is similar to Minimal root data, except that it contains
 * the full validated transition at a root instead of just a pointer to one and protocol states for the root scan state *)
module Limited : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V3 : sig
      type t

      val hashes : t -> State_hash.State_hashes.Stable.V1.t

      val common : t -> Common.Stable.V2.t

      val protocol_states :
           t
        -> Mina_state.Protocol_state.Value.Stable.V2.t
           Mina_base.State_hash.With_state_hashes.Stable.V1.t
           list

      val create :
           transition:Mina_block.Validated.Stable.V2.t
        -> scan_state:Staged_ledger.Scan_state.Stable.V2.t
        -> pending_coinbase:Pending_coinbase.Stable.V2.t
        -> protocol_states:
             Mina_state.Protocol_state.value
             State_hash.With_state_hashes.Stable.V1.t
             list
        -> t
    end
  end]

  module Serializable_type : sig
    [%%versioned:
    module Stable : sig
      module V3 : sig
        type t
      end
    end]

    val hashes : t -> State_hash.State_hashes.Stable.V1.t

    val common : t -> Common.Serializable_type.t

    val protocol_states :
         t
      -> Mina_state.Protocol_state.Value.Stable.V2.t
         Mina_base.State_hash.With_state_hashes.Stable.V1.t
         list

    val create :
         transition:Mina_block.Validated.Serializable_type.Stable.V2.t
      -> scan_state:Staged_ledger.Scan_state.Serializable_type.Stable.V2.t
      -> pending_coinbase:Pending_coinbase.Stable.V2.t
      -> protocol_states:
           Mina_state.Protocol_state.value
           State_hash.With_state_hashes.Stable.V1.t
           list
      -> t
  end

  type t [@@deriving to_yojson]

  val transition : t -> Mina_block.Validated.t

  val hashes : t -> State_hash.State_hashes.t

  val scan_state : t -> Staged_ledger.Scan_state.t

  val pending_coinbase : t -> Pending_coinbase.t

  val protocol_states :
    t -> Mina_state.Protocol_state.value State_hash.With_state_hashes.t list

  val create :
       transition:Mina_block.Validated.t
    -> scan_state:Staged_ledger.Scan_state.t
    -> pending_coinbase:Pending_coinbase.t
    -> protocol_states:
         Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
    -> t

  val common : t -> Common.t
end

(* Minimal root data contains the smallest amount of information about a root.
 * It contains a hash pointing to the root transition, and the auxiliary data
 * needed to reconstruct the staged ledger at that point (scan_state,
 * pending_coinbase).
 *)
module Minimal : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t

      val hash : t -> State_hash.t

      val of_limited : common:Common.Stable.V2.t -> State_hash.Stable.V1.t -> t

      val common : t -> Common.Stable.V2.t

      val scan_state : t -> Staged_ledger.Scan_state.Stable.V2.t

      val pending_coinbase : t -> Pending_coinbase.Stable.V2.t
    end
  end]

  module Serializable_type : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t

        val hash : t -> State_hash.t

        val of_limited :
          common:Common.Serializable_type.t -> State_hash.Stable.V1.t -> t

        val common : t -> Common.Serializable_type.t

        val scan_state :
          t -> Staged_ledger.Scan_state.Serializable_type.Stable.V2.t

        val pending_coinbase : t -> Pending_coinbase.Stable.V2.t
      end
    end]
  end

  type t

  val hash : t -> State_hash.t

  val scan_state : t -> Staged_ledger.Scan_state.t

  val pending_coinbase : t -> Pending_coinbase.t

  val of_limited : common:Common.t -> State_hash.t -> t

  val upgrade :
       t
    -> transition:Mina_block.Validated.t
    -> protocol_states:
         (Mina_base.State_hash.t * Mina_state.Protocol_state.Value.t) list
    -> Limited.t

  val create :
       hash:State_hash.t
    -> scan_state:Staged_ledger.Scan_state.t
    -> pending_coinbase:Pending_coinbase.t
    -> t

  val read_all_proofs_from_disk : t -> Stable.Latest.t
end

type t =
  { transition : Mina_block.Validated.t
  ; staged_ledger : Staged_ledger.t
  ; protocol_states :
      Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
      list
  }

val minimize : t -> Minimal.t

val limit : t -> Limited.t
