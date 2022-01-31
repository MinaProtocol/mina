open Core_kernel

module Derivers = struct
  include Fields_derivers.Make2
            (Fields_derivers_json.Both_yojson)
            (Fields_derivers_graphql.Graphql_fields)
  module G = Fields_derivers_graphql.Graphql_fields

  module Helpers = struct
    let iso_string ~name ?doc:doc_top ~to_string ~of_string : 'a Input.t =
      ( ( (fun x -> `String (to_string x))
        , function `String x -> of_string x | _ -> failwith "expected string" )
      , { G.Deriver_basic.Input.run =
            (fun ?doc () ->
              G.Schema.scalar name
                ?doc:(match doc with Some doc -> Some doc | None -> doc_top)
                ~coerce:(fun x -> `String (to_string x))
              |> G.Schema.non_null)
        } )

    let unsigned_scalar ~to_string ~of_string ~name =
      iso_string ~to_string ~of_string ~name
        ~doc:
          (Format.sprintf
             !"String representing a %s number in base 10"
             (String.lowercase name))
  end

  let uint64_ : Unsigned.UInt64.t Input.t =
    Helpers.unsigned_scalar ~name:"UInt64" ~to_string:Unsigned.UInt64.to_string
      ~of_string:Unsigned.UInt64.of_string

  let uint32_ : Unsigned.UInt32.t Input.t =
    Helpers.unsigned_scalar ~name:"UInt32" ~to_string:Unsigned.UInt32.to_string
      ~of_string:Unsigned.UInt32.of_string

  module Prim = struct
    include Prim

    let uint64 fd acc = add_field uint64_ fd acc

    let uint32 fd acc = add_field uint32_ fd acc
  end
end

let%test_module "Test" =
  ( module struct
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
      |> Derivers.finish

    let%test_unit "roundtrips json" =
      [%test_eq: V.t]
        (of_json (to_json V.v))
        (V.of_yojson (V.to_yojson V.v) |> Result.ok_or_failwith)
  end )
