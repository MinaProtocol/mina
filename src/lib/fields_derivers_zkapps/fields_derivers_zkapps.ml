[%%import "/src/config.mlh"]

open Core_kernel
module Field = Snark_params.Tick.Field

module Make (Schema : Graphql_intf.Schema) = struct
  module Graphql = Fields_derivers_graphql.Graphql_raw.Make (Schema)

  let derivers () =
    let graphql_fields =
      ref Graphql.Fields.Input.T.{ run = (fun () -> failwith "unimplemented") }
    in
    let nullable_graphql_fields =
      ref Graphql.Fields.Input.T.{ run = (fun () -> failwith "unimplemented") }
    in
    let graphql_fields_accumulator = ref [] in
    let graphql_arg = ref (fun () -> failwith "unimplemented") in
    let nullable_graphql_arg = ref (fun () -> failwith "unimplemented") in
    let graphql_arg_accumulator = ref Graphql.Args.Acc.T.Init in
    let graphql_creator = ref (fun _ -> failwith "unimplemented") in
    let graphql_query = ref None in
    let graphql_query_accumulator = ref [] in

    let to_json = ref (fun _ -> failwith "unimplemented") in
    let of_json = ref (fun _ -> failwith "unimplemented") in
    let to_json_accumulator = ref [] in
    let of_json_creator = ref String.Map.empty in

    let js_layout = ref (`Assoc []) in
    let js_layout_accumulator = ref [] in

    let contramap = ref (fun _ -> failwith "unimplemented") in
    let map = ref (fun _ -> failwith "unimplemented") in

    let skip = ref false in

    object
      method skip = skip

      method graphql_fields = graphql_fields

      method nullable_graphql_fields = nullable_graphql_fields

      method graphql_fields_accumulator = graphql_fields_accumulator

      method graphql_arg = graphql_arg

      method nullable_graphql_arg = nullable_graphql_arg

      method graphql_arg_accumulator = graphql_arg_accumulator

      method graphql_creator = graphql_creator

      method graphql_query = graphql_query

      method graphql_query_accumulator = graphql_query_accumulator

      method to_json = to_json

      method of_json = of_json

      method to_json_accumulator = to_json_accumulator

      method of_json_creator = of_json_creator

      method js_layout = js_layout

      method js_layout_accumulator = js_layout_accumulator

      method contramap = contramap

      method map = map
    end

  let o () = derivers ()

  module Unified_input = struct
    type 'a t = < .. > as 'a
      constraint 'a = _ Fields_derivers_json.To_yojson.Input.t
      constraint 'a = _ Fields_derivers_json.Of_yojson.Input.t
      constraint 'a = _ Graphql.Fields.Input.t
      constraint 'a = _ Graphql.Args.Input.t
      constraint 'a = _ Fields_derivers_graphql.Graphql_query.Input.t
      constraint 'a = _ Fields_derivers_js.Js_layout.Input.t
  end

  let yojson obj ?doc ~name ~js_type ~map ~contramap : _ Unified_input.t =
    (obj#graphql_fields :=
       let open Schema in
       Graphql.Fields.Input.T.
         { run =
             (fun () ->
               scalar name ?doc ~coerce:Yojson.Safe.to_basic |> non_null )
         } ) ;

    (obj#nullable_graphql_fields :=
       let open Schema in
       Graphql.Fields.Input.T.
         { run = (fun () -> scalar name ?doc ~coerce:Yojson.Safe.to_basic) } ) ;

    (obj#graphql_arg :=
       fun () ->
         Schema.Arg.scalar name ?doc ~coerce:Graphql.arg_to_yojson
         |> Schema.Arg.non_null ) ;

    (obj#nullable_graphql_arg :=
       fun () -> Schema.Arg.scalar name ?doc ~coerce:Graphql.arg_to_yojson ) ;

    obj#to_json := Fn.id ;

    obj#of_json := Fn.id ;

    obj#contramap := contramap ;

    obj#map := map ;

    obj#js_layout := Fields_derivers_js.Js_layout.leaf_type js_type ;

    Fields_derivers_graphql.Graphql_query.scalar obj

  let invalid_scalar_to_string = function
    | `Uint ->
        "Uint"
    | `Field ->
        "Field"
    | `Token_id ->
        "Token_id"
    | `Public_key ->
        "Public_key"
    | `Amount ->
        "Amount"
    | `Balance ->
        "Balance"
    | `Unit ->
        "Unit"
    | `Proof ->
        "Proof"
    | `Verification_key ->
        "Verification_key"
    | `Signature ->
        "Signature"

  let raise_invalid_scalar t s =
    failwith ("Invalid rich scalar: " ^ invalid_scalar_to_string t ^ " " ^ s)

  let except ~f v (x : string) = try f x with _ -> raise_invalid_scalar v x

  let iso_string ?doc ~name ~js_type obj ~(to_string : 'a -> string)
      ~(of_string : string -> 'a) =
    yojson obj ?doc ~name ~js_type
      ~map:(function
        | `String x ->
            of_string x
        | _ ->
            raise (Fields_derivers_json.Of_yojson.Invalid_json_scalar `String)
        )
      ~contramap:(fun x -> `String (to_string x))

  let uint64 obj : _ Unified_input.t =
    iso_string obj
      ~doc:"Unsigned 64-bit integer represented as a string in base10"
      ~name:"UInt64" ~js_type:UInt64 ~to_string:Unsigned.UInt64.to_string
      ~of_string:(except ~f:Unsigned.UInt64.of_string `Uint)

  let uint32 obj : _ Unified_input.t =
    iso_string obj
      ~doc:"Unsigned 32-bit integer represented as a string in base10"
      ~name:"UInt32" ~js_type:UInt32 ~to_string:Unsigned.UInt32.to_string
      ~of_string:(except ~f:Unsigned.UInt32.of_string `Uint)

  let field obj : _ Unified_input.t =
    iso_string obj ~name:"Field" ~js_type:Field
      ~doc:"String representing an Fp Field element" ~to_string:Field.to_string
      ~of_string:(except ~f:Field.of_string `Field)

  let public_key obj : _ Unified_input.t =
    iso_string obj ~name:"PublicKey" ~js_type:PublicKey
      ~doc:"String representing a public key in base58"
      ~to_string:Signature_lib.Public_key.Compressed.to_string
      ~of_string:
        (except ~f:Signature_lib.Public_key.Compressed.of_base58_check_exn
           `Public_key )

  let skip obj : _ Unified_input.t =
    let _a = Graphql.Fields.skip obj in
    let _b = Graphql.Args.skip obj in
    let _c = Fields_derivers_json.To_yojson.skip obj in
    let _d = Fields_derivers_graphql.Graphql_query.skip obj in
    let _e = Fields_derivers_js.Js_layout.skip obj in
    Fields_derivers_json.Of_yojson.skip obj

  let js_only (js_layout : _ Fields_derivers_js.Js_layout.Input.t -> 'a) obj :
      _ Unified_input.t =
    let _a = Graphql.Fields.skip obj in
    let _b = Graphql.Args.skip obj in
    let _c = Fields_derivers_json.To_yojson.skip obj in
    let _d = Fields_derivers_graphql.Graphql_query.skip obj in
    let _e = js_layout obj in
    Fields_derivers_json.Of_yojson.skip obj

  let js_leaf leaf obj =
    js_only Fields_derivers_js.Js_layout.(of_layout @@ leaf_type leaf) obj

  let js_record entries obj =
    js_only (Fields_derivers_js.Js_layout.record entries) obj

  let int obj : _ Unified_input.t =
    let _a = Graphql.Fields.int obj in
    let _b = Graphql.Args.int obj in
    let _c = Fields_derivers_json.To_yojson.int obj in
    let _d = Fields_derivers_graphql.Graphql_query.int obj in
    let _e = Fields_derivers_js.Js_layout.int obj in
    Fields_derivers_json.Of_yojson.int obj

  let string obj : _ Unified_input.t =
    let _a = Graphql.Fields.string obj in
    let _b = Graphql.Args.string obj in
    let _c = Fields_derivers_json.To_yojson.string obj in
    let _d = Fields_derivers_graphql.Graphql_query.string obj in
    let _e = Fields_derivers_js.Js_layout.string obj in
    Fields_derivers_json.Of_yojson.string obj

  let bool obj : _ Unified_input.t =
    let _a = Graphql.Fields.bool obj in
    let _b = Graphql.Args.bool obj in
    let _c = Fields_derivers_json.To_yojson.bool obj in
    let _d = Fields_derivers_graphql.Graphql_query.bool obj in
    let _e = Fields_derivers_js.Js_layout.bool obj in
    Fields_derivers_json.Of_yojson.bool obj

  let global_slot_since_genesis obj =
    iso_string obj ~name:"GlobalSlotSinceGenesis" ~js_type:UInt32
      ~to_string:Mina_numbers.Global_slot_since_genesis.to_string
      ~of_string:
        (except ~f:Mina_numbers.Global_slot_since_genesis.of_string `Uint)

  let global_slot_since_hard_fork obj =
    iso_string obj ~name:"GlobalSlotSinceHardFork" ~js_type:UInt32
      ~to_string:Mina_numbers.Global_slot_since_hard_fork.to_string
      ~of_string:
        (except ~f:Mina_numbers.Global_slot_since_hard_fork.of_string `Uint)

  let global_slot_span obj =
    iso_string obj ~name:"GlobalSlotSpan" ~js_type:UInt32
      ~to_string:Mina_numbers.Global_slot_span.to_string
      ~of_string:(except ~f:Mina_numbers.Global_slot_span.of_string `Uint)

  let amount obj =
    iso_string obj ~name:"CurrencyAmount" ~js_type:UInt64
      ~to_string:Currency.Amount.to_string
      ~of_string:(except ~f:Currency.Amount.of_string `Amount)

  let balance obj =
    iso_string obj ~name:"Balance" ~js_type:UInt64
      ~to_string:Currency.Balance.to_string
      ~of_string:(except ~f:Currency.Balance.of_string `Balance)

  let option (x : _ Unified_input.t) ~js_type obj : _ Unified_input.t =
    let _a = Graphql.Fields.option x obj in
    let _b = Graphql.Args.option x obj in
    let _c = Fields_derivers_json.To_yojson.option x obj in
    let _d = Fields_derivers_graphql.Graphql_query.option x obj in
    let _e = Fields_derivers_js.Js_layout.option ~js_type x obj in
    Fields_derivers_json.Of_yojson.option x obj

  let list ?(static_length : int option) (x : _ Unified_input.t) obj :
      _ Unified_input.t =
    let _a = Graphql.Fields.list x obj in
    let _b = Graphql.Args.list x obj in
    let _c = Fields_derivers_json.To_yojson.list x obj in
    let _d = Fields_derivers_graphql.Graphql_query.list x obj in
    let _e = Fields_derivers_js.Js_layout.list ?static_length x obj in
    Fields_derivers_json.Of_yojson.list x obj

  let iso ~map ~contramap (x : _ Unified_input.t) obj : _ Unified_input.t =
    let _a = Graphql.Fields.contramap ~f:contramap x obj in
    let _b = Graphql.Args.map ~f:map x obj in
    let _c = Fields_derivers_json.To_yojson.contramap ~f:contramap x obj in
    let _d = Fields_derivers_graphql.Graphql_query.wrapped x obj in
    let _e = Fields_derivers_js.Js_layout.wrapped x obj in
    Fields_derivers_json.Of_yojson.map ~f:map x obj

  let iso_record ~of_record ~to_record record_deriver obj =
    iso ~map:of_record ~contramap:to_record (record_deriver @@ o ()) obj

  let array inner obj : _ Unified_input.t =
    iso ~map:Array.of_list ~contramap:Array.to_list
      ((list @@ inner @@ o ()) (o ()))
      obj

  let add_field ?skip_data ~t_fields_annots (x : _ Unified_input.t) fd acc =
    let _, acc' = Graphql.Fields.add_field ~t_fields_annots x fd acc in
    let c1, acc'' =
      Graphql.Args.add_field ?skip_data ~t_fields_annots x fd acc'
    in
    let _, acc''' =
      Fields_derivers_json.To_yojson.add_field ~t_fields_annots x fd acc''
    in
    let c2, acc'''' =
      Fields_derivers_json.Of_yojson.add_field ?skip_data ~t_fields_annots x fd
        acc'''
    in
    let _, acc''''' =
      Fields_derivers_graphql.Graphql_query.add_field ~t_fields_annots x fd
        acc''''
    in
    let _, acc'''''' =
      Fields_derivers_js.Js_layout.add_field ~t_fields_annots x fd acc'''''
    in
    ((function `Left x -> c1 x | `Right x -> c2 x), acc'''''')

  let ( !. ) ?skip_data x fd acc = add_field ?skip_data (x @@ o ()) fd acc

  let finish name ~t_toplevel_annots (f, acc) =
    let _a =
      Graphql.Fields.finish name ~t_toplevel_annots ((fun x -> f (`Left x)), acc)
    in
    let _b =
      Graphql.Args.finish name ~t_toplevel_annots ((fun x -> f (`Left x)), acc)
    in
    let _c =
      Fields_derivers_json.To_yojson.finish ((fun x -> f (`Right x)), acc)
    in
    let _d =
      Fields_derivers_graphql.Graphql_query.finish ((fun x -> f (`Left x)), acc)
    in
    let _e =
      Fields_derivers_js.Js_layout.finish name ~t_toplevel_annots
        ((fun x -> f (`Left x)), acc)
    in
    Fields_derivers_json.Of_yojson.finish ((fun x -> f (`Right x)), acc)

  let needs_custom_js ~js_type ~name deriver obj =
    Fields_derivers_js.Js_layout.needs_custom_js ~name
      (js_type @@ o ())
      (deriver obj)

  let balance_change obj =
    let sign_to_string = function
      | Sgn.Pos ->
          "Positive"
      | Sgn.Neg ->
          "Negative"
    in
    let sign_of_string = function
      | "Positive" ->
          Sgn.Pos
      | "Negative" ->
          Sgn.Neg
      | _ ->
          failwith "impossible"
    in
    let sign_deriver =
      iso_string ~name:"Sign" ~js_type:Sign ~to_string:sign_to_string
        ~of_string:sign_of_string
    in
    let ( !. ) = ( !. ) ~t_fields_annots:Currency.Signed_poly.t_fields_annots in
    Currency.Signed_poly.Fields.make_creator obj ~magnitude:!.amount
      ~sgn:!.sign_deriver
    |> finish "BalanceChange"
         ~t_toplevel_annots:Currency.Signed_poly.t_toplevel_annots

  let to_json obj x = !(obj#to_json) @@ !(obj#contramap) x

  let of_json obj x = !(obj#map) @@ !(obj#of_json) x

  let js_layout deriver = !((deriver @@ o ())#js_layout)

  let typ obj = !(obj#graphql_fields).Graphql.Fields.Input.T.run ()

  let arg_typ obj = !(obj#graphql_arg) ()

  let inner_query obj = Fields_derivers_graphql.Graphql_query.inner_query obj

  let rec json_to_safe : Yojson.Basic.t -> Yojson.Safe.t = function
    | `Assoc kv ->
        `Assoc (List.map kv ~f:(fun (k, v) -> (k, json_to_safe v)))
    | `Bool b ->
        `Bool b
    | `Float f ->
        `Float f
    | `Int i ->
        `Int i
    | `List xs ->
        `List (List.map xs ~f:json_to_safe)
    | `Null ->
        `Null
    | `String s ->
        `String s

  (* TODO: remove this or move to a %test_module once the deriver code is stable *)
  (* Can be used to print the graphql schema, like this:
     Fields_derivers_zkapps.Test.print_schema full ;
  *)
  module Test = struct
    module M = struct
      let ( let* ) = Schema.Io.bind

      let return = Schema.Io.return
    end

    let print_schema (full : _ Unified_input.t) =
      let typ = !(full#graphql_fields).run () in
      let query_top_level =
        Schema.(
          field "query" ~typ:(non_null typ)
            ~args:Arg.[]
            ~doc:"sample query"
            ~resolve:(fun _ _ -> ()))
      in
      let schema =
        Schema.(schema [ query_top_level ] ~mutations:[] ~subscriptions:[])
      in
      let res : 'a Schema.Io.t =
        Schema.execute schema ()
          (Fields_derivers_graphql.Test.introspection_query ())
      in
      let open Schema.Io in
      bind res (function
        | Ok (`Response data) ->
            data |> Yojson.Basic.to_string |> printf "%s" |> return
        | _ ->
            failwith "Unexpected response" )

    module Loop = struct
      let rec json_to_string_gql : Yojson.Safe.t -> string = function
        | `Assoc kv ->
            sprintf "{\n%s\n}"
              ( List.map kv ~f:(fun (k, v) ->
                    sprintf "%s: %s"
                      (Fields_derivers.under_to_camel k)
                      (json_to_string_gql v) )
              |> String.concat ~sep:",\n" )
        | `List xs ->
            sprintf "[\n%s\n]"
              (List.map xs ~f:json_to_string_gql |> String.concat ~sep:",\n")
        | x ->
            Yojson.Safe.to_string x

      let arg_query json =
        Printf.sprintf
          {graphql|query LoopIn {
            arg(
              input : %s
            )
          }|graphql}
          (json_to_string_gql json)

      let out_query keys =
        Printf.sprintf
          {graphql|
          query LoopOut {
            out %s
          }
        |graphql}
          keys

      let run deriver (a : 'a) =
        let schema =
          let in_schema : ('a option ref, unit) Schema.field =
            Schema.(
              field "arg" ~typ:(non_null int)
                ~args:Arg.[ arg "input" ~typ:(arg_typ deriver) ]
                ~doc:"sample args query"
                ~resolve:(fun { ctx; _ } () (input : 'a) ->
                  ctx := Some input ;
                  0 ))
          in
          let out_schema : ('a option ref, unit) Schema.field =
            Schema.(
              field "out" ~typ:(typ deriver)
                ~args:Arg.[]
                ~doc:"sample query"
                ~resolve:(fun { ctx; _ } () -> Option.value_exn !ctx))
          in
          Schema.(
            schema [ in_schema; out_schema ] ~mutations:[] ~subscriptions:[])
        in
        let ctx = ref None in
        let open M in
        let run_query q =
          let x = Graphql_parser.parse q in
          match x with
          | Ok res ->
              Schema.execute schema ctx res
          | Error err ->
              failwithf "Failed to parse query: %s %s" q err ()
        in
        (* send json in *)
        let* () =
          let json = to_json deriver a in
          let q = arg_query json in
          let* res = run_query q in
          match res with
          | Ok (`Response _) ->
              return @@ ()
          | Error e ->
              failwithf "Unexpected response in: %s"
                (e |> Yojson.Basic.to_string)
                ()
          | _ ->
              failwith "Unexpected stream in"
        in
        (* get query *)
        let inner_query =
          Option.value_exn
            (Fields_derivers_graphql.Graphql_query.inner_query deriver)
        in
        (* read json out *)
        let* a' =
          let* res = run_query (out_query inner_query) in
          match res with
          | Ok (`Response json) ->
              let unwrap k json =
                match json with
                | `Assoc kv ->
                    List.Assoc.find_exn kv ~equal:String.equal k
                | _ ->
                    failwithf "Expected wrapping %s" k ()
              in
              let inner = json |> unwrap "data" |> unwrap "out" in
              of_json deriver (json_to_safe inner) |> return
          | Error e ->
              failwithf "Unexpected response out: %s"
                (e |> Yojson.Basic.to_string)
                ()
          | _ ->
              failwith "Unexpected stream out"
        in
        [%test_eq: string]
          (Yojson.Safe.to_string (to_json deriver a))
          (Yojson.Safe.to_string (to_json deriver a')) ;
        return ()
    end
  end
end

module Derivers = Make (Fields_derivers_graphql.Schema)
include Derivers
module Js_layout = Fields_derivers_js.Js_layout

[%%ifdef consensus_mechanism]

let proof obj : _ Unified_input.t =
  let of_string s =
    match Pickles.Side_loaded.Proof.of_base64 s with
    | Ok proof ->
        proof
    | Error _err ->
        raise_invalid_scalar `Proof s
  in
  iso_string obj ~name:"ZkappProof" ~js_type:String
    ~to_string:Pickles.Side_loaded.Proof.to_base64 ~of_string

let verification_key_with_hash obj =
  let verification_key obj =
    let of_string s =
      match Pickles.Side_loaded.Verification_key.of_base64 s with
      | Ok vk ->
          vk
      | Error _err ->
          raise_invalid_scalar `Verification_key s
    in
    Pickles.Side_loaded.Verification_key.(
      iso_string obj ~name:"VerificationKey" ~js_type:String
        ~to_string:to_base64 ~of_string ~doc:"Verification key in Base64 format")
  in
  let ( !. ) =
    ( !. ) ~t_fields_annots:With_hash.Stable.Latest.t_fields_annots
  in
  With_hash.Stable.Latest.Fields.make_creator ~data:!.verification_key
    ~hash:!.field obj
  |> finish "VerificationKeyWithHash"
       ~t_toplevel_annots:With_hash.Stable.Latest.t_toplevel_annots

let%test_unit "verification key with hash, roundtrip json" =
  let open Pickles.Side_loaded.Verification_key in
  (* we do this because the dummy doesn't have a wrap_vk on it *)
  let data = dummy |> to_base58_check |> of_base58_check_exn in
  let v = { With_hash.data; hash = Field.one } in
  let o = verification_key_with_hash @@ o () in
  [%test_eq: (t, Field.t) With_hash.t] v (of_json o (to_json o v))

[%%endif]

let%test_module "Test" =
  ( module struct
    module IO = struct
      type +'a t = 'a

      let bind t f = f t

      let return t = t

      module Stream = struct
        type 'a t = 'a Seq.t

        let map t f = Seq.map f t

        let iter t f = Seq.iter f t

        let close _t = ()
      end
    end

    module Field_error = struct
      type t = string

      let message_of_field_error t = t

      let extensions_of_field_error _t = None
    end

    module Schema = Graphql_schema.Make (IO) (Field_error)
    module Derivers = Make (Schema)
    include Derivers
    module Public_key = Signature_lib.Public_key.Compressed

    module Or_ignore_test = struct
      type 'a t = Check of 'a | Ignore [@@deriving compare, sexp, equal]

      let of_option = function None -> Ignore | Some x -> Check x

      let to_option = function Ignore -> None | Check x -> Some x

      let to_yojson a x = [%to_yojson: 'a option] a (to_option x)

      let of_yojson a x = Result.map ~f:of_option ([%of_yojson: 'a option] a x)

      let derived inner init =
        iso ~map:of_option ~contramap:to_option
          ((option ~js_type:Flagged_option @@ inner @@ o ()) (o ()))
          init
    end

    module V = struct
      type t =
        { foo : int
        ; foo1 : Unsigned_extended.UInt64.t
        ; bar : Unsigned_extended.UInt64.t Or_ignore_test.t
        ; baz : Unsigned_extended.UInt32.t list
        }
      [@@deriving annot, compare, sexp, equal, fields, yojson]

      let v =
        { foo = 1
        ; foo1 = Unsigned.UInt64.of_int 10
        ; bar = Or_ignore_test.Check (Unsigned.UInt64.of_int 10)
        ; baz = Unsigned.UInt32.[ of_int 11; of_int 12 ]
        }

      let ( !. ) = ( !. ) ~t_fields_annots

      let derivers obj =
        Fields.make_creator obj ~foo:!.int ~foo1:!.uint64
          ~bar:!.(Or_ignore_test.derived uint64)
          ~baz:!.(list @@ uint32 @@ o ())
        |> finish "V" ~t_toplevel_annots
    end

    let v1 = V.derivers @@ o ()

    let%test_unit "full roundtrips" = Test.Loop.run v1 V.v

    module V2 = struct
      type t = { field : Field.t; nothing : unit [@skip] }
      [@@deriving annot, compare, sexp, equal, fields]

      let v = { field = Field.of_int 10; nothing = () }

      let derivers obj =
        let open Derivers in
        let ( !. ) ?skip_data = ( !. ) ?skip_data ~t_fields_annots in
        Fields.make_creator obj ~field:!.field
          ~nothing:(( !. ) ~skip_data:() skip)
        |> finish "V2" ~t_toplevel_annots
    end

    let v2 = V2.derivers @@ Derivers.o ()

    let%test_unit "to_json'" =
      let open Derivers in
      [%test_eq: string]
        (Yojson.Safe.to_string (to_json v2 V2.v))
        {|{"field":"10"}|}

    let%test_unit "roundtrip json'" =
      let open Derivers in
      [%test_eq: V2.t] (of_json v2 (to_json v2 V2.v)) V2.v

    module V3 = struct
      type t = { public_key : Public_key.t }
      [@@deriving annot, compare, sexp, equal, fields]

      let v =
        { public_key =
            Public_key.of_base58_check_exn
              "B62qoTqMG41DFgkyQmY2Pos1x671Gfzs9k8NKqUdSg7wQasEV6qnXQP"
        }

      let derivers obj =
        let open Derivers in
        let ( !. ) = ( !. ) ~t_fields_annots in
        Fields.make_creator obj ~public_key:!.public_key
        |> finish "V3" ~t_toplevel_annots
    end

    let v3 = V3.derivers @@ Derivers.o ()

    let%test_unit "to_json'" =
      let open Derivers in
      [%test_eq: string]
        (Yojson.Safe.to_string (to_json v3 V3.v))
        {|{"publicKey":"B62qoTqMG41DFgkyQmY2Pos1x671Gfzs9k8NKqUdSg7wQasEV6qnXQP"}|}

    let%test_unit "roundtrip json'" =
      let open Derivers in
      [%test_eq: V3.t] (of_json v3 (to_json v3 V3.v)) V3.v
  end )
