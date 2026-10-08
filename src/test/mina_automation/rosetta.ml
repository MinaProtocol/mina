(**
Module to run a Rosetta API server over an archive PostgreSQL database.
*)
open Core

open Async

module Config = struct
  type t =
    { archive_uri : String.t
    ; graphql_uri : String.t
    ; port : int
    ; max_db_pool_size : int
    ; extra_args : String.t list
    }

  let to_args t =
    [ "--archive-uri"
    ; t.archive_uri
    ; "--graphql-uri"
    ; t.graphql_uri
    ; "--port"
    ; string_of_int t.port
    ; "--log-json"
    ]
    @ t.extra_args

  (* Rosetta refuses to start without MINA_ROSETTA_MAX_DB_POOL_SIZE. *)
  let to_env t =
    `Extend
      [ ("MINA_ROSETTA_MAX_DB_POOL_SIZE", string_of_int t.max_db_pool_size) ]

  let create ?(graphql_uri = "http://127.0.0.1:3085/graphql") ?(port = 3087)
      ?(max_db_pool_size = 16) ?(extra_args = []) ~archive_uri () =
    { archive_uri; graphql_uri; port; max_db_pool_size; extra_args }
end

module Paths = struct
  let dune_name = "src/app/rosetta/rosetta.exe"

  let official_name = "mina-rosetta"
end

module Executor = Executor.Make (Paths)

type t = { config : Config.t; executor : Executor.t }

let of_config config = { config; executor = Executor.AutoDetect }

module Process = struct
  type t = { process : Process.t; config : Config.t }

  let force_kill t = Utils.force_kill t.process

  (** Drains stdout and stderr into [log_file], so neither pipe fills and a
      failure to start leaves its reason behind. *)
  let start_logging t ~log_file =
    let drain reader =
      don't_wait_for
      @@ Pipe.iter (Reader.pipe reader) ~f:(fun chunk ->
             Writer.with_file log_file ~append:true ~f:(fun writer ->
                 Writer.write_line writer chunk ;
                 Writer.flushed writer ) )
    in
    drain (Process.stdout t.process) ;
    drain (Process.stderr t.process)
end

let start t =
  let%map _, process =
    Executor.run_in_background t.executor ~args:(Config.to_args t.config)
      ~env:(Config.to_env t.config) ()
  in
  Process.{ process; config = t.config }

(** Waits until the server answers HTTP on its port, whatever the status. *)
let wait_until_ready ?(timeout = Time.Span.of_sec 60.) (t : Process.t) =
  let uri = Uri.of_string (sprintf "http://127.0.0.1:%d/" t.config.port) in
  let deadline = Time.add (Time.now ()) timeout in
  let rec poll () =
    match%bind Monitor.try_with (fun () -> Cohttp_async.Client.get uri) with
    | Ok (_, body) ->
        let%map () = Cohttp_async.Body.drain body in
        Ok ()
    | Error _ when Time.( > ) (Time.now ()) deadline ->
        Deferred.Or_error.error_string
          "Timeout waiting for rosetta to answer HTTP"
    | Error _ ->
        let%bind () = after (Time.Span.of_sec 1.) in
        poll ()
  in
  poll ()
