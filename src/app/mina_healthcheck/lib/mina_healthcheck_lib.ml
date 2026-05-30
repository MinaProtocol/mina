open Core
open Async
module GC = Mina_graphql_client.Client
module Types = Mina_graphql_client.Types

(** CLI response payloads — see [mina_healthcheck_lib.mli] for the
    shape rules.  Every subcommand emits exactly one of these so success
    and failure paths share the same JSON schema; [healthy] is always
    present, optional fields are omitted when [None] (no [null]-noise),
    and [error] is present iff the request itself failed. *)

type sync_status_response =
  { healthy : bool
  ; sync_status : string option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

type daemon_status_response =
  { healthy : bool
  ; sync_status : Sync_status.t option [@default None]
  ; blockchain_length : int option [@default None]
  ; highest_block_length_received : int option [@default None]
  ; uptime_secs : int option [@default None]
  ; state_hash : string option [@default None]
  ; commit_id : string option [@default None]
  ; peer_count : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

type peer_count_response =
  { healthy : bool
  ; peer_count : int option [@default None]
  ; min_peers : int
  ; error : string option [@default None]
  }
[@@deriving yojson]

type chain_length_response =
  { healthy : bool
  ; blockchain_length : int option [@default None]
  ; highest_block_length_received : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

type readiness_response =
  { healthy : bool
  ; sync_status : Sync_status.t option [@default None]
  ; peer_count : int option [@default None]
  ; blockchain_length : int option [@default None]
  ; highest_block_length_received : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

let check_peer_count ?num_tries ?retry_delay_sec ?deadline ~logger node_uri
    ~min_peers =
  let open Deferred.Or_error.Let_syntax in
  let%map ds =
    GC.get_daemon_status ?num_tries ?retry_delay_sec ?deadline ~logger node_uri
  in
  (ds.peer_count >= min_peers, ds.peer_count)

let check_chain_length ?num_tries ?retry_delay_sec ?deadline ~logger node_uri =
  let open Deferred.Or_error.Let_syntax in
  let%map ds =
    GC.get_daemon_status ?num_tries ?retry_delay_sec ?deadline ~logger node_uri
  in
  let ok =
    match (ds.blockchain_length, ds.highest_block_length_received) with
    | Some a, Some b ->
        a = b
    | _ ->
        false
  in
  (ok, ds.blockchain_length, ds.highest_block_length_received)

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
    connection failure (retried until timeout).

    [f] receives the absolute wall-clock deadline so its inner GraphQL
    retries can honor the same budget — without this, a single call to
    [exec_graphql_request] can independently retry for up to 5 minutes
    against an unreachable daemon, which is what made [wait --timeout 30]
    take 300s before this fix.  Each call is also wrapped in
    [Clock.with_timeout] using the remaining budget as a belt-and-
    suspenders bound, so even a buggy inner caller that ignores the
    deadline parameter cannot wedge us past the user's [--timeout]. *)
let poll_until ?(quiet = false) ~timeout ~interval ~timeout_msg f =
  let start = Time.now () in
  let deadline = Time.add start (Time.Span.of_sec (Float.of_int timeout)) in
  let interval_span = Time.Span.of_sec (Float.of_int interval) in
  let timed_out () = Time.( >= ) (Time.now ()) deadline in
  let remaining_budget () =
    let r = Time.diff deadline (Time.now ()) in
    if Time.Span.( <= ) r Time.Span.zero then Time.Span.zero else r
  in
  let timeout_error_with_msg msg =
    let elapsed = Time.Span.to_sec (Time.diff (Time.now ()) start) in
    Deferred.Or_error.errorf "timed out after %.2fs: %s" elapsed msg
  in
  let rec loop () =
    let budget = remaining_budget () in
    if Time.Span.( <= ) budget Time.Span.zero then
      timeout_error_with_msg timeout_msg
    else
      match%bind Clock.with_timeout budget (f ~deadline ()) with
      | `Timeout ->
          timeout_error_with_msg timeout_msg
      | `Result (Ok (Some v)) ->
          return (Ok v)
      | `Result (Ok None) ->
          if timed_out () then timeout_error_with_msg timeout_msg
          else
            let%bind () = after interval_span in
            loop ()
      | `Result (Error e) ->
          ( if not quiet then
            let elapsed = Time.Span.to_sec (Time.diff (Time.now ()) start) in
            eprintf "[%6.2fs] connection error: %s\n%!" elapsed
              (Error.to_string_hum e) ) ;
          if timed_out () then timeout_error_with_msg (Error.to_string_hum e)
          else
            let%bind () = after interval_span in
            loop ()
  in
  loop ()

let wait_for_graphql ?(quiet = false) ~logger node_uri ~timeout ~interval =
  poll_until ~quiet ~timeout ~interval
    ~timeout_msg:"waiting for GraphQL endpoint" (fun ~deadline () ->
      match%map GC.get_sync_status ~deadline ~logger node_uri with
      | Ok status ->
          Ok (Some status)
      | Error e ->
          Error e )

let wait_for_ready ?(quiet = false) ~logger node_uri ~min_peers ~timeout
    ~interval =
  let fmt = Option.value_map ~default:"?" ~f:Int.to_string in
  poll_until ~quiet ~timeout ~interval
    ~timeout_msg:"waiting for node to become ready" (fun ~deadline () ->
      match%map GC.get_readiness ~deadline ~logger node_uri ~min_peers with
      | Ok r when r.ready ->
          Ok (Some r)
      | Ok r ->
          if not quiet then
            eprintf "%-10s (peers: %d, chain: %s/%s)\n%!"
              (Sync_status.to_string r.sync_status)
              r.peer_count (fmt r.blockchain_length)
              (fmt r.highest_block_length_received) ;
          Ok None
      | Error e ->
          Error e )
