open Core_kernel
open Async_kernel

module type S = sig
  type t

  module Config : sig
    type t

    val create : ?indirect_ping_count:int
      -> ?expected_latency:Time.Span.t
      -> unit
      -> t

    val indirect_ping_count : t -> int
    val protocol_period : t -> Time.Span.t
    val rtt : t -> Time.Span.t
  end

  val connect : config:Config.t -> initial_peers:Host_and_port.t list -> me:Host_and_port.t -> t Deferred.t

  val peers : t -> Host_and_port.t list

  val changes : t -> Peer.Event.t Pipe.Reader.t

  val stop : t -> unit

  val test_only_network_partition_add : from:Host_and_port.t -> to_:Host_and_port.t -> unit
  val test_only_network_partition_remove : from:Host_and_port.t -> to_:Host_and_port.t -> unit
end

module Node = struct
  type state = Dead | Alive [@@deriving bin_io, sexp]

  type t =
    { peer : Host_and_port.t
    ; mutable state : state
    } [@@deriving bin_io, sexp]

  let is_alive t = t.state = Alive
  let is_dead t = t.state = Dead

  let alive peer = { peer ; state = Alive }


  let dead peer = { peer ; state = Dead }
end

module type RandomIterer_intf = sig
  type 'a t

  val create : initial:'a list -> 'a t

  (* Add an element that may at random be chosen for an iteration that's already happenning *)
  val add : 'a t -> 'a -> unit

  (* Semantics:
   * 1. Merge all pending adds into the list
   * 2. Permute the list randomly
   * 3. Start iterating slowly through the frozen list of size `n`
   * 4. During iteration, new entries could have been added to our `t` structure
   * Whenever there exists `k` items that have been added, with
   * probability `k / (n + k)` choose an element `x` from the new entries
   * without replacement and use that instead
   *)
  val effectful_iter_async : 'a t -> f:('a -> unit Deferred.t) -> unit Deferred.t
end

(* Rough sketch of a possible idea *)
module RandomIterer = struct
  type 'a collection = Todo

  type 'a t =
    { frozen : 'a list
    ; mutable consuming : 'a collection
    ; mutable pending : 'a collection
    }

  let create ~initial = failwith "TODO"

  let add t x = failwith "TODO"

  let effectful_iter_async t ~f = failwith "TODO"
end

module type NetworkState_intf = sig
  type t

  (* A slice of state for network delivery *)
  type slice = Node.t list [@@deriving bin_io, sexp]

  val create : Log.logger -> t

  val add_slice : t -> slice -> unit Deferred.t

  val changes : t -> Peer.Event.t Pipe.Reader.t

  (* Pure getter for live_nodes *)
  val live_nodes : t -> Host_and_port.t Set.Poly.t

  (* Effectfully (mutating t) extracts a slice of the network state
   * maintaining necessary SWIM invariants *)
  val extract : t -> transmit_limit:int -> Host_and_port.t -> slice
end

(* Taken mostly from mirage-swim *)
module NetworkState : NetworkState_intf = struct
  module E = struct
    type t = Node.t [@@deriving sexp]
    type id = Host_and_port.t

    let invalidates (node : t) (node' : t) : bool =
      node.peer = node'.peer && node.state <> node'.state

    let skip (node : t) peer =
      node.peer = peer

    let size = Node.bin_size_t
  end

  type broadcast_queue_t = (int * E.t) list [@@deriving sexp]
  type t =
    { mutable broadcast_queue : broadcast_queue_t
    ; mutable live_nodes : Host_and_port.t Set.Poly.t
    ; logger : Log.logger
    ; changes : Peer.Event.t Pipe.Reader.t * Peer.Event.t Pipe.Writer.t
    }

  type slice = Node.t list [@@deriving bin_io, sexp]

  let create logger : t =
    { broadcast_queue = []
    ; live_nodes = Set.Poly.empty
    ; logger
    ; changes = Pipe.create ()
    }

  let update_live t (node : E.t) =
    if node.state = Node.Alive then
      t.live_nodes <- Set.Poly.add t.live_nodes node.peer
    else
      t.live_nodes <- Set.Poly.remove t.live_nodes node.peer

  let add (t : t) (node : E.t) =
    update_live t node;
    if not (List.exists t.broadcast_queue ~f:(fun (_, node') -> node = node')) then begin
      let q = List.filter t.broadcast_queue ~f:(fun (_, node') -> not (E.invalidates node node')) in
      t.broadcast_queue <- ((0, node)::q)
    end

  let push_changes t slice =
    let (_, w) = t.changes in
    let (connected, disconnected) =
      slice
      |> List.filter ~f:(fun (node : Node.t) ->
        (* dead information is new information *)
        node.state = Node.Dead ||
          (* skip over the live nodes in the slice if we already know about them *)
          not (Set.Poly.mem t.live_nodes node.peer)
        )
      |> List.partition_map ~f:(fun (node : Node.t) ->
          match node.state with
          | Node.Alive -> `Fst node.peer
          | Node.Dead -> `Snd node.peer
        )
    in
    let%bind () = Pipe.write w (Peer.Event.Disconnect disconnected) in
    let%map () = Pipe.write w (Peer.Event.Connect connected) in
    ()

  let add_slice t slice =
    let%map () = push_changes t slice in
    List.iter slice (add t)

  let live_nodes t = t.live_nodes

  let changes t =
    let (r, _) = t.changes in
    r

  let extract (t : t) ~transmit_limit addr =
    let select memo elem =
      let transmit, elems, bytes_left = memo in
      let transmit_count, broadcast = elem in
      let size = E.size broadcast in
      if transmit_count > transmit_limit then
        (transmit, elems, bytes_left)
      else if size > bytes_left || E.skip broadcast addr then
        (transmit, elem::elems, bytes_left)
      else
        (broadcast::transmit, (transmit_count+1, broadcast)::elems, bytes_left - size)
    in
    let transmit, bq', _ = List.fold_left t.broadcast_queue ~f:select ~init:([], [], 65507) in
    t.broadcast_queue <- List.sort ~cmp:(fun e e' -> Int.compare (fst e) (fst e')) bq';
    transmit
end

module Request_or_ack = struct
  type 'a t = Ack | Request of 'a [@@deriving bin_io, sexp]
end

module Payload = struct
  type t = Ping | Ping_req of Host_and_port.t [@@deriving bin_io, sexp]
end

module AckTable = struct
  type t = (int, unit Ivar.t) Hashtbl.t
end

module Messager : (sig
  type t
  type msg =
    { from: Host_and_port.t
    ; action: Payload.t Request_or_ack.t
    ; net_slice: NetworkState.slice
    ; seq_no: int
    } [@@deriving bin_io, sexp]

  val create : incoming:msg Pipe.Reader.t
    -> net_state:NetworkState.t
    -> get_transmit_limit:(unit -> int)
    (* to send messages *)
    -> send_msg:(recipient:Host_and_port.t -> msg -> unit Or_error.t Deferred.t)
    (* handle incoming msgs (with seq_no) *)
    -> handle_msg:(t -> Payload.t * int -> [`Stop | `Want_ack] Deferred.t)
    -> me: Host_and_port.t
    -> t

  val send : t -> (Host_and_port.t * Payload.t) list -> seq_no:int -> timeout:Time.Span.t -> [ `Timeout | `Acked ] Deferred.t
end) = struct
  type msg =
    { from: Host_and_port.t
    ; action: Payload.t Request_or_ack.t
    ; net_slice: NetworkState.slice
    ; seq_no: int
    } [@@deriving bin_io, sexp]

  type t =
    { table : AckTable.t
    ; net_state : NetworkState.t
    ; get_transmit_limit : unit -> int
    ; send_msg : recipient:Host_and_port.t -> msg -> unit Or_error.t Deferred.t
    ; me : Host_and_port.t
    (* TODO(bkase): Remember to handle different msgs having diff timeouts *)
    }

  let raw_send t addr action seq_no : _ Or_error.t Deferred.t =
    let open Let_syntax in
    t.send_msg ~recipient:addr
      { from = t.me
      ; action
      ; net_slice = NetworkState.extract t.net_state ~transmit_limit:(t.get_transmit_limit ()) addr
      ; seq_no
      }

  let create : incoming:msg Pipe.Reader.t
    -> net_state:NetworkState.t
    -> get_transmit_limit:(unit -> int)
    (* to send messages *)
    -> send_msg:(recipient:Host_and_port.t -> msg -> unit Or_error.t Deferred.t)
    (* handle incoming msgs (with seq_no) *)
    -> handle_msg:(t -> Payload.t * int -> [`Stop | `Want_ack] Deferred.t)
    -> me: Host_and_port.t
    -> t = fun ~incoming ~net_state ~get_transmit_limit ~send_msg ~handle_msg ~me ->
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
      Pipe.iter_without_pushback incoming (fun {from; action; net_slice; seq_no} ->
        let open Let_syntax in
        let open Request_or_ack in

        (* the sender must have been alive *)
        let with_sender : Node.t list = ({peer = from; state = Alive}::net_slice) in
        (* We need this iter to be fast so UDP packets don't build up *)
        (* Implicit contract with change pipe consumer to keep up with events *)
        don't_wait_for begin
          NetworkState.add_slice net_state with_sender
        end;

        match action with
        | Request x ->
           (* Not pushing-back here since UDP packets should send fast *)
           (* Plus handle_msg will be very slow, but is mostly IO blocked not compute bound *)
           don't_wait_for begin
             match%bind handle_msg t (x, seq_no) with
             | `Stop -> return ()
             | `Want_ack ->
               let%map _ = raw_send t from Ack seq_no in
               ()
           end
        | Ack ->
          Option.iter (Hashtbl.Poly.find t.table seq_no) (fun ivar ->
              Hashtbl.Poly.remove t.table seq_no;
              Ivar.fill_if_empty ivar ()
          )
      )
    end;
    t

  let send t msgs ~seq_no ~timeout =
    let open Let_syntax in
    let wait_ack = Deferred.create (fun _ivar ->
      Hashtbl.Poly.set ~key:seq_no t.table ~data:_ivar;
    ) in
    List.iter msgs (fun (addr, payload) ->
      (* We're implicitly waiting for an ack, so no risk for async pressure *)
      don't_wait_for(
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

    val send : t -> recipient:Host_and_port.t -> Message.t -> unit Or_error.t Deferred.t
    val listen : t -> Message.t Pipe.Reader.t Deferred.t

    val stop_listening : t -> unit

    val test_only_network_partition_add : from:Host_and_port.t -> to_:Host_and_port.t -> unit
    val test_only_network_partition_remove : from:Host_and_port.t -> to_:Host_and_port.t -> unit
  end

module FakeTransport (Message : sig
  type t [@@deriving bin_io, sexp]
end) = struct
  type network_t =
    { connected : (recipient:Host_and_port.t -> Message.t -> unit Or_error.t Deferred.t) Host_and_port.Table.t
    ; partition_key_to_val : Host_and_port.t list Host_and_port.Table.t
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
    match (
      Host_and_port.Table.find network.partition_key_to_val (me t),
      Host_and_port.Table.find network.connected recipient
    ) with
    | (Some xs, _) when List.mem xs recipient ~equal:Host_and_port.equal -> return (Ok ())
    | (_, None) -> return (Ok ())
    | (_, Some fn) -> fn ~recipient msg

  let listen (t: t) : Message.t Pipe.Reader.t Deferred.t =
    let (r,w) = Pipe.create () in
    Host_and_port.Table.add_exn network.connected
      ~key:(me t)
      ~data:(fun ~recipient msg ->
        let%bind () = Pipe.write w msg in
        return (Ok ())
      );
    return r

  let stop_listening t =
    Host_and_port.Table.remove network.connected (me t)

  let test_only_network_partition_add ~from ~to_ =
    match Host_and_port.Table.find network.partition_key_to_val from with
    | Some xs ->
        Host_and_port.Table.remove network.partition_key_to_val from;
        Host_and_port.Table.add_exn network.partition_key_to_val ~key:from ~data:(
          to_::xs
        )
    | None ->
        Host_and_port.Table.add_exn network.partition_key_to_val ~key:from ~data:([to_])

  let test_only_network_partition_remove ~from ~to_ =
    match Host_and_port.Table.find network.partition_key_to_val from with
    | Some xs ->
        Host_and_port.Table.remove network.partition_key_to_val from;
        Host_and_port.Table.add_exn network.partition_key_to_val ~key:from ~data:(
          List.filter xs ~f:(fun x -> x <> to_)
        )
    | None -> ()

end


module UdpTransport (Message : sig
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
      stop_fn := Some (fun () -> Ivar.fill ivar ())
    ) in
    { logger
    ; config = Udp.Config.create ~stop:stop_deferred ()
    ; stop = Option.value_exn !stop_fn
    ; port
    }

  let stop_listening t = t.stop ()

  let send : t -> recipient:Host_and_port.t -> Message.t -> unit Or_error.t Deferred.t = fun t ~recipient msg ->
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
    (*printf "Got sendto error code of %d" code;*)

  let listen : t -> Message.t Pipe.Reader.t Deferred.t =
    fun t ->
      let socket_addr =
        Socket.Address.Inet.create
          (Unix.Inet_addr.of_string "127.0.0.1")
          ~port:t.port
      in
      let open Deferred.Let_syntax in
      let%map socket = Udp.bind socket_addr in
      let (r,w) = Pipe.create () in
      don't_wait_for begin
        Udp.recvfrom_loop (Socket.fd socket) (fun buf addr ->
          let msg = Iobuf.Consume.bin_prot Message.bin_reader_t buf in
          t.logger#logf Debug "Got msg %s on socket" (msg |> Message.sexp_of_t |> Sexp.to_string);
          (* TODO: Do we need pushback here? *)
          Pipe.write_without_pushback w msg
        )
      end;
      r

  let test_only_network_partition_add ~from ~to_ =
    failwith "only for tests"
  let test_only_network_partition_remove ~from ~to_ =
    failwith "only for tests"
end

module Make (Transport : Transport_intf) = struct
  module Net = Transport(struct
    type t = Messager.msg [@@deriving bin_io, sexp]
  end)

  module Config = struct
    type t =
      { indirect_ping_count : int
      ; protocol_period : Time.Span.t
      ; rtt : Time.Span.t
      }

    let create ?indirect_ping_count:(indirect_ping_count=6)
      ?expected_latency:(expected_latency=Time.Span.of_ms 500.)
      () =
        let epsilon = Time.Span.of_ms 5. in
        let rtt = Time.Span.(expected_latency + expected_latency) in
        let protocol_period = Time.Span.(rtt + rtt + rtt + epsilon) in
        { indirect_ping_count
        ; protocol_period
        ; rtt
        }

    let indirect_ping_count t = t.indirect_ping_count
    let protocol_period t = t.protocol_period
    let rtt t = t.rtt
  end

  type t =
    { messager : Messager.t
    ; net_state  : NetworkState.t
    ; mutable seq_no : int
    ; logger : Log.logger
    ; net : Net.t
    ; config : Config.t
    ; mutable stop : bool
    }

  let fresh_seq_no t =
    let seq_no = t.seq_no in
    t.seq_no <- t.seq_no + 1;
    seq_no

  let prob_node t (m_i : Node.t) =
    let sample_nodes xs k exclude =
      xs |> Set.Poly.to_list
      |> List.filter ~f:(fun n -> n <> exclude)
      |> List.permute
      |> fun l -> List.take l k
    in

    let seq_no = fresh_seq_no t in
    t.logger#logf Info "Begin round %d probing node %s" t.seq_no (m_i |> Node.sexp_of_t |> Sexp.to_string);
    match%bind Messager.send t.messager [ (m_i.peer, Ping) ] ~seq_no ~timeout:(Config.rtt t.config) with
    | `Acked ->
        t.logger#logf Info "Round %d acked" t.seq_no;
        return ()
    | `Timeout ->
        t.logger#logf Info "Round %d timeout" t.seq_no;
        let m_ks = sample_nodes (NetworkState.live_nodes t.net_state) (Config.indirect_ping_count t.config) m_i.peer in
        match%map Messager.send t.messager (List.map m_ks ~f:(fun m_k -> (m_k, Payload.Ping_req m_i.peer))) ~seq_no ~timeout:Time.Span.((Config.protocol_period t.config) - (Config.rtt t.config)) with
        | `Acked ->
            t.logger#logf Info "Round %d secondary acked" t.seq_no
        | `Timeout ->
            m_i.state <- Node.Dead;
            t.logger#logf Info "Round %d m_i died" t.seq_no

  (* TODO: Round-Robin extension *)
  let rec failure_detect (t : t) : unit Deferred.t =
    t.logger#logf Debug "Start failure_detect";
    let%bind () =
      match Set.Poly.length (NetworkState.live_nodes t.net_state) with
      | 0 ->
        Async.after (Config.protocol_period t.config)
      | _ ->
        let choose xs =
          Option.value_exn (List.nth xs (Random.int (List.length xs))) in

        let m_i = choose (NetworkState.live_nodes t.net_state |> Set.Poly.to_list) in
        let%map ((), ()) = Deferred.both
          (prob_node t {peer=m_i;state=Alive})
          (Async.after (Config.protocol_period t.config)) in
        ()
    in
    if not t.stop then
      failure_detect t
    else
      return ()


  (* From mirage-swim *)
  let transmit_limit net_state =
    let live_count = Set.Poly.length (NetworkState.live_nodes net_state) in
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
    let%map incoming = Net.listen net in
    let net_state = NetworkState.create logger in
    let rec handle_msg messager = function
      | (Payload.Ping, _) -> Deferred.return `Want_ack
      | (Payload.Ping_req addr_i, seq_no) ->
          match%map Messager.send messager [(addr_i, Payload.Ping)] ~seq_no:seq_no ~timeout:(Config.rtt config) with
          | `Timeout -> `Stop
          | `Acked -> `Want_ack
    and make_messager () =
      Messager.create
        ~incoming
        ~net_state
        ~get_transmit_limit:(fun () -> transmit_limit net_state)
        ~send_msg:(Net.send net)
        ~handle_msg
        ~me
    in
    let t =
      { messager = make_messager ()
      ; net_state
      (* Assume all initial_peers start alive *)
      ; seq_no = 0
      ; logger
      ; net
      ; config
      ; stop = false
      }
    in
    (* Assume initial peers are alive *)
    don't_wait_for begin
      NetworkState.add_slice t.net_state
        (List.map initial_peers ~f:Node.alive)
    end;

    don't_wait_for(schedule' (fun () -> failure_detect t));

    t

  let peers t = NetworkState.live_nodes t.net_state |> Set.Poly.to_list

  let changes t =
    NetworkState.changes t.net_state

  let stop t =
    Net.stop_listening t.net;
    t.stop <- true

  let test_only_network_partition_add ~from ~to_ =
    Net.test_only_network_partition_add ~from:from ~to_:to_

  let test_only_network_partition_remove ~from ~to_ =
    Net.test_only_network_partition_remove ~from:from ~to_:to_
end

module Udp : S = Make(UdpTransport)
module Test : S = Make(FakeTransport)
