open Core

module Combinators = struct
  module Scalar = struct
    type t = Int of int | String of string | Null

    let is_json_equal : t -> Yojson.Basic.json -> bool = function
      | Int int_value -> (
          function
          | `Int json_int_value ->
              Int.equal int_value json_int_value
          | _ ->
              false )
      | String string_value -> (
          function
          | `String json_string_value ->
              String.equal string_value json_string_value
          | _ ->
              false )
      | Null -> (
          function `Null -> true | _ -> false )
  end

  module Pattern = struct
    let list : Yojson.Basic.json -> Yojson.Basic.json list option = function
      | `List list ->
          Some list
      | _ ->
          None

    let assoc_list :
        Yojson.Basic.json -> (string * Yojson.Basic.json) list option =
      function
      | `Assoc assoc ->
          Some assoc
      | _ ->
          None

    let assoc_list_elem :
        string -> (string * Yojson.Basic.json) list -> Yojson.Basic.json option
        =
     fun test_name assoc_list ->
      let get_individual_value test_name (key, (value_json : Yojson.Basic.json))
          =
        Option.some_if (String.equal key test_name) value_json
      in
      List.find_map assoc_list ~f:(get_individual_value test_name)

    let is_equal_scalar : Scalar.t -> Yojson.Basic.json -> bool option =
     fun target_json json ->
      Option.some @@ Scalar.is_json_equal target_json json

    let key_and_value ~key ~value assoc_list =
      let open Option.Let_syntax in
      assoc_list_elem key assoc_list >>= is_equal_scalar value

    let ( && ) :
        ('a -> bool option) -> ('a -> bool option) -> 'a -> bool option =
     fun f1 f2 x ->
      let open Option.Let_syntax in
      if%bind f1 x then f2 x else None

    let ( || ) :
        ('a -> bool option) -> ('a -> bool option) -> 'a -> bool option =
     fun f1 f2 x ->
      let open Option.Let_syntax in
      if%bind f1 x then Some true else f2 x
  end

  let compute_validity = Option.value_map ~default:false ~f:Fn.id

  module Change = struct
    open Pattern

    let list json
        ~(f : Yojson.Basic.json list -> Yojson.Basic.json list Or_error.t) =
      let open Result.Let_syntax in
      let%bind list =
        Result.of_option (list json) ~error:(Error.of_string "Expected list")
      in
      let%map result = f list in
      `List result

    let association_list json
        ~(f :
              (string * Yojson.Basic.json) list
           -> (string * Yojson.Basic.json) list Or_error.t) =
      let open Result.Let_syntax in
      let%bind assoc_list =
        Result.of_option (assoc_list json)
          ~error:(Error.of_string "Expected association list")
      in
      let%map result = f assoc_list in
      `Assoc result

    let key_value_pair (assoc_list : (string * Yojson.Basic.json) list)
        ~(f : string * Yojson.Basic.json -> Yojson.Basic.json Or_error.t) =
      let open Result.Let_syntax in
      let have_all_errors, result =
        List.fold_map assoc_list ~init:false
          ~f:(fun acc_is_error (key, value) ->
            match
              let%map new_value = f (key, value) in
              (key, new_value)
            with
            | Ok new_keypair ->
                (true, new_keypair)
            | Error _ ->
                (acc_is_error, (key, value)) )
      in
      let%map () =
        Result.ok_if_true have_all_errors
          ~error:(Error.of_string "No Key pair change, so expected error")
      in
      result

    let value_with_name
        ~(f : Yojson.Basic.json -> Yojson.Basic.json Or_error.t) test_name
        (assoc_list : (string * Yojson.Basic.json) list) =
      Result.map_error
        ~f:
          (Fn.const
             (Error.createf
                !"Could not find key matching with name: %s"
                test_name))
      @@ key_value_pair assoc_list ~f:(fun (name, value) ->
             let open Or_error.Let_syntax in
             let%bind () =
               Result.ok_if_true
                 (String.equal test_name name)
                 ~error:
                   (Error.of_string "Element did not have expected test name")
             in
             f value )
  end
end

let rec stitch (json : Yojson.Basic.json) ~predicate ~action :
    Yojson.Basic.json =
  if predicate json then Or_error.ok_exn (action json)
  else
    match json with
    | `Assoc assoc_list ->
        `Assoc
          (List.map assoc_list ~f:(fun (key, value) ->
               (key, stitch value ~predicate ~action) ))
    | `List subjsons ->
        `List (List.map subjsons ~f:(stitch ~predicate ~action))
    | json ->
        json
