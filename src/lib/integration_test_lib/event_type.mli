open Core_kernel
open Mina_base

type 'a parse_event =
  | From_error_log of (Logger.Message.t -> 'a Or_error.t)
  | From_daemon_log of
      Structured_log_events.id * (Logger.Message.t -> 'a Or_error.t)
  | From_puppeteer_log of string * (Puppeteer_message.t -> 'a Or_error.t)

module type Event_type_intf = sig
  type t [@@deriving to_yojson]

  val name : string

  val parse : t parse_event
end

module Log_error : sig
  type t = Logger.Message.t

  include Event_type_intf with type t := t
end

module Node_initialization : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Node_offline : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Transition_frontier_diff_application : sig
  type root_transitioned =
    { new_root : State_hash.t; garbage : State_hash.t list }

  type t =
    { new_node : State_hash.t option
    ; best_tip_changed : State_hash.t option
    ; root_transitioned : root_transitioned option
    }

  include Event_type_intf with type t := t
end

module Block_produced : sig
  type t =
    { block_height : int
    ; epoch : int
    ; global_slot : int
    ; snarked_ledger_generated : bool
    ; state_hash : State_hash.t
    }

  include Event_type_intf with type t := t

  (*
  type aggregated =
    {last_seen_result: t; blocks_generated: int; snarked_ledgers_generated: int}
  [@@deriving to_yojson]

  val empty_aggregated : aggregated

  val init_aggregated : t -> aggregated

  val aggregate : aggregated -> t -> aggregated
  *)
end

module Breadcrumb_added : sig
  type t =
    { state_hash : State_hash.t
    ; user_commands : User_command.Valid.t With_status.t list
    }

  include Event_type_intf with type t := t
end

module Transition_frontier_loaded_from_persistence : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Persisted_frontier_loaded : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Persisted_frontier_fresh_boot : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Bootstrap_required : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Persisted_frontier_dropped : sig
  type t = unit

  include Event_type_intf with type t := t
end

module Gossip : sig
  module Direction : sig
    type t = Sent | Received [@@deriving yojson]
  end

  module With_direction : sig
    type 'a t = 'a * Direction.t [@@deriving yojson]
  end

  module Block : sig
    type r = { state_hash : State_hash.t } [@@deriving hash, yojson]

    type t = r With_direction.t

    include Event_type_intf with type t := t
  end

  module Snark_work : sig
    type r = { work : Network_pool.Snark_pool.Resource_pool.Diff.compact }
    [@@deriving hash, yojson]

    type t = r With_direction.t

    include Event_type_intf with type t := t
  end

  module Transactions : sig
    type r = { txns : Network_pool.Transaction_pool.Resource_pool.Diff.t }
    [@@deriving hash, yojson]

    type t = r With_direction.t

    include Event_type_intf with type t := t
  end
end

module Snark_work_failed : sig
  type t = { error : Yojson.Safe.t }

  include Event_type_intf with type t := t
end

type 'a t =
  | Log_error : Log_error.t t
  | Node_initialization : Node_initialization.t t
  | Node_offline : Node_offline.t t
  | Transition_frontier_diff_application
      : Transition_frontier_diff_application.t t
  | Block_produced : Block_produced.t t
  | Breadcrumb_added : Breadcrumb_added.t t
  | Block_gossip : Gossip.Block.t t
  | Snark_work_gossip : Gossip.Snark_work.t t
  | Transactions_gossip : Gossip.Transactions.t t
  | Snark_work_failed : Snark_work_failed.t t
  | Transition_frontier_loaded_from_persistence
      : Transition_frontier_loaded_from_persistence.t t
  | Persisted_frontier_loaded : Persisted_frontier_loaded.t t
  | Persisted_frontier_fresh_boot : Persisted_frontier_fresh_boot.t t
  | Persisted_frontier_dropped : Persisted_frontier_dropped.t t
  | Bootstrap_required : Bootstrap_required.t t

val to_string : 'a t -> string

type existential = Event_type : 'a t -> existential
[@@deriving sexp, to_yojson]

val all_event_types : existential list

val event_type_module : 'a t -> (module Event_type_intf with type t = 'a)

val existential_to_string : existential -> string

val existential_of_string_exn : string -> existential

val to_structured_event_id : existential -> Structured_log_events.id option

val of_structured_event_id : Structured_log_events.id -> existential option

module Map : Map.S with type Key.t = existential

type event = Event : 'a t * 'a -> event [@@deriving to_yojson]

val type_of_event : event -> existential

val parse_daemon_event : Logger.Message.t -> (event, Error.t) result

val parse_error_log : Logger.Message.t -> (event, Error.t) result

val parse_puppeteer_event : Puppeteer_message.t -> (event, Error.t) result

val dispatch_exn : 'a t -> 'a -> 'b t -> ('b -> 'c) -> 'c
