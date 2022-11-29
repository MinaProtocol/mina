module Stable : sig
  module V1 : sig
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V1.t = N0 | N1 | N2
    [@@deriving sexp, compare, yojson, hash, equal]

    include Pickles_types.Sigs.Binable.S with type t := t

    include Pickles_types.Sigs.VERSIONED
  end
end

type t = Stable.V1.t = N0 | N1 | N2
[@@deriving sexp, compare, yojson, hash, equal]

val of_nat : 'n Pickles_types.Nat.t -> t

val of_int : int -> t

val to_int : t -> int

module One_hot : sig
  module Checked : sig
    type 'f t = ('f, Pickles_types.Nat.N3.n) One_hot_vector.t

    val to_input :
      'f t -> 'f Snarky_backendless.Cvar.t Random_oracle_input.Chunked.t
  end

  val to_input : zero:'a -> one:'a -> t -> 'a Random_oracle_input.Chunked.t

  val typ :
       (module Snarky_backendless.Snark_intf.Run with type field = 'f)
    -> ( 'f Checked.t
       , t
       , 'f
       , (unit, 'f) Snarky_backendless.Checked_ast.t )
       Snarky_backendless__.Types.Typ.t
end

type 'f boolean = 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t

type 'a vec2 = ('a, Pickles_types.Nat.N2.n) Pickles_types.Vector.t

module Prefix_mask : sig
  module Checked : sig
    type 'f t = 'f boolean vec2
  end

  val there : t -> bool vec2

  val back : bool vec2 -> t

  val typ :
       (module Snarky_backendless.Snark_intf.Run with type field = 'f)
    -> ( 'f Checked.t
       , t
       , 'f
       , (unit, 'f) Snarky_backendless.Checked_ast.t )
       Snarky_backendless__.Types.Typ.t
end
