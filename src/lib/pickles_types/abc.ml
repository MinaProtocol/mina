open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = {a: 'a; b: 'a; c: 'a}
    [@@deriving fields, sexp, compare, yojson]
  end
end]

type 'a t = 'a Stable.Latest.t = {a: 'a; b: 'a; c: 'a}
[@@deriving fields, sexp, compare, yojson, hlist]

module H_list = Snarky.H_list

let typ (type a b f) (g : (a, b, f) Snarky.Typ.t) : (a t, b t, f) Snarky.Typ.t
    =
  Snarky.Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let map {a; b; c} ~f = {a= f a; b= f b; c= f c}

let map2 t1 t2 ~f = {a= f t1.a t2.a; b= f t1.b t2.b; c= f t1.c t2.c}

module Label = struct
  type t = A | B | C [@@deriving eq]

  let all = [A; B; C]
end

let abc a b c = function Label.A -> a | B -> b | C -> c
