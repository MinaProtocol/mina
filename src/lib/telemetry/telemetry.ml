(* telemetry.ml *)

open Async

let get_telemetry_data_from_peers (net : Mina_networking.t)
    (peers : Network_peer.Peer.t list option) =
  let open Deferred.Let_syntax in
  let run peer = Mina_networking.get_peer_telemetry_data net peer in
  let%bind peer_ids =
    match peers with
    | Some ps ->
        return ps
    | None ->
        (* use daemon peers *)
        Mina_networking.peers net
  in
  Deferred.List.map ~how:`Parallel peer_ids ~f:run
