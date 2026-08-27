open Core
open Async_kernel
open Network_peer

let logger = Logger.null ()

let entry kind identity until : Handle.Entry.t = { kind; identity; until }

let peer_id = "12D3KooWEiGVAFC7curXWXiGZyMWnZK9h8BKr88U8D5PKV3dXciv"

let%test_unit "null handle is inert" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let t = Handle.null in
      Handle.useful t (Peer.Id.unsafe_of_string peer_id) ;
      let%bind () =
        match%map
          Handle.ban_manual t
            ~peer_id:(Peer.Id.unsafe_of_string peer_id)
            ~ip:None
        with
        | Ok () ->
            ()
        | Error e ->
            failwithf "null ban_manual errored: %s" (Error.to_string_hum e) ()
      in
      match%map Handle.bans t with
      | Ok [] ->
          ()
      | Ok _ ->
          failwith "null handle reported bans"
      | Error e ->
          failwithf "null bans errored: %s" (Error.to_string_hum e) () )

let%test_unit "cache fold: entries land in the right tables and survive \
               round-trip" =
  let cache = Ban_status_cache.create ~logger Handle.null in
  let until = Some (Time.add (Time.now ()) (Time.Span.of_hr 1.)) in
  Ban_status_cache.set_entries cache
    [ entry Peer_id peer_id until
    ; entry Ip "127.0.0.1" None
    ; entry Ip "not an ip" None (* ignored, not fatal *)
    ] ;
  assert (
    Ban_status_cache.is_banned_peer cache (Peer.Id.unsafe_of_string peer_id) ) ;
  assert (
    Ban_status_cache.is_banned_ip cache (Unix.Inet_addr.of_string "127.0.0.1") ) ;
  assert (
    not
      (Ban_status_cache.is_banned_ip cache
         (Unix.Inet_addr.of_string "10.0.0.1") ) ) ;
  assert (
    Ban_status_cache.is_banned cache
      ~peer_id:(Peer.Id.unsafe_of_string "unknown")
      ~ip:(Some (Unix.Inet_addr.of_string "127.0.0.1")) ) ;
  [%test_eq: Core.Time.t option]
    (Ban_status_cache.until_of_peer cache (Peer.Id.unsafe_of_string peer_id))
    until ;
  (* manual bans have no expiry *)
  [%test_eq: Core.Time.t option]
    (Ban_status_cache.until_of_ip cache (Unix.Inet_addr.of_string "127.0.0.1"))
    None ;
  let snapshot = Ban_status_cache.snapshot cache in
  assert (List.length snapshot.banned_peers = 1) ;
  assert (List.length snapshot.banned_ips = 1) ;
  assert (List.length (Ban_status_cache.entries cache) = 2)

let%test_unit "cache rebuild is wholesale: stale entries drop out" =
  let cache = Ban_status_cache.create ~logger Handle.null in
  Ban_status_cache.set_entries cache [ entry Peer_id peer_id None ] ;
  Ban_status_cache.set_entries cache [ entry Ip "8.8.8.8" None ] ;
  assert (
    not
      (Ban_status_cache.is_banned_peer cache (Peer.Id.unsafe_of_string peer_id)) ) ;
  assert (
    Ban_status_cache.is_banned_ip cache (Unix.Inet_addr.of_string "8.8.8.8") )

let%test_unit "expired entries never report as banned" =
  let cache = Ban_status_cache.create ~logger Handle.null in
  let past = Some (Time.sub (Time.now ()) (Time.Span.of_hr 1.)) in
  Ban_status_cache.set_entries cache [ entry Peer_id peer_id past ] ;
  assert (
    not
      (Ban_status_cache.is_banned_peer cache (Peer.Id.unsafe_of_string peer_id)) ) ;
  [%test_eq: Core.Time.t option]
    (Ban_status_cache.until_of_peer cache (Peer.Id.unsafe_of_string peer_id))
    None ;
  assert (List.is_empty (Ban_status_cache.entries cache)) ;
  let snapshot = Ban_status_cache.snapshot cache in
  assert (List.is_empty snapshot.banned_peers)
