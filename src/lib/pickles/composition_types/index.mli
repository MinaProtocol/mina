open Pickles_types

type t [@@deriving sexp, bin_io, sexp, compare, yojson, hash, eq]

val of_int : int -> t option

val of_int_exn : int -> t

val to_int : t -> int

val of_field :
     (module Snarky.Snark_intf.Run with type field = 'f)
  -> 'f Snarky.Cvar.t
  -> ('f Snarky.Cvar.t Snarky.Boolean.t, Nat.N8.n) Vector.t

val typ :
     ('bvar, bool, 'f) Snarky.Typ.t
  -> (('bvar, Nat.N8.n) Vector.t, t, 'f) Snarky.Typ.t

val packed_typ :
     (module Snarky.Snark_intf.Run with type field = 'f)
  -> ('f Snarky.Cvar.t, t, 'f) Snarky.Typ.t
