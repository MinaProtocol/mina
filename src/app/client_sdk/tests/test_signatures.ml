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

(* signer *)
let keypair =
  let private_key =
    Private_key.of_base58_check_exn
      "6BnSDyt3FKhJSt5oDk1HHeM5J8uKSnp7eaSYndj53y7g7oYzUEhHFrkpk6po4XfNFyjtoJK4ovVHvmCgdUqXVEfTXoAC1CNpaGLAKtu7ah9i4dTi3FtcoKpZhtiTGrRQkEN6Q95cb39Kp"
  in
  let public_key =
    Public_key.(
      Compressed.of_base58_check_exn
        "4vsRCVnc5xmYJhaVbUgkg6po6nR3Mu7KEFunP3uQL67qZmPNnJKev57TRvMfuJ15XDP8MjaLSh7THG7CpTiTkfgRcQAKGmFo1XGMStCucmWAxBUiXjycDbx7hbVCqkDYiezM8Lvr1NMdTEGU"
      |> decompress_exn)
  in
  let fld1, fld2 = public_key in
  eprintf
    !"PUBLIC KEY ORIG: (x: %s, y: %s)\n%!"
    (Field.to_string fld1) (Field.to_string fld2) ;
  Keypair.{public_key; private_key}

(* payment receiver *)
let receiver =
  Public_key.Compressed.of_base58_check_exn
    "4vsRCVHzeYYbneMkHR3u445f8zYwo6nhx3UHKZQH7B2txTV5Shz66Ds9PdxoRKCiALWtuwPQDwpm2Kj22QPcZpKCLr6rnHmUMztKpWxL9meCPQcTkKhmK5HyM4Y9dMnTKrEjD1MX71kLTUaP"

(* delegatee *)
let new_delegate =
  Public_key.Compressed.of_base58_check_exn
    "4vsRCVQNkGihARy4Jg9FsJ6NFtnwDsRnTqi2gQnPAoCNUoyLveY6FEnicGMmwEumPx3GjLxAb5fAivVSLnYRPPMfb5HdkhLdjHunjgqp6g7gYi8cWy4avdmHMRomaKkWyWeWn91w7baaFnUk"

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

let transactions = [List.hd_exn transactions] (* TEMP *)

type jsSignature = {privateKey: Field.t; publicKey: Inner_curve.Scalar.t}

(* output format matches signatures in client SDK *)
let print_signature payload =
  eprintf !"PAYLOAD: %{sexp: User_command_payload.t}\n%!" payload ;
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
