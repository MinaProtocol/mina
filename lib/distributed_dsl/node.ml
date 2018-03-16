open Core_kernel
open Async_kernel

module type Transport_intf = sig
  type t
  type message
  type peer

  val send : t -> recipient:peer -> message -> unit Or_error.t Deferred.t
  val listen : t -> message Linear_pipe.Reader.t
end

module type Timer_intf = sig
  type tok [@@deriving eq]
  val wait : Time.Span.t -> tok * [`Cancelled | `Finished] Deferred.t
  val cancel : tok -> unit
end

module type S = sig
  type message
  type state
  module Message_label : Hashable.S
  module Timer_label : Hashable.S
  module Condition_label : Hashable.S
  module Timer : Timer_intf

  type condition = state -> bool

  type message_condition = message -> condition

  type transition = t -> state -> state Deferred.t
  and message_transition = t -> message -> state -> state Deferred.t
  and t

  type handle_command = Condition_label.t * condition * transition
  type message_command = Message_label.t * message_condition * message_transition

  val on
    : Condition_label.t
    -> condition
    -> f:transition
    -> handle_command

  val msg
    : Message_label.t
    -> message_condition
    -> f:message_transition
    -> message_command

  val cancel
    : t
    -> Timer_label.t
    -> ?tok:Timer.tok option
    -> unit

  val timeout
    : t
    -> Timer_label.t
    -> Time.Span.t
    -> f:transition
    -> Timer.tok

  val next_ready : t -> unit Deferred.t

  val make_node 
    : messages : message Linear_pipe.Reader.t
    -> ?parent : t
    -> initial_state : state
    -> message_command list 
    -> handle_command list 
    -> t

  val step : t -> t Deferred.t
end

module type F =
  functor 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : Timer_intf)
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
    (Transport : Transport_intf with type message := Message.t 
                                 and type peer := Peer.t) 
    -> S with type message := Message.t
          and type state := State.t
          and module Timer := Timer
          and module Message_label := Message_label
          and module Timer_label := Timer_label
          and module Condition_label := Condition_label

module Make 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : Timer_intf)
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
    (Transport : Transport_intf with type message := Message.t 
                                 and type peer := Peer.t)
= struct
    type condition = State.t -> bool

    type message_condition = Message.t -> condition

    type transition = t -> State.t -> State.t Deferred.t
    and message_transition = t -> Message.t -> State.t -> State.t Deferred.t
    and t =
      { state : State.t
      ; last_state : State.t option
      ; conditions : (condition * transition) Condition_label.Table.t
      ; message_pipe : Message.t Linear_pipe.Reader.t
      ; message_handlers : (message_condition * message_transition) Message_label.Table.t
      ; triggered_timers_r : transition Linear_pipe.Reader.t
      ; triggered_timers_w : transition Linear_pipe.Writer.t
      ; timers : Timer.tok list Timer_label.Table.t
      }

    type handle_command = Condition_label.t * condition * transition
    type message_command = Message_label.t * message_condition * message_transition

    let on label condition ~f =
      (label, condition, f)

    let msg label condition ~f =
      (label, condition, f)

    let add_back_timers t ~key ~data =
      if List.length data > 0 then
        let _ = Timer_label.Table.add t.timers ~key ~data in
        ()
      else
        Timer_label.Table.remove t.timers key

    let cancel t label ?tok:(tok=None) =
      let l = Timer_label.Table.find_multi t.timers label in
      let (to_cancel, to_put_back) =
        List.partition_map l ~f:(fun tok' ->
          match tok with
          | None -> `Fst tok'
          | Some tok ->
              if tok = tok' then
                `Fst tok'
              else
                `Snd tok'
        )
      in
      List.iter to_cancel ~f:(fun tok' ->
        Timer.cancel tok'
      );
      add_back_timers t ~key:label ~data:to_put_back

    let timeout t label ts ~(f:transition) =
      let remove_tok tok =
        let l = Timer_label.Table.find_multi t.timers label in
        let l' = List.filter l ~f:(fun tok' -> not (Timer.equal_tok tok tok')) in
        add_back_timers t ~key:label ~data:l'
      in

      let tok, waited = Timer.wait ts in
      let _ = Timer_label.Table.add_multi t.timers ~key:label ~data:tok  in
      don't_wait_for begin
        match%map waited with
        | `Cancelled ->
          remove_tok tok
        | `Finished ->
          remove_tok tok;
          Linear_pipe.write_or_exn ~capacity:1024 t.triggered_timers_w t.triggered_timers_r f
      end;
      tok

    let state_changed t =
      not (Option.equal State.equal (Some t.state) t.last_state)

    let next_ready t : unit Deferred.t =
      let ready p = Linear_pipe.values_available p >>= (fun _ -> return ()) in
      Deferred.any
      [ ready t.message_pipe
      ; ready t.triggered_timers_r
      ; if state_changed t then
          return ()
        else
          Deferred.never ()
      ]

    let make_node ~messages ?parent ~initial_state message_conditions handle_conditions =
      let conditions = Condition_label.Table.create () in
      List.iter handle_conditions ~f:(fun (l, c, h) ->
        match Condition_label.Table.add conditions ~key:l ~data:(c,h) with
        | `Duplicate ->
            failwithf "You specified the same condition twice! %s"
              (Condition_label.sexp_of_label l |> Sexp.to_string_hum) ()
        | `Ok -> ()
      );
      let message_handlers = Message_label.Table.create () in
      List.iter message_conditions ~f:(fun (l, c, h) ->
        match Message_label.Table.add message_handlers ~key:l ~data:(c,h) with
        | `Duplicate ->
            failwithf "You specified the same message handler twice! %s"
              (Message_label.sexp_of_label l |> Sexp.to_string_hum) ()
        | `Ok -> ()
      );
      let timers = Timer_label.Table.create () in
      let triggered_timers_r, triggered_timers_w = Linear_pipe.create () in
      let t =
        { state = initial_state
        ; last_state = None
        ; conditions
        ; message_pipe = messages
        ; message_handlers
        ; triggered_timers_r
        ; triggered_timers_w
        ; timers
        }
      in
      t

    let with_new_state t state : t =
      { t with last_state = Some (t.state)
      ; state
      }

    let step t : t Deferred.t =
      match (
        state_changed t,
        Linear_pipe.peek t.triggered_timers_r,
        Linear_pipe.peek t.message_pipe
      ) with
      | true, _, _ ->
          let checks = Condition_label.Table.to_alist t.conditions in
          let matches = List.filter checks ~f:(fun (_, (cond, _)) ->
            cond t.state
          ) in
          (match matches with
          | [] ->
              return (with_new_state t (t.state))
          | (_,(_,transition))::[] ->
              (transition t t.state) >>| (with_new_state t)
          | _::_::xs as l ->
            failwithf "Multiple conditions matched current state: %s"
              (List.map l ~f:(fun (label, _) -> label) |> List.sexp_of_t Condition_label.sexp_of_label |> Sexp.to_string_hum) ())
      | false, Some transition, _ ->
          let _ = Linear_pipe.read_now t.triggered_timers_r in
          (transition t t.state) >>| (with_new_state t)
      | false, None, Some msg ->
          let _ = Linear_pipe.read_now t.message_pipe in
          let checks = Message_label.Table.to_alist t.message_handlers in
          let matches = List.filter checks ~f:(fun (_, (cond, _)) ->
            cond msg t.state
          ) in
          (match matches with
          | [] ->
              return (with_new_state t (t.state))
          | (_,(_,transition))::[] ->
              (transition t msg t.state) >>| (with_new_state t)
          | _::_::xs as l ->
            failwithf "Multiple conditions matched current state: %s"
              (List.map l ~f:(fun (label, _) -> label) |> List.sexp_of_t Message_label.sexp_of_label |> Sexp.to_string_hum) ())
      | false, None, None ->
          return (with_new_state t (t.state))
end

