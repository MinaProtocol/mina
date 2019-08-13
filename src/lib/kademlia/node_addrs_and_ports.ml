open Core
open Network_peer

type t =
  { external_ip: Unix.Inet_addr.t
  ; bind_ip: Unix.Inet_addr.t
  ; discovery_port: int
  ; communication_port: int
  ; client_port: int }
[@@deriving bin_io]

let to_peer : t -> Peer.t = function
  | {external_ip; discovery_port; communication_port; _} ->
      Peer.create external_ip ~discovery_port ~communication_port

let to_discovery_host_and_port : t -> Host_and_port.t = function
  | {external_ip; discovery_port; _} ->
      Host_and_port.create
        ~host:(Unix.Inet_addr.to_string external_ip)
        ~port:discovery_port
