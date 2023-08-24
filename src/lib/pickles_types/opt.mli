(* Implementation of an extended nullable type *)

(** {1 Type} *)

type ('a, 'bool) t =
  | Just of 'a
  | Nothing
  | Maybe of 'bool * 'a
      (** Representation of a value that can either be [None] or [Some]
                            depending on the actual value of its first parameter. *)
[@@deriving sexp, compare, yojson, hash, equal]

(** {1 Constructors} *)

val just : 'a -> ('a, 'bool) t

val nothing : ('a, 'bool) t

val maybe : 'bool -> 'a -> ('a, 'bool) t

(** {1 Iterators} *)

val map : ('a, 'bool) t -> f:('a -> 'b) -> ('b, 'bool) t

(** {1 Accessors and convertors} *)

(** [value_exn o] is v when [o] if [Some v] or [Maybe (_, v)].

     @raise Invalid_argument if [o] is [None]
  **)
val value_exn : ('a, 'bool) t -> 'a

(** [to_option_unsafe opt] is [Some v] when [opt] if [Just v] or [Maybe (_, v)],
    [None] otherwise *)
val to_option_unsafe : ('a, 'bool) t -> 'a option

(** [to_option bool_opt] maps {!const:Just}, resp. {!const:Nothing}, to
    {!const:Option.Some}, resp. {!const:Option.None}.
    
    The difference with {!val:to_option_unsafe} lies in the treatment of
    {!const:Maybe}, where [Maybe(false, x)] maps to {!val:Option.None} and
    [Maybe(true, x)] to [Option.Some x].
 *)
val to_option : ('a, bool) t -> 'a option

(** [of_option o] is a straightforward injection of a regular {!type:Option.t}
    value [o] into type {!type:t}.

    {!const:Option.Some} maps to {!const:Just} and {!const:Option.None} to
    {!const:Nothing}.
*)
val of_option : 'a option -> ('a, 'bool) t

(** [lift ?on_maybe ~nothing f] lifts the application of function [f] to a value
    of type !{type:('a, 'bool) t} as follows:
    - [Just v]: apply [f] to contained value [v]
    - [Nothing]: return the value specified by [nothing]
    - [Maybe (b, v)]: defaults to the case [Some v] when [on_maybe] is
      unspecified, otherwise apply [on_maybe b v]
*)
val lift :
  ?on_maybe:('a -> 'b -> 'c) -> nothing:'c -> ('b -> 'c) -> ('b, 'a) t -> 'c

module Flag : sig
  type t = Yes | No | Maybe [@@deriving sexp, compare, yojson, hash, equal]

  (** [( ||| )] is a commutative ternary disjunction on {!type:t} with 
      a similar specification to its usual Boolean [||] counterpart:

      - [Yes] is absorbing: [Yes ||| x] is [Yes]
      - [No] is neutral:    [No ||| x]  is [x]
   *)
  val ( ||| ) : t -> t -> t
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
