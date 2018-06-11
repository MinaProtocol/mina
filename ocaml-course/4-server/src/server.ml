open Core
open Async

let people = [ "Greg"; "Laura"; "Jerry K"; ]
;;

let echo s = 
  List.fold people ~init:s ~f:(fun acc s -> 
    String.substr_replace_all acc ~pattern:s ~with_:"Name replaced!" )
;;

let rpc = 
  Rpc.Rpc.create 
    ~name:"echo" 
    ~version:5 
    ~bin_query:String.bin_t 
    ~bin_response:String.bin_t
;;

let implementations = 
  Rpc.Implementations.create_exn 
    ~implementations:
      [ Rpc.Rpc.implement rpc (fun () s -> return (echo s)) ] 
    ~on_unknown_rpc:`Close_connection
;;

let address = `Inet (Unix.Inet_addr.of_string "127.0.0.1", 4511)

let server = 
  Tcp.Server.create 
    ~on_handler_error:`Ignore
    (Tcp.Where_to_listen.create 
       ~socket_type:Socket.Type.tcp 
       ~address
       ~listening_on:(fun x -> x))
    (fun address reader writer -> 
       Rpc.Connection.server_with_close 
         reader writer 
         ~implementations
         ~connection_state:(fun _ -> ())
         ~on_handshake_error:`Ignore)
;;

let () = never_returns (Scheduler.go ())
;;
