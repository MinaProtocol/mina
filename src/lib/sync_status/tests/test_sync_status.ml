open Core_kernel
open Sync_status

(* Test helper to check round-trip conversion *)
let check_conv to_repr of_repr ok_or_fail =
  let all_statuses =
    [ `Offline; `Bootstrap; `Synced; `Connecting; `Listening; `Catchup ]
  in
  List.for_all all_statuses ~f:(fun sync_status ->
      equal sync_status (of_repr (to_repr sync_status) |> ok_or_fail) )

(* Test string conversions *)
let test_string_conversion () =
  Alcotest.(check bool)
    "String round-trip conversion" true
    (check_conv to_string of_string Or_error.ok_exn)

(* Individual string conversion tests for better error reporting *)
let test_string_conversions_individual () =
  let test_status status =
    let str = to_string status in
    let result = of_string str |> Or_error.ok_exn in
    Alcotest.(check bool)
      (Printf.sprintf "String conversion for %s" str)
      true (equal status result)
  in

  List.iter
    [ `Offline; `Bootstrap; `Synced; `Connecting; `Listening; `Catchup ]
    ~f:test_status

(* Test JSON conversions *)
let test_json_conversion () =
  Alcotest.(check bool)
    "JSON round-trip conversion" true
    (check_conv to_yojson of_yojson (function
      | Error e ->
          failwith e
      | Ok x ->
          x ) )

(* Individual JSON conversion tests for better error reporting *)
let test_json_conversions_individual () =
  let test_status status =
    let json = to_yojson status in
    let result =
      of_yojson json |> function Error e -> failwith e | Ok x -> x
    in
    Alcotest.(check bool)
      (Printf.sprintf "JSON conversion for %s" (Yojson.Safe.to_string json))
      true (equal status result)
  in

  List.iter
    [ `Offline; `Bootstrap; `Synced; `Connecting; `Listening; `Catchup ]
    ~f:test_status

(* Test error handling in string conversion *)
let test_of_string_error () =
  match of_string "invalid_status" with
  | Ok _ ->
      Alcotest.fail "Expected error for invalid status string, but got Ok"
  | Error e ->
      Alcotest.(check bool)
        "Error message for invalid status string" true
        (String.is_substring (Error.to_string_hum e)
           ~substring:"is not a valid status" )

(* Test error handling in JSON conversion *)
let test_of_json_error () =
  match of_yojson (`Int 42) with
  | Ok _ ->
      Alcotest.fail "Expected error for invalid JSON value, but got Ok"
  | Error e ->
      Alcotest.(check string)
        "Error message for invalid JSON value" "expected string" e

(* Main test runner *)
let () =
  Alcotest.run "Sync_status"
    [ ( "Conversion tests"
      , [ Alcotest.test_case "String round-trip" `Quick test_string_conversion
        ; Alcotest.test_case "String individual conversions" `Quick
            test_string_conversions_individual
        ; Alcotest.test_case "JSON round-trip" `Quick test_json_conversion
        ; Alcotest.test_case "JSON individual conversions" `Quick
            test_json_conversions_individual
        ] )
    ; ( "Error handling"
      , [ Alcotest.test_case "Invalid string" `Quick test_of_string_error
        ; Alcotest.test_case "Invalid JSON" `Quick test_of_json_error
        ] )
    ]
