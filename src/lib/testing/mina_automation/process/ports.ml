(** A pool of host TCP ports for the nodes of one test network. *)

open Core

type t = { mutable available_ports : int list }

let create ~min_port ~max_port =
  { available_ports = List.range min_port max_port }

(* [port_is_free port] is true when a TCP socket can bind [port] on the
   loopback address. Anything already listening there (a daemon leaked by an
   earlier run, a host service) makes the bind fail. The socket is closed
   again at once, so another process can still take the port before the
   node binds it. *)
let port_is_free port =
  let socket =
    Core.Unix.socket ~domain:PF_INET ~kind:SOCK_STREAM ~protocol:0 ()
  in
  Exn.protect
    ~f:(fun () ->
      try
        Core.Unix.setsockopt socket SO_REUSEADDR true ;
        Core.Unix.bind socket
          ~addr:(ADDR_INET (Core.Unix.Inet_addr.localhost, port)) ;
        true
      with Core.Unix.Unix_error _ -> false )
    ~finally:(fun () -> Core.Unix.close socket)

(** Allocate the next port in the range that is free now. *)
let rec allocate t =
  match t.available_ports with
  | [] ->
      failwith "No available ports"
  | port :: rest ->
      t.available_ports <- rest ;
      if port_is_free port then port else allocate t
