open Core_kernel

include Monad.S3 with type ('a, 'e, 's) t = 'e -> 's -> 's * 'a

type ('a, 'e, 's) as_prover = ('a, 'e, 's) t

val run : ('a, 'e, 's) t -> 'e -> 's -> 's * 'a

module type S = sig
  type var

  type field

  type env = var -> field

  include Monad.S2 with type ('a, 's) t = ('a, env, 's) t

  val run : ('a, 's) t -> env -> 's -> 's * 'a

  val get_state : ('s, 's) t

  val set_state : 's -> (unit, 's) t

  val modify_state : ('s -> 's) -> (unit, 's) t

  val map2 : ('a, 's) t -> ('b, 's) t -> f:('a -> 'b -> 'c) -> ('c, 's) t

  val read_var : var -> (field, 's) t

  val read :
    ('var, 'value, field, var, 'sys) Typ.t -> 'var -> ('value, 'prover_state) t

  module Ref : sig
    type 'a t

    val create :
         ('a, env, 'prover_state) as_prover
      -> ('a t, 'prover_state, field, var, 'sys) Checked.t

    val get : 'a t -> ('a, env, _) as_prover

    val set : 'a t -> 'a -> (unit, env, _) as_prover
  end
end

module Make (Env : sig
  type var

  type field
end) : S with type var := Env.var with type field := Env.field
