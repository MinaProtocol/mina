open Core
open Async
open Swimlib

module type S =
  functor (Message : sig type t [@@deriving bin_io] end) -> sig

    type t = 
      { timeout : Time.Span.t
      ; target_peer_count : int
      ; new_peer_reader : Peer.t Linear_pipe.Reader.t
      ; broadcast_writer : Message.t Linear_pipe.Writer.t
      ; received_reader : Message.t Linear_pipe.Reader.t
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
      -> unit Rpc.Implementations.t
      -> t

    val received : t -> Message.t Linear_pipe.Reader.t

    val broadcast : t -> Message.t Linear_pipe.Writer.t

    val broadcast_all : t -> Message.t -> 
      (unit -> bool Deferred.t)

    val query_peer
      : t
      -> Peer.t
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t

    val query_random_peers
      : t
      -> int
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t List.t
  end

module Make (Message : sig type t [@@deriving bin_io] end) = struct

  type t = 
    { timeout : Time.Span.t
    ; target_peer_count : int
    ; new_peer_reader : Peer.t Linear_pipe.Reader.t
    ; broadcast_writer : Message.t Linear_pipe.Writer.t
    ; received_reader : Message.t Linear_pipe.Reader.t
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

  let broadcast_rpc = 
    Rpc.One_way.create 
      ~name:"broadcast" 
      ~version:1
      ~bin_msg:Message.bin_t 
  ;;

  let broadcast_selected timeout peers msg =
    let send peer = 
      try_with (fun () ->
        Tcp.with_connection
          (Tcp.Where_to_connect.of_host_and_port peer)
          ~timeout:timeout
          (fun _ r w ->
             match%map Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
             | Error exn -> Or_error.error_string (Exn.to_string exn)
             | Ok conn -> Rpc.One_way.dispatch broadcast_rpc conn msg)
      ) >>| function
      | Ok Ok result -> Ok result
      | Ok Error exn -> Error exn
      | Error exn -> Or_error.of_exn exn
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
      Rpc.Implementations.add_exn 
        implementations 
        (Rpc.One_way.implement broadcast_rpc (fun () m -> 
          Linear_pipe.write_or_drop
            ~capacity:broadcast_received_capacity 
            received_writer received_reader m
        ))
    in
    don't_wait_for begin
      Linear_pipe.iter_unordered ~max_concurrency:64 peer_events ~f:(fun p -> 
        printf "got peer %s\n" (Sexp.to_string_hum ([%sexp_of: Peer.Event.t] p));
        match p with
        | Connect peers -> 
          List.iter peers ~f:(fun peer -> Hash_set.add t.peers peer); return ()
        | Disconnect peers -> 
          List.iter peers ~f:(fun peer -> Hash_set.remove t.peers peer); return ()
      )
    end;
    ignore begin
      Tcp.Server.create 
        ~on_handler_error:(`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
        (Tcp.Where_to_listen.create 
           ~socket_type:Socket.Type.tcp 
           ~address:(`Inet (Unix.Inet_addr.of_string (Host_and_port.host params.address), Host_and_port.port params.address))
           ~listening_on:(fun x -> Fn.id))
        (fun address reader writer -> 
           Rpc.Connection.server_with_close 
             reader writer
             ~implementations
             ~connection_state:(fun _ -> ())
             ~on_handshake_error:
               (`Call (fun exn -> 
                  eprintf "%s\n" (Exn.to_string_mach exn);
                return ())))
    end;
    t

  let received t = t.received_reader

  let broadcast t = t.broadcast_writer

  let new_peers t = t.new_peer_reader

  let broadcast_all t msg = 
    let to_broadcast = ref (List.permute (Hash_set.to_list t.peers)) in
    fun () -> 
      let selected = List.take !to_broadcast t.target_peer_count in
      to_broadcast := List.drop !to_broadcast t.target_peer_count;
      let%map () = broadcast_selected t.timeout selected msg in
      List.length !to_broadcast = 0

  let query_peer t (peer : Peer.t) rpc query = 
    try_with (fun () ->
      Tcp.with_connection
        (Tcp.Where_to_connect.of_host_and_port peer)
        ~timeout:t.timeout
        (fun _ r w ->
           match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
           | Error exn -> return (Or_error.of_exn exn)
           | Ok conn -> Rpc.Rpc.dispatch rpc conn query)
    ) >>| function
    | Ok Ok result -> Ok result
    | Ok Error exn -> Error exn
    | Error exn -> Or_error.of_exn exn

  let query_random_peers t n rpc query = 
    let peers = random_sublist (Hash_set.to_list t.peers) n in
    List.map peers ~f:(fun peer -> query_peer t peer rpc query)
end
