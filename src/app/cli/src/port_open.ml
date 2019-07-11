open Core
open Async
module Udp = Async_udp

let check_udp ip ~port_to_use ~port_to_check ~logger =
  let code = string_of_int (Random.int 1_000_000) ^ "\n" in
  let server_deferred =
    let addr =
      Socket.Address.Inet.create Unix.Inet_addr.bind_any ~port:port_to_check
    in
    let socket = Udp.bind addr in
    let socket_fd = Socket.fd socket in
    let die_ivar : unit Ivar.t = Ivar.create () in
    let stop =
      Deferred.any [Async.after (Time.Span.of_sec 1.0); Ivar.read die_ivar]
    in
    let config = Udp.Config.create ~stop () in
    (* listen for the request *)
    let%map loop_result =
      Udp.recvfrom_loop ~config socket_fd (fun buf addr ->
          match
            Iobuf.fill_bin_prot buf [%bin_type_class: string].writer code
          with
          | Ok () -> (
            (* fire the response *)
            match Udp.sendto () with
            | Ok f ->
                let reply = f socket_fd buf addr in
                Deferred.upon reply (fun () -> Ivar.fill_if_empty die_ivar ()) ;
                don't_wait_for reply
            | Error e ->
                Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
                  (Error.to_string_mach e) ;
                Ivar.fill_if_empty die_ivar () )
          | Error e ->
              Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
                (Error.to_string_mach e) ;
              Ivar.fill_if_empty die_ivar () )
    in
    Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
      "Udp (serverside) loop result: %s"
      (Udp.Loop_result.sexp_of_t loop_result |> Sexp.to_string_hum)
  in
  let client_deferred =
    let addr =
      Socket.Address.Inet.create Unix.Inet_addr.bind_any ~port:port_to_use
    in
    let socket = Udp.bind addr in
    let socket_fd = Socket.fd socket in
    let result :
        (unit, [> `Timeout | `Bad_code | `Io_error of Error.t]) Result.t Ivar.t
        =
      Ivar.create ()
    in
    let stop =
      Deferred.any
        [Async.after (Time.Span.of_sec 1.0); Ivar.read result >>| ignore]
    in
    let config = Udp.Config.create ~stop () in
    (* listen for the response *)
    ( don't_wait_for
    @@ let%map loop_result =
         Udp.recvfrom_loop ~config socket_fd (fun buf _addr ->
             match
               Iobuf.consume_bin_prot buf [%bin_type_class: string].reader
             with
             | Ok code' ->
                 if String.equal code' code then
                   Ivar.fill result (Result.return ())
                 else Ivar.fill result (Error `Bad_code)
             | Error e ->
                 Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
                   (Error.to_string_mach e) ;
                 Ivar.fill result (Error (`Io_error e)) )
       in
       Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
         "Udp (clientside) loop result: %s"
         (Udp.Loop_result.sexp_of_t loop_result |> Sexp.to_string_hum) ) ;
    (* fire the send *)
    ( don't_wait_for
    @@
    match Udp.sendto () with
    | Ok f ->
        let buf = Iobuf.create ~len:(String.length code + 1) in
        let addr = Socket.Address.Inet.create ip ~port:port_to_check in
        f socket_fd buf addr
    | Error e ->
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
          (Error.to_string_mach e) ;
        Ivar.fill result (Error (`Io_error e)) ;
        Deferred.return () ) ;
    Ivar.read result
  in
  don't_wait_for server_deferred ;
  Deferred.any
    [ client_deferred
    ; (Async.after (Time.Span.of_sec 2.0) >>| fun () -> Error `Timeout) ]

let check_tcp ip ~port ~logger =
  let code = string_of_int (Random.int 1_000_000) ^ "\n" in
  let die_ivar : unit Ivar.t = Ivar.create () in
  let server_deferred =
    Tcp.Server.create
      ~on_handler_error:
        (`Call
          (fun _net exn ->
            Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
              (Exn.to_string_mach exn) ;
            Ivar.fill_if_empty die_ivar () ))
      (Tcp.Where_to_listen.bind_to All_addresses (On_port port))
      (fun _address _reader writer ->
        Writer.write writer code ;
        let%map () = Writer.close writer in
        Ivar.fill_if_empty die_ivar () )
  in
  let%bind server = server_deferred in
  don't_wait_for @@ (Ivar.read die_ivar >>= fun () -> Tcp.Server.close server) ;
  let client_deferred :
      ( unit
      , [> `Io_error of Error.t | `Timeout | `Bad_code | `Eof] )
      Deferred.Result.t =
    let%map result_or_error =
      Monitor.try_with_or_error (fun () ->
          Tcp.with_connection ~timeout:(Time.Span.of_sec 1.0)
            (Tcp.Where_to_connect.of_inet_address
               (Socket.Address.Inet.create ip ~port))
            (fun _socket reader _writer ->
              match%map Reader.read_line reader with
              | `Eof ->
                  Error `Eof
              | `Ok str ->
                  if String.equal str code then Result.return ()
                  else Error `Bad_code ) )
    in
    (* recover (which should be a combinator in Core, if you ask me) *)
    match result_or_error with Ok v -> v | Error e -> Error (`Io_error e)
  in
  Deferred.any
    [ client_deferred
    ; ( Async.after (Time.Span.of_sec 2.0)
      >>| fun () ->
      Ivar.fill_if_empty die_ivar () ;
      Error `Timeout ) ]
