open Async_kernel

module Node : Test_intf.Node_intf = struct
  type t = unit

  let start _t = Deferred.Or_error.unit

  let stop _t = Deferred.Or_error.unit

  let send_payment _t _input = Deferred.Or_error.error_string "Not implemented"
end

module Network_config : Test_intf.Network_config_intf = struct
  type t = unit

  let create () = ()
end

module Daemon_config : Test_intf.Daemon_config_intf = struct
  type t = unit

  let create () = ()
end

module Testnet : Test_intf.Testnet_intf = struct
  type node = Node.t

  type t =
    { block_producers: Node.t list
    ; snark_coordinators: Node.t list
    ; archive_nodes: Node.t list
    ; testnet_log_filter: string }
end

module Network_manager : Test_intf.Network_manager_intf = struct
  type testnet = Testnet.t

  type network_config = Network_config.t

  type daemon_config = Demon_config.t

  let deploy _network_config _daemon_config = Deferred.unit

  let destroy _testnet = Deferred.unit
end

module Log_engine = Stack_driver_log_engine.Make (Testnet)

let main () =
  let open Deferred.Or_error.Let_syntax in
  let logger = Logger.create () in
  let network_config = Network_config.create () in
  let daemon_config = Daemon_config.create () in
  let%bind testnet = Network_manager.deploy network_config daemon_config in
  let%bind log_engine = Log_engine.create ~logger testnet in
  let%bind () = wait_for ~blocks:1 log_engine in
  Network_manager.destroy testnet
