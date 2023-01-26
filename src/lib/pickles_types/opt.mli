(* Implementation of an extended nullable type *)

(** {1 Type} *)

type ('a, 'bool) t =
  | Some of 'a
  | None
  | Maybe of 'bool * 'a
      (** Representation of a value that can either be [None] or [Some]
                            depending on the actual value of its first parameter. *)
[@@deriving sexp, compare, yojson, hash, equal]

(** {1 Constructors} *)
val some : 'a -> ('a, 'bool) t

val none : ('a, 'bool) t

val maybe : 'bool -> 'a -> ('a, 'bool) t

val map : ('a, 'bool) t -> f:('a -> 'b) -> ('b, 'bool) t

(** [value_exn o] is v when [o] if [Some v] or [Maybe (_, v)].

     @raise Invalid_argument if [o] is [None]
  **)
val value_exn : ('a, 'bool) t -> 'a

(** [to_option opt] is [Some v] when [opt] if [Some v] or [Maybe (_, v)], [None]
    otherwise *)
val to_option : ('a, 'bool) t -> 'a option

(** [of_option o] is a straightforward injection of a regular option type [o]
    into type {!type:t}.

    {!const:Option.Some} maps to {!const:Some} and {!const:Option.None} to
    {!const:None}.
*)
val of_option : 'a option -> ('a, 'bool) t

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
