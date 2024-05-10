open Core_kernel

module Proof_level : sig
  type t = Full | Check | None [@@deriving equal]

  include Binable.S with type t := t

  val to_string : t -> string

  val of_string : string -> t

  val compiled : t

  val for_unit_tests : t
end

module Fork_constants : sig
  type t =
    { state_hash : Pickles.Backend.Tick.Field.Stable.Latest.t
    ; blockchain_length : Mina_numbers.Length.Stable.Latest.t
    ; global_slot_since_genesis :
        Mina_numbers.Global_slot_since_genesis.Stable.Latest.t
    }
  [@@deriving sexp, equal, compare, yojson]

  include Binable.S with type t := t
end

module Constraint_constants : sig
  type t =
    { sub_windows_per_window : int
    ; ledger_depth : int
    ; work_delay : int
    ; block_window_duration_ms : int
    ; transaction_capacity_log_2 : int
    ; pending_coinbase_depth : int
    ; coinbase_amount : Currency.Amount.Stable.Latest.t
    ; supercharged_coinbase_factor : int
    ; account_creation_fee : Currency.Fee.Stable.Latest.t
    ; fork : Fork_constants.t option
    }
  [@@deriving sexp, equal, compare, yojson]

  include Binable.S with type t := t

  val to_snark_keys_header : t -> Snark_keys_header.Constraint_constants.t

  val compiled : t

  val for_unit_tests : t
end

module Protocol : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('length, 'delta, 'genesis_state_timestamp) t =
              ( 'length
              , 'delta
              , 'genesis_state_timestamp )
              Mina_wire_types.Genesis_constants.Protocol.Poly.V1.t =
          { k : 'length
          ; slots_per_epoch : 'length
          ; slots_per_sub_window : 'length
          ; grace_period_slots : 'length
          ; delta : 'delta
          ; genesis_state_timestamp : 'genesis_state_timestamp
          }
        [@@deriving equal, ord, hash, sexp, yojson, hlist, fields]
      end
    end]
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = (int, int, Int64.t) Poly.Stable.V1.t
      [@@deriving equal, ord, hash, to_yojson, sexp_of]
    end
  end]
end

type t =
  { protocol : Protocol.Stable.Latest.t
  ; txpool_max_size : int
  ; num_accounts : int option
  ; zkapp_proof_update_cost : float
  ; zkapp_signed_single_update_cost : float
  ; zkapp_signed_pair_update_cost : float
  ; zkapp_transaction_cost_limit : float
  ; max_event_elements : int
  ; max_action_elements : int
  ; zkapp_cmd_limit_hardcap : int
  }
[@@deriving to_yojson, sexp_of]

include Binable.S with type t := t

val hash : t -> string

val validate_time : string -> (int64, string) result

val genesis_timestamp_of_string : string -> Time.t

val genesis_timestamp_to_string : int64 -> string

val genesis_state_timestamp_string : string

val k : int

val slots_per_epoch : int

val slots_per_sub_window : int

val grace_period_slots : int

val delta : int

val pool_max_size : int

val compiled : t

val for_unit_tests : t
