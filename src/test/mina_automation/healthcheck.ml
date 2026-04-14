(** Client for running the mina-healthcheck CLI binary from tests.

    Provides typed OCaml functions for each healthcheck subcommand,
    following the same Paths/Executor/Client convention as {!Daemon}.
    Response types are shared with the healthcheck app via
    {!Mina_healthcheck_lib}. *)

open Core
open Async
open Mina_healthcheck_lib
module Types = Mina_graphql_client.Types

module Paths = struct
  let dune_name = "src/app/mina_healthcheck/mina_healthcheck.exe"

  let official_name = "mina-healthcheck"
end

module Executor = Executor.Make (Paths)

(** Result for binary checks that only report pass/fail. *)
type check_result = { healthy : bool; exit_code : int }

module Client = struct
  type t = { graphql_uri : string; executor : Executor.t }

  (** Create a healthcheck client.
      @param graphql_uri  Daemon GraphQL endpoint (default [http://127.0.0.1:3085/graphql]).
      @param executor     How to locate the binary (default [AutoDetect]). *)
  let create ?(graphql_uri = "http://127.0.0.1:3085/graphql")
      ?(executor = Executor.AutoDetect) () =
    { graphql_uri; executor }

  (** Run the healthcheck binary with the given args, returning
      [(exit_code, stdout, stderr)]. *)
  let run_raw t args =
    let full_args = args @ [ "--graphql-uri"; t.graphql_uri ] in
    let%bind prog = Executor.PathFinder.standalone_path_exn in
    Process.create ~prog ~args:full_args ()
    >>= function
    | Error e ->
        return
          (Or_error.errorf "failed to spawn healthcheck: %s"
             (Error.to_string_hum e) )
    | Ok process ->
        let%map output = Process.collect_output_and_wait process in
        let exit_code =
          match output.exit_status with
          | Ok () ->
              0
          | Error (`Exit_non_zero n) ->
              n
          | Error (`Signal _) ->
              -1
        in
        Ok (exit_code, output.stdout, output.stderr)

  (** Run with [--json], parse stdout, and apply [f] to [(exit_code, json)]. *)
  let run_json_map t args ~f =
    let%map result = run_raw t (args @ [ "--json" ]) in
    let open Result.Let_syntax in
    let%bind exit_code, stdout, _stderr = result in
    let%bind json =
      try Ok (Yojson.Safe.from_string (String.strip stdout))
      with exn ->
        Or_error.errorf "failed to parse JSON: %s\nstdout: %s"
          (Exn.to_string exn) stdout
    in
    f exit_code json

  (** Deserialize a JSON value using a [ppx_deriving_yojson] parser. *)
  let decode of_yojson json =
    match of_yojson json with
    | Ok v ->
        Ok v
    | Error msg ->
        Or_error.errorf "failed to parse response: %s" msg

  (** Query the daemon's sync status.  Returns the status string
      (e.g. ["SYNCED"]) and whether it is synced (exit code 0). *)
  let sync_status t : (string * bool) Deferred.Or_error.t =
    let%map result = run_raw t [ "sync-status" ] in
    let open Result.Let_syntax in
    let%map exit_code, stdout, _ = result in
    (String.strip stdout, exit_code = 0)

  (** Get comprehensive daemon status including peers, chain height,
      uptime, and commit info. *)
  let daemon_status t : Types.daemon_status Deferred.Or_error.t =
    run_json_map t [ "daemon-status" ] ~f:(fun _exit_code json ->
        decode Types.daemon_status_of_yojson json )

  (** Check whether the connected peer count exceeds [min_peers]. *)
  let peer_count t ~min_peers : check_result Deferred.Or_error.t =
    run_json_map t
      [ "peer-count"; "--min-peers"; Int.to_string min_peers ]
      ~f:(fun exit_code json ->
        let open Result.Let_syntax in
        let%map resp = decode peer_count_response_of_yojson json in
        { healthy = resp.healthy; exit_code } )

  (** Check whether the local chain length equals the highest block
      length received from peers. *)
  let chain_length t : check_result Deferred.Or_error.t =
    run_json_map t [ "chain-length" ] ~f:(fun exit_code json ->
        let open Result.Let_syntax in
        let%map resp = decode chain_length_response_of_yojson json in
        { healthy = resp.healthy; exit_code } )

  (** Combined readiness check: synced, peers above threshold, and
      chain caught up. *)
  let ready t ~min_peers : Types.readiness Deferred.Or_error.t =
    run_json_map t
      [ "ready"; "--min-peers"; Int.to_string min_peers ]
      ~f:(fun _exit_code json -> decode Types.readiness_of_yojson json)

  (** Block until the node passes all readiness checks or [timeout]
      seconds elapse.  Polls every [interval] seconds. *)
  let wait t ~min_peers ~timeout ~interval : Types.readiness Deferred.Or_error.t
      =
    run_json_map t
      [ "wait"
      ; "--min-peers"
      ; Int.to_string min_peers
      ; "--timeout"
      ; Int.to_string timeout
      ; "--interval"
      ; Int.to_string interval
      ]
      ~f:(fun _exit_code json -> decode Types.readiness_of_yojson json)
end
