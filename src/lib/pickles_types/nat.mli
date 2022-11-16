(** Representation of naturals for Pickles *)

(** {1 Type definitions} *)

(** [z] is uninhabited *)
type z = Z of z

type 'a s = Z | S of 'a

type _ t = Z : z t | S : 'n t -> 'n s t

type 'a nat = 'a t

type e = T : 'n nat -> e

(** {1 Modules} *)

module type Intf = sig
  type n

  val n : n t
end

module Adds : sig
  type ('a, 'b, 'c) t =
    | Z : (z, 'n, 'n) t
    | S : ('a, 'b, 'c) t -> ('a s, 'b, 'c s) t

  val add_zr : 'n nat -> ('n, z, 'n) t
end

module Lte : sig
  type (_, _) t = Z : (z, 'a) t | S : ('n, 'm) t -> ('n s, 'm s) t

  val refl : 'n nat -> ('n, 'n) t

  val trans : ('a, 'b) t -> ('b, 'c) t -> ('a, 'c) t
end

module Add : sig
  module type Intf = sig
    type _ plus_n

    type n

    val eq : (n, z plus_n) Core_kernel.Type_equal.t

    val n : z plus_n t

    val add : 'm nat -> 'm plus_n nat * (z plus_n, 'm, 'm plus_n) Adds.t
  end

  module type Intf_transparent = sig
    type _ plus_n

    type n = z plus_n

    val eq : (n, n) Base.Type_equal.t

    val n : z plus_n nat

    val add : 'm nat -> 'm plus_n nat * (z plus_n, 'm, 'm plus_n) Adds.t
  end

  val n : 'n. (module Intf with type n = 'n) -> 'n nat

  val create : 'n nat -> (module Intf with type n = 'n)
end

module type I = Add.Intf_transparent

(** {2 Module encoding naturals} *)

module N0 : I with type 'a plus_n = 'a

module N1 : I with type 'a plus_n = 'a s

module N2 : I with type 'a plus_n = 'a N1.plus_n s

module N3 : I with type 'a plus_n = 'a N2.plus_n s

module N4 : I with type 'a plus_n = 'a N3.plus_n s

module N5 : I with type 'a plus_n = 'a N4.plus_n s

module N6 : I with type 'a plus_n = 'a N5.plus_n s

module N7 : I with type 'a plus_n = 'a N6.plus_n s

module N8 : I with type 'a plus_n = 'a N7.plus_n s

module N9 : I with type 'a plus_n = 'a N8.plus_n s

module N10 : I with type 'a plus_n = 'a N9.plus_n s

module N11 : I with type 'a plus_n = 'a N10.plus_n s

module N12 : I with type 'a plus_n = 'a N11.plus_n s

module N13 : I with type 'a plus_n = 'a N12.plus_n s

module N14 : I with type 'a plus_n = 'a N13.plus_n s

module N15 : I with type 'a plus_n = 'a N14.plus_n s

module N16 : I with type 'a plus_n = 'a N15.plus_n s

module N17 : I with type 'a plus_n = 'a N16.plus_n s

module N18 : I with type 'a plus_n = 'a N17.plus_n s

module N19 : I with type 'a plus_n = 'a N18.plus_n s

module N20 : I with type 'a plus_n = 'a N19.plus_n s

module N21 : I with type 'a plus_n = 'a N20.plus_n s

module N22 : I with type 'a plus_n = 'a N21.plus_n s

module N23 : I with type 'a plus_n = 'a N22.plus_n s

module N24 : I with type 'a plus_n = 'a N23.plus_n s

module N25 : I with type 'a plus_n = 'a N24.plus_n s

module N26 : I with type 'a plus_n = 'a N25.plus_n s

module N27 : I with type 'a plus_n = 'a N26.plus_n s

module N28 : I with type 'a plus_n = 'a N27.plus_n s

module N29 : I with type 'a plus_n = 'a N28.plus_n s

module N30 : I with type 'a plus_n = 'a N29.plus_n s

module N31 : I with type 'a plus_n = 'a N30.plus_n s

module N32 : I with type 'a plus_n = 'a N31.plus_n s

module N33 : I with type 'a plus_n = 'a N32.plus_n s

module N34 : I with type 'a plus_n = 'a N33.plus_n s

module N35 : I with type 'a plus_n = 'a N34.plus_n s

module N36 : I with type 'a plus_n = 'a N35.plus_n s

module N37 : I with type 'a plus_n = 'a N36.plus_n s

module N38 : I with type 'a plus_n = 'a N37.plus_n s

module N39 : I with type 'a plus_n = 'a N38.plus_n s

module N40 : I with type 'a plus_n = 'a N39.plus_n s

module N41 : I with type 'a plus_n = 'a N40.plus_n s

module N42 : I with type 'a plus_n = 'a N41.plus_n s

module N43 : I with type 'a plus_n = 'a N42.plus_n s

module N44 : I with type 'a plus_n = 'a N43.plus_n s

module N45 : I with type 'a plus_n = 'a N44.plus_n s

module N46 : I with type 'a plus_n = 'a N45.plus_n s

module N47 : I with type 'a plus_n = 'a N46.plus_n s

module N48 : I with type 'a plus_n = 'a N47.plus_n s

module Empty : sig
  type t = T of t

  val elim : t -> 'a
end

module Not : sig
  type 'a t = 'a -> Empty.t
end

(** {1 Functions} *)

val to_int : 'n. 'n t -> int

val of_int : int -> e

val lte_exn : 'a nat -> 'b nat -> ('a, 'b) Lte.t

val eq_exn : 'n 'm. 'n nat -> 'm nat -> ('n, 'm) Core_kernel.Type_equal.t

val compare :
  'n 'm. 'n t -> 'm t -> [ `Lte of ('n, 'm) Lte.t | `Gt of ('n, 'm) Lte.t Not.t ]

val gt_implies_gte :
  'n 'm. 'n nat -> 'm nat -> ('n, 'm) Lte.t Not.t -> ('m, 'n) Lte.t
