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

module type S = sig
  include Monad.S

  type state

  val run_state : 'a t -> state:state -> ('a * state) Or_error.t

  val get : state t

  val put : state -> unit t

  val error_if : bool -> message:string -> value:'a -> 'a t
end

module type S2 = sig
  include Monad.S2

  type 'a state

  val run_state : ('b, 'a) t -> state:'a state -> ('b * 'a state) Or_error.t

  val get : ('a state, 'a) t

  val put : 'a state -> (unit, 'a) t

  val error_if : bool -> message:string -> value:'a -> ('a, _) t
end

module type S3 = sig
  include Monad.S3

  type ('a, 'b) state

  val run_state :
    ('c, 'a, 'b) t -> state:('a, 'b) state -> ('c * ('a, 'b) state) Or_error.t

  val get : (('a, 'b) state, 'a, 'b) t

  val put : ('a, 'b) state -> (unit, 'a, 'b) t

  val error_if : bool -> message:string -> value:'a -> ('a, _, _) t
end
