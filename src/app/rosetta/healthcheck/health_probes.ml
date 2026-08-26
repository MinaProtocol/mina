(* The health probes.  See [health_probes.mli] for the contract, and
   [rosetta_healthcheck.ml] for the CLI that presents these verdicts. *)

open Core_kernel
open Async
module MRC = Rosetta_client
module RM = MRC.Models

type tip = { height : int64; hash : string; age_seconds : int64; fresh : bool }

type readiness = { ready : bool; tip : tip option; problems : string list }

(* Now-time as epoch seconds. *)
let now_secs () = Time.now () |> Time.to_span_since_epoch |> Time.Span.to_sec

let age_seconds_from_timestamp_ms ts =
  let now_ms = Int64.of_float (now_secs () *. 1000.0) in
  let age_ms = Int64.( - ) now_ms ts in
  let age_secs = Int64.( / ) age_ms 1000L in
  if Int64.( < ) age_secs 0L then 0L else age_secs

let describe (network_identifier : RM.Network_identifier.t) =
  sprintf "%s:%s" network_identifier.RM.Network_identifier.blockchain
    network_identifier.RM.Network_identifier.network

let connectivity client ~expected_blockchain ~expected_network =
  match%map MRC.Data.network_list_response client with
  | Error e ->
      Error e
  | Ok response ->
      let advertised = response.RM.Network_list_response.network_identifiers in
      if List.is_empty advertised then
        Or_error.error_string "/network/list returned no network_identifiers"
      else
        let match_found =
          List.exists advertised ~f:(fun n ->
              String.equal n.RM.Network_identifier.blockchain
                expected_blockchain
              && String.equal n.RM.Network_identifier.network expected_network )
        in
        if match_found then Ok advertised
        else
          Or_error.errorf "expected network %s:%s not advertised (got: %s)"
            expected_blockchain expected_network
            (String.concat ~sep:", " (List.map advertised ~f:describe))

let tip_recency client ~max_age =
  match%map MRC.Data.network_status_response client with
  | Error e ->
      Error e
  | Ok response ->
      let block =
        response.RM.Network_status_response.current_block_identifier
      in
      let age_seconds =
        age_seconds_from_timestamp_ms
          response.RM.Network_status_response.current_block_timestamp
      in
      Ok
        { height = block.RM.Block_identifier.index
        ; hash = block.RM.Block_identifier.hash
        ; age_seconds
        ; fresh = Int64.( <= ) age_seconds (Int64.of_int max_age)
        }

(* [/network/options] is the third readiness signal: a server that
   answers it with a version and a non-empty operation_types list has
   finished wiring up its Data API. *)
let network_options_ok client =
  match%map MRC.Data.network_options_response client with
  | Error e ->
      Error (sprintf "network-options: %s" (Error.to_string_hum e))
  | Ok response ->
      let version = response.RM.Network_options_response.version in
      let allow = response.RM.Network_options_response.allow in
      if
        String.is_empty version.RM.Version.rosetta_version
        || List.is_empty allow.RM.Allow.operation_types
      then Error "network-options: missing rosetta_version or operation_types"
      else Ok ()

let readiness client ~expected_blockchain ~expected_network ~max_age =
  let%bind connectivity_result =
    connectivity client ~expected_blockchain ~expected_network
  in
  let%bind tip_result = tip_recency client ~max_age in
  let%map options_result = network_options_ok client in
  let problem_of_error label e =
    sprintf "%s: %s" label (Error.to_string_hum e)
  in
  let problems =
    List.filter_opt
      [ Result.error connectivity_result
        |> Option.map ~f:(problem_of_error "connectivity")
      ; ( match tip_result with
        | Error e ->
            Some (problem_of_error "tip-recency" e)
        | Ok tip when not tip.fresh ->
            Some
              (sprintf "tip-recency: tip age %Lds > %ds" tip.age_seconds max_age)
        | Ok _ ->
            None )
      ; Result.error options_result
      ]
  in
  { ready = List.is_empty problems; tip = Result.ok tip_result; problems }
