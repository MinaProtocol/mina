open Core
open Network_peer

type t =
  { external_ip: Unix.Inet_addr.t
  ; bind_ip: Unix.Inet_addr.t
  ; peer: Peer.Stable.Latest.t
  ; client_port: int }
[@@deriving fields]

module Display = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { external_ip: string
        ; bind_ip: string
        ; peer: Peer.Display.Stable.V1.t
        ; client_port: int }
      [@@deriving fields, yojson, bin_io, version]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { external_ip: string
    ; bind_ip: string
    ; peer: Peer.Display.Stable.Latest.t
    ; client_port: int }
  [@@deriving fields, yojson]
end

let to_display (t : t) =
  Display.
    { external_ip= Unix.Inet_addr.to_string t.external_ip
    ; bind_ip= Unix.Inet_addr.to_string t.bind_ip
    ; peer= Peer.to_display t.peer
    ; client_port= t.client_port }

let of_display (d : Display.t) : t =
  { external_ip= Unix.Inet_addr.of_string d.external_ip
  ; bind_ip= Unix.Inet_addr.of_string d.bind_ip
  ; peer= Peer.of_display d.peer
  ; client_port= d.client_port }

let to_yojson = Fn.compose Display.Stable.V1.to_yojson to_display

let to_peer : t -> Peer.t = function
  | {peer; _} -> peer
