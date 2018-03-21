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

  let%bind proc = 
    Process.create_exn
      ~prog:"/bin/bash" 
      ~args:
        [ "-c"
        ; "/app/lib/mnt_cycle_search_testbridge/search.sh"
        ] 
      () 
  in
  let stdout = Process.stdout proc in
  let stderr = Process.stderr proc in
  let stdin = Process.stdin proc in

  don't_wait_for begin
    let rec go () = 
      let%bind line = Reader.read_line stderr in
      let line = 
        match line with
        | `Ok s -> s
        | `Eof -> "EoF"
      in
      printf "err: %s\n" line;
      go ()
    in 
    go ()
  end;

  let get_cycle n = 
    printf "writing %d\n" n;
    Writer.write_line stdin (Int.to_string n);
    let%map stdout = Reader.read_line stdout in
    match stdout with
    | `Ok s -> (printf "output: %s\n" s; (n, s))
    | `Eof -> (n, "process exited")
  in

  let get_cycles _ (low, high) = 
    Deferred.List.map ~how:`Sequential (List.range low high) ~f:get_cycle
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
