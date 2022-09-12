(* string_sign.ml -- signatures for strings *)

module Inner_curve = Snark_params.Tick.Inner_curve
open Signature_lib

let nybble_bits = function
  | 0x0 ->
      [ false; false; false; false ]
  | 0x1 ->
      [ false; false; false; true ]
  | 0x2 ->
      [ false; false; true; false ]
  | 0x3 ->
      [ false; false; true; true ]
  | 0x4 ->
      [ false; true; false; false ]
  | 0x5 ->
      [ false; true; false; true ]
  | 0x6 ->
      [ false; true; true; false ]
  | 0x7 ->
      [ false; true; true; true ]
  | 0x8 ->
      [ true; false; false; false ]
  | 0x9 ->
      [ true; false; false; true ]
  | 0xA ->
      [ true; false; true; false ]
  | 0xB ->
      [ true; false; true; true ]
  | 0xC ->
      [ true; true; false; false ]
  | 0xD ->
      [ true; true; false; true ]
  | 0xE ->
      [ true; true; true; false ]
  | 0xF ->
      [ true; true; true; true ]
  | _ ->
      failwith "nybble_bits: expected value from 0 to 0xF"

let char_bits c =
  let open Core_kernel in
  let n = Char.to_int c in
  let hi = Int.(shift_right (bit_and n 0xF0) 4) in
  let lo = Int.bit_and n 0x0F in
  List.concat_map [ hi; lo ] ~f:nybble_bits

let string_to_input s =
  Random_oracle.Input.Legacy.
    { field_elements = [||]
    ; bitstrings = Stdlib.(Array.of_seq (Seq.map char_bits (String.to_seq s)))
    }

let verify ?signature_kind signature pk s =
  let m = string_to_input s in
  let inner_curve = Inner_curve.of_affine pk in
  Schnorr.Legacy.verify ?signature_kind signature inner_curve m

let sign ?signature_kind sk s =
  let m = string_to_input s in
  Schnorr.Legacy.sign ?signature_kind sk m

let%test_module "Sign_string tests" =
  ( module struct
    let keypair : Signature_lib.Keypair.t =
      let public_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn
          "B62qnNkiQn1t1Nhof2fyTtBTbHLbXcUDVX2BWpjGKKK3HsfP8LPhYgE"
        |> Signature_lib.Public_key.decompress_exn
      in
      let private_key =
        Signature_lib.Private_key.of_base58_check_exn
          "EKEyDHNLpR42jU8j9p13t6GA3wKBXdHszrV17G6jpfJbK8FZDfYo"
      in
      { public_key; private_key }

    let%test "Sign, verify with default network" =
      let s =
        "Now is the time for all good men to come to the aid of their party"
      in
      let signature = sign keypair.private_key s in
      verify signature keypair.public_key s

    let%test "Sign, verify with mainnet" =
      let s = "Rain and Spain don't rhyme with cheese" in
      let signature_kind = Mina_signature_kind.Mainnet in
      let signature = sign ~signature_kind:Mainnet keypair.private_key s in
      verify ~signature_kind signature keypair.public_key s

    let%test "Sign, verify with testnet" =
      let s = "In a galaxy far, far away" in
      let signature_kind = Mina_signature_kind.Testnet in
      let signature = sign ~signature_kind keypair.private_key s in
      verify ~signature_kind signature keypair.public_key s

    let%test "Sign with testnet, fail to verify with mainnet" =
      let open Mina_signature_kind in
      let s = "Some pills make you larger" in
      let signature = sign ~signature_kind:Testnet keypair.private_key s in
      not (verify ~signature_kind:Mainnet signature keypair.public_key s)

    let%test "Sign with mainnet, fail to verify with testnet" =
      let open Mina_signature_kind in
      let s = "Watson, come here, I need you" in
      let signature = sign ~signature_kind:Mainnet keypair.private_key s in
      not (verify ~signature_kind:Testnet signature keypair.public_key s)
  end )
