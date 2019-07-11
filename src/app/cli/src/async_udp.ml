(* Taken from https://github.com/janestreet/async_extra/blob/master/async_udp/src/async_udp.ml which we cannot find in our current version of async extra *)
open! Core
open! Async
open! Int.Replace_polymorphic_compare

type write_buffer = (read_write, Iobuf.seek) Iobuf.t

let default_capacity = 1472

let default_retry = 12

module Config = struct
  type t =
    {capacity: int; init: write_buffer; stop: unit Deferred.t; max_ready: int}
  [@@deriving fields]

  let create ?(capacity = default_capacity)
      ?(init = Iobuf.create ~len:capacity) ?(stop = Deferred.never ())
      ?(max_ready = default_retry) () =
    {capacity; init; stop; max_ready}
end

let fail iobuf message a sexp_of_a =
  (* Render buffers immediately, before we have a chance to change them. *)
  failwiths message
    (a, [%sexp_of: (_, _) Iobuf.Hexdump.t option] iobuf)
    (Tuple.T2.sexp_of_t sexp_of_a ident)

(* Don't use [Or_error.map] to extract any of the [send] functions.  The natural usage
   results in partially applied functions! *)

let sendto_sync () =
  match Iobuf.sendto_nonblocking_no_sigpipe () with
  | Error _ as e ->
      e
  | Ok sendto ->
      Ok
        (fun fd buf addr ->
          Fd.with_file_descr_exn fd ~nonblocking:true (fun desc ->
              sendto buf desc (Unix.Socket.Address.to_sockaddr addr) ) )

let send_sync () =
  match Iobuf.send_nonblocking_no_sigpipe () with
  | Error _ as e ->
      e
  | Ok send ->
      Ok
        (fun fd buf ->
          Fd.with_file_descr_exn fd ~nonblocking:true (fun desc ->
              send buf desc ) )

(** [ready_iter fd ~stop ~max_ready ~f] iterates [f] over [fd], handling [EINTR] by
    retrying immediately (at most [max_ready] times in a row) and [EWOULDBLOCK]/[EAGAIN]
    by retrying when ready.  Iteration is terminated when [fd] closes, [stop] fills, or
    [f] returns [User_stopped].

    [ready_iter] may fill [stop] itself.

    By design, this function will not return to the Async scheduler until [fd] is no
    longer ready to transfer data or [f] has succeeded [max_ready] consecutive times. To
    avoid starvation, use [stop] or [User_stopped] and/or choose [max_ready] carefully to
    allow other Async jobs to run.

    @raise Unix.Unix_error on errors other than [EINTR] and [EWOULDBLOCK]/[EAGAIN]. *)
module Ready_iter = struct
  module Ok = struct
    type t = Poll_again | User_stopped
    [@@deriving sexp_of, enumerate, compare]

    let of_int_exn = function
      | 0 ->
          Poll_again
      | 1 ->
          User_stopped
      | i ->
          failwithf "invalid ready iter ok %d" i ()

    let to_int = function Poll_again -> 0 | User_stopped -> 1
  end

  include Unix.Syscall_result.Make (Ok) ()

  let poll_again = create_ok Poll_again

  let user_stopped = create_ok User_stopped
end

let ready_iter fd ~stop ~max_ready ~f read_or_write ~syscall_name =
  let rec inner_loop i file_descr : Ready_iter.Ok.t =
    if i < max_ready && Ivar.is_empty stop && Fd.is_open fd then
      match f file_descr |> Ready_iter.to_result (* doesn't allocate *) with
      | Ok Poll_again | Error EINTR ->
          inner_loop (i + 1) file_descr
      | Ok User_stopped ->
          User_stopped
      | Error (EWOULDBLOCK | EAGAIN) ->
          Poll_again
      (* This looks extreme but serves the purpose of effectively terminating the
         [interruptible_every_ready_iter] job and the [ready_iter] loop. *)
      | Error e ->
          raise (Unix.Unix_error (e, syscall_name, ""))
    else Poll_again
  in
  (* [Fd.with_file_descr] is for [Raw_fd.set_nonblock_if_necessary].
     [with_file_descr_deferred] would be the more natural choice, but it doesn't call
     [set_nonblock_if_necessary]. *)
  match
    Fd.with_file_descr ~nonblocking:true fd (fun file_descr ->
        Fd.interruptible_every_ready_to fd read_or_write
          ~interrupt:(Ivar.read stop)
          (fun file_descr ->
            match inner_loop 0 file_descr with
            | Poll_again ->
                ()
            | User_stopped ->
                Ivar.fill_if_empty stop () )
          file_descr )
  with
  (* Avoid one ivar creation and wait immediately by returning the result from
     [Fd.interruptible_every_ready_to] directly. *)
  | `Ok deferred ->
      deferred
  | `Already_closed ->
      return `Closed
  | `Error e ->
      raise e

let sendto () =
  match Iobuf.sendto_nonblocking_no_sigpipe () with
  | Error _ as e ->
      e
  | Ok sendto ->
      Ok
        (fun fd buf addr ->
          let addr = Unix.Socket.Address.to_sockaddr addr in
          let stop = Ivar.create () in
          ready_iter fd ~max_ready:default_retry ~stop `Write
            ~syscall_name:"sendto" ~f:(fun file_descr ->
              match
                Unix.Syscall_result.Unit.to_result (sendto buf file_descr addr)
              with
              | Ok () ->
                  Ready_iter.user_stopped
              | Error e ->
                  Ready_iter.create_error e )
          >>= function
          | `Interrupted ->
              Deferred.unit
          | (`Bad_fd | `Closed | `Unsupported) as error ->
              fail (Some buf) "Udp.sendto" (error, addr)
                [%sexp_of:
                  [`Bad_fd | `Closed | `Unsupported] * Core.Unix.sockaddr] )

let send () =
  match Iobuf.send_nonblocking_no_sigpipe () with
  | Error _ as e ->
      e
  | Ok send ->
      Ok
        (fun fd buf ->
          let stop = Ivar.create () in
          ready_iter fd ~max_ready:default_retry ~stop `Write
            ~syscall_name:"send" ~f:(fun file_descr ->
              match
                Unix.Syscall_result.Unit.to_result (send buf file_descr)
              with
              | Ok () ->
                  Ready_iter.user_stopped
              | Error e ->
                  Ready_iter.create_error e )
          >>= function
          | `Interrupted ->
              Deferred.unit
          | (`Bad_fd | `Closed | `Unsupported) as error ->
              fail (Some buf) "Udp.send" error
                [%sexp_of: [`Bad_fd | `Closed | `Unsupported]] )

let bind ?ifname addr =
  let socket = Socket.create Socket.Type.udp in
  let is_multicast a =
    Unix.Cidr.does_match Unix.Cidr.multicast (Socket.Address.Inet.addr a)
  in
  ( if is_multicast addr then
    try
      (* We do not treat [mcast_join] as a blocking operation because it only instructs
       the kernel to send an IGMP message, which the kernel handles asynchronously. *)
      Core.Unix.mcast_join ?ifname
        (Fd.file_descr_exn (Socket.fd socket))
        (Socket.Address.to_sockaddr addr)
    with exn ->
      raise_s
        [%message
          "Async_udp.bind unable to join multicast group"
            (addr : Socket.Address.Inet.t)
            (ifname : string option)
            (exn : Exn.t)] ) ;
  Socket.bind_inet socket addr

let bind_any () =
  let bind_addr = Socket.Address.Inet.create_bind_any ~port:0 in
  let socket = Socket.create Socket.Type.udp in
  (* When bind() is called with a port number of zero, a non-conflicting local port
     address is chosen (i.e., an ephemeral port).  In almost all cases where we use
     this, we want a unique port, and hence prevent reuseaddr. *)
  try Socket.bind_inet socket ~reuseaddr:false bind_addr
  with bind_exn ->
    let socket_fd = Socket.fd socket in
    don't_wait_for
      (* Errors from [close] are generally harmless, so we ignore them *)
      (Monitor.handle_errors
         (fun () -> Fd.close socket_fd)
         (fun (_ : exn) -> ())) ;
    raise bind_exn

module Loop_result = struct
  type t = Closed | Stopped [@@deriving sexp_of, compare]

  let of_fd_interruptible_every_ready_to_result_exn buf function_name x
      sexp_of_x result =
    match result with
    | (`Bad_fd | `Unsupported) as error ->
        fail buf function_name (error, x)
          [%sexp_of: [`Bad_fd | `Unsupported] * x]
    | `Closed ->
        Closed
    | `Interrupted ->
        Stopped
end

let recvfrom_loop_with_buffer_replacement ?(config = Config.create ()) fd f =
  let stop = Ivar.create () in
  Config.stop config >>> Ivar.fill_if_empty stop ;
  let buf = ref (Config.init config) in
  ready_iter ~stop ~max_ready:config.max_ready fd `Read
    ~syscall_name:"recvfrom" ~f:(fun file_descr ->
      match Iobuf.recvfrom_assume_fd_is_nonblocking !buf file_descr with
      | exception Unix.Unix_error (e, _, _) ->
          Ready_iter.create_error e
      | ADDR_UNIX dom ->
          fail (Some !buf) "Unix domain socket addresses not supported" dom
            [%sexp_of: string]
      | ADDR_INET (host, port) ->
          Iobuf.flip_lo !buf ;
          buf := f !buf (`Inet (host, port)) ;
          Iobuf.reset !buf ;
          Ready_iter.poll_again )
  >>| Loop_result.of_fd_interruptible_every_ready_to_result_exn (Some !buf)
        "recvfrom_loop_without_buffer_replacement" fd [%sexp_of: Fd.t]

let recvfrom_loop ?config fd f =
  recvfrom_loop_with_buffer_replacement ?config fd (fun b a -> f b a ; b)

(* We don't care about the address, so read instead of recvfrom. *)
let read_loop_with_buffer_replacement ?(config = Config.create ()) fd f =
  let stop = Ivar.create () in
  Config.stop config >>> Ivar.fill_if_empty stop ;
  let buf = ref (Config.init config) in
  ready_iter ~stop ~max_ready:config.max_ready fd `Read ~syscall_name:"read"
    ~f:(fun file_descr ->
      let result = Iobuf.read_assume_fd_is_nonblocking !buf file_descr in
      if Unix.Syscall_result.Unit.is_ok result then (
        Iobuf.flip_lo !buf ;
        buf := f !buf ;
        Iobuf.reset !buf ;
        Ready_iter.poll_again )
      else Unix.Syscall_result.Unit.reinterpret_error_exn result )
  >>| Loop_result.of_fd_interruptible_every_ready_to_result_exn (Some !buf)
        "read_loop_with_buffer_replacement" fd [%sexp_of: Fd.t]

let read_loop ?config fd f =
  read_loop_with_buffer_replacement ?config fd (fun b -> f b ; b)

(* Too small a [max_count] here negates the value of [recvmmsg], while too large risks
   starvation of other ready file descriptors.  32 was chosen empirically to stay below
   ~64kb of data, assuming a standard Ethernet MTU. *)
let default_recvmmsg_loop_max_count = 32

let recvmmsg_loop =
  let create_buffers ~max_count config =
    let len = Config.capacity config in
    if len <= 2048 then
      let bstr = Bigstring.create (2048 * max_count) in
      Array.init max_count ~f:(fun index ->
          Iobuf.of_bigstring ~pos:(index * 2048) ~len bstr )
    else
      Array.init max_count ~f:(function
        | 0 ->
            Config.init config
        | _ ->
            Iobuf.create ~len:(Iobuf.length (Config.init config)) )
  in
  match Iobuf.recvmmsg_assume_fd_is_nonblocking with
  | Error _ as e ->
      e
  | Ok recvmmsg ->
      Ok
        (fun ?(config = Config.create ())
             ?(max_count = default_recvmmsg_loop_max_count)
             ?(on_wouldblock = fun () -> ()) fd f ->
          let bufs = create_buffers ~max_count config in
          let context = Iobuf.Recvmmsg_context.create bufs in
          let stop = Ivar.create () in
          Config.stop config >>> Ivar.fill_if_empty stop ;
          ready_iter ~stop ~max_ready:config.max_ready fd `Read
            ~syscall_name:"recvmmsg" ~f:(fun file_descr ->
              let result = recvmmsg file_descr context in
              if Unix.Syscall_result.Int.is_ok result then
                let count = Unix.Syscall_result.Int.ok_exn result in
                if count > Array.length bufs then
                  failwithf
                    "Unexpected result from \
                     Iobuf.recvmmsg_assume_fd_is_nonblocking: count (%d) > \
                     Array.length bufs (%d)"
                    count (Array.length bufs) ()
                else (
                  (* [recvmmsg_assume_fd_is_nonblocking] implicitly calls [flip_lo]
                   before and [reset] after the call, so we mustn't. *)
                  f bufs ~count ;
                  Ready_iter.poll_again )
              else (
                ( match Unix.Syscall_result.Int.error_exn result with
                | EWOULDBLOCK | EAGAIN ->
                    on_wouldblock ()
                | _ ->
                    () ) ;
                Unix.Syscall_result.Int.reinterpret_error_exn result ) )
          >>| Loop_result.of_fd_interruptible_every_ready_to_result_exn None
                "recvmmsg_loop" fd [%sexp_of: Fd.t] )

module Private = struct
  module Ready_iter = Ready_iter
end
