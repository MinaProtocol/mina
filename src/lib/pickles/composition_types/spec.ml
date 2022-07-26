module D = Digest
open Core_kernel
open Pickles_types
open Hlist
module Sc = Kimchi_backend_common.Scalar_challenge

module Basic = struct
  type (_, _, _) t =
    | Field : ('field1, 'field2, < field1 : 'field1 ; field2 : 'field2 ; .. >) t
    | Bool : ('bool1, 'bool2, < bool1 : 'bool1 ; bool2 : 'bool2 ; .. >) t
    | Digest
        : ( 'digest1
          , 'digest2
          , < digest1 : 'digest1 ; digest2 : 'digest2 ; .. > )
          t
    | Challenge
        : ( 'challenge1
          , 'challenge2
          , < challenge1 : 'challenge1 ; challenge2 : 'challenge2 ; .. > )
          t
    | Bulletproof_challenge
        : ( 'bp_chal1
          , 'bp_chal2
          , < bulletproof_challenge1 : 'bp_chal1
            ; bulletproof_challenge2 : 'bp_chal2
            ; .. > )
          t
    | Branch_data
        : ( 'branch_data1
          , 'branch_data2
          , < branch_data1 : 'branch_data1 ; branch_data2 : 'branch_data2 ; .. >
          )
          t
end

open Basic

type ('a, 'b, 'c) basic = ('a, 'b, 'c) Basic.t =
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

module rec T : sig
  type (_, _, _) t =
    | B : ('a, 'b, 'env) Basic.t -> ('a, 'b, 'env) t
    | Scalar :
        ('a, 'b, (< challenge1 : 'a ; challenge2 : 'b ; .. > as 'env)) Basic.t
        -> ('a Sc.t, 'b Sc.t, 'env) t
    | Vector :
        ('t1, 't2, 'env) t * 'n Nat.t
        -> (('t1, 'n) Vector.t, ('t2, 'n) Vector.t, 'env) t
    | Array : ('t1, 't2, 'env) t * int -> ('t1 array, 't2 array, 'env) t
    | Struct :
        ('xs1, 'xs2, 'env) H2_1.T(T).t
        -> ('xs1 Hlist.HlistId.t, 'xs2 Hlist.HlistId.t, 'env) t
end =
  T

include T

type ('scalar, 'env) pack =
  { pack : 'a 'b. ('a, 'b, 'env) Basic.t -> 'b -> 'scalar array }

let rec pack :
    type t v env. ('scalar, env) pack -> (t, v, env) T.t -> v -> 'scalar array =
 fun p spec t ->
  match spec with
  | B spec ->
      p.pack spec t
  | Scalar chal ->
      let { Sc.inner = t } = t in
      p.pack chal t
  | Vector (spec, _) ->
      Array.concat_map (Vector.to_array t) ~f:(pack p spec)
  | Struct [] ->
      [||]
  | Struct (spec :: specs) ->
      let (hd :: tl) = t in
      let hd = pack p spec hd in
      Array.append hd (pack p (Struct specs) tl)
  | Array (spec, _) ->
      Array.concat_map t ~f:(pack p spec)

type ('f, 'env) typ =
  { typ :
      'var 'value.
         ('value, 'var, 'env) Basic.t
      -> ('var, 'value, 'f) Snarky_backendless.Typ.t
  }

let rec typ :
    type f var value env.
       (f, env) typ
    -> (value, var, env) T.t
    -> (var, value, f) Snarky_backendless.Typ.t =
  let open Snarky_backendless.Typ in
  fun t spec ->
    match spec with
    | B spec ->
        t.typ spec
    | Scalar chal ->
        Sc.typ (t.typ chal)
    | Vector (spec, n) ->
        Vector.typ (typ t spec) n
    | Array (spec, n) ->
        array ~length:n (typ t spec)
    | Struct [] ->
        let open Hlist.HlistId in
        transport (unit ()) ~there:(fun [] -> ()) ~back:(fun () -> [])
        |> transport_var ~there:(fun [] -> ()) ~back:(fun () -> [])
    | Struct (spec :: specs) ->
        let open Hlist.HlistId in
        tuple2 (typ t spec) (typ t (Struct specs))
        |> transport
             ~there:(fun (x :: xs) -> (x, xs))
             ~back:(fun (x, xs) -> x :: xs)
        |> transport_var
             ~there:(fun (x :: xs) -> (x, xs))
             ~back:(fun (x, xs) -> x :: xs)

type 'env exists = T : ('t1, 't2, 'env) T.t -> 'env exists

type generic_spec = { spec : 'env. 'env exists }

module ETyp = struct
  type ('var, 'value, 'f) t =
    | T :
        ('inner, 'value, 'f) Snarky_backendless.Typ.t
        * ('inner -> 'var)
        * ('var -> 'inner)
        -> ('var, 'value, 'f) t
end

type ('f, 'env) etyp =
  { etyp :
      'var 'value. ('value, 'var, 'env) Basic.t -> ('var, 'value, 'f) ETyp.t
  }

let rec etyp :
    type f var value env.
    (f, env) etyp -> (value, var, env) T.t -> (var, value, f) ETyp.t =
  let open Snarky_backendless.Typ in
  fun e spec ->
    match spec with
    | B spec ->
        e.etyp spec
    | Scalar chal ->
        let (T (typ, f, f_inv)) = e.etyp chal in
        T (Sc.typ typ, Sc.map ~f, Sc.map ~f:f_inv)
    | Vector (spec, n) ->
        let (T (typ, f, f_inv)) = etyp e spec in
        T (Vector.typ typ n, Vector.map ~f, Vector.map ~f:f_inv)
    | Array (spec, n) ->
        let (T (typ, f, f_inv)) = etyp e spec in
        T (array ~length:n typ, Array.map ~f, Array.map ~f:f_inv)
    | Struct [] ->
        let open Hlist.HlistId in
        let there [] = () in
        let back () = [] in
        T
          ( transport (unit ()) ~there ~back |> transport_var ~there ~back
          , Fn.id
          , Fn.id )
    | Struct (spec :: specs) ->
        let open Hlist.HlistId in
        let (T (t1, f1, f1_inv)) = etyp e spec in
        let (T (t2, f2, f2_inv)) = etyp e (Struct specs) in
        T
          ( tuple2 t1 t2
            |> transport
                 ~there:(fun (x :: xs) -> (x, xs))
                 ~back:(fun (x, xs) -> x :: xs)
          , (fun (x, xs) -> f1 x :: f2 xs)
          , fun (x :: xs) -> (f1_inv x, f2_inv xs) )

module Common (Impl : Snarky_backendless.Snark_intf.Run) = struct
  module Digest = D.Make (Impl)
  module Challenge = Limb_vector.Challenge.Make (Impl)
  open Impl

  module Env = struct
    type ('other_field, 'other_field_var, 'a) t =
      < field1 : 'other_field
      ; field2 : 'other_field_var
      ; bool1 : bool
      ; bool2 : Boolean.var
      ; digest1 : Digest.Constant.t
      ; digest2 : Digest.t
      ; challenge1 : Challenge.Constant.t
      ; challenge2 : Challenge.t
      ; bulletproof_challenge1 :
          Challenge.Constant.t Sc.t Bulletproof_challenge.t
      ; bulletproof_challenge2 : Challenge.t Sc.t Bulletproof_challenge.t
      ; branch_data1 : Branch_data.t
      ; branch_data2 : Impl.field Branch_data.Checked.t
      ; .. >
      as
      'a
  end
end

let pack_basic (type field other_field other_field_var)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = field) =
  let open Impl in
  let module C = Common (Impl) in
  let open C in
  let pack :
      type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) Basic.t
      -> b
      -> [ `Field of other_field_var | `Packed_bits of Field.t * int ] array =
   fun basic x ->
    match basic with
    | Field ->
        [| `Field x |]
    | Bool ->
        [| `Packed_bits ((x :> Field.t), 1) |]
    | Digest ->
        [| `Packed_bits (x, Field.size_in_bits) |]
    | Challenge ->
        [| `Packed_bits (x, Challenge.length) |]
    | Branch_data ->
        [| `Packed_bits
             ( Branch_data.Checked.pack (module Impl) x
             , Branch_data.length_in_bits )
        |]
    | Bulletproof_challenge ->
        let { Bulletproof_challenge.prechallenge = { Sc.inner = pre } } = x in
        [| `Packed_bits (pre, Challenge.length) |]
  in
  { pack }

let pack impl t = pack (pack_basic impl) t

let typ_basic (type field other_field other_field_var)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = field)
    ~assert_16_bits (field : (other_field_var, other_field) Impl.Typ.t) =
  let open Impl in
  let module C = Common (Impl) in
  let open C in
  let typ :
      type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) Basic.t
      -> (b, a) Impl.Typ.t =
   fun basic ->
    match basic with
    | Field ->
        field
    | Bool ->
        Boolean.typ
    | Branch_data ->
        Branch_data.typ (module Impl) ~assert_16_bits
    | Digest ->
        Digest.typ
    | Challenge ->
        Challenge.typ
    | Bulletproof_challenge ->
        Bulletproof_challenge.typ Challenge.typ
  in
  { typ }

let typ ~assert_16_bits impl field t =
  typ (typ_basic ~assert_16_bits impl field) t

let packed_typ_basic (type field other_field other_field_var)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = field)
    (field : (other_field_var, other_field, field) ETyp.t) =
  let open Impl in
  let module Digest = D.Make (Impl) in
  let module Challenge = Limb_vector.Challenge.Make (Impl) in
  let module Env = struct
    type ('other_field, 'other_field_var, 'a) t =
      < field1 : 'other_field
      ; field2 : 'other_field_var
      ; bool1 : bool
      ; bool2 : Boolean.var
      ; digest1 : Digest.Constant.t
      ; digest2 : Field.t
      ; challenge1 : Challenge.Constant.t
      ; challenge2 : (* Challenge.t *) Field.t
      ; bulletproof_challenge1 :
          Challenge.Constant.t Sc.t Bulletproof_challenge.t
      ; bulletproof_challenge2 : Field.t Sc.t Bulletproof_challenge.t
      ; branch_data1 : Branch_data.t
      ; branch_data2 : Field.t
      ; .. >
      as
      'a
  end in
  let etyp :
      type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) Basic.t
      -> (b, a, field) ETyp.t = function
    | Field ->
        field
    | Bool ->
        T (Boolean.typ, Fn.id, Fn.id)
    | Digest ->
        T (Digest.typ, Fn.id, Fn.id)
    | Challenge ->
        T (Challenge.typ, Fn.id, Fn.id)
    | Branch_data ->
        T (Branch_data.packed_typ (module Impl), Fn.id, Fn.id)
    | Bulletproof_challenge ->
        let typ =
          let there { Bulletproof_challenge.prechallenge = { Sc.inner = pre } }
              =
            pre
          in
          let back pre =
            { Bulletproof_challenge.prechallenge = { Sc.inner = pre } }
          in
          Typ.transport Challenge.typ ~there ~back
          |> Typ.transport_var ~there ~back
        in
        T (typ, Fn.id, Fn.id)
  in
  { etyp }

let packed_typ impl field t = etyp (packed_typ_basic impl field) t
