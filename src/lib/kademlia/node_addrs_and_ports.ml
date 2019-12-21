open Core
open Network_peer

type t =
  { external_ip: Unix.Inet_addr.t
  ; bind_ip: Unix.Inet_addr.t
  ; discovery_port: int
  ; client_port: int
  ; libp2p_port: int
  ; communication_port: int }
[@@deriving bin_io, fields]

module Display = struct
  module Stable = struct
    module V1 = struct
      type t =
        { external_ip: string
        ; bind_ip: string
        ; discovery_port: int
        ; client_port: int
        ; libp2p_port: int
        ; communication_port: int }
      [@@deriving fields, yojson, bin_io]
    end
  end
end

let to_display (t : t) =
  Display.Stable.V1.
    { external_ip= Unix.Inet_addr.to_string t.external_ip
    ; bind_ip= Unix.Inet_addr.to_string t.bind_ip
    ; discovery_port= t.discovery_port
    ; client_port= t.client_port
    ; libp2p_port= t.libp2p_port
    ; communication_port= t.communication_port }

let to_yojson = Fn.compose Display.Stable.V1.to_yojson to_display

let to_peer : t -> Peer.t = function
  | {external_ip; discovery_port; communication_port; _} ->
      Peer.create external_ip ~discovery_port ~communication_port

let to_discovery_host_and_port : t -> Host_and_port.t = function
  | {external_ip; discovery_port; _} ->
      Host_and_port.create
        ~host:(Unix.Inet_addr.to_string external_ip)
        ~port:discovery_port
