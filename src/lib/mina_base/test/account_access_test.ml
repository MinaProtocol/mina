(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^account-access$'
    Subject:    Test account access statuses of signed commands.
 *)

open Core
open Mina_base
module Payload = Signed_command_payload

let empty_pk = Signature_lib.Public_key.Compressed.empty

let fee_payer_pk =
  Quickcheck.random_value ~seed:(`Deterministic "account-access fee payer")
    Signature_lib.Public_key.Compressed.gen

let mk_payload body =
  Payload.create ~fee:Currency.Fee.zero ~fee_payer_pk
    ~nonce:Mina_numbers.Account_nonce.zero ~valid_until:None
    ~memo:Signed_command_memo.empty ~body

let statuses_for body status =
  Payload.account_access_statuses (mk_payload body) status

let receiver_status body status =
  let payload = mk_payload body in
  List.Assoc.find_exn ~equal:Account_id.equal
    (Payload.account_access_statuses payload status)
    (Payload.receiver payload)

let pp_status ppf = function
  | `Accessed ->
      Format.fprintf ppf "`Accessed"
  | `Not_accessed ->
      Format.fprintf ppf "`Not_accessed"

let status = Alcotest.testable pp_status Poly.equal

let unstake_receiver_not_accessed () =
  let body =
    Payload.Body.Stake_delegation (Set_delegate { new_delegate = empty_pk })
  in
  Alcotest.check status "empty-key receiver of applied unstake is not accessed"
    `Not_accessed
    (receiver_status body Transaction_status.Applied)

let delegation_receiver_accessed () =
  let delegate =
    Quickcheck.random_value ~seed:(`Deterministic "account-access delegate")
      Signature_lib.Public_key.Compressed.gen
  in
  let body =
    Payload.Body.Stake_delegation (Set_delegate { new_delegate = delegate })
  in
  Alcotest.check status "non-empty delegate of applied delegation is accessed"
    `Accessed
    (receiver_status body Transaction_status.Applied)

let fee_payer_always_accessed () =
  let body =
    Payload.Body.Stake_delegation (Set_delegate { new_delegate = empty_pk })
  in
  List.iter
    [ Transaction_status.Applied
    ; Failed [ [ Transaction_status.Failure.Update_not_permitted_delegate ] ]
    ] ~f:(fun txn_status ->
      let payload = mk_payload body in
      Alcotest.check status "fee payer is accessed" `Accessed
        (List.Assoc.find_exn ~equal:Account_id.equal
           (statuses_for body txn_status)
           (Payload.fee_payer payload) ) )
