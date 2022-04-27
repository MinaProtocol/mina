(** The following module types define the different kinds of terms at the type
    level by their arity. These types are manipulated and passed around as
    parameters of the various functors defined in {!Hlist}.

    Each term is represented by a module containing a single n-ary type.
*)

(** The kind of values (no type parameters). *)
module type T0 = sig
  type t
end

(** Unary type functions (1 type parameter). *)
module type T1 = sig
  type _ t
end

(** Binary type functions (2 type parameters). *)
module type T2 = sig
  type (_, _) t
end

(** Ternary type functions (3 type parameters). *)
module type T3 = sig
  type (_, _, _) t
end

(** Quaternary type functions (4 type parameters). *)
module type T4 = sig
  type (_, _, _, _) t
end

(** Quinary type functions (5 type parameters). *)
module type T5 = sig
  type (_, _, _, _, _) t
end
