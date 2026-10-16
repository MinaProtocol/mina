(**
Module to run archive process over archive PostgreSQL database.
*)
open Core

open Async

module Config = struct
  (** [config_file] is [None] for an archive that only follows a daemon; it
      then takes the genesis ledger from the blocks it is sent. *)
  type t =
    { config_file : String.t option
    ; postgres_uri : String.t
    ; server_port : int
    ; log_level : String.t option
    }

  let to_args t =
    [ "run" ]
    @ Option.value_map t.config_file ~default:[] ~f:(fun file ->
          [ "--config-file"; file ] )
    @ [ "--postgres-uri"
      ; t.postgres_uri
      ; "--server-port"
      ; string_of_int t.server_port
      ; "--log-json"
      ]
    @ Option.value_map t.log_level ~default:[] ~f:(fun level ->
          [ "--log-level"; level ] )

  let create ~config_file ~postgres_uri ~server_port =
    { config_file = Some config_file
    ; postgres_uri
    ; server_port
    ; log_level = None
    }

  let without_config_file ?log_level ~postgres_uri ~server_port () =
    { config_file = None; postgres_uri; server_port; log_level }

  let of_config_file config_file
      ?(postgres_uri = "postgres://postgres:postgres@localhost:5432/archive")
      ?(server_port = 3030) =
    create ~config_file ~postgres_uri ~server_port
end

module Paths = struct
  let dune_name = "src/app/archive/archive.exe"

  let official_name = "mina-archive"
end

module Scripts = Archive_scripts
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
  let force_kill t = Utils.force_kill t.process

  (** [start_logging t ~log_file] starts logging the stdout of the given process [t].
    It creates a logger and asynchronously iterates over the stdout pipe of the process,
    logging each line with a debug level and attaching the stdout content as metadata.
    Also writes the output to the specified log file.

    @param t The process whose stdout will be logged.
    @param log_file The filename where stdout will be written.
  *)
  let start_logging t ~log_file =
    let logger = Logger.create () in
    don't_wait_for
    @@ Pipe.iter
         (Process.stdout t.process |> Reader.lines)
         ~f:(fun stdout ->
           let%bind () =
             Writer.with_file log_file ~append:true ~f:(fun writer ->
                 Writer.write_line writer stdout ;
                 Writer.flushed writer )
           in
           return
           @@ [%log debug] "Archive stdout: $stdout"
                ~metadata:[ ("stdout", `String stdout) ] )

  let get_memory_usage_mib t =
    Utils.get_memory_usage_mib @@ (Process.pid t.process |> Pid.to_int)
end

(** [start t] starts the archive process using the given configuration [t].
  
  @param t The configuration and executor for the archive process.
  @return A [Deferred.t] containing the archive process.
*)
let start t =
  let open Deferred.Let_syntax in
  let args = Config.to_args t.config in
  let%bind _, process = Executor.run_in_background t.executor ~args () in
  (* Callers that need to gate on archive readiness must use
     [Archive_healthcheck.wait_db_and_server_ready] rather than relying
     on this fixed sleep: on a slow agent the archive takes longer than
     5 s to start listening, and a block sent before then is silently
     lost.  [wait_db_ready] alone is not a gate either — the schema is
     loaded before this process starts. *)
  let%map () = after (Time.Span.of_sec 5.) in
  Process.{ process; config = t.config }
