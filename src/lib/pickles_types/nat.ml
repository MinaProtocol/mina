type z = Z

type _ s = S

type _ t = Z : z t | S : 'n t -> 'n s t

let to_int : type n. n t -> int =
  let rec go : type n. int -> n t -> int =
   fun acc n -> match n with Z -> acc | S n -> go (acc + 1) n
  in
  fun x -> go 0 x

module type Intf = sig
  type n

  val n : n t
end

module S (N : Intf) : Intf with type n = N.n s = struct
  type n = N.n s

  let n = S N.n
end

module N0 = struct
  type n = z

  let n = Z
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
