open Pickles_types

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving sexp, sexp, compare, yojson, hash, equal]
  end
end]

val of_int : int -> t option

val of_int_exn : int -> t

val to_int : t -> int

val of_field :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> ( 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
     , Nat.N8.n )
     Vector.t

val typ :
     ('bvar, bool, 'f) Snarky_backendless.Typ.t
  -> (('bvar, Nat.N8.n) Vector.t, t, 'f) Snarky_backendless.Typ.t

val packed_typ :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> ('f Snarky_backendless.Cvar.t, t, 'f) Snarky_backendless.Typ.t
