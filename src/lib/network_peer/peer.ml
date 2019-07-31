(* peer.ml -- peer with discovery port and communications port *)

open Core
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { host: Core.Unix.Inet_addr.Stable.V1.t (* IPv4 or IPv6 address *)
        ; discovery_port: int (* UDP *)
        ; communication_port: int (* TCP *) }
      [@@deriving bin_io, compare, sexp, version]

      let equal t t' = compare t t' = 0

      (* these hash functions come from the implementation of Inet_addr, 
         though they're not exposed *)
      let hash_fold_t hash t = hash_fold_int hash (Hashtbl.hash t)

      let hash : t -> int = Ppx_hash_lib.Std.Hash.of_fold hash_fold_t

      let to_yojson {host; discovery_port; communication_port} =
        `Assoc
          [ ("host", `String (Unix.Inet_addr.to_string host))
          ; ("discovery_port", `Int discovery_port)
          ; ("communication_port", `Int communication_port) ]

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
               let%bind discovery_port =
                 List.Assoc.find ls "discovery_port" ~equal:String.equal
                 >>= lift_int
               in
               let%map communication_port =
                 List.Assoc.find ls "communication_port" ~equal:String.equal
                 >>= lift_int
               in
               let host = Unix.Inet_addr.of_string host_str in
               {host; discovery_port; communication_port})
        | _ ->
            Error "expected object"
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "peer"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted *)
type t = Stable.Latest.t =
  { host: Core.Unix.Inet_addr.Stable.V1.t
  ; discovery_port: int
  ; communication_port: int }
[@@deriving compare, sexp]

[%%define_locally
Stable.Latest.(of_yojson, to_yojson)]

include Hashable.Make (Stable.Latest)
include Comparable.Make_binable (Stable.Latest)

let create host ~discovery_port ~communication_port =
  {host; discovery_port; communication_port}

(** localhost with dummy ports *)
let local =
  create Unix.Inet_addr.localhost ~discovery_port:0 ~communication_port:0

let to_discovery_host_and_port t =
  Host_and_port.create
    ~host:(Unix.Inet_addr.to_string t.host)
    ~port:t.discovery_port

let to_communications_host_and_port t =
  Host_and_port.create
    ~host:(Unix.Inet_addr.to_string t.host)
    ~port:t.communication_port

let to_string {host; discovery_port; communication_port} =
  sprintf
    !"[host : %s, discovery_port : %s, communication_port : %s]"
    (Unix.Inet_addr.to_string host)
    (Int.to_string discovery_port)
    (Int.to_string communication_port)

let pretty_list peers = String.concat ~sep:"," @@ List.map peers ~f:to_string

module Event = struct
  type t =
    | Connect of Stable.Latest.t list
    | Disconnect of Stable.Latest.t list
  [@@deriving sexp]
end
