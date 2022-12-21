(* node_status.ml *)

open Core
open Async

let get_node_status_from_peers (net : Mina_networking.t)
    (peers : Mina_net2.Multiaddr.t list option) =
  let run =
    Deferred.List.map ~how:`Parallel
      ~f:(Mina_networking.get_peer_node_status net)
  in
  match peers with
  | None ->
      Mina_networking.peers net >>= run
  | Some peers -> (
      match Option.all (List.map ~f:Mina_net2.Multiaddr.to_peer peers) with
      | Some peers ->
          run peers
      | None ->
          Deferred.return
            (List.map peers ~f:(fun _ ->
                 Or_error.error_string
                   "Could not parse peers in node status request" ) ) )
