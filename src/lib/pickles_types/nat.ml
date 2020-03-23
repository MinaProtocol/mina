type z = Z

type _ s = S

type _ t = Z : z t | S : 'n t -> 'n s t

type 'a nat = 'a t

let to_int : type n. n t -> int =
  let rec go : type n. int -> n t -> int =
   fun acc n -> match n with Z -> acc | S n -> go (acc + 1) n
  in
  fun x -> go 0 x

module type Intf = sig
  type n

  val n : n t
end

module Adds = struct
  type ('a, 'b, 'c) t =
    | Z : (z, 'n, 'n) t
    | S : ('a, 'b, 'c) t -> ('a s, 'b, 'c s) t

  let rec add_zr : type n. n nat -> (n, z, n) t = function
    | Z ->
        Z
    | S n ->
        let pi = add_zr n in
        S pi
end

module Add = struct
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

    val eq : (n, z plus_n) Core_kernel.Type_equal.t

    val n : z plus_n t

    val add : 'm nat -> 'm plus_n nat * (z plus_n, 'm, 'm plus_n) Adds.t
  end
end

module N0 = struct
  type 'a plus_n = 'a

  type n = z

  let n = Z

  let add m = (m, Adds.Z)

  let eq = Core_kernel.Type_equal.T
end

module S (N : Add.Intf) = struct
  type 'a plus_n = 'a N.plus_n s

  type n = z plus_n

  let n = S N.n

  let add m =
    let k, pi = N.add m in
    (S k, Adds.S pi)

  let eq = match N.eq with T -> Core_kernel.Type_equal.T
end

module N1 = S (N0)
module N2 = S (N1)
module N3 = S (N2)
module N4 = S (N3)
module N5 = S (N4)
module N6 = S (N5)
module N7 = S (N6)
module N8 = S (N7)
module N9 = S (N8)
module N10 = S (N9)
module N11 = S (N10)
module N12 = S (N11)
module N13 = S (N12)
module N14 = S (N13)
module N15 = S (N14)
module N16 = S (N15)
module N17 = S (N16)
module N18 = S (N17)
module N19 = S (N18)
module N20 = S (N19)
module N21 = S (N20)
module N22 = S (N21)
module N23 = S (N22)
module N24 = S (N23)
module N25 = S (N24)
module N26 = S (N25)
module N27 = S (N26)
module N28 = S (N27)
module N29 = S (N28)
module N30 = S (N29)

module Empty = struct
  type t = T of t

  let rec elim : type a. t -> a = function T t -> elim t
end

module Not = struct
  type 'a t = 'a -> Empty.t
end

open Core_kernel

let rec eq : type n m.
       n nat
    -> m nat
    -> [`Equal of (n, m) Type_equal.t | `Not_equal of (n, m) Type_equal.t Not.t]
    =
 fun n m ->
  match (n, m) with
  | Z, Z ->
      `Equal T
  | S _, Z ->
      `Not_equal (function _ -> .)
  | Z, S _ ->
      `Not_equal (function _ -> .)
  | S n, S m -> (
    match eq n m with
    | `Equal T ->
        `Equal T
    | `Not_equal f ->
        `Not_equal (function T -> f T) )
