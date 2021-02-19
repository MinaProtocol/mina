(* telemetry.ml *)

open Core_kernel
open Async

let get_telemetry_data_from_peers (net : Mina_networking.t)
    (peer_ids : Network_peer.Peer.Id.t list option) =
  let open Deferred.Let_syntax in
  let run peer_id =
    let open Mina_base.Rpc_intf in
    match%map
      Mina_networking.(
        query_peer net peer_id Mina_networking.Rpcs.Get_telemetry_data ())
    with
    | Failed_to_connect err ->
        Error err
    | Connected envelope -> (
      match Network_peer.Envelope.Incoming.data envelope with
      | Ok response ->
          (* already an Or_error.t *)
          response
      | Error err ->
          Error err )
  in
  let%bind peer_ids =
    match peer_ids with
    | Some ids ->
        return ids
    | None ->
        (* use daemon peers *)
        let%bind peers = Mina_networking.peers net in
        Deferred.List.map peers ~f:(fun {peer_id; _} -> return peer_id)
  in
  Deferred.List.map ~how:`Parallel peer_ids ~f:run
