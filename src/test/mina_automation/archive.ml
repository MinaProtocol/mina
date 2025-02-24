(**
Module to run archive_blocks utility for the given list of block files and an archive PostgreSQL database.
*)
open Core

open Async
include Async_executor

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

type t = { process : Process.t; config : Config.t; executor : Async_executor.t }

let of_context context =
  Async_executor.of_context ~context ~dune_name:"src/app/archive/archive.exe"
    ~official_name:"mina-archive"

module ArchiveProcess = struct
  type t = { process : Process.t; config : Config.t }

  let force_kill t =
    Process.send_signal t.process Core.Signal.kill ;
    Deferred.map (Process.wait t.process) ~f:Or_error.return

  let print_output t =
    let logger = Logger.create () in
    don't_wait_for
    @@ Pipe.iter
         (Process.stdout t.process |> Reader.pipe)
         ~f:(fun stdout ->
           return
           @@ [%log debug] "Archive stdout: $stdout"
                ~metadata:[ ("stdout", `String stdout) ] )
end

let start (config : Config.t) t =
  let open Deferred.Let_syntax in
  let args = Config.to_args config in
  let%bind prog = path t in

  Async.printf "Starting archive with command: %s %s\n" prog
    (String.concat ~sep:" " args) ;

  let%bind process = run t ~args () in

  (* TODO: wait until ready *)
  Core.Unix.sleep 5 ;

  let archive_process : ArchiveProcess.t = { process; config } in
  Deferred.return archive_process

let force_kill t =
  Process.send_signal t.process Core.Signal.term ;
  Deferred.map (Process.wait t.process) ~f:Or_error.return
