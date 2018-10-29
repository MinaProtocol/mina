open Core
open Async
open Kademlia
module Membership = Membership.Haskell

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module type Message_intf = sig
  type msg

  include
    Versioned_rpc.Both_convert.One_way.S
    with type callee_msg := msg
     and type caller_msg := msg
end

module type Config_intf = sig
  type t =
    { timeout: Time.Span.t
    ; target_peer_count: int
    ; initial_peers: Host_and_port.t list
    ; me: Peer.t
    ; conf_dir: string
    ; parent_log: Logger.t
    ; banlist: Coda_base.Banlist.t }
  [@@deriving make]
end

module type S = sig
  type msg

  type t

  module Config : Config_intf

  val create : Config.t -> unit Rpc.Implementation.t list -> t Deferred.t

  val received : t -> msg Linear_pipe.Reader.t

  val broadcast : t -> msg Linear_pipe.Writer.t

  val broadcast_all :
    t -> msg -> (unit -> [`Done | `Continue] Deferred.t) Staged.t

  val random_peers : t -> int -> Peer.t list

  val random_peers_except : t -> int -> except:Peer.Hash_set.t -> Peer.t list

  val peers : t -> Peer.t list

  val query_peer :
    t -> Peer.t -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t

  val query_random_peers :
    t -> int -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t List.t
end

module Make (Message : Message_intf) : S with type msg := Message.msg = struct
  type t =
    { timeout: Time.Span.t
    ; log: Logger.t
    ; target_peer_count: int
    ; broadcast_writer: Message.msg Linear_pipe.Writer.t
    ; received_reader: Message.msg Linear_pipe.Reader.t
    ; peers: Peer.Hash_set.t }

  module Config = struct
    type t =
      { timeout: Time.Span.t
      ; target_peer_count: int
      ; initial_peers: Host_and_port.t list
      ; me: Peer.t
      ; conf_dir: string
      ; parent_log: Logger.t
      ; banlist: Coda_base.Banlist.t }
    [@@deriving make]
  end

  (* OPTIMIZATION: use fast n choose k implementation - see python or old flow code *)
  let random_sublist xs n = List.take (List.permute xs) n

  let create_connection_with_menu r w =
    match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
    | Error exn -> return (Or_error.of_exn exn)
    | Ok conn -> Versioned_rpc.Connection_with_menu.create conn

  let try_call_rpc peer timeout dispatch query =
    try_with (fun () ->
        Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port peer)
          ~timeout (fun _ r w ->
            create_connection_with_menu r w
            >>=? fun conn -> dispatch conn query ) )
    >>| function
    | Ok (Ok result) -> Ok result
    | Ok (Error exn) -> Error exn
    | Error exn -> Or_error.of_exn exn

  let broadcast_selected t peers msg =
    let peers = List.map peers ~f:(fun peer -> Peer.external_rpc peer) in
    let send peer =
      try_call_rpc peer t.timeout
        (fun conn m -> return (Message.dispatch_multi conn m))
        msg
    in
    Deferred.List.iter ~how:`Parallel peers ~f:(fun p ->
        match%map send p with
        | Ok () -> ()
        | Error e -> Logger.error t.log "%s" (Error.to_string_hum e) )

  let broadcast_random t n msg =
    let selected_peers = random_sublist (Hash_set.to_list t.peers) n in
    broadcast_selected t selected_peers msg

  let create (config : Config.t) implementations =
    let log = Logger.child config.parent_log __MODULE__ in
    let%map membership =
      match%map
        Membership.connect ~initial_peers:config.initial_peers ~me:config.me
          ~conf_dir:config.conf_dir ~parent_log:log ~banlist:config.banlist
      with
      | Ok membership -> membership
      | Error e ->
          failwith
            (Printf.sprintf "Failed to connect to kademlia process: %s\n"
               (Error.to_string_hum e))
    in
    let peer_events = Membership.changes membership in
    let broadcast_reader, broadcast_writer = Linear_pipe.create () in
    let received_reader, received_writer = Linear_pipe.create () in
    let t =
      { timeout= config.timeout
      ; log
      ; target_peer_count= config.target_peer_count
      ; broadcast_writer
      ; received_reader
      ; peers= Peer.Hash_set.create () }
    in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:64 broadcast_reader
         ~f:(fun m ->
           Logger.trace log "broadcasting message" ;
           broadcast_random t t.target_peer_count m )) ;
    let broadcast_received_capacity = 64 in
    let implementations =
      let implementations =
        Versioned_rpc.Menu.add
          ( Message.implement_multi (fun () ~version:_ msg ->
                Linear_pipe.force_write_maybe_drop_head
                  ~capacity:broadcast_received_capacity received_writer
                  received_reader msg )
          @ implementations )
      in
      Rpc.Implementations.create_exn ~implementations
        ~on_unknown_rpc:`Close_connection
    in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:64 peer_events ~f:(function
        | Connect peers ->
            Logger.info log "Some peers connected %s"
              (List.sexp_of_t Peer.sexp_of_t peers |> Sexp.to_string_hum) ;
            List.iter peers ~f:(fun peer -> Hash_set.add t.peers peer) ;
            Deferred.unit
        | Disconnect peers ->
            Logger.info log "Some peers disconnected %s"
              (List.sexp_of_t Peer.sexp_of_t peers |> Sexp.to_string_hum) ;
            List.iter peers ~f:(fun peer -> Hash_set.remove t.peers peer) ;
            Deferred.unit )) ;
    ignore
      (Tcp.Server.create
         ~on_handler_error:
           (`Call
             (fun _ exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
         (Tcp.Where_to_listen.of_port (snd config.me))
         (fun _ reader writer ->
           Rpc.Connection.server_with_close reader writer ~implementations
             ~connection_state:(fun _ -> ())
             ~on_handshake_error:
               (`Call
                 (fun exn ->
                   Logger.error log "%s" (Exn.to_string_mach exn) ;
                   Deferred.unit )) )) ;
    t

  let received t = t.received_reader

  let broadcast t = t.broadcast_writer

  let peers t = Hash_set.to_list t.peers

  let broadcast_all t msg =
    let to_broadcast = ref (List.permute (Hash_set.to_list t.peers)) in
    stage (fun () ->
        let selected = List.take !to_broadcast t.target_peer_count in
        to_broadcast := List.drop !to_broadcast t.target_peer_count ;
        let%map () = broadcast_selected t selected msg in
        if List.length !to_broadcast = 0 then `Done else `Continue )

  let random_peers t n = random_sublist (Hash_set.to_list t.peers) n

  let random_peers_except t n ~(except : Peer.Hash_set.t) =
    let new_peers = Hash_set.(diff t.peers except |> to_list) in
    random_sublist new_peers n

  let query_peer t (peer : Peer.t) rpc query =
    Logger.trace t.log !"Querying peer %{sexp: Peer.t}" peer ;
    let peer = Peer.external_rpc peer in
    try_call_rpc peer t.timeout rpc query

  let query_random_peers t n rpc query =
    let peers = random_sublist (Hash_set.to_list t.peers) n in
    Logger.trace t.log !"Querying random peers: %{sexp: Peer.t list}" peers ;
    List.map peers ~f:(fun peer -> query_peer t peer rpc query)
end
