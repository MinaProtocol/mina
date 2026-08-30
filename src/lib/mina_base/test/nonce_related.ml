open Core
open Mina_base
open Zkapp_command
open Signature_lib

let filter ((x, _y) : t * int) : bool =
  Unsigned.UInt32.to_int x.fee_payer.body.nonce
  + 1
  + List.length (Call_forest.to_list x.account_updates)
  <= Unsigned.UInt32.to_int Unsigned.UInt32.max_int

let filtered =
  Base_quickcheck.Generator.filter Valid_size.zkapp_type_gen ~f:filter

(* [target_nonce_on_success] advances the fee payer's nonce past the end of its
   range when [succ] alone overflows, which is to say when the nonce is at its
   maximum. Searching a generated nonce for that does not terminate in
   practice, and each draw builds a call forest of up to a thousand account
   updates, so set the nonce rather than filtering for it. *)
let with_overflowing_nonce ((x : t), y) =
  let fee_payer =
    { x.fee_payer with
      body = { x.fee_payer.body with nonce = Account.Nonce.max_value }
    }
  in
  (({ x with fee_payer } : t), y)

let filtered_overflow =
  Quickcheck.Generator.map Valid_size.zkapp_type_gen ~f:with_overflowing_nonce

(* target_nonce_on_success *)
(* Check that the nonce after the function has been applied is higher *)
let target_nonce_on_success_test () =
  Quickcheck.test ~trials:50 filtered ~f:(fun (x, _y) ->
      [%test_pred: Account.Nonce.t * Account.Nonce.t]
        (fun (a, b) -> Unsigned.UInt32.to_int a < Unsigned.UInt32.to_int b)
        (x.fee_payer.body.nonce, target_nonce_on_success x) )

(* target_nonce_on_success *)
(* Check that the nonce after the function has been applied is lower when there is overflow *)
let target_nonce_on_success_overflow () =
  Quickcheck.test ~trials:50 filtered_overflow ~f:(fun (x, _y) ->
      [%test_pred: Account.Nonce.t * Account.Nonce.t]
        (fun (a, b) -> Unsigned.UInt32.to_int a > Unsigned.UInt32.to_int b)
        (x.fee_payer.body.nonce, target_nonce_on_success x) )

(* nonce_increments *)
(* Check that the total in the Map is less than or equal to the total number of elements in the account_updates *)
let nonce_increments_test () =
  Quickcheck.test ~trials:50 Valid_size.zkapp_type_gen ~f:(fun (x, _y) ->
      let total_nonce (input : int Public_key.Compressed.Map.t) : int =
        Map.fold input ~init:0 ~f:(fun ~key:_ ~data accum -> data + accum)
      in
      [%test_pred: int * int]
        (fun (a, b) -> a >= b)
        ( List.length (Call_forest.to_list x.account_updates)
        , total_nonce (nonce_increments x) - 1 ) )

let tests =
  ( "nonce related"
  , [ Alcotest.test_case
        "Check that the nonce after the function has been applied is higher."
        `Quick target_nonce_on_success_test
    ; Alcotest.test_case
        "Check that the nonce after the function has been applied is lower \
         when there is overflow."
        `Quick target_nonce_on_success_overflow
    ; Alcotest.test_case
        "Check that the total in the Map is less than or equal to the total \
         number of elements in the account_updates."
        `Quick nonce_increments_test
    ] )
