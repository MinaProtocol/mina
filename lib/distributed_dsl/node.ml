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

  module Condition : sig
    type t
    type timer_tok

    type condition

    val timeout : Time.Span.t -> t
    val msg : (state -> message -> bool) -> t
    val predicate : (state -> bool) -> t

    (* or *)
    val ( + ) : t -> t -> t
    (* additive identity *)
    val never : t

    (* and *)
    val ( * ) : t -> t -> t
    (* multiplicative identity *)
    val always : t

    val check : t -> state -> message -> timer_tok list -> bool

    val wait_timers : t -> timer_tok Deferred.t
  end

  type t = 
    { state : state
    ; last_state : state
    ; conditions : (Condition.t * transition) Condition_label.Table.t
    ; message_pipe : message Linear_pipe.Reader.t
    ; work : transition Linear_pipe.Reader.t
    }
  and transition = t -> state -> state
  and override_transition = t -> original:transition -> state -> state

  type command =
    | On of Condition_label.t * Condition.t * transition
    | Override of Condition_label.t * transition

  val on
    : Condition_label.t
    -> Condition.t
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

    module Condition = struct
      type timer_tok = int [@@deriving eq]
      type t =
        { pred : State.t -> Message.t -> timer_tok list -> bool
        ; timers : timer_tok Deferred.t list
        }

      type condition =
        | Timeout of Time.Span.t
        | Message of (State.t -> Message.t -> bool)
        | Predicate of (State.t -> bool)

      let curr_tok = ref 0
      let next_tok () =
        let tok = !curr_tok in
        curr_tok := tok + 1;
        tok

      let single : condition -> t = function
        | Timeout ts ->
          let new_tok = next_tok () in
          let timeout ts = Deferred.map (Timer.wait ts) (fun () -> new_tok) in
          { pred = (fun _ _ toks -> List.exists toks ~f:(fun tok -> equal_timer_tok tok new_tok))
          ; timers = [ timeout ts ]
          }
        | Message f ->
          { pred = (fun s m _ -> f s m)
          ; timers = []
          }
        | Predicate f ->
          { pred = (fun s _ _ -> f s)
          ; timers = []
          }

      let timeout ts = single (Timeout ts)
      let msg f = single (Message f)
      let predicate f = single (Predicate f)

      let ( + ) x y =
        { pred = (fun s m toks -> x.pred s m toks || y.pred s m toks)
        ; timers = x.timers @ y.timers
        }

      let never =
        { pred = (fun _ _ _ -> false)
        ; timers = []
        }

      let ( * ) x y =
        { pred = (fun s m toks -> x.pred s m toks && y.pred s m toks)
        ; timers = x.timers @ y.timers
        }

      let always =
        { pred = (fun _ _ _ -> true)
        ; timers = []
        }

      let check {pred} = pred

      let wait_timers {timers} = Deferred.any timers
    end

    type t = 
      { state : State.t
      ; last_state : State.t
      ; conditions : (Condition.t * transition) Condition_label.Table.t
      ; message_pipe : Message.t Linear_pipe.Reader.t
      ; work : transition Linear_pipe.Reader.t
      }
    and transition = t -> State.t -> State.t
    and override_transition = t -> original:transition -> State.t -> State.t

    type command =
      | On of Condition_label.t * Condition.t * transition
      | Override of Condition_label.t * transition

    let on label condition ~f = failwith "nyi"

    let override label ~f = failwith "nyi"

    let make_node ~messages ?parent ~initial_state conditions = failwith "nyi"

    let step t = failwith "nyi"
      (* if we called a transition recently, check all the conditions *)
      (* else if a timeout/interval is up, call the relevant transition *)
      (* else if message queue not empty, check all message conditions *)

end

