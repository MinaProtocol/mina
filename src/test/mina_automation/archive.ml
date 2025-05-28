(**
Module to run archive process over archive PostgreSQL database.
*)
open Core

open Async

module Config = struct
  type t =
    { config_file : String.t; postgres_uri : String.t; server_port : int }

  let to_args t =
    [ "run"
    ; "--config-file"
    ; t.config_file
    ; "--postgres-uri"
    ; t.postgres_uri
    ; "--server-port"
    ; string_of_int t.server_port
    ]

  let create ~config_file ~postgres_uri ~server_port =
    { config_file; postgres_uri; server_port }

  let of_config_file config_file =
    { config_file
    ; postgres_uri = "postgres://postgres:postgres@localhost:5432/archive"
    ; server_port = 3030
    }
end

module Paths = struct
  let dune_name = "src/app/archive/archive.exe"

  let official_name = "mina-archive"
end

module Executor = Executor.Make (Paths)

type t = { config : Config.t; executor : Executor.t }

let of_config config = { config; executor = Executor.AutoDetect }

(*
  Module [Process] provides functions to interact with the archive process.
*)
module Process = struct
  type t = { process : Process.t; config : Config.t }

  (** Forcefully kills the given process.

    @param t The process to be killed.
    @return A deferred result indicating the success or failure of the operation.
  *)
  let force_kill t =
    Process.send_signal t.process Core.Signal.kill ;
    Deferred.map (Process.wait t.process) ~f:Or_error.return

  (** [start_logging t] starts logging the stdout of the given process [t].
    It creates a logger and asynchronously iterates over the stdout pipe of the process,
    logging each line with a debug level and attaching the stdout content as metadata.

    @param t The process whose stdout will be logged.
  *)
  let start_logging t =
    let logger = Logger.create () in
    don't_wait_for
    @@ Pipe.iter
         (Process.stdout t.process |> Reader.pipe)
         ~f:(fun stdout ->
           return
           @@ [%log debug] "Archive stdout: $stdout"
                ~metadata:[ ("stdout", `String stdout) ] )
end

(** [start t] starts the archive process using the given configuration [t].
  
  @param t The configuration and executor for the archive process.
  @return A [Deferred.t] containing the archive process.
*)
let start t =
  let open Deferred.Let_syntax in
  let args = Config.to_args t.config in
  let%bind process = Executor.run_in_background t.executor ~args () in

  (* TODO: wait until ready *)
  Core.Unix.sleep 5 ;

  let archive_process : Process.t = { process; config = t.config } in
  Deferred.return archive_process
