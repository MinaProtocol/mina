(* test_signatures.ml -- generate signatures for some transactions,
    for comparison against signatures generated in client SDK
*)

open Core_kernel
open Snark_params.Tick
open Mina_base
open Signature_lib

let signer_pk =
  Public_key.Compressed.of_base58_check_exn
    "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"

(* signer *)
let keypair =
  let private_key =
    Private_key.of_base58_check_exn
      "EKFKgDtU3rcuFTVSEpmpXSkukjmX4cKefYREi6Sdsk7E7wsT7KRw"
  in
  let public_key = Public_key.decompress_exn signer_pk in
  Keypair.{ public_key; private_key }

(* payment receiver *)
let receiver =
  Public_key.Compressed.of_base58_check_exn
    "B62qrcFstkpqXww1EkSGrqMCwCNho86kuqBd4FrAAUsPxNKdiPzAUsy"

(* delegatee *)
let new_delegate =
  Public_key.Compressed.of_base58_check_exn
    "B62qkfHpLpELqpMK6ZvUTJ5wRqKDRF3UHyJ4Kv3FU79Sgs4qpBnx5RR"

let make_common ~fee ~fee_payer_pk ~nonce ~valid_until memo =
  let fee = Currency.Fee.nanomina_unsafe fee in
  let nonce = Account.Nonce.of_int nonce in
  let valid_until = Mina_numbers.Global_slot.of_int valid_until in
  let memo = Signed_command_memo.create_from_string_exn memo in
  Signed_command_payload.Common.Poly.
    { fee; fee_payer_pk; nonce; valid_until; memo }

let make_payment ~amount ~fee ~fee_payer_pk ~source_pk ~receiver_pk ~nonce
    ~valid_until memo =
  let common = make_common ~fee ~fee_payer_pk ~nonce ~valid_until memo in
  let amount = Currency.Amount.nanomina_unsafe amount in
  let body =
    Signed_command_payload.Body.Payment { source_pk; receiver_pk; amount }
  in
  Signed_command_payload.Poly.{ common; body }

let payments =
  let receiver_pk = receiver in
  let source_pk = signer_pk in
  let fee_payer_pk = signer_pk in
  [ make_payment ~receiver_pk ~source_pk ~fee_payer_pk ~amount:42 ~fee:3
      ~nonce:200 ~valid_until:10000 "this is a memo"
  ; make_payment ~receiver_pk ~source_pk ~fee_payer_pk ~amount:2048 ~fee:15
      ~nonce:212 ~valid_until:305 "this is not a pipe"
  ; make_payment ~receiver_pk ~source_pk ~fee_payer_pk ~amount:109 ~fee:2001
      ~nonce:3050 ~valid_until:9000 "blessed be the geek"
  ]

let make_stake_delegation ~delegator ~new_delegate ~fee ~fee_payer_pk ~nonce
    ~valid_until memo =
  let common = make_common ~fee ~fee_payer_pk ~nonce ~valid_until memo in
  let body =
    Signed_command_payload.Body.Stake_delegation
      (Stake_delegation.Set_delegate { delegator; new_delegate })
  in
  Signed_command_payload.Poly.{ common; body }

let delegations =
  let delegator = signer_pk in
  let fee_payer_pk = signer_pk in
  [ make_stake_delegation ~fee_payer_pk ~delegator ~new_delegate ~fee:3
      ~nonce:10 ~valid_until:4000 "more delegates, more fun"
  ; make_stake_delegation ~fee_payer_pk ~delegator ~new_delegate ~fee:10
      ~nonce:1000 ~valid_until:8192 "enough stake to kill a vampire"
  ; make_stake_delegation ~fee_payer_pk ~delegator ~new_delegate ~fee:8
      ~nonce:1010 ~valid_until:100000 "another memo"
  ]

let strings =
  [ "this is a test"
  ; "this is only a test"
  ; "if this had been an actual emergency..."
  ]

let transactions = payments @ delegations

type jsSignature = { privateKey : Field.t; publicKey : Inner_curve.Scalar.t }

let get_signature ~signature_kind payload =
  ( Signed_command.sign ~signature_kind keypair payload
    :> Signed_command.With_valid_signature.t )

(* output format matches signatures in client SDK *)
let print_signature field scalar =
  printf "  { field: '%s'\n" (Field.to_string field) ;
  printf "  , scalar: '%s'\n" (Inner_curve.Scalar.to_string scalar) ;
  printf "  },\n%!"

let signature_kinds =
  let open Mina_signature_kind in
  [ Testnet; Mainnet ]

let main () =
  List.iter signature_kinds ~f:(fun signature_kind ->
      let txn_signatures =
        List.map transactions ~f:(get_signature ~signature_kind)
      in
      let string_signatures =
        List.map strings
          ~f:(String_sign.sign ~signature_kind keypair.private_key)
      in
      (* make sure signatures verify *)
      List.iteri txn_signatures ~f:(fun i signature ->
          let signature = (signature :> Signed_command.t) in
          if not (Signed_command.check_signature ~signature_kind signature) then (
            eprintf
              !"Transaction signature (%d) failed to verify: %{sexp: \
                Signed_command.t}\n\
                %!"
              i signature ;
            exit 1 ) ) ;
      List.iteri string_signatures ~f:(fun i signature ->
          if
            not
              (String_sign.verify ~signature_kind signature keypair.public_key
                 (List.nth_exn strings i) )
          then (
            eprintf
              !"Signature (%d) failed to verify for string: %s\n%!"
              i (List.nth_exn strings i) ;
            exit 1 ) ) ;
      printf "[\n" ;
      List.iter txn_signatures ~f:(fun signature ->
          let Signed_command.Poly.{ signature = field, scalar; _ } =
            (signature :> Signed_command.t)
          in
          print_signature field scalar ) ;
      List.iter string_signatures ~f:(fun signature ->
          let field, scalar = signature in
          print_signature field scalar ) ;
      printf "]\n" )

let _ = main ()
