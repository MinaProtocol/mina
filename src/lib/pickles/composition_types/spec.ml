module D = Digest
open Core_kernel
open Pickles_types
open Hlist
module Sc = Import.Scalar_challenge

type 'f impl = (module Snarky_backendless.Snark_intf.Run with type field = 'f)

type ('a, 'b, 'c) basic =
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

module type Bool_intf = sig
  type var

  val true_ : var

  val false_ : var
end

module rec T : sig
  type (_, _, _) t =
    | B : ('a, 'b, 'env) basic -> ('a, 'b, 'env) t
    | Scalar :
        ('a, 'b, (< challenge1 : 'a ; challenge2 : 'b ; .. > as 'env)) basic
        -> ('a Sc.t, 'b Sc.t, 'env) t
    | Vector :
        ('t1, 't2, 'env) t * 'n Nat.t
        -> (('t1, 'n) Vector.t, ('t2, 'n) Vector.t, 'env) t
    | Array : ('t1, 't2, 'env) t * int -> ('t1 array, 't2 array, 'env) t
    | Struct :
        ('xs1, 'xs2, 'env) H2_1.T(T).t
        -> ('xs1 Hlist.HlistId.t, 'xs2 Hlist.HlistId.t, 'env) t
    | Opt :
        { inner : ('a1, 'a2, (< bool1 : bool ; bool2 : 'bool ; .. > as 'env)) t
        ; flag : Opt.Flag.t
        ; dummy1 : 'a1
        ; dummy2 : 'a2
        ; bool : (module Bool_intf with type var = 'bool)
        }
        -> ('a1 option, ('a2, 'bool) Opt.t, 'env) t
    | Opt_unflagged :
        { inner : ('a1, 'a2, (< bool1 : bool ; bool2 : 'bool ; .. > as 'env)) t
        ; flag : Opt.Flag.t
        ; dummy1 : 'a1
        ; dummy2 : 'a2
        }
        -> ('a1 option, 'a2 option, 'env) t
    | Constant : 'a * ('a -> 'a -> unit) * ('a, 'b, 'env) t -> ('a, 'b, 'env) t
end =
  T

type ('scalar, 'env) pack =
  { pack : 'a 'b. ('a, 'b, 'env) basic -> 'a option -> 'b -> 'scalar array }

let rec pack :
    type t v env.
       zero:'scalar
    -> one:'scalar
    -> ('scalar, env) pack
    -> (t, v, env) T.t
    -> t option
    -> v
    -> 'scalar array =
 fun ~zero ~one p spec t_constant_opt t ->
  match spec with
  | B spec ->
      p.pack spec t_constant_opt t
  | Scalar chal ->
      let t_constant_opt =
        Option.map t_constant_opt ~f:(fun { Sc.inner = x } -> x)
      in
      let { Sc.inner = t } = t in
      p.pack chal t_constant_opt t
  | Vector (spec, _) ->
      let t_constant_opt = Option.map ~f:Vector.to_array t_constant_opt in
      let t = Vector.to_array t in
      pack ~zero ~one p (Array (spec, Array.length t)) t_constant_opt t
  | Struct [] ->
      [||]
  | Struct (spec :: specs) ->
      let (hd :: tl) = t in
      let hd_constant_opt, tl_constant_opt =
        match t_constant_opt with
        | None ->
            (None, None)
        | Some (hd :: tl) ->
            (Some hd, Some tl)
      in
      let hd = pack ~zero ~one p spec hd_constant_opt hd in
      Array.append hd (pack ~zero ~one p (Struct specs) tl_constant_opt tl)
  | Array (spec, _) ->
      Array.concat_mapi t ~f:(fun i t ->
          let t_constant_opt =
            Option.map t_constant_opt ~f:(fun t_const -> t_const.(i))
          in
          pack ~zero ~one p spec t_constant_opt t )
  | Opt { inner; dummy1; dummy2; flag = _; bool = _ } -> (
      match t with
      | Nothing ->
          let t_constant_opt = Option.map t_constant_opt ~f:(fun _ -> dummy1) in
          Array.append [| zero |]
            (pack ~zero ~one p inner t_constant_opt dummy2)
      | Just x ->
          let t_constant_opt =
            Option.map ~f:(fun x -> Option.value_exn x) t_constant_opt
          in
          Array.append [| one |] (pack ~zero ~one p inner t_constant_opt x)
      | Maybe (b, x) ->
          let b_constant_opt = Option.map ~f:Option.is_some t_constant_opt in
          let x_constant_opt =
            Option.map ~f:(Option.value ~default:dummy1) t_constant_opt
          in
          Array.append
            (p.pack Bool b_constant_opt b)
            (pack ~zero ~one p inner x_constant_opt x) )
  | Opt_unflagged { inner; dummy1; dummy2; flag = _ } -> (
      match t with
      | None ->
          let t_constant_opt = Option.map t_constant_opt ~f:(fun _ -> dummy1) in
          pack ~zero ~one p inner t_constant_opt dummy2
      | Some x ->
          let t_constant_opt =
            Option.map ~f:(fun x -> Option.value_exn x) t_constant_opt
          in
          pack ~zero ~one p inner t_constant_opt x )
  | Constant (x, _, inner) ->
      pack ~zero ~one p inner (Some x) t

type ('f, 'env) typ =
  { typ :
      'var 'value.
      ('value, 'var, 'env) basic -> ('var, 'value, 'f) Snarky_backendless.Typ.t
  }

let rec typ :
    type f var value env.
       (f, env) typ
    -> (value, var, env) T.t
    -> (var, value, f) Snarky_backendless.Typ.t =
  let open Snarky_backendless.Typ in
  fun t spec ->
    match[@warning "-45"] spec with
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
    | Opt { inner; flag; dummy1; dummy2; bool = (module B) } ->
        let bool = typ t (B Bool) in
        let open B in
        (* Always use the same "maybe" layout which is a boolean and then the value *)
        Opt.constant_layout_typ bool flag ~dummy:dummy1 ~dummy_var:dummy2 ~true_
          ~false_ (typ t inner)
    | Opt_unflagged { inner; flag; dummy1; dummy2 } -> (
        match flag with
        | Opt.Flag.No ->
            let open Snarky_backendless.Typ in
            unit ()
            |> Snarky_backendless.Typ.transport
                 ~there:(function Some _ -> assert false | None -> ())
                 ~back:(fun () -> None)
            |> Snarky_backendless.Typ.transport_var
                 ~there:(function Some _ -> assert false | None -> ())
                 ~back:(fun _ -> None)
        | Opt.Flag.(Yes | Maybe) ->
            typ t inner
            |> Snarky_backendless.Typ.transport
                 ~there:(function Some x -> x | None -> dummy1)
                 ~back:(fun x -> Some x)
            |> Snarky_backendless.Typ.transport_var
                 ~there:(function Some x -> x | None -> dummy2)
                 ~back:(fun x -> Some x) )
    | Constant (x, assert_eq, spec) ->
        let (Typ typ) = typ t spec in
        let constant_var =
          let fields, aux = typ.value_to_fields x in
          let fields =
            Array.map fields ~f:(fun x -> Snarky_backendless.Cvar.Constant x)
          in
          typ.var_of_fields (fields, aux)
        in
        let open Snarky_backendless.Typ in
        unit ()
        |> transport ~there:(fun y -> assert_eq x y) ~back:(fun () -> x)
        |> transport_var ~there:(fun _ -> ()) ~back:(fun () -> constant_var)

module ETyp = struct
  type ('var, 'value, 'f) t =
    | T :
        ('inner, 'value, 'f) Snarky_backendless.Typ.t
        * ('inner -> 'var)
        * ('var -> 'inner)
        -> ('var, 'value, 'f) t
end

type ('f, 'env) etyp =
  { etyp : 'var 'value. ('value, 'var, 'env) basic -> ('var, 'value, 'f) ETyp.t
  }

let rec etyp :
    type f var value env.
    (f, env) etyp -> (value, var, env) T.t -> (var, value, f) ETyp.t =
  let open Snarky_backendless.Typ in
  fun e spec ->
    match[@warning "-45"] spec with
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
    | Opt { inner; flag; dummy1; dummy2; bool = (module B) } ->
        let (T (bool, f_bool, f_bool')) = etyp e (B Bool) in
        let (T (a, f_a, f_a')) = etyp e inner in
        let opt_map ~f1 ~f2 (x : _ Opt.t) : _ Opt.t =
          match x with
          | Nothing ->
              Opt.nothing
          | Just x ->
              Opt.just (f1 x)
          | Maybe (b, x) ->
              Maybe (f2 b, f1 x)
        in
        let f = opt_map ~f1:f_a ~f2:f_bool in
        let f' = opt_map ~f1:f_a' ~f2:f_bool' in
        T
          ( Opt.constant_layout_typ ~dummy:dummy1 ~dummy_var:(f_a' dummy2)
              ~true_:(f_bool' B.true_) ~false_:(f_bool' B.false_) bool flag a
          , f
          , f' )
    | Opt_unflagged { inner; dummy1; dummy2; flag = _ } ->
        let (T (typ, f, f_inv)) = etyp e inner in
        let f x = Some (f x) in
        let f_inv = function None -> f_inv dummy2 | Some x -> f_inv x in
        let typ =
          typ
          |> Snarky_backendless.Typ.transport
               ~there:(Option.value ~default:dummy1) ~back:(fun x -> Some x)
        in
        T (typ, f, f_inv)
    | Constant (x, _assert_eq, spec) ->
        let (T (Typ typ, f, f')) = etyp e spec in
        let constant_var =
          let fields, aux = typ.value_to_fields x in
          let fields =
            Array.map fields ~f:(fun x -> Snarky_backendless.Cvar.Constant x)
          in
          typ.var_of_fields (fields, aux)
        in
        (* We skip any constraints that would be added here, but we *do* use
           the underlying [Typ.t] to make sure that we allocate public inputs
           correctly.
        *)
        T
          ( Typ
              { typ with
                check =
                  (fun _ -> Snarky_backendless.Checked_runner.Simple.return ())
              }
          , (fun _ -> f constant_var)
          , f' )

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
    ((module Impl) : field impl) =
  let open Impl in
  let module C = Common (Impl) in
  let open C in
  let pack :
      type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) basic
      -> a option
      -> b
      -> [ `Field of other_field_var | `Packed_bits of Field.t * int ] array =
   fun basic x_constant_opt x ->
    (* TODO *)
    ignore x_constant_opt ;
    match basic with
    | Unit ->
        [||]
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
        let { Sc.inner = pre } = Bulletproof_challenge.pack x in
        [| `Packed_bits (pre, Challenge.length) |]
  in
  { pack }

let pack (type f) ((module Impl) as impl : f impl) t =
  let open Impl in
  pack (pack_basic impl) t
    ~zero:(`Packed_bits (Field.zero, 1))
    ~one:(`Packed_bits (Field.one, 1))
    None

let typ_basic (type field other_field other_field_var)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = field)
    ~assert_16_bits (field : (other_field_var, other_field) Impl.Typ.t) =
  let open Impl in
  let module C = Common (Impl) in
  let open C in
  let typ :
      type a b.
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) basic
      -> (b, a) Impl.Typ.t =
   fun basic ->
    match basic with
    | Unit ->
        Typ.unit
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
         (a, b, ((other_field, other_field_var, 'e) Env.t as 'e)) basic
      -> (b, a, field) ETyp.t = function
    | Unit ->
        T (Typ.unit, Fn.id, Fn.id)
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
          let there bp_challenge =
            let { Sc.inner = pre } = Bulletproof_challenge.pack bp_challenge in
            pre
          in
          let back pre = Bulletproof_challenge.unpack { Sc.inner = pre } in
          Typ.transport Challenge.typ ~there ~back
          |> Typ.transport_var ~there ~back
        in
        T (typ, Fn.id, Fn.id)
  in
  { etyp }

let packed_typ impl field t = etyp (packed_typ_basic impl field) t
