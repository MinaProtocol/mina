open Core

let default_client = 8301

let default_external = 8302

let default_rest = 0xc0d

let of_local port = Host_and_port.create ~host:"127.0.0.1" ~port
