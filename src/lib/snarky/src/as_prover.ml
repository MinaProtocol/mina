open Core_kernel

type ('a, 'e, 's) t = ('a, 'e, 's) As_prover0.t

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
         ('a, env, 'prover_state) As_prover0.t
      -> ('a t, 'prover_state, field, var, 'sys) Checked.t

    val get : 'a t -> ('a, env, _) As_prover0.t

    val set : 'a t -> 'a -> (unit, env, _) As_prover0.t
  end
end

module T = struct
  include As_prover0.T

  let read ({read; _} : ('var, 'value, 'field, 'cvar, 'sys) Typ.t) (var : 'var)
      : ('value, 'cvar -> 'field, 'prover_state) t =
   fun tbl s -> (s, Typ_monads.Read.run (read var) tbl)

  module Ref = struct
    type 'a t = 'a option ref

    let create (x : ('a, 'cvar -> 'field, 's) As_prover0.t) :
        ('a t, 's, 'field, 'cvar, 'sys) Checked.t =
      let r = ref None in
      let open Checked in
      let%map () =
        Checked.as_prover (As_prover0.map x ~f:(fun x -> r := Some x))
      in
      r

    let get (r : 'a t) _tbl s = (s, Option.value_exn !r)

    let set (r : 'a t) x _tbl s = (s, (r := Some x))
  end
end

module Make (Env : sig
  type var

  type field
end) =
struct
  include Env

  type env = var -> field

  type nonrec ('a, 's) t = ('a, env, 's) t

  include T

  module T = struct
    type nonrec ('a, 's) t = ('a, 's) t

    let map = `Custom map

    let bind = bind

    let return = return
  end

  include Monad.Make2 (T)
end

include T

include Monad.Make3 (struct
  type nonrec ('a, 'e, 's) t = ('a, 'e, 's) t

  let map = `Custom map

  let bind = bind

  let return = return
end)
