[%%import
"../../config.mlh"]

open Core
open Async
open Pipe_lib
open Network_peer
open Kademlia
open O1trace
module Membership = Membership.Haskell

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module type Message_intf = sig
  type msg [@@deriving to_yojson]

  include
    Versioned_rpc.Both_convert.One_way.S
    with type callee_msg := msg
     and type caller_msg := msg

  val summary : msg -> string
end

module type Config_intf = sig
  type t =
    { timeout: Time.Span.t
    ; target_peer_count: int
    ; initial_peers: Host_and_port.t list
    ; addrs_and_ports: Kademlia.Node_addrs_and_ports.t
    ; conf_dir: string
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; max_concurrent_connections: int option }
  [@@deriving make]
end

module type S = sig
  type msg

  module Connection_with_state : sig
    type t = Banned | Allowed of Rpc.Connection.t Ivar.t
  end

  type t =
    { timeout: Time.Span.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; tcp_server: (Socket.Address.Inet.t, int) Tcp.Server.t option
    ; membership: Membership.t
    ; target_peer_count: int
    ; broadcast_writer: msg Linear_pipe.Writer.t
    ; received_reader: msg Envelope.Incoming.t Strict_pipe.Reader.t
    ; addrs_and_ports: Kademlia.Node_addrs_and_ports.t
    ; initial_peers: Host_and_port.t list
    ; peers: Peer.Hash_set.t
    ; peers_by_ip: (Unix.Inet_addr.t, Peer.t list) Hashtbl.t
    ; connections:
        ( Unix.Inet_addr.t
        , (Uuid.t, Connection_with_state.t) Hashtbl.t )
        Hashtbl.t
    ; max_concurrent_connections: int option }

  module Config : Config_intf

  val create :
    Config.t -> Host_and_port.t Rpc.Implementation.t list -> t Deferred.t

  val received : t -> msg Envelope.Incoming.t Strict_pipe.Reader.t

  val broadcast : t -> msg Linear_pipe.Writer.t

  val broadcast_all :
    t -> msg -> (unit -> [`Done | `Continue] Deferred.t) Staged.t

  val random_peers : t -> int -> Peer.t list

  val random_peers_except : t -> int -> except:Peer.Hash_set.t -> Peer.t list

  val peers : t -> Peer.t list

  val initial_peers : t -> Host_and_port.t list

  val query_peer :
    t -> Peer.t -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t

  val query_random_peers :
    t -> int -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t List.t

  val shutdown : t -> unit Deferred.t

  module For_tests : sig
    val induce_handshake_error : bool ref
  end
end

module Make (Message : Message_intf) : S with type msg := Message.msg = struct
  module Connection_with_state = struct
    type t = Banned | Allowed of Rpc.Connection.t Ivar.t

    let value_map ~when_allowed ~when_banned t =
      match t with Allowed c -> when_allowed c | _ -> when_banned
  end

  type t =
    { timeout: Time.Span.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; tcp_server: (Socket.Address.Inet.t, int) Tcp.Server.t option
    ; membership: Membership.t
    ; target_peer_count: int
    ; broadcast_writer: Message.msg Linear_pipe.Writer.t
    ; received_reader: Message.msg Envelope.Incoming.t Strict_pipe.Reader.t
    ; addrs_and_ports: Kademlia.Node_addrs_and_ports.t
    ; initial_peers: Host_and_port.t list
    ; peers: Peer.Hash_set.t
    ; peers_by_ip: (Unix.Inet_addr.t, Peer.t list) Hashtbl.t
    ; connections:
        ( Unix.Inet_addr.t
        , (Uuid.t, Connection_with_state.t) Hashtbl.t )
        Hashtbl.t
          (**mapping a Uuid to a connection to be able to remove it from the hash
         *table since Rpc.Connection.t doesn't have the socket information*)
    ; max_concurrent_connections: int option
          (* maximum number of concurrent connections from an ip (infinite if None)*)
    }

  let shutdown t =
    Deferred.all
      [ Membership.stop t.membership
      ; Option.value_map ~default:Deferred.unit
          ~f:(Tcp.Server.close ~close_existing_connections:true)
          t.tcp_server ]
    >>| Fn.const ()

  module Config = struct
    type t =
      { timeout: Time.Span.t
      ; target_peer_count: int
      ; initial_peers: Host_and_port.t list
      ; addrs_and_ports: Kademlia.Node_addrs_and_ports.t
      ; conf_dir: string
      ; logger: Logger.t
      ; trust_system: Trust_system.t
      ; max_concurrent_connections: int option }
    [@@deriving make]
  end

  (* OPTIMIZATION: use fast n choose k implementation - see python or old flow code *)
  let random_sublist xs n = List.take (List.permute xs) n

  let create_connection_with_menu peer r w =
    match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> peer) with
    | Error exn ->
        return (Or_error.of_exn exn)
    | Ok conn ->
        Versioned_rpc.Connection_with_menu.create conn

  (* remove peer from set of peers and peers_by_ip

     there are issues with this simple approach, because
     Kademlia is not informed when peers are removed, so:

     - the node may not be informed when a peer reconnects, so the
        peer won't be re-added to the peer set
     - Kademlia may propagate information about the removed peers
        other nodes
  *)
  let remove_peer t peer =
    Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
      !"Removing peer from peer set: %{sexp: Peer.t}"
      peer ;
    Hash_set.remove t.peers peer ;
    Hashtbl.update t.peers_by_ip peer.host ~f:(function
      | None ->
          failwith "Peer to remove doesn't appear in peers_by_ip"
      | Some ip_peers ->
          List.filter ip_peers ~f:(fun ip_peer -> not (Peer.equal ip_peer peer)) )

  let is_unix_errno errno unix_errno =
    Int.equal (Unix.Error.compare errno unix_errno) 0

  (* Create a socket bound to the correct IP, for outgoing connections. *)
  let get_socket t =
    let socket = Async.Socket.(create Type.tcp) in
    (* Binding with a source port of 0 tells the kernel to pick a free one for
       us. Because we're binding an address and port before the kernel knows
       whether this will be a listen socket or an outgoing socket, it won't
       allocate the same source port twice, even when the destination IP will be
       different. So we could in very extreme cases run out of ephemeral ports.
       The IP_BIND_ADDRESS_NO_PORT socket option informs the kernel we're
       binding the socket to an IP and intending to make an outgoing connection,
       but it only works on Linux. I think we don't need to worry about it,
       there are a lot of ephemeral ports and we don't make very many
       simultaneous connections.
    *)
    Async.Socket.bind_inet socket @@ `Inet (t.addrs_and_ports.bind_ip, 0)

  let try_call_rpc t (peer : Peer.t) dispatch query =
    (* use error collection, close connection strategy of Tcp.with_connection *)
    let collect_errors writer f =
      let monitor = Writer.monitor writer in
      ignore (Monitor.detach_and_get_error_stream monitor) ;
      choose
        [ choice (Monitor.get_next_error monitor) (fun e -> Error e)
        ; choice (try_with ~name:"Tcp.collect_errors" f) Fn.id ]
    in
    let close_connection reader writer =
      Writer.close writer ~force_close:(Clock.after (sec 30.))
      >>= fun () -> Reader.close reader
    in
    let call () =
      try_with (fun () ->
          let socket = get_socket t in
          let peer_addr = `Inet (peer.host, peer.communication_port) in
          let%bind connected_socket = Async.Socket.connect socket peer_addr in
          let reader, writer =
            let fd = Socket.fd connected_socket in
            (Reader.create fd, Writer.create fd)
          in
          let run_query () =
            create_connection_with_menu peer reader writer
            >>=? fun conn -> dispatch conn query
          in
          let result = collect_errors writer run_query in
          Deferred.any
            [ (result >>| fun (_ : ('a, exn) Result.t) -> ())
            ; Reader.close_finished reader
            ; Writer.close_finished writer ]
          >>= fun () ->
          close_connection reader writer
          >>= fun () -> result >>| function Ok v -> v | Error e -> raise e )
      >>= function
      | Ok (Ok result) ->
          (* call succeeded, result is valid *)
          return (Ok result)
      | Ok (Error err) -> (
          (* call succeeded, result is an error *)
          Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
            !"RPC call error: %s {{{%s}}} [[[%{sexp: Error.t}]]]"
            (Exn.to_string (Error.to_exn err))
            (Exn.to_string_mach (Error.to_exn err))
            err ;
          match (Error.to_exn err, Error.sexp_of_t err) with
          | ( _
            , Sexp.List
                [ Sexp.Atom "src/connection.ml.Handshake_error.Handshake_error"
                ; _ ] ) ->
              let%map () =
                Trust_system.(
                  record t.trust_system t.logger peer.host
                    Actions.
                      (Outgoing_connection_error, Some ("handshake error", [])))
              in
              remove_peer t peer ; Error err
          | ( _
            , Sexp.List
                [ Sexp.List
                    [ Sexp.Atom "rpc_error"
                    ; Sexp.List [Sexp.Atom "Connection_closed"; _] ]
                ; _connection_description
                ; _rpc_tag
                ; _rpc_version ] ) ->
              let%map () =
                Trust_system.(
                  record t.trust_system t.logger peer.host
                    Actions.
                      ( Outgoing_connection_error
                      , Some ("Closed connection", []) ))
              in
              remove_peer t peer ; Error err
          | _ ->
              let%map () =
                Trust_system.(
                  record t.trust_system t.logger peer.host
                    Actions.
                      ( Violated_protocol
                      , Some
                          ( "RPC call failed, reason: $exn"
                          , [("exn", `String (Error.to_string_hum err))] ) ))
              in
              remove_peer t peer ; Error err )
      | Error monitor_exn -> (
          (* call itself failed *)
          (* TODO: learn what other exceptions are raised here *)
          let exn = Monitor.extract_exn monitor_exn in
          match exn with
          | Unix.Unix_error (errno, _, _)
            when is_unix_errno errno Unix.ECONNREFUSED ->
              let%map () =
                Trust_system.(
                  record t.trust_system t.logger peer.host
                    Actions.
                      ( Outgoing_connection_error
                      , Some ("Connection refused", []) ))
              in
              remove_peer t peer ; Or_error.of_exn exn
          | _ ->
              Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
                "RPC call raised an exception: %s" (Exn.to_string exn) ;
              return (Or_error.of_exn exn) )
    in
    match Hashtbl.find t.connections peer.host with
    | None ->
        call ()
    | Some conn_map ->
        if
          Option.is_some t.max_concurrent_connections
          && Hashtbl.length conn_map
             >= Option.value_exn t.max_concurrent_connections
        then
          Deferred.return
            (Or_error.errorf
               !"Not connecting to peer %{sexp:Peer.t}. Number of open \
                 connections to the peer equals the limit %d.\n"
               peer
               (Option.value_exn t.max_concurrent_connections))
        else call ()

  let broadcast_selected t peers msg =
    let send peer =
      try_call_rpc t peer
        (fun conn m -> return (Message.dispatch_multi conn m))
        msg
    in
    trace_event "broadcasting message" ;
    Deferred.List.iter ~how:`Parallel peers ~f:(fun peer ->
        match%map send peer with
        | Ok () ->
            ()
        | Error e ->
            Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
              "broadcasting $short_msg to $peer failed: %s"
              ~metadata:
                [ ("short_msg", `String (Message.summary msg))
                ; ("msg", Message.msg_to_yojson msg)
                ; ("peer", Peer.to_yojson peer) ]
              (Error.to_string_hum e) )

  let broadcast_random t n msg =
    let selected_peers = random_sublist (Hash_set.to_list t.peers) n in
    broadcast_selected t selected_peers msg

  module For_tests = struct
    let induce_handshake_error = ref false
  end

  let create (config : Config.t)
      (implementation_list : Host_and_port.t Rpc.Implementation.t list) =
    trace_task "gossip net" (fun () ->
        let%bind membership =
          match%map
            trace_task "membership" (fun () ->
                Membership.connect ~initial_peers:config.initial_peers
                  ~node_addrs_and_ports:config.addrs_and_ports
                  ~conf_dir:config.conf_dir ~logger:config.logger
                  ~trust_system:config.trust_system )
          with
          | Ok membership ->
              membership
          | Error e ->
              failwith
                (Printf.sprintf "Failed to connect to kademlia process: %s\n"
                   (Error.to_string_hum e))
        in
        let peer_events = Membership.changes membership in
        let broadcast_reader, broadcast_writer = Linear_pipe.create () in
        let received_reader, received_writer =
          Strict_pipe.create ~name:"received gossip messages"
            (Buffered (`Capacity 64, `Overflow Crash))
        in
        let t =
          { timeout= config.timeout
          ; logger= config.logger
          ; trust_system= config.trust_system
          ; tcp_server= None
          ; membership
          ; target_peer_count= config.target_peer_count
          ; broadcast_writer
          ; received_reader
          ; addrs_and_ports= config.addrs_and_ports
          ; peers= Peer.Hash_set.create ()
          ; initial_peers= config.initial_peers
          ; peers_by_ip= Hashtbl.create (module Unix.Inet_addr)
          ; connections= Hashtbl.create (module Unix.Inet_addr)
          ; max_concurrent_connections= config.max_concurrent_connections }
        in
        don't_wait_for
          (Strict_pipe.Reader.iter (Trust_system.ban_pipe config.trust_system)
             ~f:(fun addr ->
               match Hashtbl.find t.connections addr with
               | None ->
                   Deferred.unit
               | Some conn_tbl ->
                   Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                     !"Peer %{sexp: Unix.Inet_addr.t} banned, disconnecting."
                     addr ;
                   let%map () =
                     Deferred.List.iter (Hashtbl.to_alist conn_tbl)
                       ~f:(fun (_, conn_state) ->
                         Connection_with_state.value_map conn_state
                           ~when_allowed:(fun conn_ivar ->
                             let%bind conn = Ivar.read conn_ivar in
                             Rpc.Connection.close conn )
                           ~when_banned:Deferred.unit )
                   in
                   Hashtbl.map_inplace conn_tbl ~f:(fun conn_state ->
                       Connection_with_state.value_map conn_state
                         ~when_allowed:(fun _ -> Connection_with_state.Banned)
                         ~when_banned:Banned ) )) ;
        trace_task "rebroadcasting messages" (fun () ->
            don't_wait_for
              (Linear_pipe.iter_unordered ~max_concurrency:64 broadcast_reader
                 ~f:(fun m ->
                   Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
                     "broadcasting message" ;
                   broadcast_random t t.target_peer_count m )) ) ;
        let implementations =
          let implementations =
            Versioned_rpc.Menu.add
              ( Message.implement_multi
                  (fun client_host_and_port ~version:_ msg ->
                    (* wrap received message in envelope *)
                    let sender =
                      Envelope.Sender.Remote
                        (Unix.Inet_addr.of_string
                           client_host_and_port.Host_and_port.host)
                    in
                    Strict_pipe.Writer.write received_writer
                      (Envelope.Incoming.wrap ~data:msg ~sender) )
              @ implementation_list )
          in
          let handle_unknown_rpc conn ~rpc_tag ~version =
            let inet_addr = Unix.Inet_addr.of_string conn.Host_and_port.host in
            Deferred.don't_wait_for
              Trust_system.(
                record t.trust_system t.logger inet_addr
                  Actions.
                    ( Violated_protocol
                    , Some
                        ( "Attempt to make unknown (fixed-version) RPC call \
                           \"$rpc\" with version $version"
                        , [("rpc", `String rpc_tag); ("version", `Int version)]
                        ) )) ;
            `Close_connection
          in
          Rpc.Implementations.create_exn ~implementations
            ~on_unknown_rpc:(`Call handle_unknown_rpc)
        in
        trace_task "peer events" (fun () ->
            Linear_pipe.iter_unordered ~max_concurrency:64 peer_events
              ~f:(function
              | Connect peers ->
                  Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                    "Some peers connected %s"
                    (List.sexp_of_t Peer.sexp_of_t peers |> Sexp.to_string_hum) ;
                  List.iter peers ~f:(fun peer ->
                      Hash_set.add t.peers peer ;
                      Hashtbl.add_multi t.peers_by_ip ~key:peer.host ~data:peer
                  ) ;
                  Deferred.unit
              | Disconnect peers ->
                  Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                    "Some peers disconnected %s"
                    (List.sexp_of_t Peer.sexp_of_t peers |> Sexp.to_string_hum) ;
                  List.iter peers ~f:(remove_peer t) ;
                  Deferred.unit )
            |> ignore ) ;
        let%map tcp_server =
          Tcp.Server.create
            ~on_handler_error:
              (`Call
                (fun _ exn ->
                  Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
                    "%s" (Exn.to_string_mach exn) ;
                  raise exn ))
            Tcp.(
              Where_to_listen.bind_to
                (Bind_to_address.Address t.addrs_and_ports.bind_ip)
                (Bind_to_port.On_port t.addrs_and_ports.communication_port))
            (fun client reader writer ->
              if !For_tests.induce_handshake_error then
                let%bind () = Writer.close writer in
                Reader.close reader
              else
                let client_inet_addr = Socket.Address.Inet.addr client in
                let%bind () =
                  Trust_system.(
                    record t.trust_system t.logger client_inet_addr
                      Actions.(Connected, None))
                in
                let conn_map =
                  Option.value_map
                    ~default:(Hashtbl.create (module Uuid))
                    (Hashtbl.find t.connections client_inet_addr)
                    ~f:Fn.id
                in
                let is_client_banned =
                  let peer_status =
                    Trust_system.Peer_trust.lookup t.trust_system
                      client_inet_addr
                  in
                  match peer_status.banned with
                  | Banned_until _ ->
                      true
                  | Unbanned ->
                      false
                in
                if is_client_banned then (
                  Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                    "Rejecting connection from banned peer %s"
                    (Socket.Address.Inet.to_string client) ;
                  Reader.close reader >>= fun _ -> Writer.close writer )
                else if
                  Option.is_some t.max_concurrent_connections
                  && Hashtbl.length conn_map
                     >= Option.value_exn t.max_concurrent_connections
                then (
                  Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
                    "Cannot open another connection. Number of open \
                     connections from %s equals the limit %d."
                    (Socket.Address.Inet.to_string client)
                    (Option.value_exn t.max_concurrent_connections) ;
                  Reader.close reader >>= fun _ -> Writer.close writer )
                else
                  let conn_id = Uuid_unix.create () in
                  Hashtbl.add_exn conn_map ~key:conn_id
                    ~data:(Allowed (Ivar.create ())) ;
                  Hashtbl.set t.connections ~key:client_inet_addr
                    ~data:conn_map ;
                  let%map () =
                    Rpc.Connection.server_with_close reader writer
                      ~implementations
                      ~connection_state:(fun conn ->
                        (* connection state is the client's IP and ephemeral port
                        when connecting to the server over TCP; the ephemeral
                        port is distinct from the client's discovery and
                        communication ports *)
                        Connection_with_state.value_map
                          (Hashtbl.find_exn conn_map conn_id)
                          ~when_allowed:(fun ivar -> Ivar.fill ivar conn)
                          ~when_banned:() ;
                        Hashtbl.set t.connections
                          ~key:(Socket.Address.Inet.addr client)
                          ~data:conn_map ;
                        Socket.Address.Inet.to_host_and_port client )
                      ~on_handshake_error:
                        (`Call
                          (fun exn ->
                            Trust_system.(
                              record t.trust_system t.logger client_inet_addr
                                Actions.
                                  ( Incoming_connection_error
                                  , Some
                                      ( "Handshake error: $exn"
                                      , [("exn", `String (Exn.to_string exn))]
                                      ) )) ))
                  in
                  let conn_map =
                    Hashtbl.find_exn t.connections client_inet_addr
                  in
                  Hashtbl.remove conn_map conn_id ;
                  if Hashtbl.is_empty conn_map then
                    Hashtbl.remove t.connections client_inet_addr
                  else
                    Hashtbl.set t.connections ~key:client_inet_addr
                      ~data:conn_map )
        in
        {t with tcp_server= Some tcp_server} )

  let received t = t.received_reader

  let broadcast t = t.broadcast_writer

  let peers t = Hash_set.to_list t.peers

  let initial_peers t = t.initial_peers

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
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      !"Querying peer %{sexp: Peer.t}"
      peer ;
    try_call_rpc t peer rpc query

  let query_random_peers t n rpc query =
    let peers = random_peers t n in
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      !"Querying random peers: %{sexp: Peer.t list}"
      peers ;
    List.map peers ~f:(fun peer -> query_peer t peer rpc query)
end

let%test_module "edge cases trust actions test" =
  (* These tests exercise a variety of RPC edge cases, ensuring they generate the trust system actions that we expect. See each test for more details. *)
  ( module struct
    open Trust_system.Actions

    (* First, the boilerplate... *)
    module Message = struct
      module T = struct
        type msg = string [@@deriving to_yojson]

        let summary s = s
      end

      include T

      include Versioned_rpc.Both_convert.One_way.Make (struct
        include T
        module Caller = T
        module Callee = T

        let name = "message"
      end)
    end

    let () = Backtrace.elide := false

    let () = Async.Scheduler.set_record_backtraces true

    module Gossip_net = Make (Message)

    let make_peer n =
      let discovery_port = 23000 + (2 * n) in
      let communication_port = discovery_port + 1 in
      Kademlia.Node_addrs_and_ports.
        { external_ip= Unix.Inet_addr.localhost
        ; bind_ip= Unix.Inet_addr.localhost
        ; discovery_port
        ; communication_port }

    let logger = Logger.create ()

    let make_config n tmpdir initial_peers =
      let our_dir = tmpdir ^/ sprintf "node_%d" n in
      let ts_db = our_dir ^/ "trust_system" in
      let%map () = Unix.mkdir ~p:() ts_db in
      let addrs_and_ports = make_peer n in
      { Gossip_net.Config.timeout= Time.Span.of_min 5.
      ; target_peer_count= 8
      ; initial_peers
      ; addrs_and_ports
      ; conf_dir= tmpdir ^/ sprintf "node_%d" n
      ; logger= Logger.extend logger [("node", `Int n)]
      ; trust_system= Trust_system.create ~db_dir:ts_db
      ; max_concurrent_connections= None }

    (* This gets used to wait for the RPC to be in progress before shutting down the receiver. *)
    let blocking_rpc_called = Ivar.create ()

    let ping_rpc =
      Rpc.Rpc.create ~name:"ping" ~version:0
        ~bin_query:Bin_prot.Type_class.bin_unit
        ~bin_response:Bin_prot.Type_class.bin_unit

    (* Normal implementation of Ping: replies with a unit *)
    let rpcs = [Rpc.Rpc.implement ping_rpc (fun _ () -> return ())]

    (* Faulty implementation of Ping: the RPC handler throws an exception  *)
    let faulty_rpc =
      [ Rpc.Rpc.implement ping_rpc (fun _ () ->
            raise (Failure "failed on purpose") ) ]

    (* Blocking implementation of Ping: never responds. This gives us a
    chance to close the connection prematurely while the RPC data is
    transfering, but after the handshake. *)
    let blocking_rpc =
      [ Rpc.Rpc.implement ping_rpc (fun _ () ->
            Ivar.fill blocking_rpc_called () ;
            Deferred.never () ) ]

    let dispatch_ping vcm =
      Rpc.Rpc.dispatch ping_rpc
        (Versioned_rpc.Connection_with_menu.connection vcm)

    let teardown gns =
      Deferred.List.all_unit (List.map gns ~f:Gossip_net.shutdown)

    let config_to_peer (c : Gossip_net.Config.t) =
      Kademlia.Node_addrs_and_ports.to_peer c.addrs_and_ports

    let config_to_hp c = Peer.to_discovery_host_and_port (config_to_peer c)

    (* Read events from [action_pipe] and make sure they match [expected].
       This will NOT ensure they are the only actions! *)
    let expect_actions
        (action_pipe : (Trust_system.Actions.t * _) Pipe.Reader.t)
        ~(expected : Trust_system.Actions.action list) =
      match%map
        Pipe.read_exactly action_pipe ~num_values:(List.length expected)
      with
      | `Eof ->
          failwith "out of trust actions?"
      | `Fewer _ ->
          failwith "not enough trust actions in the pipe"
      | `Exactly action_queue ->
          let actual = Queue.to_list action_queue in
          List.map2_exn actual expected
            ~f:(fun ((actual_action, _), _) expected_action ->
              [%test_eq: Trust_system.Actions.action] actual_action
                expected_action )
          |> ignore

    let%test_unit "success" =
      (* Simple RPC should succeed, and generate a Connected event on the receiver *)
      let x : unit Deferred.t =
        File_system.with_temp_dir
          ~f:(fun tmpdir ->
            let%bind one_config = make_config 1 tmpdir [] in
            let%bind two_config =
              make_config 2 tmpdir [config_to_hp one_config]
            in
            let one_ts_pipe =
              Trust_system.For_tests.get_action_pipe one_config.trust_system
              |> Pipe.map ~f:(fun (a, ip) ->
                     let s, md = Trust_system.Actions.to_log a in
                     Logger.info logger "%s" s ~metadata:md ~location:__LOC__
                       ~module_:__MODULE__ ;
                     (a, ip) )
            in
            let%bind one = Gossip_net.create one_config rpcs in
            let%bind two = Gossip_net.create two_config rpcs in
            let%bind () = after (Time.Span.of_ms 500.) in
            let%bind res =
              Gossip_net.query_peer two
                (config_to_peer one_config)
                dispatch_ping ()
            in
            ( match res with
            | Ok _ ->
                ()
            | Error _ ->
                failwith "Should have succeeded!" ) ;
            let%bind () = expect_actions one_ts_pipe ~expected:[Connected] in
            teardown [one; two] )
          "gossip_net_test"
      in
      Async.Thread_safe.block_on_async_exn (fun () -> x)

    let%test_unit "connection closed" =
      (* This uses the blocking_rpc to hang the RPC, and shuts down the TCP server. *)
      let x : unit Deferred.t =
        File_system.with_temp_dir
          ~f:(fun tmpdir ->
            let%bind one_config = make_config 1 tmpdir [] in
            let%bind two_config =
              make_config 2 tmpdir [config_to_hp one_config]
            in
            let two_ts_pipe =
              Trust_system.For_tests.get_action_pipe two_config.trust_system
            in
            let%bind one = Gossip_net.create one_config blocking_rpc in
            let%bind two = Gossip_net.create two_config rpcs in
            let%bind () = after (Time.Span.of_ms 500.) in
            let finished_handling_failure = Ivar.create () in
            let res =
              Gossip_net.query_peer two
                (config_to_peer one_config)
                dispatch_ping ()
            in
            don't_wait_for
              ( match%bind res with
              | Ok _ ->
                  failwith "other peer should have blocked forever"
              | Error _ ->
                  let%map () =
                    expect_actions two_ts_pipe
                      ~expected:[Outgoing_connection_error]
                  in
                  Ivar.fill finished_handling_failure () ) ;
            let%bind () = Ivar.read blocking_rpc_called in
            (* Close the connection *)
            let%bind () = Gossip_net.shutdown one in
            let%bind () = Ivar.read finished_handling_failure in
            Pipe.close_read two_ts_pipe ;
            Gossip_net.shutdown two )
          "gossip_net_test"
      in
      Async.Thread_safe.block_on_async_exn (fun () -> x)

    let%test_unit "handshake" =
      (* This closes the TCP connection on the receiver before passing the reader/writer to RPC.
         The resulting handshake error should result in an Outgoing_connection_error. *)
      let x : unit Deferred.t =
        File_system.with_temp_dir
          ~f:(fun tmpdir ->
            let%bind one_config = make_config 1 tmpdir [] in
            let%bind two_config =
              make_config 2 tmpdir [config_to_hp one_config]
            in
            let two_ts_pipe =
              Trust_system.For_tests.get_action_pipe two_config.trust_system
            in
            let%bind one = Gossip_net.create one_config rpcs in
            Gossip_net.For_tests.induce_handshake_error := true ;
            let%bind two = Gossip_net.create two_config rpcs in
            let%bind () = after (Time.Span.of_ms 500.) in
            let%bind res =
              Gossip_net.query_peer two
                (config_to_peer one_config)
                dispatch_ping ()
            in
            let%bind () =
              match res with
              | Ok _ ->
                  failwith
                    "induce_handshake_error should have prevented success"
              | Error _ ->
                  Gossip_net.For_tests.induce_handshake_error := false ;
                  expect_actions two_ts_pipe
                    ~expected:[Outgoing_connection_error]
            in
            Pipe.close_read two_ts_pipe ;
            teardown [one; two] )
          "gossip_net_test"
      in
      Async.Thread_safe.block_on_async_exn (fun () -> x)

    let%test_unit "rpc failed" =
      (* If the RPC fails, we should get Violated_protocol *)
      let x : unit Deferred.t =
        File_system.with_temp_dir
          ~f:(fun tmpdir ->
            let%bind one_config = make_config 1 tmpdir [] in
            let%bind two_config =
              make_config 2 tmpdir [config_to_hp one_config]
            in
            let two_ts_pipe =
              Trust_system.For_tests.get_action_pipe two_config.trust_system
            in
            let%bind one = Gossip_net.create one_config faulty_rpc in
            let%bind two = Gossip_net.create two_config rpcs in
            let%bind () = after (Time.Span.of_ms 500.) in
            let%bind res =
              Gossip_net.query_peer two
                (config_to_peer one_config)
                dispatch_ping ()
            in
            let%bind () =
              match res with
              | Ok _ ->
                  failwith "faulty_rpc should have failed"
              | Error _ ->
                  expect_actions two_ts_pipe ~expected:[Violated_protocol]
            in
            Pipe.close_read two_ts_pipe ;
            teardown [one; two] )
          "gossip_net_test"
      in
      Async.Thread_safe.block_on_async_exn (fun () -> x)
  end )
