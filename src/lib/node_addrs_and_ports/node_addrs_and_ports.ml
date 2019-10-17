open Core
open Network_peer

type t =
  { external_ip: Unix.Inet_addr.t
  ; bind_ip: Unix.Inet_addr.t
  ; client_port: int
  ; libp2p_port: int
  ; communication_port: int }
[@@deriving bin_io]

let to_peer : t -> Peer.t = function
  | {external_ip; libp2p_port; communication_port; _} ->
      Peer.create external_ip ~libp2p_port ~communication_port

let to_libp2p_host_and_port : t -> Host_and_port.t = function
  | {external_ip; libp2p_port; _} ->
      Host_and_port.create
        ~host:(Unix.Inet_addr.to_string external_ip)
        ~port:libp2p_port
