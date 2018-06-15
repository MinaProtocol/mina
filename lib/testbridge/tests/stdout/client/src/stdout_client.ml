open Core
open Async

let () = Random.self_init ()

let rand_name () =
  let rand_char () = Char.of_int_exn (Char.to_int 'a' + Random.int 26) in
  String.init 10 ~f:(fun _ -> rand_char ())

let name = rand_name ()

let calls = ref 0

let () = printf "name: %s\n" name

let () =
  let rec go i =
    printf "stdout: %s %d\n" (rand_name ()) i ;
    eprintf "stderr: %s %d\n" (rand_name ()) i ;
    let%bind () = after (sec 1.0) in
    go (i + 1)
  in
  don't_wait_for (go 0)

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]

    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0 ~bin_query ~bin_response
  end

  module Echo = struct
    type query = String.t [@@deriving bin_io]

    type response = String.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Echo" ~version:0 ~bin_query ~bin_response
  end
end

let echo _ echo =
  let current_calls = !calls in
  calls := current_calls + 1 ;
  printf "got call %d %s\n" current_calls echo ;
  return ("echo-" ^ name ^ "-" ^ Int.to_string current_calls ^ ": " ^ echo)

let implementations =
  [ Rpc.Rpc.implement Rpcs.Echo.rpc echo
  ; Rpc.Rpc.implement Rpcs.Ping.rpc (fun _ () -> return ()) ]

let implementations =
  Rpc.Implementations.create_exn ~implementations
    ~on_unknown_rpc:`Close_connection

;; Tcp.Server.create
     ~on_handler_error:
       (`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
     (Tcp.Where_to_listen.create ~socket_type:Socket.Type.tcp
        ~address:(`Inet (Unix.Inet_addr.of_string "127.0.0.1", 8000))
        ~listening_on:(fun x -> Fn.id))
     (fun address reader writer ->
       Rpc.Connection.server_with_close reader writer ~implementations
         ~connection_state:(fun _ -> ())
         ~on_handshake_error:`Ignore )

let () = never_returns (Scheduler.go ())
