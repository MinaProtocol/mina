(* telemetry.ml *)

open Async

let get_telemetry_data_from_peers (_net : Coda_networking.t)
    (_peers : Network_peer.Peer.t list) =
  Deferred.return []
