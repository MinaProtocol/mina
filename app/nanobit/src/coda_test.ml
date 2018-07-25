open Core
open Async
open Nanobit_base
open Coda_main
open Spawner

let recieved_message = "Recieved Message"

module type Input_intf = sig
  type ('host, 'log_dir) t = {host: 'host; log_dir: 'log_dir}
  [@@deriving bin_io, fields]
end

module Coda_worker = struct
  type t = {reader: string Pipe.Reader.t; writer: string Pipe.Writer.t}

  type input = {host: string; log_dir: string; program_dir: string}
  [@@deriving bin_io]

  type state = string [@@deriving bin_io]

  let create {host; log_dir; program_dir} =
    let reader, writer = Pipe.create () in
    let%bind () = Sys.chdir program_dir in
    let log = Logger.create () in
    let conf_dir = log_dir in
    let%bind prover = Prover.create ~conf_dir
    and verifier = Verifier.create ~conf_dir in
    let module Init = struct
      type proof = Proof.Stable.V1.t [@@deriving bin_io, sexp]

      let logger = log

      let conf_dir = conf_dir

      let verifier = verifier

      let prover = prover

      let genesis_proof = Precomputed_values.base_proof

      let fee_public_key = Genesis_ledger.rich_pk
    end in
    let module Main : Main_intf = Coda_without_snark (Init) () in
    let module Run = Run (Main) in
    let open Main in
    let net_config =
      { Inputs.Net.Config.parent_log= log
      ; gossip_net_params=
          { Inputs.Net.Gossip_net.Params.timeout= Time.Span.of_sec 1.
          ; target_peer_count= 8
          ; address= Host_and_port.of_string (host ^ ":1234") }
      ; initial_peers= []
      ; me= Host_and_port.of_string (host ^ ":1235")
      ; remap_addr_port= Fn.id }
    in
    let%map minibit =
      Main.create
        (Main.Config.make ~log ~net_config
           ~ledger_builder_persistant_location:"ledger_builder"
           ~transaction_pool_disk_location:"transaction_pool"
           ~snark_pool_disk_location:"snark_pool" ())
    in
    {reader; writer}

  let new_states {reader} = reader

  let run {writer} = Pipe.write writer recieved_message
end

module Worker = Parallel_worker.Make (Coda_worker)
module Master = Master.Make (Worker) (Int)

let run =
  let open Command.Let_syntax in
  (* HACK: to run the dependency, Kademlia *)
  let%map_open program_dir =
    flag "program-directory" ~doc:"base directory of nanobit project "
      (optional file)
  and {host; executable_path; log_dir} = Command_util.config_arguments in
  fun () ->
    let open Deferred.Let_syntax in
    let open Master in
    let t = create () in
    let%bind program_dir =
      Option.value_map program_dir ~default:(Unix.getcwd ()) ~f:return
    in
    let%bind log_dir = File_system.create_dir log_dir in
    let config = {Spawner.Config.host; executable_path; log_dir}
    and process_id = 1 in
    let%bind () = add t {host; log_dir; program_dir} process_id ~config in
    let%bind () = Option.value_exn (run t process_id) in
    let reader = new_states t in
    let%map _, creation_message = Linear_pipe.read_exn reader in
    assert (recieved_message = creation_message)

let command = Command.async ~summary:"Current daemon" run
