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
    obj#contramap := Fn.id ;
    (obj#to_json :=
       fun t ->
         `Assoc
           ( List.map to_json_accumulator ~f:(fun (name, f) -> (name, f t))
           |> List.rev )) ;
    obj

  let int obj =
    obj#contramap := Fn.id ;
    (obj#to_json := fun x -> `Int x) ;
    obj

  let string obj =
    obj#contramap := Fn.id ;
    (obj#to_json := fun x -> `String x) ;
    obj

  let bool obj =
    obj#contramap := Fn.id ;
    (obj#to_json := fun x -> `Bool x) ;
    obj

  let list x obj =
    obj#contramap := List.map ~f:!(x#contramap) ;
    (obj#to_json := fun a -> `List (List.map ~f:!(x#to_json) a)) ;
    obj

  let option x obj =
    obj#contramap := Option.map ~f:!(x#contramap) ;
    (obj#to_json :=
       fun a_opt -> match a_opt with Some a -> !(x#to_json) a | None -> `Null) ;
    obj

  let contramap ~f x obj =
    (obj#contramap := fun a -> !(x#contramap) (f a)) ;
    obj#to_json := !(x#to_json) ;
    obj
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

  exception Field_not_found of string

  let add_field : ('t, 'a, 'c) Input.t -> 'field -> 'obj -> 'creator * 'obj =
   fun t_field field acc_obj ->
    let creator finished_obj =
      let map = !(finished_obj#of_json_creator) in
      !(t_field#map)
        (!(t_field#of_json)
           (let name = Fields_derivers.name_under_to_camel field in
            match Map.find map name with
            | None ->
                raise (Field_not_found name)
            | Some x ->
                x))
    in
    (creator, acc_obj)

  exception Json_not_object

  let finish (creator, obj) =
    let of_json json =
      match json with
      | `Assoc pairs ->
          obj#of_json_creator := String.Map.of_alist_exn pairs ;
          creator obj
      | _ ->
          raise Json_not_object
    in
    obj#map := Fn.id ;
    obj#of_json := of_json ;
    obj

  exception Invalid_json_scalar of [ `Int | `String | `Bool | `List ]

  (* TODO: Replace failwith's exception *)
  let int obj =
    (obj#of_json :=
       function `Int x -> x | _ -> raise (Invalid_json_scalar `Int)) ;
    obj#map := Fn.id ;
    obj

  let string obj =
    (obj#of_json :=
       function `String x -> x | _ -> raise (Invalid_json_scalar `String)) ;
    obj#map := Fn.id ;
    obj

  let bool obj =
    (obj#of_json :=
       function `Bool x -> x | _ -> raise (Invalid_json_scalar `Bool)) ;
    obj#map := Fn.id ;
    obj

  let list x obj =
    (obj#of_json :=
       function
       | `List xs ->
           List.map xs ~f:!(x#of_json)
       | _ ->
           raise (Invalid_json_scalar `List)) ;
    obj#map := List.map ~f:!(x#map) ;
    obj

  let option x obj =
    (obj#of_json :=
       function `Null -> None | other -> Some (!(x#of_json) other)) ;
    obj#map := Option.map ~f:!(x#map) ;
    obj

  let map ~f x obj =
    (obj#map := fun a -> f (!(x#map) a)) ;
    obj#of_json := !(x#of_json) ;
    obj
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

    let deriver () =
      let to_json = ref (fun _ -> failwith "unimplemented") in
      let of_json = ref (fun _ -> failwith "unimplemented") in
      let to_json_accumulator = ref [] in
      let of_json_creator = ref String.Map.empty in
      let map = ref Fn.id in
      let contramap = ref Fn.id in
      object
        method to_json = to_json

        method map = map

        method contramap = contramap

        method of_json = of_json

        method to_json_accumulator = to_json_accumulator

        method of_json_creator = of_json_creator
      end

    let o () = deriver ()

    (* Explanation: Fields.make_creator roughly executes the following code:

       let make_creator ~foo_hello ~bar obj =
         (* Fieldslib.Field is actually a little more complicated *)
         let field_foo = Field { name = "foo_hello" ; getter = (fun o -> o.foo_hello) } in
         let field_bar = Field { name = "bar"; getter = (fun o -> o.bar) } in
         let creator_foo, obj = foo_hello field_foo obj in
         let creator_bar, obj = bar field_bar obj in
         let creator finished_obj =
           { foo_hello = creator_foo finished_obj ; bar = creator_bar finished_obj }
         in
         (creator, obj)
    *)

    let to_json obj =
      let open To_yojson in
      let ( !. ) x fd acc = add_field (x @@ o ()) fd acc in
      Fields.make_creator obj ~foo_hello:!.int ~bar:!.(list @@ string @@ o ())
      |> finish

    let of_json obj =
      let open Of_yojson in
      let ( !. ) x fd acc = add_field (x @@ o ()) fd acc in
      Fields.make_creator obj ~foo_hello:!.int ~bar:!.(list @@ string @@ o ())
      |> finish

    let both_json obj =
      let _a = to_json obj in
      let _b = of_json obj in
      obj

    let full_derivers = both_json @@ o ()

    let%test_unit "folding creates a yojson object we expect (modulo camel \
                   casing)" =
      [%test_eq: string]
        (Yojson_version.to_yojson Yojson_version.v |> Yojson.Safe.to_string)
        (!(full_derivers#to_json) v |> Yojson.Safe.to_string)

    let%test_unit "unfolding creates a yojson object we expect" =
      let expected =
        Yojson_version.of_yojson m |> Result.ok |> Option.value_exn
      in
      let actual = !(full_derivers#of_json) m in
      [%test_eq: string list] expected.bar actual.bar ;
      [%test_eq: int] expected.foo_hello actual.foo_hello

    let%test_unit "round trip" =
      [%test_eq: string]
        ( !(full_derivers#to_json) (!(full_derivers#of_json) m)
        |> Yojson.Safe.to_string )
        (m |> Yojson.Safe.to_string)
  end )
