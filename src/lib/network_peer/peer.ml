(* peer.ml -- peer with libp2p port and peer id *)

open Core

(** A libp2p PeerID is more or less a hash of a public key. *)
module Id = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving bin_io, compare, hash, equal, sexp, version]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving compare, hash, equal, sexp]

  (** Convert to the libp2p-defined base58 string *)
  let to_string (x : t) = x

  (** Create a Peer ID from a string, without checking if it is well-formed. *)
  let unsafe_of_string (s : string) : t = s
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { host: Core.Unix.Inet_addr.Stable.V1.t (* IPv4 or IPv6 address *)
      ; libp2p_port: int (* TCP *)
      ; peer_id: Id.Stable.V1.t }
    [@@deriving compare, sexp]

    let to_latest = Fn.id

    let equal t t' = compare t t' = 0

    (* these hash functions come from the implementation of Inet_addr,
         though they're not exposed *)
    let hash_fold_t hash t = hash_fold_int hash (Hashtbl.hash t)

    let hash : t -> int = Ppx_hash_lib.Std.Hash.of_fold hash_fold_t

    let to_yojson {host; peer_id; libp2p_port} =
      `Assoc
        [ ("host", `String (Unix.Inet_addr.to_string host))
        ; ("peer_id", `String peer_id)
        ; ("libp2p_port", `Int libp2p_port) ]

    let of_yojson =
      let lift_string = function `String s -> Some s | _ -> None in
      let lift_int = function `Int n -> Some n | _ -> None in
      function
      | `Assoc ls ->
          let open Option.Let_syntax in
          Result.of_option ~error:"missing keys"
            (let%bind host_str =
               List.Assoc.find ls "host" ~equal:String.equal >>= lift_string
             in
             let%bind peer_id =
               List.Assoc.find ls "peer_id" ~equal:String.equal >>= lift_string
             in
             let%map libp2p_port =
               List.Assoc.find ls "libp2p_port" ~equal:String.equal
               >>= lift_int
             in
             let host = Unix.Inet_addr.of_string host_str in
             {host; peer_id; libp2p_port})
      | _ ->
          Error "expected object"
  end
end]

type t = Stable.Latest.t =
  {host: Unix.Inet_addr.Blocking_sexp.t; libp2p_port: int; peer_id: string}
[@@deriving compare, sexp]

[%%define_locally
Stable.Latest.(of_yojson, to_yojson)]

include Hashable.Make (Stable.Latest)
include Comparable.Make_binable (Stable.Latest)

let create host ~libp2p_port ~peer_id = {host; libp2p_port; peer_id}

let to_discovery_host_and_port t =
  Host_and_port.create
    ~host:(Unix.Inet_addr.to_string t.host)
    ~port:t.libp2p_port

let to_string {host; libp2p_port; peer_id} =
  sprintf
    !"[host : %s, libp2p_port : %s, peer_id : %s]"
    (Unix.Inet_addr.to_string host)
    (Int.to_string libp2p_port)
    peer_id

let to_multiaddr_string {host; libp2p_port; peer_id} =
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
    module V1 = struct
      type t = {host: string; libp2p_port: int; peer_id: string}
      [@@deriving yojson, version, sexp, fields]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = {host: string; libp2p_port: int; peer_id: string}
  [@@deriving yojson, sexp]

  module Fields = Stable.Latest.Fields
end

let to_display {host; libp2p_port; peer_id} =
  Display.
    { host= Unix.Inet_addr.to_string host
    ; libp2p_port
    ; peer_id= Id.to_string peer_id }

let of_display {Display.host; libp2p_port; peer_id} =
  { host= Unix.Inet_addr.of_string host
  ; libp2p_port
  ; peer_id= Id.unsafe_of_string peer_id }
