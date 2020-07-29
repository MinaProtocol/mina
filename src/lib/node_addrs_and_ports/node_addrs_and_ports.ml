open Core
open Network_peer

(** Network information for speaking to this daemon. *)
type t =
  { external_ip: Unix.Inet_addr.Blocking_sexp.t
  ; bind_ip: Unix.Inet_addr.Blocking_sexp.t
        (** When peer is [None], the peer_id will be auto-generated and this field
      replaced with [Some] after libp2p initialization. *)
  ; mutable peer: Peer.Stable.Latest.t option
  ; libp2p_port: int
  ; client_port: int }
[@@deriving fields, sexp]

module Display = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { external_ip: string
        ; bind_ip: string
        ; peer: Peer.Display.Stable.V1.t option
        ; libp2p_port: int
        ; client_port: int }
      [@@deriving fields, yojson, bin_io, version, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { external_ip: string
    ; bind_ip: string
    ; peer: Peer.Display.Stable.Latest.t option
    ; libp2p_port: int
    ; client_port: int }
  [@@deriving fields, yojson, sexp]
end

let to_display (t : t) =
  Display.
    { external_ip= Unix.Inet_addr.to_string t.external_ip
    ; bind_ip= Unix.Inet_addr.to_string t.bind_ip
    ; peer= Option.map ~f:Peer.to_display t.peer
    ; libp2p_port= t.libp2p_port
    ; client_port= t.client_port }

let of_display (d : Display.t) : t =
  { external_ip= Unix.Inet_addr.of_string d.external_ip
  ; bind_ip= Unix.Inet_addr.of_string d.bind_ip
  ; peer= Option.map ~f:Peer.of_display d.peer
  ; libp2p_port= d.libp2p_port
  ; client_port= d.client_port }

let to_multiaddr (t : t) =
  match t.peer with
  | Some peer ->
      Some
        (sprintf "/ip4/%s/tcp/%d/p2p/%s"
           (Unix.Inet_addr.to_string t.external_ip)
           t.libp2p_port peer.peer_id)
  | None ->
      None

let to_multiaddr_exn t =
  Option.value_exn
    ~message:"cannot format peer as multiaddr before libp2p key generated"
    (to_multiaddr t)

let to_yojson = Fn.compose Display.Stable.V1.to_yojson to_display

let to_peer_exn : t -> Peer.t = function
  | {peer= Some peer; _} ->
      peer
  | _ ->
      failwith "to_peer_exn: no peer yet"
