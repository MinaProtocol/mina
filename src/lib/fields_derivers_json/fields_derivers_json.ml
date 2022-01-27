open Core_kernel
open Fieldslib

module To_yojson = struct
  module Input = struct
    type 'input_type t = 'input_type -> Yojson.Safe.t
  end

  module Creator = struct
    type 'input_type t = unit
  end

  module Output = Input

  module Accumulator = struct
    type 'input_type t = (string * ('input_type -> Yojson.Safe.t)) list
  end

  let init () = []

  let add_field t_field field acc =
    ( (fun _ -> failwith "Unused")
    , ( Fields_derivers.name_under_to_camel field
      , fun x -> t_field (Field.get field x) )
      :: acc )

  let finish (_creator, field_convs) t =
    `Assoc (List.map field_convs ~f:(fun (name, f) -> (name, f t)) |> List.rev)

  module Prim = struct
    let int acc x = add_field (fun x -> `Int x) acc x

    let string acc x = add_field (fun x -> `String x) acc x
  end
end

(* Make sure that this is a deriver *)
module To_yojson_ : Fields_derivers.Deriver = To_yojson

module Of_yojson = struct
  module Input = struct
    type 'input_type t = Yojson.Safe.t -> 'input_type
  end

  module Creator = struct
    type 'input_type t = Yojson.Safe.t String.Map.t
  end

  module Output = Input

  module Accumulator = struct
    type _ t = unit
  end

  let init () = ()

  let add_field t_field field () =
    ( (fun map ->
        t_field (Map.find_exn map (Fields_derivers.name_under_to_camel field)))
    , () )

  let finish (creator, ()) json =
    match json with
    | `Assoc pairs ->
        creator (String.Map.of_alist_exn pairs)
    | _ ->
        failwith "oh no"

  module Prim = struct
    let int acc x =
      add_field (function `Int x -> x | _ -> failwith "todo") acc x

    let string acc x =
      add_field (function `String x -> x | _ -> failwith "todo") acc x
  end
end

(* Make sure that this is a deriver *)
module Of_yojson_ : Fields_derivers.Deriver = Of_yojson

let%test_module "Test" =
  ( module struct
    type t = { foo_hello : int; bar : string } [@@deriving fields]

    let v = { foo_hello = 1; bar = "baz" }

    let m = "{ fooHello: 1, bar: \"baz\" }" |> Yojson.Safe.from_string

    module Yojson_version = struct
      type t = { foo_hello : int [@key "fooHello"]; bar : string }
      [@@deriving yojson]

      let v = { foo_hello = 1; bar = "baz" }
    end

    let to_json : t -> Yojson.Safe.t =
      Fields.make_creator (To_yojson.init ()) ~foo_hello:To_yojson.Prim.int
        ~bar:To_yojson.Prim.string
      |> To_yojson.finish

    let of_json =
      Fields.make_creator (Of_yojson.init ()) ~foo_hello:Of_yojson.Prim.int
        ~bar:Of_yojson.Prim.string
      |> Of_yojson.finish

    let%test_unit "folding creates a yojson object we expect (modulo camel \
                   casing)" =
      [%test_eq: string]
        (Yojson_version.to_yojson Yojson_version.v |> Yojson.Safe.to_string)
        (to_json v |> Yojson.Safe.to_string)

    let%test_unit "unfolding creates a yojson object we expect" =
      let expected =
        Yojson_version.of_yojson m |> Result.ok |> Option.value_exn
      in
      let actual = of_json m in
      [%test_eq: string] expected.bar actual.bar ;
      [%test_eq: int] expected.foo_hello actual.foo_hello

    let%test_unit "round trip" =
      [%test_eq: string]
        (to_json (of_json m) |> Yojson.Safe.to_string)
        (m |> Yojson.Safe.to_string)
  end )
