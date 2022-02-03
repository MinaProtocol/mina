open Core_kernel

module Derivers = struct
  let derivers () =
    let open Fields_derivers_graphql in
    let graphql_fields =
      ref Graphql_fields.Input.T.{ run = (fun () -> failwith "unimplemented") }
    in
    let contramap = ref (fun _ -> failwith "unimplemented") in
    let nullable_graphql_fields =
      ref Graphql_fields.Input.T.{ run = (fun () -> failwith "unimplemented") }
    in
    let graphql_fields_accumulator = ref [] in
    let nullable = ref Nullable.Non_null in
    let to_json = ref (fun _ -> failwith "unimplemented") in
    let of_json = ref (fun _ -> failwith "unimplemented") in
    let to_json_accumulator = ref [] in
    let of_json_creator = ref String.Map.empty in
    let map = ref Fn.id in

    object
      method graphql_fields = graphql_fields

      method contramap = contramap

      method nullable_graphql_fields = nullable_graphql_fields

      method graphql_fields_accumulator = graphql_fields_accumulator

      method nullable = nullable

      method to_json = to_json

      method map = map

      method contramp = contramap

      method of_json = of_json

      method to_json_accumulator = to_json_accumulator

      method of_json_creator = of_json_creator
    end

  module Unified_input = struct
    type 'a t = < .. > as 'a
      constraint 'a = _ Fields_derivers_json.To_yojson.Input.t
      constraint 'a = _ Fields_derivers_json.Of_yojson.Input.t
      constraint 'a = _ Fields_derivers_graphql.Graphql_fields.Input.t
  end

  let yojson ?doc ~name ~map ~contramap : 'a Unified_input.t =
    let open Fields_derivers_graphql in
    object
      method graphql_fields =
        let open Graphql_fields.Schema in
        ref
          Graphql_fields.Input.T.
            { run =
                (fun () ->
                  scalar name ?doc ~coerce:Yojson.Safe.to_basic |> non_null)
            }

      method contramap = ref contramap

      method nullable_graphql_fields =
        let open Graphql_fields.Schema in
        ref
          Graphql_fields.Input.T.
            { run = (fun () -> scalar name ?doc ~coerce:Yojson.Safe.to_basic) }

      method nullable = ref Nullable.Non_null

      method to_json = ref Fn.id

      method map = ref map

      method of_json = ref Fn.id
    end

  let iso_string ~to_string ~of_string ~doc ~name =
    yojson ~doc ~name
      ~map:(function `String x -> of_string x | _ -> failwith "unsupported")
      ~contramap:(fun uint64 -> `String (to_string uint64))

  let uint64 : _ Unified_input.t =
    iso_string ~doc:"Unsigned 64-bit integer represented as a string in base10"
      ~name:"UInt64" ~to_string:Unsigned.UInt64.to_string
      ~of_string:Unsigned.UInt64.of_string

  let uint32 : _ Unified_input.t =
    iso_string ~doc:"Unsigned 32-bit integer represented as a string in base10"
      ~name:"UInt32" ~to_string:Unsigned.UInt32.to_string
      ~of_string:Unsigned.UInt32.of_string

  let field : _ Unified_input.t =
    let module Field = Pickles.Impls.Step.Field.Constant in
    iso_string ~name:"Field" ~doc:"String representing an Fp Field element"
      ~to_string:Field.to_string ~of_string:Field.of_string

  let option (x : _ Unified_input.t) : _ Unified_input.t =
    x |> Fields_derivers_graphql.Graphql_fields.option'
    |> Fields_derivers_json.To_yojson.option
    |> Fields_derivers_json.Of_yojson.option
end

let%test_module "Test" =
  ( module struct
    module Field = Pickles.Impls.Step.Field.Constant

    module V = struct
      type t =
        { foo : int
        ; bar : Unsigned_extended.UInt64.t
        ; baz : Unsigned_extended.UInt32.t list
        }
      [@@deriving compare, sexp, equal, fields, yojson]

      let v =
        { foo = 1
        ; bar = Unsigned.UInt64.of_int 10
        ; baz = Unsigned.UInt32.[ of_int 11; of_int 12 ]
        }
    end

    let (to_json, of_json), _typ =
      let open Derivers.Prim in
      V.Fields.make_creator (Derivers.init ()) ~foo:int ~bar:uint64
        ~baz:(list Derivers.uint32_)
      |> Derivers.(finish (finished "V"))

    let%test_unit "roundtrips json" =
      [%test_eq: V.t]
        (of_json (to_json V.v))
        (V.of_yojson (V.to_yojson V.v) |> Result.ok_or_failwith)

    module V2 = struct
      type t = { field : Field.t } [@@deriving compare, sexp, equal, fields]

      let v = { field = Field.of_int 10 }
    end

    let (to_json', of_json'), _typ' =
      let open Derivers.Prim in
      V2.Fields.make_creator (Derivers.init ()) ~field |> Derivers.finish

    let%test_unit "to_json'" =
      [%test_eq: string]
        (Yojson.Safe.to_string (to_json' V2.v))
        {|{"field":"10"}|}

    let%test_unit "roundtrip json'" =
      [%test_eq: V2.t] (of_json' (to_json' V2.v)) V2.v
  end )
