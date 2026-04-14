open Core
open Async
module GC = Mina_graphql_client.Client
module Types = Mina_graphql_client.Types

type error_response = { healthy : bool; error : string } [@@deriving yojson]

type sync_status_response = { healthy : bool; sync_status : string }
[@@deriving yojson]

type peer_count_response = { healthy : bool; peer_count : int; min_peers : int }
[@@deriving yojson]

type chain_length_response =
  { healthy : bool
  ; blockchain_length : int option [@yojson.option]
  ; highest_block_length_received : int option [@yojson.option]
  }
[@@deriving yojson]

type wait_timeout_response =
  { ready : bool
  ; timed_out : bool
  ; elapsed_secs : int
  ; sync_status : string option [@yojson.option]
  ; peer_count : int option [@yojson.option]
  ; blockchain_length : int option [@yojson.option]
  ; highest_block_length_received : int option [@yojson.option]
  ; error : string option [@yojson.option]
  }
[@@deriving yojson]

let get_sync_status = GC.get_sync_status

let get_daemon_status = GC.get_daemon_status

let check_peer_count ~logger node_uri ~min_peers =
  let open Deferred.Or_error.Let_syntax in
  let%map ds = GC.get_daemon_status ~logger node_uri in
  (ds.peer_count >= min_peers, ds.peer_count)

let check_chain_length ~logger node_uri =
  let open Deferred.Or_error.Let_syntax in
  let%map ds = GC.get_daemon_status ~logger node_uri in
  let ok =
    match (ds.blockchain_length, ds.highest_block_length_received) with
    | Some a, Some b ->
        a = b
    | _ ->
        false
  in
  (ok, ds.blockchain_length, ds.highest_block_length_received)

let check_readiness = GC.get_readiness

let readiness_problems ~min_peers (r : Types.readiness) =
  let ps = ref [] in
  if not (Sync_status.equal r.sync_status `Synced) then
    ps := sprintf "not synced (%s)" (Sync_status.to_string r.sync_status) :: !ps ;
  if r.peer_count < min_peers then
    ps := sprintf "peer count %d < %d" r.peer_count min_peers :: !ps ;
  ( match (r.blockchain_length, r.highest_block_length_received) with
  | Some a, Some b when a <> b ->
      ps := "chain length != highest received" :: !ps
  | None, _ | _, None ->
      ps := "chain length unknown" :: !ps
  | _ ->
      () ) ;
  !ps

(** Poll [f] every [interval] seconds until it returns [Ok (Some v)]
    (success), [Ok None] (not yet, keep polling), or [Error] on
    connection failure (retried until timeout). *)
let poll_until ~timeout ~interval ~timeout_msg f =
  let start = Time.now () in
  let deadline = Time.add start (Time.Span.of_sec (Float.of_int timeout)) in
  let interval_span = Time.Span.of_sec (Float.of_int interval) in
  let timed_out () = Time.( >= ) (Time.now ()) deadline in
  let rec loop () =
    match%bind f () with
    | Ok (Some v) ->
        return (Ok v)
    | Ok None ->
        if timed_out () then
          Deferred.Or_error.errorf "timed out after %ds: %s" timeout timeout_msg
        else
          let%bind () = after interval_span in
          loop ()
    | Error e ->
        let elapsed =
          Time.Span.to_sec (Time.diff (Time.now ()) start) |> Float.to_int
        in
        eprintf "[%4ds] connection error: %s\n%!" elapsed
          (Error.to_string_hum e) ;
        if timed_out () then
          Deferred.Or_error.errorf "timed out after %ds: %s" timeout
            (Error.to_string_hum e)
        else
          let%bind () = after interval_span in
          loop ()
  in
  loop ()

let wait_for_graphql ~logger node_uri ~timeout ~interval =
  poll_until ~timeout ~interval ~timeout_msg:"waiting for GraphQL endpoint"
    (fun () ->
      match%map GC.get_sync_status ~logger node_uri with
      | Ok status ->
          Ok (Some status)
      | Error e ->
          Error e )

let wait_for_ready ~logger node_uri ~min_peers ~timeout ~interval =
  let fmt = Option.value_map ~default:"?" ~f:Int.to_string in
  poll_until ~timeout ~interval ~timeout_msg:"waiting for node to become ready"
    (fun () ->
      match%map GC.get_readiness ~logger node_uri ~min_peers with
      | Ok r when r.ready ->
          Ok (Some r)
      | Ok r ->
          eprintf "%-10s (peers: %d, chain: %s/%s)\n%!"
            (Sync_status.to_string r.sync_status)
            r.peer_count (fmt r.blockchain_length)
            (fmt r.highest_block_length_received) ;
          Ok None
      | Error e ->
          Error e )
