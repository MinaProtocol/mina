module D = Digest
open Core_kernel
open Rugelach_types
open Hlist

module Basic = struct
  type (_, _, _) t = ..
end

open Basic

type (_, _, _) Basic.t +=
  | Field : ('field1, 'field2, < field1: 'field1 ; field2: 'field2 ; .. >) t
  | Bool : ('bool1, 'bool2, < bool1: 'bool1 ; bool2: 'bool2 ; .. >) t
  | Digest :
      ('digest1, 'digest2, < digest1: 'digest1 ; digest2: 'digest2 ; .. >) t
  | Challenge :
      ( 'challenge1
      , 'challenge2
      , < challenge1: 'challenge1 ; challenge2: 'challenge2 ; .. > )
      t
  | Bulletproof_challenge :
      ( 'bp_chal1
      , 'bp_chal2
      , < bulletproof_challenge1: 'bp_chal1
        ; bulletproof_challenge2: 'bp_chal2
        ; .. > )
      t

module rec T : sig
  type (_, _, _) t =
    | B : ('a, 'b, 'env) Basic.t -> ('a, 'b, 'env) t
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

type ('bool, 'env) pack =
  {pack: 'a 'b. ('a, 'b, 'env) Basic.t -> 'b -> 'bool list array}

let rec pack : type t v env.
    ('bool, env) pack -> (t, v, env) T.t -> v -> 'bool list array =
 fun p spec t ->
  match spec with
  | B spec ->
      p.pack spec t
  | Vector (spec, _) ->
      Array.concat_map (Vector.to_array t) ~f:(pack p spec)
  | Struct [] ->
      [||]
  | Struct (spec :: specs) ->
      let (hd :: tl) = t in
      Array.append (pack p spec hd) (pack p (Struct specs) tl)
  | Array (spec, _) ->
      Array.concat_map t ~f:(pack p spec)

type ('f, 'env) typ =
  { typ:
      'var 'value.    ('value, 'var, 'env) Basic.t
      -> ('var, 'value, 'f) Snarky.Typ.t }

let rec typ : type f var value env.
    (f, env) typ -> (value, var, env) T.t -> (var, value, f) Snarky.Typ.t =
  let open Snarky.Typ in
  fun t spec ->
    match spec with
    | B spec ->
        t.typ spec
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

type generic_spec = {spec: 'env. 'env exists}

module ETyp = struct
  type ('var, 'value, 'f) t =
    | T :
        ('inner, 'value, 'f) Snarky.Typ.t * ('inner -> 'var)
        -> ('var, 'value, 'f) t
end

type ('f, 'env) etyp =
  {etyp: 'var 'value. ('value, 'var, 'env) Basic.t -> ('var, 'value, 'f) ETyp.t}

let rec etyp : type f var value env.
    (f, env) etyp -> (value, var, env) T.t -> (var, value, f) ETyp.t =
  let open Snarky.Typ in
  fun e spec ->
    match spec with
    | B spec ->
        e.etyp spec
    | Vector (spec, n) ->
        let (T (typ, f)) = etyp e spec in
        T (Vector.typ typ n, Vector.map ~f)
    | Array (spec, n) ->
        let (T (typ, f)) = etyp e spec in
        T (array ~length:n typ, Array.map ~f)
    | Struct [] ->
        let open Hlist.HlistId in
        let there [] = () in
        let back () = [] in
        T
          ( transport (unit ()) ~there ~back |> transport_var ~there ~back
          , Fn.id )
    | Struct (spec :: specs) ->
        let open Hlist.HlistId in
        let (T (t1, f1)) = etyp e spec in
        let (T (t2, f2)) = etyp e (Struct specs) in
        T
          ( tuple2 t1 t2
            |> transport
                 ~there:(fun (x :: xs) -> (x, xs))
                 ~back:(fun (x, xs) -> x :: xs)
          , fun (x, xs) -> f1 x :: f2 xs )

module Common (Impl : Snarky.Snark_intf.Run) = struct
  module Digest = D.Make (Impl)
  module Challenge = Challenge.Make (Impl)
  open Impl

  module Env = struct
    type ('other_field, 'other_field_var, 'a) t =
      < field1: 'other_field
      ; field2: 'other_field_var
      ; bool1: bool
      ; bool2: Boolean.var
      ; digest1: Digest.Constant.t
      ; digest2: Digest.t
      ; challenge1: Challenge.Constant.t
      ; challenge2: Challenge.t
      ; bulletproof_challenge1:
          (Challenge.Constant.t, bool) Bulletproof_challenge.t
      ; bulletproof_challenge2:
          (Challenge.t, Boolean.var) Bulletproof_challenge.t
      ; .. >
      as
      'a
  end
end

let pack_basic (type field other_field other_field_var)
    (module Impl : Snarky.Snark_intf.Run with type field = field)
    (field : other_field_var -> Impl.Boolean.var list array) =
  let open Impl in
  let module C = Common (Impl) in
  let open C in
  let pack : type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) Basic.t
      -> b
      -> Boolean.var list array =
   fun basic x ->
    match basic with
    | Field ->
        field x
    | Bool ->
        [|[x]|]
    | Digest ->
        [|x|]
    | Challenge ->
        [|x|]
    | Bulletproof_challenge ->
        [|x.is_square :: x.prechallenge|]
    | _ ->
        failwith "unknown basic spec"
  in
  {pack}

let pack impl field t = pack (pack_basic impl field) t

let typ_basic (type field other_field other_field_var)
    (module Impl : Snarky.Snark_intf.Run with type field = field)
    (field : (other_field_var, other_field) Impl.Typ.t) =
  let open Impl in
  let module C = Common (Impl) in
  let open C in
  let typ : type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) Basic.t
      -> (b, a) Impl.Typ.t =
   fun basic ->
    match basic with
    | Field ->
        field
    | Bool ->
        Boolean.typ
    | Digest ->
        Digest.typ
    | Challenge ->
        Challenge.typ
    | Bulletproof_challenge ->
        let there {Bulletproof_challenge.prechallenge; is_square} =
          (prechallenge, is_square)
        in
        let back (prechallenge, is_square) =
          {Bulletproof_challenge.prechallenge; is_square}
        in
        Typ.transport ~there ~back (Typ.tuple2 Challenge.typ Boolean.typ)
        |> Typ.transport_var ~there ~back
    | _ ->
        failwith "unknown basic spec"
  in
  {typ}

let typ impl field t = typ (typ_basic impl field) t

let packed_typ_basic (type field other_field other_field_var)
    (module Impl : Snarky.Snark_intf.Run with type field = field)
    (field : (other_field_var, other_field, field) ETyp.t) =
  let open Impl in
  let module Digest = D.Make (Impl) in
  let module Challenge = Challenge.Make (Impl) in
  let module Env = struct
    type ('other_field, 'other_field_var, 'a) t =
      < field1: 'other_field
      ; field2: 'other_field_var
      ; bool1: bool
      ; bool2: Boolean.var
      ; digest1: Digest.Constant.t
      ; digest2: Field.t
      ; challenge1: Challenge.Constant.t
      ; challenge2: (* Challenge.t *) Field.t
      ; bulletproof_challenge1:
          (Challenge.Constant.t, bool) Bulletproof_challenge.t
      ; bulletproof_challenge2:
          (Challenge.t, Boolean.var) Bulletproof_challenge.t
      ; .. >
      as
      'a
  end in
  let etyp : type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) Basic.t
      -> (b, a, field) ETyp.t =
    (* TODO: Have to think this through in terms of how to force each of these things
       to be laid out as a single field element, which is the ultimate goal *)
    function
    | Field ->
        field
    | Bool ->
        T (Boolean.typ, Fn.id)
    | Digest ->
        T (Digest.packed_typ, Fn.id (*Field.unpack ~length:Digest.length *))
    | Challenge ->
        T
          ( Challenge.packed_typ
          , Fn.id (*Field.unpack ~length:Challenge.length*) )
    | Bulletproof_challenge ->
        let length = Challenge.length + 1 in
        let typ =
          Typ.transport Typ.field
            ~there:(fun {Bulletproof_challenge.prechallenge; is_square} ->
              Field.Constant.project
                (is_square :: Challenge.Constant.to_bits prechallenge) )
            ~back:(fun x ->
              match List.take (Field.Constant.unpack x) length with
              | is_square :: bs ->
                  {is_square; prechallenge= Challenge.Constant.of_bits bs}
              | _ ->
                  assert false )
        in
        T (typ, fun x -> Bulletproof_challenge.unpack (Field.unpack ~length x))
    | _ ->
        failwith "etyp: unhandled variant"
  in
  {etyp}

let packed_typ impl field t = etyp (packed_typ_basic impl field) t
