(* Implementation of an extended nullable type *)

type ('a, 'bool) t = Some of 'a | None | Maybe of 'bool * 'a
[@@deriving sexp, compare, yojson, hash, equal]

val map : ('a, 'bool) t -> f:('a -> 'b) -> ('b, 'bool) t

(** [value_exn o] is v when [o] if [Some v] or [Maybe (_, v)].

     @raise Invalid_argument if [o] is [None]
  **)
val value_exn : ('a, 'bool) t -> 'a

(** [value_exn o] is [Some v] when [o] if [Some v] or [Maybe (_, v)], [None]
      otherwise *)
val to_option : ('a, 'bool) t -> 'a option

module Flag : sig
  type t = Yes | No | Maybe [@@deriving sexp, compare, yojson, hash, equal]
end

val constant_layout_typ :
     ('b, bool, 'f) Snarky_backendless.Typ.t
  -> true_:'b
  -> false_:'b
  -> Flag.t
  -> ('a_var, 'a, 'f) Snarky_backendless.Typ.t
  -> dummy:'a
  -> dummy_var:'a_var
  -> (('a_var, 'b) t, 'a option, 'f) Snarky_backendless.Typ.t

val typ :
     ('b, bool, 'f) Snarky_backendless.Typ.t
  -> Flag.t
  -> ('a_var, 'a, 'f) Snarky_backendless.Typ.t
  -> dummy:'a
  -> (('a_var, 'b) t, 'a option, 'f) Snarky_backendless.Typ.t

(** A sequence that should be considered to have stopped at
       the first occurence of {!Flag.No} *)
module Early_stop_sequence : sig
  type nonrec ('a, 'bool) t = ('a, 'bool) t list

  val fold :
       ('bool -> then_:'res -> else_:'res -> 'res)
    -> ('a, 'bool) t
    -> init:'acc
    -> f:('acc -> 'a -> 'acc)
    -> finish:('acc -> 'res)
    -> 'res
end
