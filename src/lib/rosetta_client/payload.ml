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

(* Whether the model understood a key is not visible in the decoded
   value: a key it ignored and a key it decoded to its [@default] both
   go missing from the re-encoded output.  Probing tells them apart --
   overwrite the key's value with something no model can have produced
   and encode again.  A key the model reads either changes the output or
   is rejected outright; a key it ignores leaves the output byte for
   byte as it was.

   This walks the whole document, so it also reaches a typo nested in a
   list element or in a sub-model, and it leaves the free-form
   [Yojson.Safe.t] fields alone on their own merits: their contents
   round-trip verbatim, so every key in them reads as understood. *)
let probe = `String "\000rosetta-client-unknown-field-probe"

let child path key = if String.is_empty path then key else path ^ "." ^ key

let rec walk ~roundtrip ~baseline ~path ~rebuild json =
  let recur = walk ~roundtrip ~baseline in
  match json with
  | `Assoc fields ->
      List.concat_map fields ~f:(fun (key, value) ->
          let replace x =
            rebuild
              (`Assoc
                 (List.map fields ~f:(fun (k, v) ->
                      if String.equal k key then (k, x) else (k, v) ) ) )
          in
          let path = child path key in
          if Option.equal Yojson.Safe.equal (roundtrip (replace probe)) baseline
          then [ path ]
          else recur ~path ~rebuild:replace value )
  | `List items ->
      List.concat_mapi items ~f:(fun i item ->
          let replace x =
            rebuild
              (`List (List.mapi items ~f:(fun j v -> if i = j then x else v)))
          in
          recur ~path:(sprintf "%s[%d]" path i) ~rebuild:replace item )
  | _ ->
      []

let unknown_keys ~roundtrip json =
  walk ~roundtrip ~baseline:(roundtrip json) ~path:"" ~rebuild:Fn.id json

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
      let roundtrip json =
        Result.ok (of_yojson json) |> Option.map ~f:to_yojson
      in
      match unknown_keys ~roundtrip parsed with
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

    let operations =
      check ~label:"--operations-json"
        ~of_yojson:[%of_yojson: Rosetta_models.Operation.t list]
        ~to_yojson:[%to_yojson: Rosetta_models.Operation.t list]

    let operation ~extra =
      sprintf
        {|[{"operation_identifier":{"index":0},"type":"payment","status":null,"related_operations":[]%s}]|}
        extra

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
      match operations {|{"a":1}|} with
      | Some message ->
          not (String.is_suffix (String.strip message) ~suffix:":")
      | None ->
          false

    (* [status] is null and [related_operations] empty: both decode to
       their default and vanish from the re-encoded output, which is not
       evidence of a typo. *)
    let%test "a field left at its default is accepted" =
      Option.is_none (operations (operation ~extra:""))

    let%test "an unknown key nested in a list element carries its path" =
      match operations (operation ~extra:{|,"typo":1|}) with
      | Some message ->
          String.is_substring message ~substring:"[0].typo"
      | None ->
          false

    (* [metadata] is free-form: every key in it round-trips verbatim, so
       none of them reads as unknown. *)
    let%test "a free-form field's keys are not reported" =
      Option.is_none
        (operations (operation ~extra:{|,"metadata":{"anything":1}|}))

    (* The case a plain key diff gets wrong: [a] holds exactly the value
       the decoder would have defaulted it to, so it is absent from the
       output even though the model reads it. *)
    let%test "a field holding its own non-empty default is accepted" =
      let module M = struct
        type t = { a : string [@default "d"] }
        [@@deriving yojson { strict = false }]
      end in
      Option.is_none
        (check ~label:"--m-json" ~of_yojson:[%of_yojson: M.t]
           ~to_yojson:[%to_yojson: M.t] {|{"a":"d"}|} )
      && Option.is_some
           (check ~label:"--m-json" ~of_yojson:[%of_yojson: M.t]
              ~to_yojson:[%to_yojson: M.t] {|{"a":"d","typo":1}|} )

    let%test "a non-object free-form flag is refused" =
      Or_error.is_error (json_object ~label:"--options-json" "5")
  end )
