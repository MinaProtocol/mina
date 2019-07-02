open Core_kernel

(*State monad with or_error (a monad of type (state -> (a * state) Or_error.t))  *)
module type State_intf = sig
  type t
end

module type State_intf1 = sig
  type 'a t
end

module type State_intf2 = sig
  type ('a, 'b) t
end

module type S = functor (State : State_intf) -> sig
  include Monad.S

  val run_state : 'a t -> state:State.t -> ('a * State.t) Or_error.t

  val get : State.t t

  val put : State.t -> unit t

  val error_if : bool -> message:string -> value:'a -> 'a t
end

module type S2 = functor (State : State_intf1) -> sig
  include Monad.S2

  val run_state :
    ('b, 'a) t -> state:'a State.t -> ('b * 'a State.t) Or_error.t

  val get : ('a State.t, 'a) t

  val put : 'a State.t -> (unit, 'a) t

  val error_if : bool -> message:string -> value:'a -> ('a, _) t
end

module type S3 = functor (State : State_intf2) -> sig
  include Monad.S3

  val run_state :
       ('c, 'a, 'b) t
    -> state:('a, 'b) State.t
    -> ('c * ('a, 'b) State.t) Or_error.t

  val get : (('a, 'b) State.t, 'a, 'b) t

  val put : ('a, 'b) State.t -> (unit, 'a, 'b) t

  val error_if : bool -> message:string -> value:'a -> ('a, _, _) t
end
