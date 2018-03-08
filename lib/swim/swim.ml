open Core_kernel
open Async_kernel

module Config = struct
  type t =
    { indirect_ping_count : int
    ; protocol_period : Time.Span.t
    (* Round-trip-time *)
    ; round_trip_time : Time.Span.t
    }

  let create ?indirect_ping_count:(indirect_ping_count=6)
    ?expected_latency:(expected_latency=Time.Span.of_ms 500.)
    ()
    =
      let epsilon = Time.Span.of_ms 5. in
      let round_trip_time = Time.Span.(expected_latency + expected_latency) in
      let protocol_period = Time.Span.(round_trip_time + round_trip_time + round_trip_time + epsilon) in
      { indirect_ping_count
      ; protocol_period
      ; round_trip_time
      }

  let indirect_ping_count t = t.indirect_ping_count
  let protocol_period t = t.protocol_period
  let round_trip_time t = t.round_trip_time
end

let udp_packet_size = 8192
;;

module type TestOnly_intf = sig
  val network_partition_add : from:Peer.t -> to_:Peer.t -> unit
  val network_partition_remove : from:Peer.t -> to_:Peer.t -> unit
end

module type S = sig
  type t

  val connect : config:Config.t -> initial_peers:Peer.t list -> me:Peer.t -> t

  val peers : t -> Peer.t list

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit

  val first_peers : t -> Peer.t list Deferred.t

  module TestOnly : TestOnly_intf
end

module Node = struct
  type t =
    { peer : Peer.t
    ; mutable state : [`Dead | `Alive]
    } [@@deriving bin_io, sexp]

  let is_alive t = t.state = `Alive
  let is_dead t = t.state = `Dead

  let alive peer = { peer ; state = `Alive }


  let dead peer = { peer ; state = `Dead }
end

module type Network_state_intf = sig
  type t

  (* A subset of information about the network's live/dead nodes *)
  type slice = Node.t list [@@deriving bin_io, sexp]

  val create : Log.logger -> t

  val add_slice : t -> slice -> unit

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val shuffled_live_nodes : t -> Peer.t Shuffled_sequence.t

  (* Pure getter for live_nodes *)
  val live_nodes : t -> Peer.t Set.Poly.t

  (* Effectfully (mutating t) extracts a slice of the network state
   * maintaining necessary SWIM invariants *)
  val extract : t -> transmit_limit:int -> Peer.t -> slice
end

(* Taken mostly from mirage-swim *)
module Network_state : Network_state_intf = struct
  module E = struct
    type t = Node.t [@@deriving sexp]
    type id = Peer.t

    let invalidates (node : t) (node' : t) : bool =
      node.peer = node'.peer && node.state <> node'.state

    let skip (node : t) peer =
      node.peer = peer

    let size = Node.bin_size_t
  end

  (* This is the collection of node liveness to be sent over the network *)
  type broadcast_list = (int * E.t) list [@@deriving sexp]
  type t =
    { mutable broadcast_list : broadcast_list
    ; mutable live_nodes : Peer.t Set.Poly.t
    ; logger : Log.logger
    ; shuffled_live_nodes : Peer.t Shuffled_sequence.t
    ; changes_reader : Peer.Event.t Linear_pipe.Reader.t
    ; changes_writer : Peer.Event.t Linear_pipe.Writer.t
    }

  type slice = Node.t list [@@deriving bin_io, sexp]

  let shuffled_live_nodes t = t.shuffled_live_nodes

  let create logger : t =
    let (changes_reader, changes_writer) = Linear_pipe.create () in
    { broadcast_list = []
    ; live_nodes = Set.Poly.empty
    ; shuffled_live_nodes = Shuffled_sequence.create (module Peer)
    ; logger
    ; changes_reader
    ; changes_writer
    }

  let update_live t (node : E.t) =
    if node.state = `Alive then begin
      t.live_nodes <- Set.Poly.add t.live_nodes node.peer;
      Shuffled_sequence.add t.shuffled_live_nodes node.peer;
    end else begin
      t.live_nodes <- Set.Poly.remove t.live_nodes node.peer;
      Shuffled_sequence.remove t.shuffled_live_nodes node.peer;
    end

  let add (t : t) (node : E.t) =
    update_live t node;
    if not (List.exists t.broadcast_list ~f:(fun (_, node') -> node = node')) then begin
      let q = List.filter t.broadcast_list ~f:(fun (_, node') -> not (E.invalidates node node')) in
      t.broadcast_list <- ((0, node)::q)
    end

  let push_changes t slice =
    let w = t.changes_writer in
    let (connected, disconnected) =
      slice
      |> List.filter ~f:(fun (node : Node.t) ->
        (* dead information is new information *)
        node.state = `Dead ||
          (* skip over the live nodes in the slice if we already know about them *)
          not (Set.Poly.mem t.live_nodes node.peer)
        )
      |> List.partition_map ~f:(fun (node : Node.t) ->
          match node.state with
          | `Alive -> `Fst node.peer
          | `Dead -> `Snd node.peer
        )
    in
    let%bind () = Pipe.write w (Peer.Event.Disconnect disconnected) in
    Pipe.write w (Peer.Event.Connect connected)

  let add_slice t slice =
    (* We need this iter to be fast so rest of protocol doesn't build up *)
    (* Implicit contract with change pipe consumer to keep up with events *)
    don't_wait_for (
      let%map () = push_changes t slice in
      t.logger#logf Debug "Adding slice %s" (slice |> sexp_of_slice |> Sexp.to_string);
      List.iter slice (add t)
    )

  let live_nodes t = t.live_nodes

  let changes t = t.changes_reader

  let extract (t : t) ~transmit_limit addr =
    let select memo elem =
      let transmit, elems, bytes_left = memo in
      let transmit_count, broadcast = elem in
      let size = E.size broadcast in
      (* If we've sent this info around enough, we can forget about it *)
      if transmit_count > transmit_limit then
        (transmit, elems, bytes_left)
      (* If we're out of bytes, then wait until another round to send the info *)
      else if size > bytes_left || E.skip broadcast addr then
        (transmit, elem::elems, bytes_left)
      else
        (broadcast::transmit, (transmit_count+1, broadcast)::elems, bytes_left - size)
    in
    let transmit, bq', _ = List.fold_left t.broadcast_list ~f:select ~init:([], [], udp_packet_size) in
    t.broadcast_list <- List.sort ~cmp:(fun e e' -> Int.compare (fst e) (fst e')) bq';
    transmit
end

module Request_or_ack = struct
  type 'a t = Ack | Request of 'a [@@deriving bin_io, sexp]
end

module Payload = struct
  type t = Ping | Ping_req of Peer.t [@@deriving bin_io, sexp]
end

module Ack_table = struct
  type t = (int, unit Ivar.t) Hashtbl.t
end

module Messager : sig
  type t
  type msg =
    { from: Peer.t
    ; action: Payload.t Request_or_ack.t
    ; net_slice: Network_state.slice
    ; seq_no: int
    } [@@deriving bin_io, sexp]

  val create : incoming:(msg Linear_pipe.Reader.t)
    -> net_state:Network_state.t
    -> get_transmit_limit:(unit -> int)
    (* to send messages *)
    -> send_msg:(recipient:Peer.t -> msg -> unit Or_error.t Deferred.t)
    (* handle incoming msgs (with seq_no) *)
    -> handle_msg:(t -> Payload.t * int -> [`Stop | `Want_ack] Deferred.t)
    -> me: Peer.t
    -> t

  val send : t -> (Peer.t * Payload.t) list -> seq_no:int -> timeout:Time.Span.t -> [ `Timeout | `Acked ] Deferred.t
end = struct
  type msg =
    { from: Peer.t
    ; action: Payload.t Request_or_ack.t
    ; net_slice: Network_state.slice
    ; seq_no: int
    } [@@deriving bin_io, sexp]

  type t =
    { table : Ack_table.t
    ; net_state : Network_state.t
    ; get_transmit_limit : unit -> int
    ; send_msg : recipient:Peer.t -> msg -> unit Or_error.t Deferred.t
    ; me : Peer.t
    }

  let raw_send t addr action seq_no : _ Or_error.t Deferred.t =
    let open Let_syntax in
    t.send_msg ~recipient:addr
      { from = t.me
      ; action
      ; net_slice = Network_state.extract t.net_state ~transmit_limit:(t.get_transmit_limit ()) addr
      ; seq_no
      }

  let create ~incoming ~net_state ~get_transmit_limit ~send_msg ~handle_msg ~me =
    let table = Hashtbl.Poly.create () in
    let t =
      { table
      ; net_state
      ; get_transmit_limit
      ; send_msg
      ; me
      }
    in

    don't_wait_for begin
      let max_ready = 64 in
      Linear_pipe.iter_unordered ~max_concurrency:max_ready incoming ~f:(fun {from; action; net_slice; seq_no} ->
        let open Let_syntax in
        let open Request_or_ack in

        (* the sender must have been alive *)
        let with_sender : Node.t list = ({peer = from; state = `Alive}::net_slice) in
        Network_state.add_slice net_state with_sender;

        match action with
        | Request x ->
           (match%bind handle_msg t (x, seq_no) with
           | `Stop -> return ()
           | `Want_ack ->
             let%map _ = raw_send t from Ack seq_no in
             ())
        | Ack ->
          Option.iter (Hashtbl.Poly.find t.table seq_no) (fun ivar ->
              Hashtbl.Poly.remove t.table seq_no;
              Ivar.fill_if_empty ivar ()
          );
          return ()
      )
    end;
    t

  let send t msgs ~seq_no ~timeout =
    let open Let_syntax in
    let wait_ack = Deferred.create (fun _ivar ->
      Hashtbl.Poly.set ~key:seq_no t.table ~data:_ivar)
    in
    List.iter msgs (fun (addr, payload) ->
      (* We're implicitly waiting for an ack, so no risk for async pressure *)
      don't_wait_for (
        match%map raw_send t addr (Request_or_ack.Request payload) seq_no with
        | Ok () -> ()
        | Error e -> printf "Failed with err %s" (Error.to_string_hum e)
      );
    );
    match%map Async.with_timeout timeout wait_ack with
    | `Timeout ->
        Hashtbl.Poly.remove t.table seq_no;
        `Timeout
    | `Result () -> `Acked

end

type logger = Log.logger
module type Transport_intf =
  functor (Message : sig type t [@@deriving bin_io, sexp] end) -> sig
    type t

    val create : logger -> port:int -> t

    val send : t -> recipient:Peer.t -> Message.t -> unit Or_error.t Deferred.t
    val listen : t -> Message.t Linear_pipe.Reader.t

    val stop_listening : t -> unit

    module TestOnly: TestOnly_intf
  end

module Fake_transport (Message : sig
  type t [@@deriving bin_io, sexp]
end) = struct
  type network_t =
    { connected : (recipient:Peer.t -> Message.t -> unit Or_error.t Deferred.t) Host_and_port.Table.t
    ; partition_key_to_val : Peer.t list Host_and_port.Table.t
    }

  let network : network_t =
    { connected = Host_and_port.Table.create ()
    ; partition_key_to_val = Host_and_port.Table.create ()
    }

  type t =
    { logger : logger
    ; port : int
    }

  let create logger ~port : t =
    { logger
    ; port
    }

  let me (t : t) =
      Host_and_port.create ~host:"127.0.0.1" ~port:t.port

  let send (t : t) ~recipient msg =
    t.logger#logf Info "Sending a msg %s" (msg |> Message.sexp_of_t |> Sexp.to_string);
    match (
      Host_and_port.Table.find network.partition_key_to_val (me t),
      Host_and_port.Table.find network.connected recipient
    ) with
    | (Some xs, _) when List.mem xs recipient ~equal:Host_and_port.equal -> return (Ok ())
    | (_, None) ->
        t.logger#logf Info "Couldn't send %s" (msg |> Message.sexp_of_t |> Sexp.to_string);
        return (Ok ())
    | (_, Some fn) ->
        t.logger#logf Info "Can send %s" (msg |> Message.sexp_of_t |> Sexp.to_string);
        fn ~recipient msg

  let listen (t: t) : Message.t Linear_pipe.Reader.t =
    let (r,w) = Linear_pipe.create () in
    Host_and_port.Table.add_exn network.connected
      ~key:(me t)
      ~data:(fun ~recipient msg ->
        t.logger#logf Info "Listened to a msg %s" (msg |> Message.sexp_of_t |> Sexp.to_string);
        let%bind () = Pipe.write w msg in
        return (Ok ())
      );
    r

  let stop_listening t =
    Host_and_port.Table.remove network.connected (me t)

  module TestOnly = struct
    let network_partition_add ~from ~to_ =
      match Host_and_port.Table.find network.partition_key_to_val from with
      | Some xs ->
          Host_and_port.Table.remove network.partition_key_to_val from;
          Host_and_port.Table.add_exn network.partition_key_to_val ~key:from ~data:(
            to_::xs
          )
      | None ->
          Host_and_port.Table.add_exn network.partition_key_to_val ~key:from ~data:([to_])

    let network_partition_remove ~from ~to_ =
      match Host_and_port.Table.find network.partition_key_to_val from with
      | Some xs ->
          Host_and_port.Table.remove network.partition_key_to_val from;
          Host_and_port.Table.add_exn network.partition_key_to_val ~key:from ~data:(
            List.filter xs ~f:(fun x -> x <> to_)
          )
      | None -> ()
  end
end


module Udp_transport (Message : sig
  type t [@@deriving bin_io, sexp]
end) = struct
  open Async
  open Core

  type t =
    { logger : logger
    ; config : Udp.Config.t
    ; stop : unit -> unit
    ; port : int
    }

  let create logger ~port : t =
    let stop_fn = ref None in
    let stop_deferred = Deferred.create (fun ivar ->
      stop_fn := Some (fun () -> Ivar.fill ivar ()))
    in
    { logger
    ; config = Udp.Config.create ~stop:stop_deferred ()
    ; stop = Option.value_exn !stop_fn
    ; port
    }


  let stop_listening t = t.stop ()

  let send : t -> recipient:Peer.t -> Message.t -> unit Or_error.t Deferred.t = fun t ~recipient msg ->
    let socket = Socket.create Socket.Type.udp in
    let addr = Socket.Address.Inet.create (Unix.Inet_addr.of_string (Host_and_port.host recipient)) ~port:(Host_and_port.port recipient) in
    let iobuf = Iobuf.create ~len:(Message.bin_size_t msg) in
    t.logger#logf Debug "Making an iobuf to send of size %d" (Message.bin_size_t msg);
    Iobuf.Fill.bin_prot Message.bin_writer_t iobuf msg;
    Iobuf.flip_lo iobuf;
    let open Or_error.Let_syntax in
    match Udp.sendto () with
    | Ok sendto ->
        let open Deferred.Let_syntax in
        let fd = Socket.fd socket in
        let%bind () = sendto fd iobuf addr in
        let%map () = Fd.close fd in
        t.logger#logf Debug "Sent buf %s over socket" (msg |> Message.sexp_of_t |> Sexp.to_string);
        Ok ()
    | Error _ as e -> Deferred.return e

  let listen : t -> Message.t Linear_pipe.Reader.t =
    fun t ->
      let socket_addr =
        Socket.Address.Inet.create
          Unix.Inet_addr.bind_any
          ~port:t.port
      in
      let open Deferred.Let_syntax in
      let socket = Udp.bind socket_addr in
      let (r,w) = Linear_pipe.create () in
      let max_ready = 64 in
      let capacity = 8192 in
      don't_wait_for begin
        Udp.recvfrom_loop 
          ~config:(Udp.Config.create ~capacity:udp_packet_size ~max_ready ()) 
          (Socket.fd socket) 
          (fun buf addr ->
            let msg = Iobuf.Consume.bin_prot Message.bin_reader_t buf in
            t.logger#logf Debug "Got msg %s on socket" (msg |> Message.sexp_of_t |> Sexp.to_string);
            (* TODO need to check to make sure this is the correct side to drain from once > capacity *)
            Linear_pipe.write_or_drop ~capacity w r msg
        )
      end;
      r

  module TestOnly = struct
    let network_partition_add ~from ~to_ =
      failwith "only for tests"
    let network_partition_remove ~from ~to_ =
      failwith "only for tests"
  end
end

module Make (Transport : Transport_intf) = struct
  module Net = Transport(struct
    type t = Messager.msg [@@deriving bin_io, sexp]
  end)

  type t =
    { messager : Messager.t
    ; net_state  : Network_state.t
    ; mutable seq_no : int
    ; logger : Log.logger
    ; net : Net.t
    ; config : Config.t
    ; mutable stop : bool
    ; out_changes : Peer.Event.t Linear_pipe.Reader.t
    ; first_peers : Peer.t list Deferred.t
    }

  let changes t = t.out_changes

  let fresh_seq_no t =
    let seq_no = t.seq_no in
    t.seq_no <- t.seq_no + 1;
    seq_no

  let probe_node t (m_i : Node.t) =
    let sample_nodes xs k exclude =
      xs |> Set.Poly.to_list
      |> List.filter ~f:(fun n -> n <> exclude)
      |> List.permute
      |> fun l -> List.take l k
    in

    let seq_no = fresh_seq_no t in
    let node_to_string m = m |> Node.sexp_of_t |> Sexp.to_string in
    t.logger#logf Info "Begin round %d probing node %s" t.seq_no (node_to_string m_i);
    match%bind Messager.send t.messager [ (m_i.peer, Ping) ] ~seq_no ~timeout:(Config.round_trip_time t.config) with
    | `Acked ->
        t.logger#logf Info "Round %d %s acked" t.seq_no (node_to_string m_i);
        return ()
    | `Timeout ->
        t.logger#logf Info "Round %d %s timeout" t.seq_no (node_to_string m_i);
        let m_ks = sample_nodes (Network_state.live_nodes t.net_state) (Config.indirect_ping_count t.config) m_i.peer in
        match%map Messager.send t.messager (List.map m_ks ~f:(fun m_k -> (m_k, Payload.Ping_req m_i.peer))) ~seq_no ~timeout:Time.Span.((Config.protocol_period t.config) - (Config.round_trip_time t.config)) with
        | `Acked ->
            t.logger#logf Info "Round %d %s secondary acked" t.seq_no (node_to_string m_i)
        | `Timeout ->
            m_i.state <- `Dead;
            t.logger#logf Info "Round %d %s died" t.seq_no (node_to_string m_i)

  (* TODO: Round-Robin extension *)
  (* Use Random_iterer here *)
  let rec failure_detect (t : t) : unit Deferred.t =
    t.logger#logf Debug "Start failure_detect";
    let%bind () =
      match Shuffled_sequence.pop (Network_state.shuffled_live_nodes t.net_state) with
      | None ->
        Async.after (Config.protocol_period t.config)
      | Some n_i ->
        let m_i : Node.t = {peer=n_i;state=`Alive} in
        let%map () = probe_node t m_i
        and () = Async.after (Config.protocol_period t.config) in
        Network_state.add_slice t.net_state [m_i];
        ()
    in
    if not t.stop then
      failure_detect t
    else
      return ()


  (* From mirage-swim *)
  let transmit_limit net_state =
    let live_count = Set.Poly.length (Network_state.live_nodes net_state) in
    if live_count = 0 then
      0
    else
      live_count
      |> Float.of_int
      |> log
      |> Float.round_up
      |> Float.to_int

  let connect ~config ~initial_peers ~me =
    let logger = new Log.logger (Printf.sprintf "Swim:%s" (me |> Host_and_port.port |> string_of_int)) in
    let net = Net.create ~port:(Host_and_port.port me) logger in
    let incoming = Net.listen net in
    let net_state = Network_state.create logger in
    let rec handle_msg messager = function
      | (Payload.Ping, _) -> Deferred.return `Want_ack
      | (Payload.Ping_req addr_i, seq_no) ->
          match%map Messager.send messager [(addr_i, Payload.Ping)] ~seq_no:seq_no ~timeout:(Config.round_trip_time config) with
          | `Timeout -> `Stop
          | `Acked -> `Want_ack
    in
    let make_messager () =
      Messager.create
        ~incoming
        ~net_state
        ~get_transmit_limit:(fun () -> transmit_limit net_state)
        ~send_msg:(Net.send net)
        ~handle_msg
        ~me
    in
    let (out_changes, first_changes) = Linear_pipe.fork2 (Network_state.changes net_state) in
    (* TODO: This is inefficient since we only care about the first update, but we're replacing this with kademlia really really soon *)
    let first_peers = Deferred.create (fun ivar ->
      don't_wait_for begin
        Linear_pipe.iter first_changes ~f:(function
          | Peer.Event.Connect peers -> return (Ivar.fill_if_empty ivar peers)
          | Peer.Event.Disconnect _ -> return ()
        )
      end
    ) in
    let t =
      { messager = make_messager ()
      ; net_state
      (* Assume all initial_peers start alive *)
      ; seq_no = 0
      ; logger
      ; net
      ; config
      ; stop = false
      ; out_changes
      ; first_peers
      }
    in
    (* Assume initial peers are alive *)
    Network_state.add_slice t.net_state
      (List.map initial_peers ~f:Node.alive);

    don't_wait_for(schedule' (fun () -> failure_detect t));

    t

  let peers t = Network_state.live_nodes t.net_state |> Set.Poly.to_list

  let stop t =
    Net.stop_listening t.net;
    t.stop <- true

  let first_peers t = t.first_peers

  module TestOnly = struct
    let network_partition_add ~from ~to_ =
      Net.TestOnly.network_partition_add ~from:from ~to_:to_

    let network_partition_remove ~from ~to_ =
      Net.TestOnly.network_partition_remove ~from:from ~to_:to_

  end
end

module Udp : S = Make(Udp_transport)
module Test : S = Make(Fake_transport)

let%test_module "Network tests" = (module struct
    module Swim = Test
    (*Log.current_level := Log.ord Log.Info*)
    let with_fixed_random_seed (f : 'a -> 'b) : 'b =
      let old_default_state = Random.State.default in
      Bracket.bracket
        ~acquire:(fun () -> Random.set_state (Random.State.make [|1;1;1;1|]))
        ~release:(fun () -> Random.set_state old_default_state)
        f

    let assert_equal ~msg x x' equal =
        if not (equal x x') then
          failwith ("Assertion Failure: " ^ msg)
        else
          ()

    let addr port =
      Host_and_port.of_string (sprintf "127.0.0.1:%d" (port + 8000))

    let swim_client idx =
      (idx, Swim.connect
          ~config:(Config.create
            ~expected_latency:(Time.Span.of_ms 5.)
            ()
          )
          ~initial_peers:(List.init idx addr)
          ~me:(addr idx))

    let live_nodes_str client =
      let nodes = Swim.peers client in
      let strs =
        List.map nodes ~f:(fun node -> node
          |> Host_and_port.sexp_of_t
          |> Sexp.to_string)
      in
      String.concat ~sep:"," strs

    let peers_and_self (idx, swim) =
      (addr idx) :: (Swim.peers swim)

    let same (ps : Host_and_port.t list) (ps' : Host_and_port.t list) : bool =
      Set.Poly.equal (Set.Poly.of_list ps) (Set.Poly.of_list ps')

    let wait_stabalize () =
      Async.after (Time.Span.of_sec 0.5)

    let shutdown clients =
      List.iter clients ~f:(fun (_, c) -> Swim.stop c);
      wait_stabalize ()

    let peers_to_string peers =
      (List.sexp_of_t Peer.sexp_of_t (peers |> List.sort ~cmp:Peer.compare)) |> Sexp.to_string

    let assert_stable (clients : (int * Swim.t) list) : unit =
      (*printf "\n";*)
      (*List.iter clients ~f:(fun (idx, c) ->*)
        (*printf "%d:%s\n" idx ((idx, c) |> peers_and_self |> peers_to_string)*)
      (* ); *)
      (*printf "\n";*)
      match clients with
      | [] -> ()
      | (idx, c)::xs ->
          let peers = (peers_and_self (idx, c)) in
          List.iter xs ~f:(fun (idx', c') ->
            let peers' = (peers_and_self (idx', c')) in
            assert_equal ~msg:(Printf.sprintf "There exists some difference in the live nodes between \n%d:%s\n%d:%s\n" idx (peers_to_string peers) idx' (peers_to_string peers'))
              (peers)
              (peers')
              same;
          )

    let assert_no_live (client : int * Swim.t) : unit =
      let (idx, c) = client in
      let peers = Swim.peers c in
      assert_equal ~msg:(
        Printf.sprintf "There exists a live node: %s" (peers_to_string peers)
      ) (peers) [] same

    let create_with_delay_in_between ~delay ~count : (int * Swim.t) list Deferred.t =
      Deferred.List.init count (fun i ->
        let (idx, c) = swim_client i in
        let%map () = Async.after delay in
        (idx, c)
      )

  let test_kill_first_node ~count : unit Deferred.t =
    with_fixed_random_seed (fun () ->
      let%bind clients =
        create_with_delay_in_between
          ~delay:(Time.Span.of_sec 0.1)
          ~count:count
      in
      let%bind () = wait_stabalize () in
      (* Full network *)
      assert_stable clients;
      match clients with
      | [] ->
        return (failwith "unreachable")
      | x::xs ->
        let%bind () = shutdown [x] in
        let%bind () = wait_stabalize () in
        let%bind () = wait_stabalize () in
        (* Node0 dead *)
        assert_stable xs;
        (* Re-create Node0, but make sure he can reach Node1 at least *)
        let c0 = (0, Swim.connect
          ~config:(Config.create
            ~expected_latency:(Time.Span.of_ms 5.)
            ()
          )
          ~initial_peers:[addr 1]
          ~me:(addr 0)) in
        let%bind () = wait_stabalize () in
        let%bind () = wait_stabalize () in
        let%bind () = wait_stabalize () in
        (* Node0 revived *)
        assert_stable (c0::xs);
        shutdown (c0::xs)
    )

  let wait_with_random_seed (f : unit -> 'a Deferred.t) : 'a = with_fixed_random_seed (fun () -> Async.Thread_safe.block_on_async_exn f)

  let%test_unit "kill_first_node_2" = wait_with_random_seed (fun () -> test_kill_first_node ~count:2)
  let%test_unit "kill_first_node_4" = wait_with_random_seed (fun () -> test_kill_first_node ~count:4)
  let%test_unit "kill_first_node_8" = wait_with_random_seed (fun () -> test_kill_first_node ~count:8)

  let test_network_partition ~count : unit Deferred.t =
    let xs : int list = List.init count (fun i -> i) in
    match xs with
    | [] -> return ()
    | x::xs ->
      (* Partition node 0 from everything except node 1 *)
      List.iter xs (fun x' ->
        Swim.TestOnly.network_partition_add ~from:(addr x) ~to_:(addr x')
      );
      Swim.TestOnly.network_partition_remove ~from:(addr x) ~to_:(addr (List.nth_exn xs 0));
      let%bind clients =
        create_with_delay_in_between
          ~delay:(Time.Span.of_sec 0.1)
          ~count:count
      in
      let%bind () = wait_stabalize () in
      let%bind () = wait_stabalize () in
      assert_stable clients;
      shutdown clients

  let%test_unit "network_partition_4" = wait_with_random_seed (fun () -> test_network_partition ~count:4)
  let%test_unit "network_partition_8" = wait_with_random_seed (fun () -> test_network_partition ~count:8)

  let%test_unit "bad_initial_peer" =
    wait_with_random_seed (fun () ->
      let client = (0, Swim.connect
          ~config:(Config.create
            ~expected_latency:(Time.Span.of_ms 5.)
            ()
            )
          ~initial_peers:[addr 1]
          ~me:(addr 0))
      in
      let%bind () = wait_stabalize () in
      assert_no_live client;
      shutdown [client]
    )
end)

