(* Base datatypes for strongly-typed heterogeneous lists. See their usage in
   {!Hlist}. *)

(** The type-level identity function. *)
module Id : sig
  type 'a t = 'a
end

(** [Length] encodes the length of lists as Peano integers.*)
module Length : sig
  (** As it is constructed, the type of integer [n] maintains a representation
      of n in the {!Nat} type (Peano natural integers) as well as a
      tuple of length [n]. The structure of this tuple matches the accumulated
      type parameter list of [Hlist.Hi_j], so that the typechecker can verify
      that the length matches a given [Hlist].

      For example, both the following value and its type represent the number 3:
      {[
        S (S (S Z))
          : (('a * ('b * ('c * unit))), Nat.(z s s s)) t
      ]}
  *)
  type (_, _) t =
    | Z : (unit, Nat.z) t
    | S : ('tail, 'n) t -> ('a * 'tail, 'n Nat.s) t

  (** [to_nat len] convert length [len] to an equivalent {!Nat}, thus dropping
      the left part of the pair. *)
  val to_nat : ('xs, 'n) t -> 'n Nat.t

  type 'xs n = T : 'n Nat.t * ('xs, 'n) t -> 'xs n

  (** [contr len1 len2] computes the witness of the equality between the lengths
      [len1] and [len2]. *)
  val contr : ('xs, 'n) t -> ('xs, 'm) t -> ('n, 'm) Base.Type_equal.t
end

(** [H1] is the datatype of heterogeneous lists whose content type varies over a
    single type parameter.

    [F] is a type function that maps that parameter to the actual contained type.

    For example, with
    {[module F = struct
        type 'a t = 'a option
      end]}
    [H1(F).t] is the type of lists that contain optional values of any type. One
    can be built with the usual list constructors:
    {[Some 1 :: None :: Some 'a' :: Some None :: None :: []
       : (int * ('a * (char * ('b option * ('c * unit))))) H1(F).t]}
*)
module H1 : functor (F : Poly_types.T1) -> sig
  type _ t = [] : unit t | ( :: ) : 'a F.t * 'b t -> ('a * 'b) t

  (** [length l] returns the length of list [l] (which is known at compile-time,
      as the depth of the type variable of [t]), which can be further reified as
      a Peano integer with {!Length.to_nat}. *)
  val length : 'tail1 t -> 'tail1 Length.n
end

(** [H1_1] is the datatype of heterogeneous lists whose content type varies over
    a single type parameter, but also varies homogeneously over another type
    parameter.

    The first parameter varies from cell to cell, the second one varies from
    list to list, and is fixed for a single list (similarly to a classical
    ['a list]).

    For example, with
    {[module F = struct
        type ('a, 's) t = First of 'a | Second of 's
      end]}
    [H1_1(F).t] is the type of lists of binary variants types of which the left
    type can vary for each cell but the right type is fixed.
    Such a list is:
    {[First 1 :: First 'a' :: Second "same" :: First 1.0 :: Second "type" :: []
       : (int * (char * ('a * (float * ('b * unit)))), string) H1(F).t]}
*)
module H1_1 : functor (F : Poly_types.T2) -> sig
  type (_, 's) t =
    | [] : (unit, 'c) t
    | ( :: ) : ('a, 's) F.t * ('b, 's) t -> ('a * 'b, 's) t

  (** See as {!H1.length}. *)
  val length : ('len, 'list) t -> 'len Length.n
end

(** [HlistId] is the simplest heteregeneous list.

    There is no common structure shared by its contained values. *)
module HlistId : sig
  type _ t = [] : unit t | ( :: ) : 'a Id.t * 'b t -> ('a * 'b) t

  val length : 'tail1 t -> 'tail1 Length.n
end
