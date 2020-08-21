(* sign_js.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

[%%error
"Client_sdk cannot be built if \"consensus_mechanism\" is defined"]

[%%endif]

open Js_of_ocaml
open Snark_params_nonconsensus
open Signature_lib_nonconsensus
open Coda_base_nonconsensus
open Js_util

let _ =
  Js.export "codaSDK"
    (object%js (_self)
       (** public key corresponding to a private key *)
       method publicKeyOfPrivateKey (sk_base58_check_js : string_js) =
         let sk =
           Js.to_string sk_base58_check_js |> Private_key.of_base58_check_exn
         in
         Public_key.(
           of_private_key_exn sk |> compress |> Compressed.to_base58_check
           |> Js.string)

       (** generate a private key, public key pair *)
       method genKeys =
         let sk = Private_key.create () in
         let sk_str_js = sk |> Private_key.to_base58_check |> Js.string in
         let pk_str_js = _self##publicKeyOfPrivateKey sk_str_js in
         object%js
           val privateKey = sk_str_js

           val publicKey = pk_str_js
         end

       (** return public key associated with private key in raw hex format for Rosetta *)
       method rawPublicKeyOfPrivateKey (sk_base58_check_js : string_js) =
         let sk =
           Js.to_string sk_base58_check_js |> Private_key.of_base58_check_exn
         in
         Public_key.of_private_key_exn sk |> Raw.of_public_key

       (** return public key in raw hex format for Rosetta *)
       method rawPublicKeyOfPublicKey (pk_base58_check_js : string_js) =
         let pk =
           Js.to_string pk_base58_check_js
           |> Public_key.Compressed.of_base58_check_exn
         in
         Raw.of_public_key_compressed pk

       (** sign arbitrary string with private key *)
       method signString (sk_base58_check_js : string_js) (str_js : string_js)
           =
         let sk_base58_check = Js.to_string sk_base58_check_js in
         let sk = Private_key.of_base58_check_exn sk_base58_check in
         let str = Js.to_string str_js in
         String_sign.Schnorr.sign sk str |> signature_to_js_object

       (** verify signature of arbitrary string signed with signString *)
       method verifyStringSignature (signature_js : signature_js)
           (public_key_js : string_js) (str_js : string_js) =
         let field = Js.to_string signature_js##.field |> Field.of_string in
         let scalar =
           Js.to_string signature_js##.scalar |> Inner_curve.Scalar.of_string
         in
         let signature = (field, scalar) in
         let pk =
           Js.to_string public_key_js
           |> Public_key.Compressed.of_base58_check_exn
           |> Public_key.decompress_exn
         in
         let inner_curve =
           Snark_params_nonconsensus.Inner_curve.of_affine pk
         in
         let str = Js.to_string str_js in
         if String_sign.Schnorr.verify signature inner_curve str then Js._true
         else Js._false

       (** sign payment transaction payload with private key *)
       method signPayment (sk_base58_check_js : string_js)
           (payment_js : payment_js) : signed_payment =
         let sk_base58_check = Js.to_string sk_base58_check_js in
         let sk = Private_key.of_base58_check_exn sk_base58_check in
         let payload = payload_of_payment_js payment_js in
         let signature =
           User_command.sign_payload sk payload |> signature_to_js_object
         in
         let publicKey = _self##publicKeyOfPrivateKey sk_base58_check_js in
         object%js
           val payment = payment_js

           val sender = publicKey

           val signature = signature
         end

       (** verify signed payments *)
       method verifyPaymentSignature (signed_payment : signed_payment) =
         let payload : User_command_payload.t =
           payload_of_payment_js signed_payment##.payment
         in
         let signer =
           signed_payment##.sender |> Js.to_string
           |> Public_key.Compressed.of_base58_check_exn
           |> Public_key.decompress_exn
         in
         let signature = signature_of_js_object signed_payment##.signature in
         let signed = User_command.Poly.{payload; signer; signature} in
         User_command.check_signature signed

       (** sign payment transaction payload with private key *)
       method signStakeDelegation (sk_base58_check_js : string_js)
           (stake_delegation_js : stake_delegation_js)
           : signed_stake_delegation =
         let sk_base58_check = Js.to_string sk_base58_check_js in
         let sk = Private_key.of_base58_check_exn sk_base58_check in
         let payload = payload_of_stake_delegation_js stake_delegation_js in
         let signature =
           User_command.sign_payload sk payload |> signature_to_js_object
         in
         let publicKey = _self##publicKeyOfPrivateKey sk_base58_check_js in
         object%js
           val stakeDelegation = stake_delegation_js

           val sender = publicKey

           val signature = signature
         end

       (** verify signed delegations *)
       method verifyStakeDelegationSignature
             (signed_stake_delegation : signed_stake_delegation) =
         let payload : User_command_payload.t =
           payload_of_stake_delegation_js
             signed_stake_delegation##.stakeDelegation
         in
         let signer =
           signed_stake_delegation##.sender
           |> Js.to_string |> Public_key.Compressed.of_base58_check_exn
           |> Public_key.decompress_exn
         in
         let signature =
           signature_of_js_object signed_stake_delegation##.signature
         in
         let signed = User_command.Poly.{payload; signer; signature} in
         User_command.check_signature signed
    end)
