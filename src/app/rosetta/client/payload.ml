(* Decoding of the JSON-valued command-line flags.  See [payload.mli]. *)

open Core_kernel

let json ~label s =
  match Or_error.try_with (fun () -> Yojson.Safe.from_string s) with
  | Ok parsed ->
      Ok parsed
  | Error _ ->
      Or_error.errorf "%s: invalid JSON" label

let model ~label of_yojson s =
  let open Or_error.Let_syntax in
  let%bind parsed = json ~label s in
  match of_yojson parsed with
  | Ok value ->
      Ok value
  | Error message ->
      Or_error.errorf "%s: does not match the Rosetta schema: %s" label message

let model_opt ~label of_yojson s =
  Option.value_map s ~default:(Ok None) ~f:(fun s ->
      Or_error.map (model ~label of_yojson s) ~f:Option.some )

let json_opt ~label s =
  Option.value_map s ~default:(Ok None) ~f:(fun s ->
      Or_error.map (json ~label s) ~f:Option.some )
