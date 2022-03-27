module D = Digest
module Sc = Pickles_types.Scalar_challenge

module Basic : sig
  type (_, _, _) t = ..
end

type (_, _, _) Basic.t +=
  | Field :
      ('field1, 'field2, < field1 : 'field1 ; field2 : 'field2 ; .. >) Basic.t
  | Bool : ('bool1, 'bool2, < bool1 : 'bool1 ; bool2 : 'bool2 ; .. >) Basic.t
  | Digest :
      ( 'digest1
      , 'digest2
      , < digest1 : 'digest1 ; digest2 : 'digest2 ; .. > )
      Basic.t
  | Challenge :
      ( 'challenge1
      , 'challenge2
      , < challenge1 : 'challenge1 ; challenge2 : 'challenge2 ; .. > )
      Basic.t
  | Bulletproof_challenge :
      ( 'bp_chal1
      , 'bp_chal2
      , < bulletproof_challenge1 : 'bp_chal1
        ; bulletproof_challenge2 : 'bp_chal2
        ; .. > )
      Basic.t
  | Index :
      ('index1, 'index2, < index1 : 'index1 ; index2 : 'index2 ; .. >) Basic.t

module rec T : sig
  type (_, _, _) t =
    | B : ('a, 'b, 'env) Basic.t -> ('a, 'b, 'env) t
    | Scalar :
        ('a, 'b, 'env) Basic.t
        -> ( 'a Pickles_types.Scalar_challenge.t
           , 'b Pickles_types.Scalar_challenge.t
           , (< challenge1 : 'a ; challenge2 : 'b ; .. > as 'env) )
           t
    | Vector :
        ('t1, 't2, 'env) t * 'n Pickles_types.Nat.t
        -> ( ('t1, 'n) Pickles_types.Vector.t
           , ('t2, 'n) Pickles_types.Vector.t
           , 'env )
           t
    | Array : ('t1, 't2, 'env) t * int -> ('t1 array, 't2 array, 'env) t
    | Struct :
        ('xs1, 'xs2, 'env) Pickles_types.Hlist.H2_1.T(T).t
        -> ( 'xs1 Pickles_types.Hlist.HlistId.t
           , 'xs2 Pickles_types.Hlist.HlistId.t
           , 'env )
           t
end

type ('a, 'b, 'c) t = ('a, 'b, 'c) T.t =
  | B : ('a, 'b, 'env) Basic.t -> ('a, 'b, 'env) t
  | Scalar :
      ('a, 'b, 'env) Basic.t
      -> ( 'a Pickles_types.Scalar_challenge.t
         , 'b Pickles_types.Scalar_challenge.t
         , (< challenge1 : 'a ; challenge2 : 'b ; .. > as 'env) )
         t
  | Vector :
      ('t1, 't2, 'env) t * 'n Pickles_types.Nat.t
      -> ( ('t1, 'n) Pickles_types.Vector.t
         , ('t2, 'n) Pickles_types.Vector.t
         , 'env )
         t
  | Array : ('t1, 't2, 'env) t * int -> ('t1 array, 't2 array, 'env) t
  | Struct :
      ('xs1, 'xs2, 'env) Pickles_types.Hlist.H2_1.T(T).t
      -> ( 'xs1 Pickles_types.Hlist.HlistId.t
         , 'xs2 Pickles_types.Hlist.HlistId.t
         , 'env )
         t

type ('bool, 'env) pack =
  { pack : 'a 'b. ('a, 'b, 'env) Basic.t -> 'b -> 'bool list array }

type ('f, 'env) typ =
  { typ :
      'var 'value.    ('value, 'var, 'env) Basic.t
      -> ('var, 'value, 'f) Snarky_backendless.Typ.t
  }

type 'env exists = T : ('t1, 't2, 'env) t -> 'env exists

type generic_spec = { spec : 'env. 'env exists }

module ETyp : sig
  type ('var, 'value, 'f) t =
    | T :
        ('inner, 'value, 'f) Snarky_backendless.Typ.t * ('inner -> 'var)
        -> ('var, 'value, 'f) t
end

type ('f, 'env) etyp =
  { etyp :
      'var 'value. ('value, 'var, 'env) Basic.t -> ('var, 'value, 'f) ETyp.t
  }

val etyp :
  ('f, 'env) etyp -> ('value, 'var, 'env) t -> ('var, 'value, 'f) ETyp.t

module Common : functor (Impl : Snarky_backendless.Snark_intf.Run) -> sig
  module Digest : sig
    type t = Impl.Field.t

    val to_bits : t -> Impl.Boolean.var list

    module Unsafe : sig
      val to_bits_unboolean : t -> Impl.Boolean.var list
    end

    module Constant : sig
      module A = Composition_types__Digest.Constant.A

      val length : int

      type t =
        Limb_vector__Constant.Hex64.t Composition_types__Digest.Constant.A.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> int

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val equal : t -> t -> bool

      val of_bits :
           bool list
        -> ( Core_kernel.Int64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types.Vector.t

      val of_tock_field :
           Backend.Tock.Field.t
        -> ( Core_kernel.Int64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types.Vector.t

      val dummy : t

      module Stable = Composition_types__Digest.Constant.Stable

      val to_tick_field :
        (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> Backend.Tick.Field.t

      val to_tock_field :
        (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> Backend.Tock.Field.t

      val of_tick_field :
           Backend.Tick.Field.t
        -> ( Core_kernel.Int64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types.Vector.t

      val to_bits :
        (Core_kernel.Int64.t, 'a) Pickles_types.Vector.t -> bool list
    end

    val typ :
      ( t
      , ( Core_kernel.Int64.t
        , Composition_types__Digest.Limbs.n )
        Pickles_types.Vector.t )
      Impl.Typ.t
  end

  module Challenge : sig
    type nonrec t = Impl.field Limb_vector__Challenge.t

    module Constant : sig
      type t = Limb_vector__Challenge.Constant.t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val to_bits : t -> bool list

      val of_bits : bool list -> t

      val dummy : t
    end

    val typ' : [ `Constrained | `Unconstrained ] -> (t, Constant.t) Impl.Typ.t

    val typ_unchecked : (t, Constant.t) Impl.Typ.t

    val packed_typ : (Digest.t, Constant.t) Impl.Typ.t

    val to_bits : t -> Impl.Boolean.var list

    val length : int
  end

  module Env : sig
    type ('other_field, 'other_field_var, 'a) t = 'a
      constraint
        'a =
        < bool1 : bool
        ; bool2 : Impl.Boolean.var
        ; bulletproof_challenge1 :
            Challenge.Constant.t Pickles_types.Scalar_challenge.t
            Bulletproof_challenge.t
        ; bulletproof_challenge2 :
            Challenge.t Pickles_types.Scalar_challenge.t Bulletproof_challenge.t
        ; challenge1 : Challenge.Constant.t
        ; challenge2 : Challenge.t
        ; digest1 : Digest.Constant.t
        ; digest2 : Digest.t
        ; field1 : 'other_field
        ; field2 : 'other_field_var
        ; index1 : Index.t
        ; index2 :
            (Impl.Boolean.var, Pickles_types.Nat.N8.n) Pickles_types.Vector.t
        ; .. >
  end
end

val pack_basic :
     (module Snarky_backendless.Snark_intf.Run with type field = 'field)
  -> (   'other_field_var
      -> 'field Snarky_backendless__.Cvar.t
         Snarky_backendless.Snark_intf.Boolean0.t
         list
         array)
  -> ( 'field Snarky_backendless__.Cvar.t
       Snarky_backendless.Snark_intf.Boolean0.t
     , < bool1 : bool
       ; bool2 :
           'field Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'field Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'field Limb_vector__Challenge.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'field Snarky_backendless__.Cvar.t
       ; field1 : 'other_field
       ; field2 : 'other_field_var
       ; index1 : Index.t
       ; index2 :
           ( 'field Snarky_backendless__.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t
           , Pickles_types.Nat.N8.n )
           Pickles_types.Vector.t
       ; .. > )
     pack

val pack_basic_unboolean :
     (module Snarky_backendless.Snark_intf.Run with type field = 'field)
  -> (   'other_field_var
      -> 'field Snarky_backendless__.Cvar.t
         Snarky_backendless.Snark_intf.Boolean0.t
         list
         array)
  -> ( 'field Snarky_backendless__.Cvar.t
       Snarky_backendless.Snark_intf.Boolean0.t
     , < bool1 : bool
       ; bool2 :
           'field Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'field Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'field Limb_vector__Challenge.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'field Snarky_backendless__.Cvar.t
       ; field1 : 'other_field
       ; field2 : 'other_field_var
       ; index1 : Index.t
       ; index2 :
           ( 'field Snarky_backendless__.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t
           , Pickles_types.Nat.N8.n )
           Pickles_types.Vector.t
       ; .. > )
     pack

val pack :
     (module Snarky_backendless.Snark_intf.Run with type field = 'a)
  -> (   'b
      -> 'a Snarky_backendless__.Cvar.t Snarky_backendless.Snark_intf.Boolean0.t
         list
         array)
  -> ( 'c
     , 'd
     , < bool1 : bool
       ; bool2 :
           'a Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'a Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'a Limb_vector__Challenge.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'a Snarky_backendless__.Cvar.t
       ; field1 : 'e
       ; field2 : 'b
       ; index1 : Index.t
       ; index2 :
           ( 'a Snarky_backendless__.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t
           , Pickles_types.Nat.N8.n )
           Pickles_types.Vector.t
       ; .. > )
     t
  -> 'd
  -> 'a Snarky_backendless__.Cvar.t Snarky_backendless.Snark_intf.Boolean0.t
     list
     array

val typ_basic :
     (module Snarky_backendless.Snark_intf.Run with type field = 'field)
  -> challenge:[ `Constrained | `Unconstrained ]
  -> scalar_challenge:[ `Constrained | `Unconstrained ]
  -> ( 'other_field_var
     , 'other_field
     , 'field
     , (unit, unit, 'field) Snarky_backendless__.Checked.t )
     Snarky_backendless__.Types.Typ.t
  -> ( 'field
     , < bool1 : bool
       ; bool2 :
           'field Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'field Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'field Limb_vector__Challenge.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'field Snarky_backendless__.Cvar.t
       ; field1 : 'other_field
       ; field2 : 'other_field_var
       ; index1 : Index.t
       ; index2 :
           ( 'field Snarky_backendless__.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t
           , Pickles_types.Nat.N8.n )
           Pickles_types.Vector.t
       ; .. > )
     typ

val typ :
     challenge:[ `Constrained | `Unconstrained ]
  -> scalar_challenge:[ `Constrained | `Unconstrained ]
  -> (module Snarky_backendless.Snark_intf.Run with type field = 'a)
  -> ( 'b
     , 'c
     , 'a
     , (unit, unit, 'a) Snarky_backendless__.Checked.t )
     Snarky_backendless__.Types.Typ.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 :
           'a Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'a Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'a Limb_vector__Challenge.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'a Snarky_backendless__.Cvar.t
       ; field1 : 'c
       ; field2 : 'b
       ; index1 : Index.t
       ; index2 :
           ( 'a Snarky_backendless__.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t
           , Pickles_types.Nat.N8.n )
           Pickles_types.Vector.t
       ; .. > )
     t
  -> ('e, 'd, 'a) Snarky_backendless.Typ.t

val packed_typ_basic :
     (module Snarky_backendless.Snark_intf.Run with type field = 'field)
  -> ('other_field_var, 'other_field, 'field) ETyp.t
  -> ( 'field
     , < bool1 : bool
       ; bool2 :
           'field Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'field Snarky_backendless__.Cvar.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'field Snarky_backendless__.Cvar.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'field Snarky_backendless__.Cvar.t
       ; field1 : 'other_field
       ; field2 : 'other_field_var
       ; index1 : Index.t
       ; index2 : 'field Snarky_backendless__.Cvar.t
       ; .. > )
     etyp

val packed_typ :
     (module Snarky_backendless.Snark_intf.Run with type field = 'a)
  -> ('b, 'c, 'a) ETyp.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 :
           'a Snarky_backendless__.Cvar.t
           Snarky_backendless.Snark_intf.Boolean0.t
       ; bulletproof_challenge1 :
           Limb_vector__Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'a Snarky_backendless__.Cvar.t Pickles_types.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector__Challenge.Constant.t
       ; challenge2 : 'a Snarky_backendless__.Cvar.t
       ; digest1 :
           ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
       ; digest2 : 'a Snarky_backendless__.Cvar.t
       ; field1 : 'c
       ; field2 : 'b
       ; index1 : Index.t
       ; index2 : 'a Snarky_backendless__.Cvar.t
       ; .. > )
     t
  -> ('e, 'd, 'a) ETyp.t
