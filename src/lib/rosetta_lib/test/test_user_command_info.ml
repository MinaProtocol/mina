open Core_kernel
open Rosetta_lib
open Alcotest
module Amount_of = Rosetta_lib.Amount_of
module Partial = Rosetta_lib.User_command_info.Partial

(* Define testable types *)
let partial_testable =
  Alcotest.testable
    (fun fmt t ->
      Format.fprintf fmt "%s" (Sexplib.Sexp.to_string_hum (Partial.sexp_of_t t))
      )
    Partial.equal

let test_payment_round_trip () =
  let start =
    { User_command_info.kind = `Payment (* default token *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status = None
    ; hash = "TXN_1_HASH"
    ; valid_until = Some (Unsigned.UInt32.of_int 10_000)
    ; memo = Some "hello"
    }
  in
  let ops = User_command_info.to_operations' start in
  match
    User_command_info.of_operations ?valid_until:start.valid_until
      ?memo:start.memo ops
  with
  | Ok partial ->
      check partial_testable "payment round trip"
        (User_command_info.forget start)
        partial
  | Error e ->
      failf "Mismatch because %s"
        (Sexplib.Sexp.to_string_hum ([%sexp_of: Partial.Reason.t list] e))

let test_delegation_round_trip () =
  let start =
    { User_command_info.kind = `Delegation
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 1_000_000_000
    ; receiver = `Pk "Bob"
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; nonce = Unsigned.UInt32.of_int 42
    ; amount = None
    ; failure_status = None
    ; hash = "TXN_2_HASH"
    ; valid_until = Some (Unsigned.UInt32.of_int 867888)
    ; memo = Some "hello"
    }
  in
  let ops = User_command_info.to_operations' start in
  match
    User_command_info.of_operations ops ?valid_until:start.valid_until
      ?memo:start.memo
  with
  | Ok partial ->
      check partial_testable "delegation round trip"
        (User_command_info.forget start)
        partial
  | Error e ->
      failf "Mismatch because %s"
        (Sexplib.Sexp.to_string_hum ([%sexp_of: Partial.Reason.t list] e))

let () =
  run "User_command_info"
    [ ( "round_trip"
      , [ test_case "payment round trip" `Quick test_payment_round_trip
        ; test_case "delegation round trip" `Quick test_delegation_round_trip
        ] )
    ]
