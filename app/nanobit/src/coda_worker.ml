open Core
open Async
open Nanobit_base
open Coda_main

module Make
    (Kernel : Kernel_intf)
    (Coda : Coda_intf.S with type ledger_proof = Kernel.Ledger_proof.t) =
struct
  type input =
    { host: string
    ; conf_dir: string
    ; program_dir: string
    ; my_port: int
    ; gossip_port: int
    ; peers: Host_and_port.t list }
  [@@deriving bin_io]

  module T = struct
    module Peers = struct
      type t = Host_and_port.t List.t [@@deriving bin_io]
    end

    type 'worker functions =
      { peers: ('worker, unit, Peers.t) Rpc_parallel.Function.t
      ; strongest_ledgers:
          ('worker, unit, unit Pipe.Reader.t) Rpc_parallel.Function.t }

    type coda_functions =
      { coda_peers: unit -> Peers.t Deferred.t
      ; coda_strongest_ledgers: unit -> unit Pipe.Reader.t Deferred.t }

    module Worker_state = struct
      type init_arg = input [@@deriving bin_io]

      type t = coda_functions
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]

      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
             with type worker_state := Worker_state.t
              and type connection_state := Connection_state.t) =
    struct
      let peers_impl ~worker_state ~conn_state:() () =
        worker_state.coda_peers ()

      let strongest_ledgers_impl ~worker_state ~conn_state:() () =
        worker_state.coda_strongest_ledgers ()

      let peers =
        C.create_rpc ~f:peers_impl ~bin_input:Unit.bin_t
          ~bin_output:Peers.bin_t ()

      let strongest_ledgers =
        C.create_pipe ~f:strongest_ledgers_impl ~bin_input:Unit.bin_t
          ~bin_output:Unit.bin_t ()

      let functions = {peers; strongest_ledgers}

      let init_worker_state
          {host; conf_dir; program_dir; my_port; peers; gossip_port} =
        let log = Logger.create () in
        let log =
          Logger.child log ("host: " ^ host ^ ":" ^ Int.to_string my_port)
        in
        let module Config = struct
          let logger = log

          let conf_dir = conf_dir

          let lbc_tree_max_depth = `Finite 50

          let transition_interval = Time.Span.of_ms 100.0

          let fee_public_key = Genesis_ledger.rich_pk

          let genesis_proof = Precomputed_values.base_proof
        end in
        let%bind (module Init) = make_init (module Config) (module Kernel) in
        let module Main = Coda.Make (Init) () in
        let module Run = Run (Main) in
        let net_config =
          { Main.Inputs.Net.Config.parent_log= log
          ; gossip_net_params=
              { Main.Inputs.Net.Gossip_net.Config.timeout= Time.Span.of_sec 1.
              ; target_peer_count= 8
              ; conf_dir
              ; address= Host_and_port.create ~host ~port:gossip_port
              ; initial_peers= peers
              ; me= Host_and_port.create ~host ~port:my_port
              ; parent_log= log } }
        in
        let%bind coda =
          Main.create
            (Main.Config.make ~log ~net_config
               ~ledger_builder_persistant_location:"ledger_builder"
               ~transaction_pool_disk_location:"transaction_pool"
               ~snark_pool_disk_location:"snark_pool"
               ~time_controller:(Main.Inputs.Time.Controller.create ())
               ())
        in
        let coda_peers () = return (Main.peers coda) in
        let coda_strongest_ledgers () =
          let r, w = Linear_pipe.create () in
          don't_wait_for
            (Linear_pipe.iter (Main.strongest_ledgers coda) ~f:(fun _ ->
                 Linear_pipe.write w () )) ;
          return r.pipe
        in
        return {coda_peers; coda_strongest_ledgers}

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end
