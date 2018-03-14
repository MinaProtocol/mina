open Core_kernel
open Async_kernel

module type Transport_intf = sig
  type t
  type message
  type peer

  val send : t -> recipient:peer -> message -> unit Or_error.t Deferred.t
  val listen : t -> message Linear_pipe.Reader.t
end

module type S = sig
  type message
  type state
  module Condition_label : Hashable.S

  type condition = 
    | Interval of Time.Span.t
    | Timeout of Time.Span.t
    | Message of (state -> message -> bool)
    | Predicate of (state -> bool)

  type t = 
    { state : state
    ; last_state : state option
    ; conditions : (condition * transition) Condition_label.Table.t
    ; message_pipe : message Linear_pipe.Reader.t
    ; work_reader : transition Linear_pipe.Reader.t
    ; work_writer : transition Linear_pipe.Writer.t
    }
  and transition = t -> state -> state Deferred.t
  and override_transition = t -> original:transition -> state -> state Deferred.t

  type command =
    | On of Condition_label.t * condition * transition
    | Override of Condition_label.t * override_transition

  val on
    : Condition_label.t
    -> condition
    -> f:transition
    -> command

  val override
    : Condition_label.t
    -> f:override_transition
    -> command

  val make_node 
    : messages : message Linear_pipe.Reader.t
    -> ?parent : t
    -> initial_state : state
    -> command list 
    -> t

  val step : t -> t Deferred.t
end

module type F =
  functor 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : sig val wait : Time.Span.t -> unit Deferred.t end)
    (Condition_label : sig 
       type label [@@deriving enum]
       include Hashable.S with type t = label
     end)
    (Transport : Transport_intf with type message := Message.t 
                                 and type peer := Peer.t) 
    -> S with type message := Message.t
          and type state := State.t
          and module Condition_label := Condition_label

module Make 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : sig val wait : Time.Span.t -> unit Deferred.t end)
    (Condition_label : sig 
       type label [@@deriving enum]
       include Hashable.S with type t = label
     end)
    (Transport : Transport_intf with type message := Message.t 
                                 and type peer := Peer.t) 
= struct

    type condition = 
      | Interval of Time.Span.t
      | Timeout of Time.Span.t
      | Message of (State.t -> Message.t -> bool)
      | Predicate of (State.t -> bool)

    type t = 
      { state : State.t
      ; last_state : State.t option
      ; conditions : (condition * transition) Condition_label.Table.t
      ; message_pipe : Message.t Linear_pipe.Reader.t
      ; work_reader : transition Linear_pipe.Reader.t
      ; work_writer : transition Linear_pipe.Writer.t
      }
    and transition = t -> State.t -> State.t Deferred.t
    and override_transition = t -> original:transition -> State.t -> State.t Deferred.t

    type command =
      | On of Condition_label.t * condition * transition
      | Override of Condition_label.t * override_transition

    let on label condition ~f = On (label, condition, f)

    let override label ~f = Override (label, f)

    let make_node ~messages ?parent ~initial_state commands = 
      let work_reader, work_writer = Linear_pipe.create () in
      let table =
        match parent with 
        | None -> Condition_label.Table.create ()
        | Some parent -> Condition_label.Table.copy parent.conditions
      in
      List.iter 
        commands
        ~f:(function
          | On (label, condition, f) -> 
            if Condition_label.Table.find table label = None
            then (failwith ("On: label " 
                            ^ "nyi" (*(Sexp.to_string_hum (Condition_label.sexp_of_label label)) *)
                            ^ " already exists"))
            else (Condition_label.Table.set table label (condition, f))
          | Override (label, f) -> 
            let condition, original_transition = Condition_label.Table.find_exn table label in
            Condition_label.Table.set table label (condition, fun t s -> f t ~original:(original_transition) s)
        );
      { state = initial_state
      ; last_state = None
      ; conditions = table
      ; message_pipe = messages
      ; work_reader
      ; work_writer
      }

    let step t = 
      let check_conditions = 
        match t.last_state with
        | None ->  true
        | Some last_state -> State.(last_state <> t.state)
      in
      let op = 
        let predicates = 
          (* if we called a transition recently, check all the conditions *)
          if check_conditions 
          then begin
            List.filter 
              (Condition_label.Table.data t.conditions)
              ~f:(fun (condition, transition) -> 
                match condition with
                | Predicate f -> f t.state 
                | _ -> false
              )
          end
          else []
        in 
        if List.length predicates > 1
        then failwith "multiple predicates passed"
        else if List.length predicates > 0
        then begin
          let _, transition = List.nth_exn predicates 0 in
          transition
        end
        else if Linear_pipe.length t.work_reader > 0
        then begin
          match Linear_pipe.read_now t.work_reader with
          | `Eof -> failwith "work pipe closed"
          | `Nothing_available -> failwith "work pipe no element"
          | `Ok work -> work
        end 
        else if Linear_pipe.length t.message_pipe > 0
        then begin
          match Linear_pipe.read_now t.message_pipe with
          | `Eof -> failwith "message pipe closed"
          | `Nothing_available -> failwith "message pipe no element"
          | `Ok message -> 
            let message_predicates =
              List.filter 
                (Condition_label.Table.data t.conditions)
                ~f:(fun (condition, transition) -> 
                  match condition with
                  | Message f -> f t.state message
                  | _ -> false
                )
            in
            if List.length message_predicates > 1
            then failwith "multiple message predicates passed"
            else if List.length message_predicates > 0
            then begin
              let _, transition = List.nth_exn message_predicates 0 in
              transition
            end
            else (fun t s -> return s)
        end
        else (fun t s -> return s)
      in 
      let%map next_state = op t t.state in
      { t with last_state = Some t.state
             ; state = next_state }
end

