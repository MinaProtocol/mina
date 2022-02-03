open Core_kernel
open Fieldslib

module To_yojson = struct
  module Input = struct
    type ('input_type, 'a, 'c) t =
      < to_json : ('input_type -> Yojson.Safe.t) ref
      ; contramap : ('c -> 'input_type) ref
      ; .. >
      as
      'a
  end

  module Accumulator = struct
    type ('input_type, 'a, 'c) t =
      < to_json_accumulator : (string * ('input_type -> Yojson.Safe.t)) list ref
      ; .. >
      as
      'a
      constraint ('input_type, 'a, 'c) t = ('input_type, 'a, 'c) Input.t
  end

  let add_field t_field field acc =
    let rest = !(acc#to_json_accumulator) in
    acc#to_json_accumulator :=
      ( Fields_derivers.name_under_to_camel field
      , fun x -> !(t_field#to_json) (!(t_field#contramap) (Field.get field x))
      )
      :: rest ;
    ((fun _ -> failwith "Unused"), acc)

  let finish (_creator, obj) =
    let to_json_accumulator = !(obj#to_json_accumulator) in
    (obj#to_json :=
       fun t ->
         `Assoc
           ( List.map to_json_accumulator ~f:(fun (name, f) -> (name, f t))
           |> List.rev )) ;
    obj

  let ( !. ) x fd acc = add_field x fd acc

  let int =
    object
      method to_json = ref (fun x -> `Int x)

      method contramap = ref Fn.id
    end

  let string =
    object
      method to_json = ref (fun x -> `String x)

      method contramap = ref Fn.id
    end

  let bool =
    object
      method to_json = ref (fun x -> `Bool x)

      method contramap = ref Fn.id
    end

  let list o =
    object
      method to_json = ref (fun x -> `List (List.map ~f:!(o#to_json) x))

      method contramap = ref (List.map ~f:!(o#contramap))
    end

  let option o =
    object
      method to_json =
        ref (fun x_opt ->
            match x_opt with Some x -> !(o#to_json) x | None -> `Null)

      method contramap = ref (Option.map ~f:!(o#contramap))
    end
end

module Of_yojson = struct
  module Input = struct
    type ('input_type, 'a, 'c) t =
      < of_json : (Yojson.Safe.t -> 'input_type) ref
      ; map : ('input_type -> 'c) ref
      ; .. >
      as
      'a
  end

  module Creator = struct
    type ('input_type, 'a, 'c) t =
      < of_json_creator : Yojson.Safe.t String.Map.t ref ; .. > as 'a
      constraint ('input_type, 'a, 'c) t = ('input_type, 'a, 'c) Input.t
  end

  let add_field : ('t, 'a, 'c) Input.t -> 'field -> 'obj -> 'creator * 'obj =
   fun t_field field acc_obj ->
    let creator finished_obj =
      let map = !(finished_obj#of_json_creator) in
      !(t_field#map)
        (!(t_field#of_json)
           (Map.find_exn map (Fields_derivers.name_under_to_camel field)))
    in
    (creator, acc_obj)

  let finish (creator, obj) =
    let of_json json =
      match json with
      | `Assoc pairs ->
          obj#of_json_creator := String.Map.of_alist_exn pairs ;
          creator obj
      | _ ->
          failwith "todo"
    in
    obj#of_json := of_json ;
    obj

  let ( !. ) x fd acc = add_field x fd acc

  (* TODO: Replace failwith's exception *)
  let int =
    object
      method of_json = ref (function `Int x -> x | _ -> failwith "todo")

      method map = ref Fn.id
    end

  let string =
    object
      method of_json = ref (function `String x -> x | _ -> failwith "todo")

      method map = ref Fn.id
    end

  let bool =
    object
      method of_json = ref (function `Bool x -> x | _ -> failwith "todo")

      method map = ref Fn.id
    end

  let list obj =
    object
      method of_json =
        ref (function
          | `List xs ->
              List.map xs ~f:!(obj#of_json)
          | _ ->
              failwith "todo")

      method map = ref (List.map ~f:!(obj#map))
    end

  let option obj =
    object
      method of_json =
        ref (function `Null -> None | other -> Some (!(obj#of_json) other))

      method map = ref (Option.map ~f:!(obj#map))
    end
end

let%test_module "Test" =
  ( module struct
    type t = { foo_hello : int; bar : string list } [@@deriving fields]

    let v = { foo_hello = 1; bar = [ "baz1"; "baz2" ] }

    let m =
      {json|{ fooHello: 1, bar: ["baz1", "baz2"] }|json}
      |> Yojson.Safe.from_string

    module Yojson_version = struct
      type t = { foo_hello : int [@key "fooHello"]; bar : string list }
      [@@deriving yojson]

      let v = { foo_hello = 1; bar = [ "baz1"; "baz2" ] }
    end

    let deriver =
      let to_json = ref (fun _ -> failwith "unimplemented") in
      let of_json = ref (fun _ -> failwith "unimplemented") in
      let to_json_accumulator = ref [] in
      let of_json_creator = ref String.Map.empty in
      let map = ref Fn.id in
      let contramap = ref Fn.id in
      object
        method to_json = to_json

        method map = map

        method contramp = contramap

        method of_json = of_json

        method to_json_accumulator = to_json_accumulator

        method of_json_creator = of_json_creator
      end

    let _to_json =
      let open To_yojson in
      Fields.make_creator deriver ~foo_hello:!.int ~bar:!.(list string)
      |> finish

    let _of_json =
      let open Of_yojson in
      Fields.make_creator deriver ~foo_hello:!.int ~bar:!.(list string)
      |> finish

    let%test_unit "folding creates a yojson object we expect (modulo camel \
                   casing)" =
      [%test_eq: string]
        (Yojson_version.to_yojson Yojson_version.v |> Yojson.Safe.to_string)
        (!(deriver#to_json) v |> Yojson.Safe.to_string)

    let%test_unit "unfolding creates a yojson object we expect" =
      let expected =
        Yojson_version.of_yojson m |> Result.ok |> Option.value_exn
      in
      let actual = !(deriver#of_json) m in
      [%test_eq: string list] expected.bar actual.bar ;
      [%test_eq: int] expected.foo_hello actual.foo_hello

    let%test_unit "round trip" =
      [%test_eq: string]
        (!(deriver#to_json) (!(deriver#of_json) m) |> Yojson.Safe.to_string)
        (m |> Yojson.Safe.to_string)
  end )
