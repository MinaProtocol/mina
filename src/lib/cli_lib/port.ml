open Core

let default_client = 8301

let default_external = 8302

let default_rest = 0xc0d

(* This is always computed as default_external+1 *)
let default_discovery = 8303

let default_libp2p = 8304

let of_local port = Host_and_port.create ~host:"127.0.0.1" ~port
