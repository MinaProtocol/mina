(**
Module to run archive process over archive PostgreSQL database.
*)
open Core

open Logger
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
    ; "--log-json"
    ]

  let create ~config_file ~postgres_uri ~server_port =
    { config_file; postgres_uri; server_port }

  let of_config_file config_file
      ?(postgres_uri = "postgres://postgres:postgres@localhost:5432/archive")
      ?(server_port = 3030) =
    { config_file; postgres_uri; server_port }
end

module Paths = struct
  let dune_name = "src/app/archive/archive.exe"

  let official_name = "mina-archive"
end

module Scripts = struct
  type t = [ `CreateSchema | `DropTables | `Upgrade | `Rollback ]

  let possible_locations = [ "/etc/mina/archive"; "src/app/archive" ]

  let file t =
    match t with
    | `CreateSchema ->
        "create_schema.sql"
    | `DropTables ->
        "drop_tables.sql"
    | `Upgrade ->
        "upgrade_to_mesa.sql"
    | `Rollback ->
        "downgrade_to_berkeley.sql"

  let filepath t =
    let file = file t in
    let possible_locations = [ "/etc/mina/archive"; "src/app/archive" ] in
    Utils.possible_locations ~file possible_locations
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
         (Process.stdout t.process |> Reader.pipe)
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

  (* TODO: wait until ready *)
  Core.Unix.sleep 5 ;

  let archive_process : Process.t = { process; config = t.config } in
  Deferred.return archive_process

let wait_for ~log_file =
  let open Deferred.Let_syntax in
  let timeout = 30.0 in
  let interval = 1 in
  let start_time = Time.now () in
  let has_timeout_elapsed () =
    int_of_float (Time.Span.to_sec (Time.diff (Time.now ()) start_time))
    > int_of_float timeout
  in
  let expected_message = "Archive process ready. Clients can now connect" in
  let rec loop () =
    Core.Unix.sleep interval ;
    let%bind log_exists =
      Sys.file_exists log_file
      >>| fun exists -> match exists with `Yes -> true | _ -> false
    in
    if not log_exists then
      if has_timeout_elapsed () then (
        eprintf "Timeout waiting for log file to be created\n" ;
        Deferred.return () )
      else loop ()
    else
      let%bind log_contents = Reader.file_contents log_file in
      let lines = String.split_lines log_contents in
      let found =
        List.exists lines ~f:(fun line ->
            match Yojson.Safe.from_string line |> Logger.Message.of_yojson with
            | Ok msg ->
                String.equal msg.message expected_message
            | Error _ ->
                false )
      in
      if found then Deferred.return ()
      else if has_timeout_elapsed () then (
        eprintf "Timeout waiting for archive process to be ready\n" ;
        Deferred.return () )
      else loop ()
  in
  loop ()
