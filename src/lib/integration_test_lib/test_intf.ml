open Async_kernel

module type Node_intf = sig
  type t

  val start : t -> unit Deferred.t

  val stop : t -> unit Deferred.t

  val send_payment :
    t -> User_command_input.t -> Coda_base.User_command.t Deferred.Or_error.t
end

module type Network_config_intf = sig
  type t
end

module type Daemon_config_intf = sig
  type t
end

module type Testnet_intf = sig
  type node

  type t =
    { block_producers: node list
    ; snark_coordinators: node list
    ; archive_nodes: node list
    ; testnet_log_filter: string }
end

module type Network_manager_intf = sig
  type testnet

  type network_config

  type daemon_config

  (* Deploy the network*)
  val deploy : network_config -> daemon_config -> testnet Deferred.t

  (*Tear down the network*)
  val destroy : testnet -> unit Deferred.t
end

module type Log_engine_intf = sig
  type t

  type testnet

  val create : logger:Logger.t -> testnet -> t Deferred.Or_error.t

  val delete : t -> unit Deferred.Or_error.t

  (** waits until a block is produced with at least one of the following conditions being true
    1. Blockchain length = blocks
    2. epoch of the block = epoch_reached
    3. Has seen some number of slots/epochs crossed/snarked ledgers generated or x milliseconds has passed
  Note: Varying number of snarked ledgers generated because of reorgs is not captured here *)
  val wait_for :
       ?blocks:int
    -> ?epoch_reached:int
    -> ?timeout:[ `Slots of int
                | `Epochs of int
                | `Snarked_ledgers_generated of int
                | `Milliseconds of int64 ]
    -> t
    -> unit Deferred.Or_error.t
end

module type Make_log_engine_intf = functor (Testnet : Testnet_intf) -> Log_engine_intf
                                                                       with type 
                                                                       testnet :=
                                                                         Testnet
                                                                         .t
