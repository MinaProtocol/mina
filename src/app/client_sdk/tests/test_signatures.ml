(* test_signatures.ml -- generate signatures for some transactions,
    for comparison against signatures generated in client SDK
 *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus
module Coda_base = Coda_base_nonconsensus
module Signature_lib = Signature_lib_nonconsensus
module Currency = Currency_nonconsensus.Currency
module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers

[%%endif]

open Coda_base
open Signature_lib

let signer_pk =
  Public_key.Compressed.of_base58_check_exn
    "B62qom56dHZvJvuZRZ2cCGRqB2UdCjoDRQjQRKfZyxX1SBTbF24L7Pt"

(* signer *)
let keypair =
  let private_key =
    Private_key.of_base58_check_exn
      "EKEjf4cZcaUScpV3iAE8r9PaEj4dbPbyUhzWryhhxQqjTTSCfyo8"
  in
  let public_key = Public_key.decompress_exn signer_pk in
  Keypair.{public_key; private_key}

(* payment receiver *)
let receiver =
  Public_key.Compressed.of_base58_check_exn
    "B62qkZCRBPiTtcq62o9G4NAuAb12ZzUobicLLvNkcWZjxymxKDVd7pv"

(* delegatee *)
let new_delegate =
  Public_key.Compressed.of_base58_check_exn
    "B62qo4biEn36khSQcQiCioznuqXFE5nyUasEfUXVqyxdPissUEReCvL"

let make_common ~fee ~fee_payer_pk ~nonce ~valid_until memo =
  let fee = Currency.Fee.of_int fee in
  let fee_token = Token_id.default in
  let nonce = Account.Nonce.of_int nonce in
  let valid_until = Coda_numbers.Global_slot.of_int valid_until in
  let memo = User_command_memo.create_from_string_exn memo in
  User_command_payload.Common.Poly.
    {fee; fee_token; fee_payer_pk; nonce; valid_until; memo}

let make_payment ~amount ~fee ~fee_payer_pk ~source_pk ~receiver_pk ~nonce
    ~valid_until memo =
  let common = make_common ~fee ~fee_payer_pk ~nonce ~valid_until memo in
  let amount = Currency.Amount.of_int amount in
  let token_id = Token_id.default in
  let body =
    User_command_payload.Body.Payment {source_pk; receiver_pk; token_id; amount}
  in
  User_command_payload.Poly.{common; body}

let payments =
  let receiver_pk = receiver in
  let source_pk = signer_pk in
  let fee_payer_pk = signer_pk in
  [ make_payment ~receiver_pk ~source_pk ~fee_payer_pk ~amount:42 ~fee:3
      ~nonce:200 ~valid_until:10000 "this is a memo"
  ; make_payment ~receiver_pk ~source_pk ~fee_payer_pk ~amount:2048 ~fee:15
      ~nonce:212 ~valid_until:305 "this is not a pipe"
  ; make_payment ~receiver_pk ~source_pk ~fee_payer_pk ~amount:109 ~fee:2001
      ~nonce:3050 ~valid_until:9000 "blessed be the geek" ]

let make_stake_delegation ~delegator ~new_delegate ~fee ~fee_payer_pk ~nonce
    ~valid_until memo =
  let common = make_common ~fee ~fee_payer_pk ~nonce ~valid_until memo in
  let body =
    User_command_payload.Body.Stake_delegation
      (Stake_delegation.Set_delegate {delegator; new_delegate})
  in
  User_command_payload.Poly.{common; body}

let delegations =
  let delegator = signer_pk in
  let fee_payer_pk = signer_pk in
  [ make_stake_delegation ~fee_payer_pk ~delegator ~new_delegate ~fee:3
      ~nonce:10 ~valid_until:4000 "more delegates, more fun"
  ; make_stake_delegation ~fee_payer_pk ~delegator ~new_delegate ~fee:10
      ~nonce:1000 ~valid_until:8192 "enough stake to kill a vampire"
  ; make_stake_delegation ~fee_payer_pk ~delegator ~new_delegate ~fee:8
      ~nonce:1010 ~valid_until:100000 "another memo" ]

let transactions = payments @ delegations

type jsSignature = {privateKey: Field.t; publicKey: Inner_curve.Scalar.t}

let get_signature payload =
  (User_command.sign keypair payload :> User_command.With_valid_signature.t)

(* output format matches signatures in client SDK *)
let print_signature field scalar =
  printf "  { field: '%s'\n" (Field.to_string field) ;
  printf "  , scalar: '%s'\n" (Inner_curve.Scalar.to_string scalar) ;
  printf "  },\n%!"

let main () =
  let signatures = List.map transactions ~f:get_signature in
  (* make sure signatures verify *)
  List.iteri signatures ~f:(fun i signature ->
      let signature = (signature :> User_command.t) in
      if not (User_command.check_signature signature) then (
        eprintf
          !"Signature (%d) failed to verify: %{sexp: User_command.t}\n%!"
          i signature ;
        exit 1 ) ) ;
  printf "[\n" ;
  List.iter signatures ~f:(fun signature ->
      let User_command.Poly.{signature= field, scalar; _} =
        (signature :> User_command.t)
      in
      print_signature field scalar ) ;
  printf "]\n"

let _ = main ()
