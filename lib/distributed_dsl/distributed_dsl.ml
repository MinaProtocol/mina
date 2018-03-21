open Core_kernel
open Async_kernel

module Ident = struct
  type t = int ref

  let state = ref 0

  let next () =
    let old = !state in
    state := old + 1;
    old
end

module type Message_delay_intf = sig
  type message
  val delay : message -> Time.Span.t
end

module Time_queue = struct
  type 'action t =
    { mutable curr_time : Time.Span.t
    ; pending_actions : ('action * Time.Span.t) Heap.t
    }

  let handle_in_future t ~after action =
    Heap.add t.pending_actions (action, Time.Span.(after + t.curr_time))

  let create ~now =
    { curr_time = now
    ; pending_actions = Heap.create ~cmp:(fun (_, ts) (_, ts') -> Time.Span.compare ts ts') ()
    }

  let tick_forwards t ~by ~f =
    t.curr_time <- Time.Span.(t.curr_time + by);
    let rec go () =
      match Heap.top t.pending_actions with
      | None -> ()
      | Some (_, at) ->
          if Time.Span.(t.curr_time >= at) then
            let (action, _) = Heap.pop_exn t.pending_actions in
            f action;
            go ()
    in
    go ()

end

module type Temporal_intf = sig
  type t
  val create : now:Time.Span.t -> t
  val tick_forwards : t -> by:Time.Span.t -> unit
end

module type Fake_transport_intf = sig
  include Node.Transport_intf
  include Temporal_intf with type t := t

  val stop_listening : t -> me:peer -> unit
end

module type Fake_transport_s =
  functor
    (Message : sig type t end)
    (Message_delay : Message_delay_intf with type message := Message.t)
    (Peer : Node.Peer_intf) -> Fake_transport_intf with type message := Message.t
                                                   and type peer := Peer.t

module Fake_transport
  (Message : sig type t end)
  (Message_delay : Message_delay_intf with type message := Message.t)
  (Peer : Node.Peer_intf)
= struct
  type message = Message.t
  type peer = Peer.t

  type t =
    { network : (message Linear_pipe.Reader.t * message Linear_pipe.Writer.t) Peer.Table.t
    ; pending_messages : (message * peer) Time_queue.t
    }

  let create ~now =
    { network = Peer.Table.create ()
    ; pending_messages = Time_queue.create ~now
    }

  let tick_forwards t ~by =
    Time_queue.tick_forwards t.pending_messages ~by ~f:(fun (m, p) ->
      match Peer.Table.find t.network p with
      | None -> failwithf "Unknown recipient %s" (Peer.sexp_of_t p |> Sexp.to_string_hum) ()
      | Some (r, w) ->
          Linear_pipe.write_or_exn ~capacity:1024 w r m
    )

  let send t ~recipient message : unit Deferred.Or_error.t =
    match Peer.Table.find t.network recipient with
    | None -> return (Or_error.error_string (Printf.sprintf "Unknown recipient %s" (Peer.sexp_of_t recipient |> Sexp.to_string_hum)))
    | Some (r, w) ->
        Deferred.Or_error.return (
          Time_queue.handle_in_future t.pending_messages ~after:(Message_delay.delay message) (message, recipient)
        )

  let listen t ~me =
    let (r, w) = Linear_pipe.create () in
    Peer.Table.add_exn t.network ~key:me ~data:(r,w);
    r

  let stop_listening t ~me =
    Peer.Table.remove t.network me
end

module type Fake_timer_intf = sig
  include Node.Timer_intf
  include Temporal_intf with type t := t
end

module Fake_timer : Fake_timer_intf = struct
  module Token = Int

  type tok = Token.t [@@deriving eq]
  type t =
    { q : [`Cancelled | `Finished] Ivar.t Time_queue.t
    ; timer_stoppers : [`Cancelled | `Finished] Ivar.t Token.Table.t
    }

  let create ~now =
    { q = Time_queue.create ~now
    ; timer_stoppers = Token.Table.create ()
    }

  let tick_forwards t ~by =
    Time_queue.tick_forwards t.q ~by ~f:(fun ivar ->
      Ivar.fill_if_empty ivar `Finished
    )

  let wait t ts =
    let tok = Ident.next () in
    let ivar = Ivar.create () in
    Time_queue.handle_in_future t.q ~after:ts ivar;
    Token.Table.add_exn t.timer_stoppers ~key:tok ~data:ivar;
    tok, Ivar.read ivar

  let cancel t tok =
    match Token.Table.find t.timer_stoppers tok with
    | Some ivar -> Ivar.fill ivar `Cancelled
    | None -> ()

end

module type S =
  functor 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Message_delay : Message_delay_intf with type message := Message.t)
    (Peer : Node.Peer_intf)
    (Message_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Timer_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Condition_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Transport : Fake_transport_intf with type message := Message.t
                                      and type peer := Peer.t)
    -> sig

    type t

    module MyNode : Node.S with type message := Message.t
                            and type state := State.t
                            and type transport := Transport.t
                            and module Message_label := Message_label
                            and module Timer_label := Timer_label
                            and module Condition_label := Condition_label
                            and module Timer := Fake_timer

    module Identifier : sig type t end

    type change =
      | Delete of Identifier.t
      | Add of MyNode.t

    val loop : t -> stop : unit Deferred.t -> unit Deferred.t

    val change : t -> change list -> unit
  end

module Make 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Message_delay : Message_delay_intf with type message := Message.t)
    (Peer : Node.Peer_intf)
    (Message_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Timer_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Condition_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Transport : Fake_transport_intf with type message := Message.t
                                      and type peer := Peer.t)
= struct

    module MyNode = Node.Make(State)(Message)(Peer)(Fake_timer)(Message_label)(Timer_label)(Condition_label)(Transport)
    module Identifier = MyNode.Identifier

    type t = 
      { nodes : MyNode.t Identifier.Table.t
      ; timer : Fake_timer.t
      ; transport : Transport.t
      }

    type change = 
      | Delete of Identifier.t
      | Add of MyNode.t

    let change t changes =
      List.iter changes ~f:(function
        | Delete ident -> Identifier.Table.remove t.nodes ident
        | Add n -> Identifier.Table.add_exn t.nodes ~key:(MyNode.ident n) ~data:n
      )

    let rec loop t ~stop =
      let ready_node =
        List.find_map (Identifier.Table.data t.nodes) ~f:(fun n ->
          if MyNode.is_ready n then
            Some n
          else
            None
        )
      in
      match Deferred.peek stop, ready_node with
      | Some (), _ -> return ()
      | None, Some n ->
        let%bind n' = MyNode.step n in
        let _ = Identifier.Table.add t.nodes ~key:(MyNode.ident n) ~data:n' in
        loop t ~stop
      | None, None ->
        Fake_timer.tick_forwards t.timer ~by:(Time.Span.of_ms 100.);
        Transport.tick_forwards t.transport ~by:(Time.Span.of_ms 100.);
        loop t ~stop
end

