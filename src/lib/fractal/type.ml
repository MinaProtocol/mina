open Hlist

module rec T : sig
  type (_, _) t =
    | Field : ('field, < field: 'field ; .. >) t
    | Polynomial : int -> ('poly, < poly: 'poly ; .. >) t
    | Pair : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t
    | Vector : ('a, 'e) t * 'n Vector.nat -> (('a, 'n) Vector.t, 'e) t
    | Hlist : ('a, 'e) Hlist2(T).t -> ('a HlistId.t, 'e) t
    | Proof : ('proof, < proof: 'proof ; .. >) t
end =
  T

module Hlist = Hlist2 (T)
include T

let field = Field
