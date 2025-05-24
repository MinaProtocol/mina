open Async
open Core_kernel

(** ['state msg_processed] is the type of result that either a data handler, or
    a control handler should return.
    [MNext s] indicates we sucessfully processed the message, and the state of
    the actor is updated to [s];
    [MExit] indicates we should stop the actor;
    [MUnprocessed] indicates we can't process this message now, and hence the
    message would be put back into the coressponding message queue. *)
type 'state msg_processed = MNext of 'state | MExit | MUnprocessed

(** [('state, 'response) req_processed] is the type of result returned by a
    request handler. *)
type ('state, 'response) req_processed =
  | RNext of ('state * 'response)
      (** [RNext (s, r)] indicates we sucessfully processed the message, and the
          state of the actor is updated to [s], and the response of the request
          is [r]; *)
  | RExit of 'response
      (** [RExit r] indicates we should stop the actor with response of this
          request being [r]; *)
  | RUnprocessed
      (** [RUnprocessed] indicates we can't process this request now, and hence
          the request would be put back into the request queue. *)

(** [('state, 'data, 'return_type, 'kind) overflow_behavior] defines the
    behavior the data inbox should have when there's to many data being sent to
    it. *)
type (_, _, _, _) overflow_behavior =
  | Throw : ('state, 'data, unit Or_error.t, [ `Throw ]) overflow_behavior
      (** We should throw an error *)
  | Drop_head :
      [ `Warns | `No_warns ]
      -> ('state, 'data, unit, [ `Drop_head ]) overflow_behavior
      (** We should drop the head of queue message. Could log what's being
          dropped in additional on demand *)
  | Drop_and_call_head :
      ('state -> 'data -> 'returns)
      -> ( 'state
         , 'data
         , 'returns option
         , [ `Drop_and_call_head ] )
         overflow_behavior
      (** We should drop the head of queue message. and call it with the
          callback provided *)
  | Push_back
      : ('state, 'data, unit Deferred.t, [ `Push_back ]) overflow_behavior
      (** We block and provide a signal and return a `Deferred.t` *)

(** [('state, 'data, 'return_type, 'kind) channel_type] defines the kind of
    channel we're using. *)
type (_, _, _, _) channel_type =
  | Infinity : ('state, 'data, unit, [ `Infinity ]) channel_type
      (** The channel has infinity buffering size so it never overflows *)
  | With_capacity :
      [ `Capacity of int ]
      * [ `Overflow of ('state, 'data, 'returns, 'behavior) overflow_behavior ]
      -> ('state, 'data, 'returns, 'behavior) channel_type
      (** [With_capacity (`Capacity c, `Overflow b)] indicates the channel has limited
      capacitiy [c]. When overflowing it would have behavior [b] *)

(** When either control inbox or data inbox is unused in an actor, we could use
    [DummyMessage] as a placeholder *)
module DummyMessage : sig
  type t = unit [@@deriving to_yojson]

  val handler : state:'a -> message:t -> 'a msg_processed Deferred.t
end

(** When request inbox is unused in an actor, we could use [DummyRequest] as a
    placeholder. *)
module DummyRequest : sig
  type _ t = Nothing : unit t

  val handler :
       state:'state
    -> request:'response t
    -> ('state, 'response) req_processed Deferred.t
end

(** The feature complete functor for constructing an actor. *)
module WithRequest (DataMessage : sig
  (** type of data being passed to data inbox of an actor *)
  type t

  val to_yojson : t -> Yojson.Safe.t
end) (Request : sig
  (** type of request sent to request inbox of an actor *)
  type _ t
end) : sig
  (** The actor data inbox has too many data, this is only trigger when using
      Throw as overflow_behavior. *)
  exception
    ActorDataInboxOverflow of
      { name : Yojson.Safe.t; capacity : int; attempt_enqueing : DataMessage.t }

  (** An already running actor is being spawned. *)
  exception RunningActorSpawned of { name : Yojson.Safe.t }

  (** Type of request handler for an actor, this has to be a record due to
      OCaml's restriction on params passing to a function.  *)
  type 'state request_handler =
    { f :
        'response.
           state:'state
        -> request:'response Request.t
        -> ('state, 'response) req_processed Deferred.t
    }

  (** Type of a actor *)
  type ('data_returns, 'data_overflew, 'control_msg, 'state) t

  (** Create an actor with specified fields, it's not running after creation *)
  val create :
       name:Yojson.Safe.t
    -> data_channel_type:
         ('state, DataMessage.t, 'data_returns, 'data_overflew) channel_type
    -> request_handler:'state request_handler
    -> control_handler:
         (   state:'state
          -> message:'control_msg
          -> 'state msg_processed Deferred.t )
    -> data_handler:
         (   state:'state
          -> message:DataMessage.t
          -> 'state msg_processed Deferred.t )
    -> logger:Logger.t
    -> state:'state
    -> ('data_returns, 'data_overflew, 'control_msg, 'state) t

  (** [terminate ~actor] terminates the actor after the current running cycle. *)
  val terminate :
    actor:('data_returns, 'data_overflew, 'control_msg, 'state) t -> unit

  (** [send_request ~actor ~request] sends a request to an actor, it returns a
      [Deferred.t] that's resolved when the actor processed the request. *)
  val send_request :
    'response 'data_returns 'data_overflew 'control_msg 'state.
       actor:('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> request:'response Request.t
    -> 'response Deferred.t

  (** [send_request ~actor ~request] sends a control message to an actor. *)
  val send_control :
       actor:('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> message:'control_msg
    -> unit

  (** [send_request ~actor ~request] sends a data message to an actor. *)
  val send_data :
    'data_returns 'data_overflew 'control_msg 'state.
       actor:('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> message:DataMessage.t
    -> 'data_returns

  (** [spwan actor] run's an actor, it returns a unit when the actor exits, and
      may throw some errors *)
  val spawn :
       ('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> unit Deferred.Or_error.t
end

module Regular (DataMessage : sig
  type t

  val to_yojson : t -> Yojson.Safe.t
end) : sig
  (** The actor data inbox has too many data, this is only trigger when using
      Throw as overflow_behavior. *)
  exception
    ActorDataInboxOverflow of
      { name : Yojson.Safe.t; capacity : int; attempt_enqueing : DataMessage.t }

  (** An already running actor is being spawned. *)
  exception RunningActorSpawned of { name : Yojson.Safe.t }

  (** Type of a actor *)
  type ('data_returns, 'data_overflew, 'control_msg, 'state) t

  (** Create an actor with specified fields, it's not running after creation *)
  val create :
       name:Yojson.Safe.t
    -> data_channel_type:
         ('state, DataMessage.t, 'data_returns, 'data_overflew) channel_type
    -> control_handler:
         (   state:'state
          -> message:'control_msg
          -> 'state msg_processed Deferred.t )
    -> data_handler:
         (   state:'state
          -> message:DataMessage.t
          -> 'state msg_processed Deferred.t )
    -> logger:Logger.t
    -> state:'state
    -> ('data_returns, 'data_overflew, 'control_msg, 'state) t

  val terminate :
    actor:('data_returns, 'data_overflew, 'control_msg, 'state) t -> unit

  (** [send_control ~actor ~message] sends a control message to an actor. *)
  val send_control :
       actor:('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> message:'control_msg
    -> unit

  (** [send_data ~actor ~message] sends a data message to an actor. *)
  val send_data :
    'data_returns 'data_overflew 'control_msg 'state.
       actor:('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> message:DataMessage.t
    -> 'data_returns

  (** [spwan actor] run's an actor, it returns a unit when the actor exits, and
      may throw some errors *)
  val spawn :
       ('data_returns, 'data_overflew, 'control_msg, 'state) t
    -> unit Deferred.Or_error.t
end
