(* Decoding of the JSON-valued CLI flags.  See [payload.mli]. *)

open Core

let json ~label s =
  match Or_error.try_with (fun () -> Yojson.Safe.from_string s) with
  | Ok parsed ->
      Ok parsed
  | Error _ ->
      Or_error.errorf "%s: invalid JSON" label

let json_object ~label s =
  let open Or_error.Let_syntax in
  match%bind json ~label s with
  | `Assoc _ as parsed ->
      Ok parsed
  | _ ->
      Or_error.errorf "%s: expected a JSON object" label

(* A value a [@default] would swallow on the way out, so its absence
   from the re-encoded output is not evidence that the key was
   misspelled. *)
let defaultable = function `Null | `List [] | `Assoc [] -> true | _ -> false

let child path key = if String.is_empty path then key else path ^ "." ^ key

let rec unknown_keys ~path input output =
  match (input, output) with
  | `Assoc input_fields, `Assoc output_fields ->
      List.concat_map input_fields ~f:(fun (key, value) ->
          match List.Assoc.find output_fields key ~equal:String.equal with
          | Some encoded ->
              unknown_keys ~path:(child path key) value encoded
          | None ->
              if defaultable value then [] else [ child path key ] )
  | `List inputs, `List outputs when List.length inputs = List.length outputs ->
      List.concat_mapi (List.zip_exn inputs outputs)
        ~f:(fun i (input, output) ->
          unknown_keys ~path:(sprintf "%s[%d]" path i) input output )
  | _ ->
      (* Not a shape whose keys correspond: a free-form [Yojson.Safe.t]
         field of a model round-trips as itself, and anything else the
         model already accepted or rejected on its own. *)
      []

let model ~label ~of_yojson ~to_yojson s =
  let open Or_error.Let_syntax in
  let%bind parsed = json ~label s in
  match of_yojson parsed with
  | Error message ->
      (* ppx_deriving_yojson has no message for some failures (a list
         whose element is the wrong shape), and a diagnostic ending in a
         bare ": " reads as truncated output. *)
      Or_error.errorf "%s: does not match the Rosetta schema%s" label
        ( if String.is_empty (String.strip message) then ""
          else ": " ^ String.strip message )
  | Ok value -> (
      match unknown_keys ~path:"" parsed (to_yojson value) with
      | [] ->
          Ok value
      | keys ->
          Or_error.errorf "%s: unknown field%s: %s" label
            (if List.length keys = 1 then "" else "s")
            (String.concat ~sep:", " keys) )

let%test_module "payload" =
  ( module struct
    let check ~label ~of_yojson ~to_yojson s =
      match model ~label ~of_yojson ~to_yojson s with
      | Ok _ ->
          None
      | Error e ->
          Some (Error.to_string_hum e)

    let public_key =
      check ~label:"--public-key-json"
        ~of_yojson:[%of_yojson: Rosetta_models.Public_key.t]
        ~to_yojson:[%to_yojson: Rosetta_models.Public_key.t]

    let%test "a well-formed payload decodes" =
      Option.is_none (public_key {|{"hex_bytes":"aabb","curve_type":"pallas"}|})

    let%test "a misspelled field is named, not dropped" =
      match
        public_key {|{"hex_bytes":"aabb","curve_type":"pallas","typo":1}|}
      with
      | Some message ->
          String.is_substring message ~substring:"typo"
      | None ->
          false

    let%test "a schema failure with no message has no trailing colon" =
      match
        check ~label:"--operations-json"
          ~of_yojson:[%of_yojson: Rosetta_models.Operation.t list]
          ~to_yojson:[%to_yojson: Rosetta_models.Operation.t list] {|{"a":1}|}
      with
      | Some message ->
          not (String.is_suffix (String.strip message) ~suffix:":")
      | None ->
          false

    let%test "a field left at its default is not reported as unknown" =
      List.is_empty
        (unknown_keys ~path:""
           (`Assoc [ ("status", `Null); ("related_operations", `List []) ])
           (`Assoc []) )

    let%test "an unknown key nested in a list carries its path" =
      List.equal String.equal
        (unknown_keys ~path:""
           (`Assoc [ ("ops", `List [ `Assoc [ ("typo", `Int 1) ] ]) ])
           (`Assoc [ ("ops", `List [ `Assoc [] ]) ]) )
        [ "ops[0].typo" ]

    let%test "a free-form object is not walked for unknown keys" =
      let free_form = `Assoc [ ("anything", `Int 1) ] in
      List.is_empty (unknown_keys ~path:"" free_form free_form)

    let%test "a non-object free-form flag is refused" =
      Or_error.is_error (json_object ~label:"--options-json" "5")
  end )
