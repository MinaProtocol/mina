open Core
open Network_peer

type t = string [@@deriving compare, bin_io_unversioned]

let to_string t = t

let of_string t = t

let of_libp2p_ipc = Libp2p_ipc.multiaddr_to_string

let to_libp2p_ipc = Libp2p_ipc.create_multiaddr

let to_peer t =
  match String.split ~on:'/' t with
  | [ ""; "ip4"; ip4_str; "tcp"; tcp_str; "p2p"; peer_id ] -> (
      try
        let host = Unix.Inet_addr.of_string ip4_str in
        let libp2p_port = Int.of_string tcp_str in
        Some (Peer.create host ~libp2p_port ~peer_id)
      with _ -> None )
  | _ ->
      None

let valid_as_peer t =
  match String.split ~on:'/' t with
  | [ ""; protocol; _; "tcp"; _; "p2p"; _ ]
    when List.mem [ "ip4"; "ip6"; "dns4"; "dns6" ] protocol ~equal:String.equal
    ->
      true
  | _ ->
      false

let of_file_contents contents : t list =
  String.split ~on:'\n' contents
  |> List.filter ~f:(fun s ->
         if valid_as_peer s then true
         else if String.is_empty s then false
         else (
           [%log' error (Logger.create ())]
             "Invalid peer $peer found in peers list"
             ~metadata:[ ("peer", `String s) ] ;
           false ) )
