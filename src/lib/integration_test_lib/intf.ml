open Async_kernel
open Core_kernel
open Mina_base
open Pipe_lib
open Mina_transaction

type metrics_t =
  { block_production_delay : int list
  ; transaction_pool_diff_received : int
  ; transaction_pool_diff_broadcasted : int
  ; transactions_added_to_pool : int
  ; transaction_pool_size : int
  }

type best_chain_block =
  { state_hash : string; command_transaction_count : int; creator_pk : string }

(* TODO: malleable error -> or error *)

module Engine = struct
  module type Network_config_intf = sig
    module Cli_inputs : sig
      type t

      val term : t Cmdliner.Term.t
    end

    type t

    val expand :
         logger:Logger.t
      -> test_name:string
      -> cli_inputs:Cli_inputs.t
      -> debug:bool
      -> test_config:Test_config.t
      -> images:Test_config.Container_images.t
      -> t
  end

  module type Network_intf = sig
    module Node : sig
      type t

      val id : t -> string

      val network_keypair : t -> Network_keypair.t option

      val start : fresh_state:bool -> t -> unit Malleable_error.t

      val stop : t -> unit Malleable_error.t

      type signed_command_result =
        { id : string
        ; hash : Transaction_hash.t
        ; nonce : Mina_numbers.Account_nonce.t
        }

      val graphql_uri : t -> string

      val send_payment :
           logger:Logger.t
        -> t
        -> sender_pub_key:Signature_lib.Public_key.Compressed.t
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> amount:Currency.Amount.t
        -> fee:Currency.Fee.t
        -> signed_command_result Deferred.Or_error.t

      val must_send_payment :
           logger:Logger.t
        -> t
        -> sender_pub_key:Signature_lib.Public_key.Compressed.t
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> amount:Currency.Amount.t
        -> fee:Currency.Fee.t
        -> signed_command_result Malleable_error.t

      val send_payment_with_raw_sig :
           logger:Logger.t
        -> t
        -> sender_pub_key:Signature_lib.Public_key.Compressed.t
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> amount:Currency.Amount.t
        -> fee:Currency.Fee.t
        -> nonce:Mina_numbers.Account_nonce.t
        -> memo:string
        -> valid_until:Mina_numbers.Global_slot.t
        -> raw_signature:string
        -> signed_command_result Deferred.Or_error.t

      val must_send_payment_with_raw_sig :
           logger:Logger.t
        -> t
        -> sender_pub_key:Signature_lib.Public_key.Compressed.t
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> amount:Currency.Amount.t
        -> fee:Currency.Fee.t
        -> nonce:Mina_numbers.Account_nonce.t
        -> memo:string
        -> valid_until:Mina_numbers.Global_slot.t
        -> raw_signature:string
        -> signed_command_result Malleable_error.t

      val send_delegation :
           logger:Logger.t
        -> t
        -> sender_pub_key:Signature_lib.Public_key.Compressed.t
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> fee:Currency.Fee.t
        -> signed_command_result Deferred.Or_error.t

      val must_send_delegation :
           logger:Logger.t
        -> t
        -> sender_pub_key:Signature_lib.Public_key.Compressed.t
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> fee:Currency.Fee.t
        -> signed_command_result Malleable_error.t

      (** returned string is the transaction id *)
      val send_zkapp :
           logger:Logger.t
        -> t
        -> zkapp_command:Mina_base.Zkapp_command.t
        -> string Deferred.Or_error.t

      val must_send_test_payments :
           repeat_count:Unsigned.UInt32.t
        -> repeat_delay_ms:Unsigned.UInt32.t
        -> logger:Logger.t
        -> t
        -> senders:Signature_lib.Private_key.t list
        -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
        -> amount:Currency.Amount.t
        -> fee:Currency.Fee.t
        -> unit Malleable_error.t

      type account_data =
        { nonce : Mina_numbers.Account_nonce.t
        ; total_balance : Currency.Balance.t
        ; liquid_balance_opt : Currency.Balance.t option
        ; locked_balance_opt : Currency.Balance.t option
        }

      val get_account_data :
           logger:Logger.t
        -> t
        -> account_id:Mina_base.Account_id.t
        -> account_data Deferred.Or_error.t

      val must_get_account_data :
           logger:Logger.t
        -> t
        -> account_id:Mina_base.Account_id.t
        -> account_data Malleable_error.t

      val get_account_permissions :
           logger:Logger.t
        -> t
        -> account_id:Mina_base.Account_id.t
        -> Mina_base.Permissions.t Deferred.Or_error.t

      (** the returned Update.t is constructed from the fields of the
          given account, as if it had been applied to the account
      *)
      val get_account_update :
           logger:Logger.t
        -> t
        -> account_id:Mina_base.Account_id.t
        -> Mina_base.Account_update.Update.t Deferred.Or_error.t

      val get_peer_id :
        logger:Logger.t -> t -> (string * string list) Deferred.Or_error.t

      val must_get_peer_id :
        logger:Logger.t -> t -> (string * string list) Malleable_error.t

      val get_best_chain :
           ?max_length:int
        -> logger:Logger.t
        -> t
        -> best_chain_block list Deferred.Or_error.t

      val must_get_best_chain :
           ?max_length:int
        -> logger:Logger.t
        -> t
        -> best_chain_block list Malleable_error.t

      val dump_archive_data :
        logger:Logger.t -> t -> data_file:string -> unit Malleable_error.t

      val run_replayer : logger:Logger.t -> t -> string Malleable_error.t

      val dump_mina_logs :
        logger:Logger.t -> t -> log_file:string -> unit Malleable_error.t

      val dump_precomputed_blocks :
        logger:Logger.t -> t -> unit Malleable_error.t

      val get_metrics : logger:Logger.t -> t -> metrics_t Deferred.Or_error.t
    end

    type t

    val constants : t -> Test_config.constants

    val constraint_constants : t -> Genesis_constants.Constraint_constants.t

    val genesis_constants : t -> Genesis_constants.t

    val seeds : t -> Node.t list

    val all_non_seed_pods : t -> Node.t list

    val block_producers : t -> Node.t list

    val snark_coordinators : t -> Node.t list

    val archive_nodes : t -> Node.t list

    val all_nodes : t -> Node.t list

    val all_keypairs : t -> Signature_lib.Keypair.t list

    val block_producer_keypairs : t -> Signature_lib.Keypair.t list

    val extra_genesis_keypairs : t -> Signature_lib.Keypair.t list

    val initialize_infra : logger:Logger.t -> t -> unit Malleable_error.t
  end

  module type Network_manager_intf = sig
    module Network_config : Network_config_intf

    module Network : Network_intf

    type t

    val create : logger:Logger.t -> Network_config.t -> t Malleable_error.t

    val deploy : t -> Network.t Malleable_error.t

    val destroy : t -> unit Malleable_error.t

    val cleanup : t -> unit Deferred.t
  end

  module type Log_engine_intf = sig
    module Network : Network_intf

    type t

    val create : logger:Logger.t -> network:Network.t -> t Deferred.Or_error.t

    val destroy : t -> unit Deferred.Or_error.t

    val event_reader : t -> (Network.Node.t * Event_type.event) Pipe.Reader.t
  end

  (** The signature of integration test engines. An integration test engine
   *  provides the core functionality for deploying, monitoring, and
   *  interacting with networks.
   *)
  module type S = sig
    (* unique name identifying the engine (used in test executive cli) *)
    val name : string

    module Network_config : Network_config_intf

    module Network : Network_intf

    module Network_manager :
      Network_manager_intf
        with module Network_config := Network_config
         and module Network := Network

    module Log_engine : Log_engine_intf with module Network := Network
  end
end

module Dsl = struct
  module type Event_router_intf = sig
    module Engine : Engine.S

    type t

    type ('a, 'b) handler_func =
      Engine.Network.Node.t -> 'a -> [ `Stop of 'b | `Continue ] Deferred.t

    type 'a event_subscription

    val create :
         logger:Logger.t
      -> event_reader:(Engine.Network.Node.t * Event_type.event) Pipe.Reader.t
      -> t

    val on :
      t -> 'a Event_type.t -> f:('a, 'b) handler_func -> 'b event_subscription

    val cancel : t -> 'a event_subscription -> 'a -> unit

    val await : 'a event_subscription -> 'a Deferred.t

    val await_with_timeout :
         t
      -> 'a event_subscription
      -> timeout_duration:Time.Span.t
      -> timeout_cancellation:'a
      -> 'a Deferred.t
  end

  module type Network_state_intf = sig
    module Engine : Engine.S

    module Event_router : Event_router_intf with module Engine := Engine

    type t =
      { block_height : int
      ; epoch : int
      ; global_slot : int
      ; snarked_ledgers_generated : int
      ; blocks_generated : int
      ; node_initialization : bool String.Map.t
      ; gossip_received : Gossip_state.t String.Map.t
      ; best_tips_by_node : State_hash.t String.Map.t
      ; blocks_produced_by_node : State_hash.t list String.Map.t
      ; blocks_seen_by_node : State_hash.Set.t String.Map.t
      ; blocks_including_txn : State_hash.Set.t Transaction_hash.Map.t
      }

    val listen :
         logger:Logger.t
      -> Event_router.t
      -> t Broadcast_pipe.Reader.t * t Broadcast_pipe.Writer.t
  end

  module type Wait_condition_intf = sig
    module Engine : Engine.S

    module Event_router : Event_router_intf with module Engine := Engine

    module Network_state :
      Network_state_intf
        with module Engine := Engine
         and module Event_router := Event_router

    type t

    type wait_condition_id =
      | Nodes_to_initialize
      | Blocks_to_be_produced
      | Nodes_to_synchronize
      | Signed_command_to_be_included_in_frontier
      | Ledger_proofs_emitted_since_genesis
      | Block_height_growth
      | Zkapp_to_be_included_in_frontier
      | Persisted_frontier_loaded

    val wait_condition_id : t -> wait_condition_id

    val with_timeouts :
         ?soft_timeout:Network_time_span.t
      -> ?hard_timeout:Network_time_span.t
      -> t
      -> t

    val node_to_initialize : Engine.Network.Node.t -> t

    val nodes_to_initialize : Engine.Network.Node.t list -> t

    val blocks_to_be_produced : int -> t

    val block_height_growth : height_growth:int -> t

    val nodes_to_synchronize : Engine.Network.Node.t list -> t

    val signed_command_to_be_included_in_frontier :
         txn_hash:Transaction_hash.t
      -> node_included_in:[ `Any_node | `Node of Engine.Network.Node.t ]
      -> t

    val ledger_proofs_emitted_since_genesis : num_proofs:int -> t

    val zkapp_to_be_included_in_frontier :
      has_failures:bool -> parties:Mina_base.Zkapp_command.t -> t

    val persisted_frontier_loaded : Engine.Network.Node.t -> t
  end

  module type Util_intf = sig
    module Engine : Engine.S

    val pub_key_of_node :
         Engine.Network.Node.t
      -> Signature_lib.Public_key.Compressed.t Malleable_error.t

    val priv_key_of_node :
      Engine.Network.Node.t -> Signature_lib.Private_key.t Malleable_error.t

    val check_common_prefixes :
         tolerance:int
      -> logger:Logger.t
      -> string list list
      -> ( unit Malleable_error.Result_accumulator.t
         , Malleable_error.Hard_fail.t )
         result
         Deferred.t

    val fetch_connectivity_data :
         logger:Logger.t
      -> Engine.Network.Node.t list
      -> ( (Engine.Network.Node.t * (string * string list)) list
           Malleable_error.Result_accumulator.t
         , Malleable_error.Hard_fail.t )
         result
         Deferred.t

    val assert_peers_completely_connected :
         (Engine.Network.Node.t * (string * string list)) list
      -> ( unit Malleable_error.Result_accumulator.t
         , Malleable_error.Hard_fail.t )
         result
         Deferred.t

    val assert_peers_cant_be_partitioned :
         max_disconnections:int
      -> (Engine.Network.Node.t * (string * string list)) list
      -> ( unit Malleable_error.Result_accumulator.t
         , Malleable_error.Hard_fail.t )
         result
         Deferred.t
  end

  module type S = sig
    module Engine : Engine.S

    module Event_router : Event_router_intf with module Engine := Engine

    module Network_state :
      Network_state_intf
        with module Engine := Engine
         and module Event_router := Event_router

    module Wait_condition :
      Wait_condition_intf
        with module Engine := Engine
         and module Event_router := Event_router
         and module Network_state := Network_state

    module Util : Util_intf with module Engine := Engine

    type t

    val section_hard : string -> 'a Malleable_error.t -> 'a Malleable_error.t

    val section : string -> unit Malleable_error.t -> unit Malleable_error.t

    val network_state : t -> Network_state.t

    val event_router : t -> Event_router.t

    val wait_for : t -> Wait_condition.t -> unit Malleable_error.t

    (* TODO: move this functionality to a more suitable location *)
    val create :
         logger:Logger.t
      -> network:Engine.Network.t
      -> event_router:Event_router.t
      -> network_state_reader:Network_state.t Broadcast_pipe.Reader.t
      -> [ `Don't_call_in_tests of t ]

    type log_error_accumulator

    val watch_log_errors :
         logger:Logger.t
      -> event_router:Event_router.t
      -> on_fatal_error:(Logger.Message.t -> unit)
      -> log_error_accumulator

    val lift_accumulated_log_errors :
         ?exit_code:int
      -> log_error_accumulator
      -> Test_error.remote_error Test_error.Set.t
  end
end

module Test = struct
  module type Inputs_intf = sig
    module Engine : Engine.S

    module Dsl : Dsl.S with module Engine := Engine
  end

  module type S = sig
    type network

    type node

    type dsl

    val config : Test_config.t

    val run : network -> dsl -> unit Malleable_error.t
  end

  (* NB: until the DSL is actually implemented, a test just takes in the engine
   * implementation directly. *)
  module type Functor_intf = functor (Inputs : Inputs_intf) ->
    S
      with type network = Inputs.Engine.Network.t
       and type node = Inputs.Engine.Network.Node.t
       and type dsl = Inputs.Dsl.t
end
