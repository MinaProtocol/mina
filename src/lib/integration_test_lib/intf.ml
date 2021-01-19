open Async_kernel
open Core_kernel

(* TODO: malleable error -> or error *)

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
    -> test_config:Test_config.t
    -> images:Test_config.Container_images.t
    -> t
end

module type Network_intf = sig
  module Node : sig
    type t

    val start : fresh_state:bool -> t -> unit Malleable_error.t

    val stop : t -> unit Malleable_error.t

    val send_payment :
         ?retry_on_graphql_error:bool
      -> logger:Logger.t
      -> t
      -> sender:Signature_lib.Public_key.Compressed.t
      -> receiver:Signature_lib.Public_key.Compressed.t
      -> amount:Currency.Amount.t
      -> fee:Currency.Fee.t
      -> unit Malleable_error.t

    val get_balance :
         logger:Logger.t
      -> t
      -> account_id:Mina_base.Account_id.t
      -> Currency.Balance.t Malleable_error.t

    val get_peer_id :
      logger:Logger.t -> t -> (string * string list) Malleable_error.t
  end

  type t

  val constraint_constants : t -> Genesis_constants.Constraint_constants.t

  val genesis_constants : t -> Genesis_constants.t

  val block_producers : t -> Node.t list

  val snark_coordinators : t -> Node.t list

  val archive_nodes : t -> Node.t list

  val keypairs : t -> Signature_lib.Keypair.t list
end

module type Network_manager_intf = sig
  module Network_config : Network_config_intf

  module Network : Network_intf

  type t

  val create : logger:Logger.t -> Network_config.t -> t Deferred.t

  val deploy : t -> Network.t Deferred.t

  val destroy : t -> unit Deferred.t

  val cleanup : t -> unit Deferred.t
end

module type Log_engine_intf = sig
  module Network : Network_intf

  type t

  val create :
       logger:Logger.t
    -> network:Network.t
    -> on_fatal_error:(Logger.Message.t -> unit)
    -> t Malleable_error.t

  val destroy : t -> Test_error.Set.t Malleable_error.t

  (** waits until a block is produced with at least one of the following conditions being true
    1. Blockchain length = blocks
    2. epoch of the block = epoch_reached
    3. Has seen some number of slots/epochs crossed/snarked ledgers generated or x milliseconds has passed
  Note: Varying number of snarked ledgers generated because of reorgs is not captured here *)
  val wait_for :
       ?blocks:int
    -> ?epoch_reached:int
    -> ?snarked_ledgers_generated:int
    -> ?timeout:[ `Slots of int
                | `Epochs of int
                | `Snarked_ledgers_generated of int
                | `Milliseconds of int64 ]
    -> t
    -> ( [> `Blocks_produced of int]
       * [> `Slots_passed of int]
       * [> `Snarked_ledgers_generated of int] )
       Malleable_error.t

  val wait_for_sync :
    Network.Node.t list -> timeout:Time.Span.t -> t -> unit Malleable_error.t

  val wait_for_init : Network.Node.t -> t -> unit Malleable_error.t

  (** wait until a payment transaction appears in an added breadcrumb
      num_tries is the maximum number of breadcrumbs to examine
  *)
  val wait_for_payment :
       ?timeout_duration:Time.Span.t
    -> t
    -> logger:Logger.t
    -> sender:Signature_lib.Public_key.Compressed.t
    -> receiver:Signature_lib.Public_key.Compressed.t
    -> amount:Currency.Amount.t
    -> unit
    -> unit Malleable_error.t
end

(** The signature of integration test engines. An integration test engine
 *  provides the core functionality for deploying, monitoring, and
 *  interacting with networks.
 *)
module type Engine_intf = sig
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

module type Test_intf = sig
  type network

  type log_engine

  val config : Test_config.t

  val expected_error_event_reprs : Structured_log_events.repr list

  val run : network -> log_engine -> unit Malleable_error.t
end

(* NB: until the DSL is actually implemented, a test just takes in the engine
 * implementation directly. *)
module type Test_functor_intf = functor (Engine : Engine_intf) -> Test_intf
                                                                  with type network =
                                                                              Engine
                                                                              .Network
                                                                              .t
                                                                   and type log_engine =
                                                                              Engine
                                                                              .Log_engine
                                                                              .t
