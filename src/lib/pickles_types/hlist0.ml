open Poly_types

(** Base datatypes for strongly-typed heterogeneous lists. See their usage in
    {!Hlist}. *)

(** Encoding of list length as a Peano integer. *)
module Length = struct
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

  (** Convert a length to an equivalent {!Nat} (dropping the left part of
      the pair. *)
  let rec to_nat : type xs n. (xs, n) t -> n Nat.t = function
    | Z ->
        Z
    | S n ->
        S (to_nat n)

  type 'xs n = T : 'n Nat.t * ('xs, 'n) t -> 'xs n

  (** Witness of the equality between two lengths. *)
  let rec contr :
      type xs n m. (xs, n) t -> (xs, m) t -> (n, m) Core_kernel.Type_equal.t =
   fun t1 t2 ->
    match (t1, t2) with
    | Z, Z ->
        T
    | S n, S m ->
        let T = contr n m in
        T
end

(** Data type of heterogeneous lists whose content type varies over a single type
    parameter.

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
module H1 (F : T1) = struct
  type _ t = [] : unit t | ( :: ) : 'a F.t * 'b t -> ('a * 'b) t

  (** The length of the list (which is known at compile-time, as the depth of
      the type variable of [t]) can be reified as a Peano integer with
      [length]. *)
  let rec length : type tail1. tail1 t -> tail1 Length.n = function
    | [] ->
        T (Z, Z)
    | _ :: xs ->
        let (T (n, p)) = length xs in
        T (S n, S p)
end

(** Data type of heterogeneous lists whose content type varies over a single type
    parameter, but also varies homogeneously over another type parameter.

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
module H1_1 (F : T2) = struct
  type (_, 's) t =
    | [] : (unit, _) t
    | ( :: ) : ('a, 's) F.t * ('b, 's) t -> ('a * 'b, 's) t

  (** See as {!H1.length}. *)
  let rec length : type tail1 tail2. (tail1, tail2) t -> tail1 Length.n =
    function
    | [] ->
        T (Z, Z)
    | _ :: xs ->
        let (T (n, p)) = length xs in
        T (S n, S p)
end

(** The type-level identity function. *)
module Id = struct
  type 'a t = 'a
end

(** The simplest heteregeneous list. There is no common structure shared by its
    contained values. *)
module HlistId = H1 (Id)
