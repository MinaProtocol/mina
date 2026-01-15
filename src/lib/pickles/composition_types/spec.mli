(** {1 Spec - Type Specification DSL for Circuit Data Layouts}

    This module provides a domain-specific language (DSL) for specifying
    the layout of data structures in circuits. It bridges the gap between
    high-level structured types and their low-level circuit representations.

    {2 Purpose}

    Pickles needs to convert between:
    - Structured data (records, nested types) used in application logic
    - Flat data layouts (vectors of field elements) used in circuits
    - Packed representations for public inputs

    The [Spec] DSL describes this mapping declaratively.

    {2 Type System}

    The specification uses a dual-type system:
    - Type 1 (e.g., ['field1], ['challenge1]): Native/constant values
    - Type 2 (e.g., ['field2], ['challenge2]): Circuit variable values

    An "environment" type (the ['env] parameter) tracks which type names
    correspond to which actual types, using OCaml's row polymorphism.

    {2 Basic Types}

    - [Unit]: No data
    - [Field]: A field element
    - [Bool]: A boolean
    - [Digest]: A hash digest (typically a field element)
    - [Challenge]: A Fiat-Shamir challenge
    - [Bulletproof_challenge]: An IPA challenge
    - [Branch_data]: Encoded branch/domain information

    {2 Compound Types}

    - [B]: Wraps a basic type
    - [Scalar]: A basic type wrapped as a scalar challenge
    - [Vector]: Fixed-length vector of elements
    - [Array]: Variable-length array
    - [Struct]: Heterogeneous list (HList) of different types
    - [Opt]: Optional value with flag for circuit optionality
    - [Constant]: Value known at compile time

    {2 Key Functions}

    - {!val:typ}: Convert spec to snarky Typ.t for Step circuits
    - {!val:wrap_typ}: Convert spec to snarky Typ.t for Wrap circuits
    - {!val:pack}: Pack structured data into flat circuit representation
    - {!val:packed_typ}: Type with packed representation

    {2 Implementation Notes for Rust Port}

    - The dual-type system maps to Rust generics with trait bounds
    - Row polymorphism (< field1: ..; ..>) can use associated types
    - Consider using a proc macro to generate the type mappings
    - The [Opt] handling needs special care for circuit optionality

    @see {!Composition_types} for types that use this spec system
*)

(** Implementation module type for snarky backends. *)
type ('f, 'v) impl =
  (module Snarky_backendless.Snark_intf.Run
     with type field = 'f
      and type field_var = 'v )

module type Branch_data_checked = sig
  type field_var

  type t

  val pack : t -> field_var
end

type ('branch_data, 'f) branch_data =
  (module Branch_data_checked with type field_var = 'f and type t = 'branch_data)

(** Basic types *)
type (_, _, _) basic =
  | Unit : (unit, unit, < .. >) basic
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

(** Compound types. These are built from Basic types described above *)
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
        ; flag : Pickles_types.Opt.Flag.t
        ; dummy1 : 'a1
        ; dummy2 : 'a2
        }
        -> ( 'a1 option
           , ('a2, 'bool) Pickles_types.Opt.t
           , (< bool1 : bool ; bool2 : 'bool ; .. > as 'env) )
           t
    | Opt_unflagged :
        { inner : ('a1, 'a2, (< bool1 : bool ; bool2 : 'bool ; .. > as 'env)) t
        ; flag : Pickles_types.Opt.Flag.t
        ; dummy1 : 'a1
        ; dummy2 : 'a2
        }
        -> ('a1 option, 'a2 option, 'env) t
    | Constant : 'a * ('a -> 'a -> unit) * ('a, 'b, 'env) t -> ('a, 'b, 'env) t
end

module Step_impl := Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl := Kimchi_pasta_snarky_backend.Wrap_impl

val typ :
     assert_16_bits:(Step_impl.Field.t -> unit)
  -> ('b, 'c) Step_impl.Typ.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 : Step_impl.Boolean.var
       ; branch_data1 : Branch_data.t
       ; branch_data2 : Branch_data.Checked.Step.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           Step_impl.Field.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : Step_impl.Field.t
       ; digest1 : Digest.Constant.t
       ; digest2 : Step_impl.Field.t
       ; field1 : 'c
       ; field2 : 'b
       ; .. > )
     T.t
  -> ('e, 'd) Step_impl.Typ.t

val wrap_typ :
     assert_16_bits:(Wrap_impl.Field.t -> unit)
  -> ('b, 'c) Wrap_impl.Typ.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 : Wrap_impl.Boolean.var
       ; branch_data1 : Branch_data.t
       ; branch_data2 : Branch_data.Checked.Wrap.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           Wrap_impl.Field.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : Wrap_impl.Field.t
       ; digest1 : Digest.Constant.t
       ; digest2 : Wrap_impl.Field.t
       ; field1 : 'c
       ; field2 : 'b
       ; .. > )
     T.t
  -> ('e, 'd) Wrap_impl.Typ.t

module Make_ETyp (Impl : sig
  module Typ : sig
    type ('var, 'value) t
  end
end) : sig
  type ('var, 'value) t =
    | T :
        ('inner, 'value) Impl.Typ.t * ('inner -> 'var) * ('var -> 'inner)
        -> ('var, 'value) t
end

module Step_etyp :
    module type of Make_ETyp (Kimchi_pasta_snarky_backend.Step_impl)

module Wrap_etyp :
    module type of Make_ETyp (Kimchi_pasta_snarky_backend.Wrap_impl)

val packed_typ :
     ('b, 'c) Step_etyp.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 : Step_impl.Boolean.var
       ; branch_data1 : Branch_data.t
       ; branch_data2 : Step_impl.Field.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           Step_impl.Field.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : Step_impl.Field.t
       ; digest1 : Digest.Constant.t
       ; digest2 : Step_impl.Field.t
       ; field1 : 'c
       ; field2 : 'b
       ; .. > )
     T.t
  -> ('e, 'd) Step_etyp.t

val wrap_packed_typ :
     ('b, 'c) Wrap_etyp.t
  -> ( 'd
     , 'e
     , < bool1 : bool
       ; bool2 : Wrap_impl.Boolean.var
       ; branch_data1 : Branch_data.t
       ; branch_data2 : Wrap_impl.Field.t
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           Wrap_impl.Field.t Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : Wrap_impl.Field.t
       ; digest1 : Digest.Constant.t
       ; digest2 : Wrap_impl.Field.t
       ; field1 : 'c
       ; field2 : 'b
       ; .. > )
     T.t
  -> ('e, 'd) Wrap_etyp.t

val pack :
     ('f, 'v) impl
  -> ('branch_data_checked, 'v) branch_data
  -> ( 'a
     , 'b
     , < bool1 : bool
       ; bool2 : 'v Snarky_backendless.Boolean.t
       ; branch_data1 : Branch_data.t
       ; branch_data2 : 'branch_data_checked
       ; bulletproof_challenge1 :
           Limb_vector.Challenge.Constant.t
           Kimchi_backend_common.Scalar_challenge.t
           Bulletproof_challenge.t
       ; bulletproof_challenge2 :
           'v Kimchi_backend_common.Scalar_challenge.t Bulletproof_challenge.t
       ; challenge1 : Limb_vector.Challenge.Constant.t
       ; challenge2 : 'v
       ; digest1 : Digest.Constant.t
       ; digest2 : 'v
       ; field1 : 'c
       ; field2 : 'd
       ; .. > )
     T.t
  -> 'b
  -> [ `Field of 'd | `Packed_bits of 'v * int ] array
