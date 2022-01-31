open Core_kernel
open Fieldslib

module To_yojson_basic = struct
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

  let int_ x = `Int x

  let string_ x = `String x

  let bool_ x = `Bool x

  let list_ f xs = `List (List.map ~f xs)
end

module To_yojson = Fields_derivers.Make (To_yojson_basic)

module Of_yojson_basic = struct
  module Input = struct
    type 'input_type t = Yojson.Safe.t -> ('input_type, string) Result.t
  end

  module Creator = struct
    type 'input_type t = Yojson.Safe.t String.Map.t
  end

  module Output = Input

  module Accumulator = struct
    type _ t = unit
  end

  let init () = ()

  let add_field (t_field : 'f Input.t)
      (field :
        ( [< `Read | `Set_and_create ]
        , 'input_type
        , 'f )
        Fieldslib.Field.t_with_perm) (() : 'input_type Accumulator.t) :
      ('input_type Creator.t -> ('f, string) Result.t)
      * 'input_type Accumulator.t =
    ( (fun map ->
        let name = Fields_derivers.name_under_to_camel field in
        match Map.find map name with
        | Some j ->
            t_field j
        | None ->
            Result.fail (Format.sprintf "cannot find field %s" name))
    , () )

  let finish (creator, ()) json =
    match json with
    | `Assoc pairs -> (
        match String.Map.of_alist pairs with
        | `Ok m ->
            Ok (creator m)
        | `Duplicate_key a ->
            Result.fail (Format.sprintf "duplicate key: %s" a) )
    | _ ->
        Result.fail "expected associated list of fields"

  let int_ = function `Int x -> Ok x | _ -> Result.fail "expected int"

  let string_ = function
    | `String x ->
        Ok x
    | _ ->
        Result.fail "expected string"

  let bool_ = function `Bool x -> Ok x | _ -> Result.fail "expected bool"

  let list_ f = function
    | `List xs ->
        let sequence (xrs : ('a, 'e) Result.t List.t) : ('a List.t, 'e) Result.t
            =
          List.fold xrs ~init:(Result.return []) ~f:(fun acc x ->
              let open Result.Let_syntax in
              let%bind acc = acc in
              let%map x = x in
              x :: acc)
        in

        List.map xs ~f |> sequence
    | _ ->
        Result.fail "expected list"
end

module Of_yojson = Fields_derivers.Make (Of_yojson_basic)
module Both_yojson = Fields_derivers.Make2 (To_yojson) (Of_yojson)

let%test_module "Test" =
  ( module struct
    type t = { foo_hello : int; bar : string list } [@@deriving fields]

    let v = { foo_hello = 1; bar = [ "baz1"; "baz2" ] }

    let m =
      "{ fooHello: 1, bar: [\"baz1\", \"baz2\"] }" |> Yojson.Safe.from_string

    module Yojson_version = struct
      type t = { foo_hello : int [@key "fooHello"]; bar : string list }
      [@@deriving yojson]

      let v = { foo_hello = 1; bar = [ "baz1"; "baz2" ] }
    end

    let to_json =
      let open To_yojson.Prim in
      Fields.make_creator (To_yojson.init ()) ~foo_hello:int
        ~bar:(list To_yojson.string_)
      |> To_yojson.finish

    let of_json =
      let open Of_yojson.Prim in
      Fields.make_creator (Of_yojson.init ()) ~foo_hello:int
        ~bar:(list Of_yojson.string_)
      |> Of_yojson.finish

    let to_json', of_json' =
      let open Both_yojson.Prim in
      Fields.make_creator (Both_yojson.init ()) ~foo_hello:int
        ~bar:(list Both_yojson.string_)
      |> Both_yojson.finish

    let%test_unit "folding creates a yojson object we expect (modulo camel \
                   casing)" =
      [%test_eq: string]
        (Yojson_version.to_yojson Yojson_version.v |> Yojson.Safe.to_string)
        (to_json v |> Yojson.Safe.to_string)

    let force x = x |> Result.ok |> Option.value_exn

    let%test_unit "unfolding creates a yojson object we expect" =
      let expected = Yojson_version.of_yojson m |> force in
      let actual = of_json m |> force in
      [%test_eq: string list] expected.bar actual.bar ;
      [%test_eq: int] expected.foo_hello actual.foo_hello

    let%test_unit "round trip" =
      [%test_eq: string]
        (to_json (of_json m |> force) |> Yojson.Safe.to_string)
        (m |> Yojson.Safe.to_string)

    let%test_unit "composed same as decomposed" =
      [%test_eq: string]
        (to_json (of_json m |> force) |> Yojson.Safe.to_string)
        (to_json' (of_json' m |> force) |> Yojson.Safe.to_string)
  end )
