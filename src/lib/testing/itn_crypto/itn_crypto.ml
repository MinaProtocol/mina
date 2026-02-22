(* itn_crypto.ml -- Ed25519 keys, signatures *)

type pubkey = Mirage_crypto_ec.Ed25519.pub

let () = Mirage_crypto_rng_async.initialize (module Mirage_crypto_rng.Fortuna)

let generate_keypair () = Mirage_crypto_ec.Ed25519.generate ()

let sign ~key s =
  let input = Cstruct.of_string s in
  let signed = Mirage_crypto_ec.Ed25519.sign ~key input in
  let output = Cstruct.to_string signed in
  Base64.encode_string output

let verify ~key ~msg sig_b64 =
  match Base64.decode sig_b64 with
  | Ok s ->
      let msg = Cstruct.of_string msg in
      let signature = Cstruct.of_string s in
      Mirage_crypto_ec.Ed25519.verify ~key ~msg signature
  | Error (`Msg _msg) ->
      false

let encode_pubkey pk = Mirage_crypto_ec.Ed25519.pub_to_cstruct pk

let equal_pubkeys pk1 pk2 =
  Cstruct.equal (encode_pubkey pk1) (encode_pubkey pk2)

let pubkey_to_base64 pk =
  let input = encode_pubkey pk in
  let s = Cstruct.to_string input in
  Base64.encode_string s

let pubkey_of_base64 b64 =
  match Base64.decode b64 with
  | Ok s ->
      let input = Cstruct.of_string s in
      Mirage_crypto_ec.Ed25519.pub_of_cstruct input
  | Error (`Msg _err) ->
      (* reuse error token, it's the base64 that's invalid *)
      Error `Invalid_format

let%test "Sign, verify" =
  let msg = "It was beauty killed the beast" in
  let privkey, pubkey = generate_keypair () in
  let signature = sign ~key:privkey msg in
  verify ~key:pubkey ~msg signature

let%test "Pubkey encode, decode" =
  let _privkey, pubkey = generate_keypair () in
  let b64 = pubkey_to_base64 pubkey in
  match pubkey_of_base64 b64 with
  | Ok decoded ->
      equal_pubkeys pubkey decoded
  | Error _err ->
      false
