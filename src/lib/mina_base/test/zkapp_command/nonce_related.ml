open Core_kernel
open Mina_base
open Snarky_backendless
open Snark_params.Tick
open Zkapp_command
open Signature_lib

let filter ((x, y) : Stable.V1.Wire.t * int) : bool =
  Unsigned.UInt32.to_int x.fee_payer.body.nonce
  + 1
  + List.length (Call_forest.to_list x.account_updates)
  <= Unsigned.UInt32.to_int Unsigned.UInt32.max_int

let filter_overflow ((x, y) : Stable.V1.Wire.t * int) : bool =
  Unsigned.UInt32.to_int x.fee_payer.body.nonce
  + 1
  + List.length (Call_forest.to_list x.account_updates)
  > Unsigned.UInt32.to_int Unsigned.UInt32.max_int

let filtered =
  Base_quickcheck.Generator.filter Zkapp_command_test.Valid_size.zkapp_type_gen
    ~f:filter

let filtered_overflow =
  Base_quickcheck.Generator.filter Zkapp_command_test.Valid_size.zkapp_type_gen
    ~f:filter_overflow

(* target_nonce_on_success *)
(* Check that the nonce after the function has been applied is higher*)
let target_nonce_on_success_test () =
  Quickcheck.test ~trials:50 filtered ~f:(fun (x, y) ->
      [%test_pred: Account.Nonce.t * Account.Nonce.t]
        (fun (a, b) -> Unsigned.UInt32.to_int a < Unsigned.UInt32.to_int b)
        ((of_wire x).fee_payer.body.nonce, target_nonce_on_success @@ of_wire x) )

(* target_nonce_on_success *)
(* Check that the nonce after the function has been applied is lower when there is overflow*)
let target_nonce_on_success_overflow () =
  Quickcheck.test ~trials:50 filtered_overflow ~f:(fun (x, y) ->
      [%test_pred: Account.Nonce.t * Account.Nonce.t]
        (fun (a, b) -> Unsigned.UInt32.to_int a > Unsigned.UInt32.to_int b)
        ((of_wire x).fee_payer.body.nonce, target_nonce_on_success @@ of_wire x) )

(* nonce_increments *)
(* Check that the total in the Map is less than or equal to the total number of elements in the account_updates*)
let nonce_increments_test () =
  Quickcheck.test ~trials:50 T.Stable.Latest.Wire.gen ~f:(fun x ->
      let total_nonce (input : int Public_key.Compressed.Map.t) : int =
        Public_key.Compressed.Map.fold input ~init:0 ~f:(fun ~key ~data accum ->
            data + accum )
      in
      [%test_pred: int * int]
        (fun (a, b) -> a >= b)
        ( List.length (Call_forest.to_list (of_wire x).account_updates)
        , total_nonce (nonce_increments @@ of_wire x) - 1 ) )

let () =
  let open Alcotest in
  run "Test nonce_related."
    [ ( "nonce_related"
      , [ test_case
            "Check that the nonce after the function has been applied is \
             higher."
            `Quick target_nonce_on_success_test
        ; test_case
            "Check that the nonce after the function has been applied is lower \
             when there is overflow."
            `Quick target_nonce_on_success_overflow
        ; test_case
            "Check that the total in the Map is less than or equal to the \
             total number of elements in the account_updates."
            `Quick nonce_increments_test
        ] )
    ]
