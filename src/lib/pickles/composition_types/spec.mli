(** *)
type 'f impl = (module Snarky_backendless.Snark_intf.Run with type field = 'f)

(** *)

type (_, _, _) basic =
  | Field
      : ('field1, 'field2, < field1 : 'field1 ; field2 : 'field2 ; .. >) basic
  | Bool : ('bool1, 'bool2, < bool1 : 'bool1 ; bool2 : 'bool2 ; .. >) basic
  | Digest
      : ( 'digest1
        , 'digest2
        , < digest1 : 'digest1 ; digest2 : 'digest2 ; .. > )
        basic
  | Challenge
      : ( 'challenge1
        , 'challenge2
        , < challenge1 : 'challenge1 ; challenge2 : 'challenge2 ; .. > )
        basic
  | Bulletproof_challenge
      : ( 'bp_chal1
        , 'bp_chal2
        , < bulletproof_challenge1 : 'bp_chal1
          ; bulletproof_challenge2 : 'bp_chal2
          ; .. > )
        basic
  | Branch_data
      : ( 'branch_data1
        , 'branch_data2
        , < branch_data1 : 'branch_data1 ; branch_data2 : 'branch_data2 ; .. >
        )
        basic

(** *)
module type Bool_intf = sig
  type var

  val true_ : var

  val false_ : var
end

(** *)
module rec T : sig
  type (_, _, _) t =
    | B : ('a, 'b, 'env) basic -> ('a, 'b, 'env) t
    | Scalar :
        ('a, 'b, 'env) basic
        -> ( 'a Kimchi_backend_common.Scalar_challenge.t
           , 'b Kimchi_backend_common.Scalar_challenge.t
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
    | Opt :
        { inner : ('a1, 'a2, 'env) t
        ; flag : Pickles_types.Plonk_types.Opt.Flag.t
        ; dummy1 : 'a1
        ; dummy2 : 'a2
        ; bool : (module Bool_intf with type var = 'bool)
        }
        -> ( 'a1 option
           , ('a2, 'bool) Pickles_types.Plonk_types.Opt.t
           , (< bool1 : bool ; bool2 : 'bool ; .. > as 'env) )
           t
end

(** *)
val typ :
     assert_16_bits:('a Snarky_backendless.Cvar.t -> unit)
  -> 'a impl
  -> ( 'b
     , 'c
     , 'a
     , (unit, 'a) Snarky_backendless.Checked_ast.t )
     Snarky_backendless.Types.Typ.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 :
           'a Snarky_backendless.Cvar.t Snarky_backendless.Snark_intf.Boolean0.t
       ; branch_data1 : Branch_data.t
       ; branch_data2 : 'a Branch_data.Checked.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'a Limb_vector.Challenge.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : 'a Limb_vector.Challenge.t
       ; digest1 :
           ( Limb_vector.Constant.Hex64.t
           , Digest.Limbs.n )
           Pickles_types.Vector.vec
       ; digest2 : 'a Snarky_backendless.Cvar.t
       ; field1 : 'c
       ; field2 : 'b
       ; .. > )
     T.t
  -> ('e, 'd, 'a) Snarky_backendless.Typ.t

(** *)
module ETyp : sig
  type ('var, 'value, 'f) t =
    | T :
        ('inner, 'value, 'f) Snarky_backendless.Typ.t
        * ('inner -> 'var)
        * ('var -> 'inner)
        -> ('var, 'value, 'f) t
end

(** *)
val packed_typ :
     'a impl
  -> ('b, 'c, 'a) ETyp.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 :
           'a Snarky_backendless.Cvar.t Snarky_backendless.Snark_intf.Boolean0.t
       ; branch_data1 : Branch_data.t
       ; branch_data2 : 'a Snarky_backendless.Cvar.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'a Snarky_backendless.Cvar.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : 'a Snarky_backendless.Cvar.t
       ; digest1 :
           ( Limb_vector.Constant.Hex64.t
           , Digest.Limbs.n )
           Pickles_types.Vector.vec
       ; digest2 : 'a Snarky_backendless.Cvar.t
       ; field1 : 'c
       ; field2 : 'b
       ; .. > )
     T.t
  -> ('e, 'd, 'a) ETyp.t

(** *)
val pack :
     'f impl
  -> ( 'a
     , 'b
     , < bool1 : bool
       ; bool2 :
           'f Snarky_backendless.Cvar.t Snarky_backendless.Snark_intf.Boolean0.t
       ; branch_data1 : Branch_data.t
       ; branch_data2 : 'f Branch_data.Checked.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'f Limb_vector.Challenge.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : 'f Limb_vector.Challenge.t
       ; digest1 :
           ( Limb_vector.Constant.Hex64.t
           , Digest.Limbs.n )
           Pickles_types.Vector.vec
       ; digest2 : 'f Snarky_backendless.Cvar.t
       ; field1 : 'c
       ; field2 : 'd
       ; .. > )
     T.t
  -> 'b
  -> [ `Field of 'd | `Packed_bits of 'f Snarky_backendless.Cvar.t * int ] array
