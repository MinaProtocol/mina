open Core
open Async
open Swimlib

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module type Message_intf = sig
  type msg
  include Versioned_rpc.Both_convert.One_way.S
    with type callee_msg := msg
    and type caller_msg := msg
end

module type S =
  functor (Message : Message_intf) -> sig

    type t = 
      { timeout : Time.Span.t
      ; target_peer_count : int
      ; new_peer_reader : Peer.t Linear_pipe.Reader.t
      ; broadcast_writer : Message.msg Linear_pipe.Writer.t
      ; received_reader : Message.msg Linear_pipe.Reader.t
      ; peers : Peer.Hash_set.t
      }

    module Params : sig
      type t =
        { timeout           : Time.Span.t
        ; target_peer_count : int
        ; address           : Peer.t
        }
    end

    val create
      :  Peer.Event.t Linear_pipe.Reader.t
      -> Params.t
      -> unit Rpc.Implementation.t list
      -> t

    val received : t -> Message.msg Linear_pipe.Reader.t

    val broadcast : t -> Message.msg Linear_pipe.Writer.t

    val broadcast_all : t -> Message.msg -> 
      (unit -> [`Done | `Continue] Deferred.t) Staged.t

    val query_peer
      : t
      -> Peer.t
      -> ('q, 'r) dispatch
      -> 'q
      -> 'r Or_error.t Deferred.t

    val query_random_peers
      : t
      -> int
      -> ('q, 'r) dispatch
      -> 'q
      -> 'r Or_error.t Deferred.t List.t
  end

module Make (Message : Message_intf) = struct

  type t = 
    { timeout : Time.Span.t
    ; target_peer_count : int
    ; new_peer_reader : Peer.t Linear_pipe.Reader.t
    ; broadcast_writer : Message.msg Linear_pipe.Writer.t
    ; received_reader : Message.msg Linear_pipe.Reader.t
    ; peers : Peer.Hash_set.t
    }

  module Params = struct
    type t =
      { timeout           : Time.Span.t
      ; target_peer_count : int
      ; address           : Peer.t
      }
  end

  (* OPTIMIZATION: use fast n choose k implementation - see python or old flow code *)
  let random_sublist xs n = List.take (List.permute xs) n
  ;;

  let create_connection_with_menu r w =
    match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
    | Error exn -> return (Or_error.of_exn exn)
    | Ok conn -> Versioned_rpc.Connection_with_menu.create conn
  ;;

  let try_call_rpc peer timeout dispatch query =
    try_with (fun () ->
      Tcp.with_connection
        (Tcp.Where_to_connect.of_host_and_port peer)
        ~timeout
        (fun _ r w ->
           create_connection_with_menu r w >>=? fun conn ->
           dispatch conn query)
    ) >>| function
    | Ok Ok result -> Ok result
    | Ok Error exn -> Error exn
    | Error exn -> Or_error.of_exn exn

  let broadcast_selected timeout peers msg =
    let send peer = 
      try_call_rpc 
        peer timeout (fun conn m -> return (Message.dispatch_multi conn m)) msg 
    in
    Deferred.List.iter 
      ~how:`Parallel 
      peers
      ~f:(fun p -> match%map (send p) with
        | Ok () -> ()
        | Error e -> eprintf "%s\n" (Error.to_string_hum e))
  ;;

  let broadcast_random timeout peers n msg = 
    let selected_peers = random_sublist (Hash_set.to_list peers) n in
    broadcast_selected timeout selected_peers msg
  ;;

  let create (peer_events : Peer.Event.t Linear_pipe.Reader.t) (params : Params.t) implementations = 
    let new_peer_reader, new_peer_writer = Linear_pipe.create () in
    let broadcast_reader, broadcast_writer = Linear_pipe.create () in
    let received_reader, received_writer = Linear_pipe.create () in
    let t = 
      { timeout = params.timeout
      ; target_peer_count = params.target_peer_count 
      ; new_peer_reader
      ; broadcast_writer
      ; received_reader
      ; peers = Peer.Hash_set.create ()
      } 
    in
    don't_wait_for begin
      Linear_pipe.iter_unordered 
        ~max_concurrency:64 
        broadcast_reader 
        ~f:(fun m -> broadcast_random t.timeout t.peers t.target_peer_count m)
    end;
    let broadcast_received_capacity = 64 in
    let implementations = 
      let implementations =
        Versioned_rpc.Menu.add begin
          Message.implement_multi (fun () ~version msg ->
            Linear_pipe.write_or_drop
              ~capacity:broadcast_received_capacity
              received_writer received_reader msg)
          @ implementations
        end
      in
      Rpc.Implementations.create_exn
        ~implementations
        ~on_unknown_rpc:`Close_connection
    in
    don't_wait_for begin
      Linear_pipe.iter_unordered 
        ~max_concurrency:64 
        peer_events ~f:(function
          | Connect peers -> 
            List.iter peers ~f:(fun peer -> Hash_set.add t.peers peer); Deferred.unit
          | Disconnect peers -> 
            List.iter peers ~f:(fun peer -> Hash_set.remove t.peers peer); Deferred.unit 
        )
    end;
    ignore begin
      Tcp.Server.create
        ~on_handler_error:(`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
        (Tcp.Where_to_listen.of_port (Host_and_port.port params.address))
        (fun address reader writer -> 
           Rpc.Connection.server_with_close 
             reader writer
             ~implementations
             ~connection_state:(fun _ -> ())
             ~on_handshake_error:
               (`Call (fun exn -> 
                  eprintf "%s\n" (Exn.to_string_mach exn);
                Deferred.unit)))
    end;
    t

  let received t = t.received_reader

  let broadcast t = t.broadcast_writer

  let new_peers t = t.new_peer_reader

  let broadcast_all t msg = 
    let to_broadcast = ref (List.permute (Hash_set.to_list t.peers)) in
    stage (
      fun () -> 
        let selected = List.take !to_broadcast t.target_peer_count in
        to_broadcast := List.drop !to_broadcast t.target_peer_count;
        let%map () = broadcast_selected t.timeout selected msg in
        if List.length !to_broadcast = 0 then `Done else `Continue)

  let query_peer t (peer : Peer.t) rpc query = 
    try_call_rpc peer t.timeout rpc query

  let query_random_peers t n rpc query = 
    let peers = random_sublist (Hash_set.to_list t.peers) n in
    List.map peers ~f:(fun peer -> query_peer t peer rpc query)
end
