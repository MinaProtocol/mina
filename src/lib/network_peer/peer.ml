(* peer.ml -- peer with libp2p port and peer id *)

open Core

(** A libp2p PeerID is more or less a hash of a public key. *)
module Id = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving compare, hash, equal, sexp]

      let to_latest = Fn.id
    end
  end]

  (** Convert to the libp2p-defined base58 string *)
  let to_string (x : t) = x

  (** Create a Peer ID from a string, without checking if it is well-formed. *)
  let unsafe_of_string (s : string) : t = s
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      { host : Core.Unix.Inet_addr.Stable.V1.t (* IPv4 or IPv6 address *)
      ; libp2p_port : int (* TCP or Websocket *)
      ; peer_id : Id.Stable.V1.t
      ; ws : bool (* true for TCP, false for Websocket *)
      }
    [@@deriving compare, sexp]

    let to_latest = Fn.id

    let equal t t' = compare t t' = 0

    (* these hash functions come from the implementation of Inet_addr,
         though they're not exposed *)
    let hash_fold_t hash t = hash_fold_int hash (Hashtbl.hash t)

    let hash : t -> int = Ppx_hash_lib.Std.Hash.of_fold hash_fold_t

    let to_yojson { host; peer_id; libp2p_port; ws } =
      `Assoc
        [ ("host", `String (Unix.Inet_addr.to_string host))
        ; ("peer_id", `String peer_id)
        ; ("libp2p_port", `Int libp2p_port)
        ; ("ws", `Bool ws)
        ]

    let of_yojson =
      let lift_string = function `String s -> Some s | _ -> None in
      let lift_int = function `Int n -> Some n | _ -> None in
      let lift_bool = function `Bool n -> Some n | _ -> None in
      function
      | `Assoc ls ->
          let open Option.Let_syntax in
          let error = "missing keys" in
          Result.of_option ~error
            (Option.value_exn ~message:error
               (let%bind host_str =
                  List.Assoc.find ls "host" ~equal:String.equal >>= lift_string
                in
                let%bind peer_id =
                  List.Assoc.find ls "peer_id" ~equal:String.equal
                  >>= lift_string
                in
                let%map libp2p_port =
                  List.Assoc.find ls "libp2p_port" ~equal:String.equal
                  >>= lift_int
                in
                let%map ws =
                  List.Assoc.find ls "ws" ~equal:String.equal >>= lift_bool
                in
                let host = Unix.Inet_addr.of_string host_str in
                { host; peer_id; libp2p_port; ws }))
      | _ ->
          Error "expected object"
  end
end]

type t = Stable.Latest.t =
  { host : Unix.Inet_addr.Blocking_sexp.t
  ; libp2p_port : int
  ; peer_id : string
  ; ws : bool
  }
[@@deriving compare, sexp]

[%%define_locally Stable.Latest.(of_yojson, to_yojson)]

include Hashable.Make (Stable.Latest)
include Comparable.Make_binable (Stable.Latest)

let create host ~libp2p_port ~peer_id ~ws = { host; libp2p_port; peer_id; ws }

let to_discovery_host_and_port t =
  Host_and_port.create
    ~host:(Unix.Inet_addr.to_string t.host)
    ~port:t.libp2p_port

let to_string { host; libp2p_port; peer_id; ws } =
  sprintf
    !"[host : %s, libp2p_port : %s, peer_id: %s, ws : %s]"
    (Unix.Inet_addr.to_string host)
    (Int.to_string libp2p_port)
    peer_id (Bool.to_string ws)

let to_multiaddr_string { host; libp2p_port; peer_id; ws } =
  match ws with
  | true ->
      sprintf "/ip4/%s/tcp/%d/ws/p2p/%s"
        (Unix.Inet_addr.to_string host)
        libp2p_port peer_id
  | _ ->
      sprintf "/ip4/%s/tcp/%d/p2p/%s"
        (Unix.Inet_addr.to_string host)
        libp2p_port peer_id

let pretty_list peers = String.concat ~sep:"," @@ List.map peers ~f:to_string

module Event = struct
  type t =
    | Connect of Stable.Latest.t list
    | Disconnect of Stable.Latest.t list
  [@@deriving sexp]
end

module Display = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = { host : string; libp2p_port : int; peer_id : string; ws : bool }
      [@@deriving yojson, version, sexp, fields]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { host : string; libp2p_port : int; peer_id : string; ws : bool }
  [@@deriving yojson, sexp]

  module Fields = Stable.Latest.Fields
end

let ip { host; _ } = host

let to_display { host; libp2p_port; peer_id; ws } =
  Display.
    { host = Unix.Inet_addr.to_string host
    ; libp2p_port
    ; peer_id = Id.to_string peer_id
    ; ws
    }

let of_display { Display.host; libp2p_port; peer_id; ws } =
  { host = Unix.Inet_addr.of_string host
  ; libp2p_port
  ; peer_id = Id.unsafe_of_string peer_id
  ; ws
  }
