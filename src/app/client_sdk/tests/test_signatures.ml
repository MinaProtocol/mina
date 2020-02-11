(* test_signatures.ml -- generate signatures for some transactions,
    for comparison against signatures generated in client SDK 
 *)

open Core_kernel
open Snark_params.Tick
open Coda_base
open Signature_lib

(* signer *)
let keypair =
  let public_key =
    Public_key.(
      Compressed.of_base58_check_exn
        "ZsMSUqsVQiPRHMi5LxTfVD1kNA6sizLAgixPMqgUA58jmyZZzizF916WMJ6agSRurXN"
      |> decompress_exn)
  in
  let private_key =
    Private_key.of_base58_check_exn
      "kPKzZFyKSFQ3J6fyAMwiQWEZSjrCGHt8y2FU7bJQiBNJvn9kfqHEFsvr8py62meN"
  in
  Keypair.{public_key; private_key}

(* payment receiver *)
let receiver =
  Public_key.Compressed.of_base58_check_exn
    "ZsMSUprkT3XHExH7NwgLdfMavFgPQDmBHPuBqUWq9Wh5dwSzLWoYGeCBih6soRmNHm2"

(* delegatee *)
let new_delegate =
  Public_key.Compressed.of_base58_check_exn
    "ZsMSUuQ7X6vVZfZUyFAa6Fsxg54zV6Ha5geDaPUb4z3VKqjtZTCeRwzh9fYkq9YyMrF"

let make_common ~fee ~nonce ~valid_until memo =
  let fee = Currency.Fee.of_int fee in
  let nonce = Account.Nonce.of_int nonce in
  let valid_until = Coda_numbers.Global_slot.of_int valid_until in
  let memo = User_command_memo.create_from_string_exn memo in
  User_command_payload.Common.Poly.{fee; nonce; valid_until; memo}

let make_payment ~receiver ~amount ~fee ~nonce ~valid_until memo =
  let common = make_common ~fee ~nonce ~valid_until memo in
  let amount = Currency.Amount.of_int amount in
  let body = User_command_payload.Body.Payment {receiver; amount} in
  User_command_payload.Poly.{common; body}

let payments =
  [ make_payment ~receiver ~amount:42 ~fee:3 ~nonce:200 ~valid_until:10000
      "this is a memo"
  ; make_payment ~receiver ~amount:2048 ~fee:15 ~nonce:212 ~valid_until:305
      "this is not a pipe"
  ; make_payment ~receiver ~amount:109 ~fee:2001 ~nonce:3050 ~valid_until:9000
      "blessed be the geek" ]

let make_stake_delegation ~new_delegate ~fee ~nonce ~valid_until memo =
  let common = make_common ~fee ~nonce ~valid_until memo in
  let body =
    User_command_payload.Body.Stake_delegation
      (Stake_delegation.Set_delegate {new_delegate})
  in
  User_command_payload.Poly.{common; body}

let delegations =
  [ make_stake_delegation ~new_delegate ~fee:3 ~nonce:10 ~valid_until:4000
      "more delegates, more fun"
  ; make_stake_delegation ~new_delegate ~fee:10 ~nonce:1000 ~valid_until:8192
      "enough stake to kill a vampire"
  ; make_stake_delegation ~new_delegate ~fee:8 ~nonce:1010 ~valid_until:100000
      "another memo" ]

let transactions = payments @ delegations

type jsSignature = {privateKey: Field.t; publicKey: Inner_curve.Scalar.t}

(* output format matches signatures in client SDK *)
let print_signature payload =
  let User_command.Poly.{signature= field, scalar; _} =
    (User_command.sign keypair payload :> User_command.t)
  in
  printf "  { field: '%s'\n" (Field.to_string field) ;
  printf "  , scalar: '%s'\n" (Inner_curve.Scalar.to_string scalar) ;
  printf "  },\n%!"

let main () =
  printf "[\n" ;
  List.iter transactions ~f:print_signature ;
  printf "]\n"

let _ = main ()
