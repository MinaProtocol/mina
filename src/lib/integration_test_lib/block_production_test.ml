open Async_kernel

module Node : Test_intf.Node_intf = struct
  type t = unit

  let start _t = Deferred.Or_error.return ()

  let stop _t = Deferred.Or_error.return ()

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

module Network_manager :
  Test_intf.Network_manager_intf
  with type network_config = Network_config.t
   and type daemon_config = Daemon_config.t
   and type testnet = Testnet.t = struct
  type testnet = Testnet.t

  type network_config = Network_config.t

  type daemon_config = Daemon_config.t

  let deploy _network_config _daemon_config =
    Deferred.Or_error.return
      { Testnet.block_producers= []
      ; snark_coordinators= []
      ; archive_nodes= []
      ; testnet_log_filter= "" }

  let destroy _testnet = Deferred.Or_error.return ()
end

module Log_engine = Stack_driver_log_engine.Make (Testnet)

let main () =
  let open Deferred.Or_error.Let_syntax in
  let logger = Logger.create () in
  let network_config = Network_config.create () in
  let daemon_config = Daemon_config.create () in
  let%bind testnet = Network_manager.deploy network_config daemon_config in
  let%bind log_engine = Log_engine.create ~logger testnet in
  let%bind () = Log_engine.wait_for ~blocks:1 log_engine in
  Network_manager.destroy testnet
