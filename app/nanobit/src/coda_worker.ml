open Core
open Async
open Nanobit_base
open Coda_main

module Kernel = Kernel.Debug ()

module Coda_worker = struct
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
      { sum: ('worker, int, int) Rpc_parallel.Function.t
      ; peers: ('worker, unit, Peers.t) Rpc_parallel.Function.t
      ; strongest_ledgers: ('worker, unit, unit Pipe.Reader.t) Rpc_parallel.Function.t
      }

    type coda_functions = 
      { coda_sum: int -> int Deferred.t 
      ; coda_peers: unit -> Peers.t Deferred.t
      ; coda_strongest_ledgers: unit -> unit Pipe.Reader.t Deferred.t
      }

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
      let sum_impl ~worker_state ~conn_state:() arg =
        worker_state.coda_sum arg

      let peers_impl ~worker_state ~conn_state:() () =
        worker_state.coda_peers ()

      let strongest_ledgers_impl ~worker_state ~conn_state:() () =
        worker_state.coda_strongest_ledgers ()

      let sum =
        C.create_rpc ~f:sum_impl ~bin_input:Int.bin_t ~bin_output:Int.bin_t ()

      let peers =
        C.create_rpc ~f:peers_impl ~bin_input:Unit.bin_t ~bin_output:Peers.bin_t ()

      let strongest_ledgers =
        C.create_pipe ~f:strongest_ledgers_impl ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t ()

      let functions = {sum; peers; strongest_ledgers}

      let init_worker_state {host; conf_dir; program_dir; my_port; peers; gossip_port} = 
        let log = Logger.create () in
        let log =
          Logger.child log ("host: " ^ host ^ ":" ^ Int.to_string my_port)
        in
        let module Coda = struct
          type ledger_proof = Ledger_proof_statement.t

          module Make
              (Init : Init_intf
               with type Ledger_proof.t = Ledger_proof_statement.t)
              () =
            Coda_without_snark (Init) ()
        end in
        let module Config = struct
          let logger = log

          let conf_dir = conf_dir

          let lbc_tree_max_depth = `Finite 50

          let transaction_interval = Time.Span.of_ms 100.0

          let fee_public_key = Genesis_ledger.rich_pk

          let genesis_proof = Precomputed_values.base_proof
        end in
        let (module Init) = make_init (module Config) (module Kernel) in
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
        (*don't_wait_for begin
          Linear_pipe.drain (Main.strongest_ledgers coda)
        end;*)
        let coda_sum x = return (x + 3) in
        let coda_strongest_ledgers () = 
          let r, w = Linear_pipe.create () in
          don't_wait_for begin
            Linear_pipe.iter 
              (Main.strongest_ledgers coda)
              ~f:(fun _ -> Linear_pipe.write w ())
          end;
          return r.pipe
        in
        return 
          { coda_sum
          ; coda_peers
          ; coda_strongest_ledgers
          }

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end
