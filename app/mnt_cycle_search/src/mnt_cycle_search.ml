open Core
open Async

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]
    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0
        ~bin_query ~bin_response
  end

  module Get_cycles = struct
    type query = int * int [@@deriving bin_io]
    type response = (int * string) list [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_cycles" ~version:0
        ~bin_query ~bin_response
  end
end

let main () =
  Random.self_init ();

  let rand_name () = 
    let rand_char () = Char.of_int_exn (Char.to_int 'a' + Random.int 26) in
    String.init 10 ~f:(fun _ -> rand_char ())
  in

  let name = rand_name ()
  in

  printf "name: %s\n" name;

  let get_cycle n = 
    let%map stdout = 
      Process.run ~prog:"python" ~args:[ "/app-lib/ecfactory/ecfactory/mnt_cycles/mnt_cycles_examples.py" ] () 
    in
    match stdout with
    | Ok s -> (n, s)
    | Error s -> (n, Error.to_string_hum s)
  in

  let get_cycles _ (low, high) = 
    Deferred.List.all (List.map (List.range low high) ~f:get_cycle)
  in

  let implementations = 
    [ Rpc.Rpc.implement Rpcs.Ping.rpc (fun _ () -> return ())
    ; Rpc.Rpc.implement Rpcs.Get_cycles.rpc get_cycles
    ]
  in

  let implementations = 
    Rpc.Implementations.create_exn 
      ~implementations
      ~on_unknown_rpc:`Close_connection
  in

  let _ = 
    Tcp.Server.create 
      ~on_handler_error:(`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
      (Tcp.Where_to_listen.of_port 8010)
      (fun address reader writer -> 
         Rpc.Connection.server_with_close 
           reader writer
           ~implementations
           ~connection_state:(fun _ -> ())
           ~on_handshake_error:`Ignore)
  in
  Async.never ()
;;

let () = ignore (main ())
;;

let () = never_returns (Scheduler.go ())
;;
