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
open Js_types

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
           (payment_js : payment_js) : signed_payment Js.t =
         let sk_base58_check = Js.to_string sk_base58_check_js in
         let sk = Private_key.of_base58_check_exn sk_base58_check in
         let User_command_payload.Common.Poly.{fee; nonce; valid_until; memo} =
           get_payload_common payment_js##.common
         in
         let payment_payload = payment_js##.paymentPayload in
         let receiver =
           Js.to_string payment_payload##.receiver
           |> Public_key.Compressed.of_base58_check_exn
         in
         let amount =
           Js.to_string payment_payload##.amount |> Currency.Amount.of_string
         in
         let body =
           User_command_payload.Body.Payment
             Payment_payload.Poly.{receiver; amount}
         in
         let payload =
           User_command_payload.create ~fee ~nonce ~valid_until ~memo ~body
         in
         let signature = Schnorr.sign sk payload |> signature_to_js_object in
         let publicKey = _self##publicKeyOfPrivateKey sk_base58_check_js in
         object%js
           val payment = payment_js

           val sender = publicKey

           val signature = signature
         end

       (** sign payment transaction payload with private key *)
       method signStakeDelegation (sk_base58_check_js : string_js)
           (stake_delegation_js : stake_delegation_js)
           : signed_stake_delegation Js.t =
         let sk_base58_check = Js.to_string sk_base58_check_js in
         let sk = Private_key.of_base58_check_exn sk_base58_check in
         let User_command_payload.Common.Poly.{fee; nonce; valid_until; memo} =
           get_payload_common stake_delegation_js##.common
         in
         let new_delegate =
           Js.to_string stake_delegation_js##.new_delegate
           |> Public_key.Compressed.of_base58_check_exn
         in
         let body =
           User_command_payload.Body.Stake_delegation
             Stake_delegation.(Set_delegate {new_delegate})
         in
         let payload =
           User_command_payload.create ~fee ~nonce ~valid_until ~memo ~body
         in
         let signature = Schnorr.sign sk payload |> signature_to_js_object in
         let publicKey = _self##publicKeyOfPrivateKey sk_base58_check_js in
         object%js
           val stakeDelegation = stake_delegation_js

           val sender = publicKey

           val signature = signature
         end
    end)
