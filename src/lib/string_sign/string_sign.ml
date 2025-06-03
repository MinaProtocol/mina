(* string_sign.ml -- signatures for strings *)

module Inner_curve = Snark_params.Tick.Inner_curve
open Signature_lib
open Core_kernel

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
  let signature_kind =
    Option.value signature_kind ~default:Mina_signature_kind.t_DEPRECATED
  in
  Schnorr.Legacy.verify ~signature_kind signature inner_curve m

let sign ?signature_kind sk s =
  let m = string_to_input s in
  let signature_kind =
    Option.value signature_kind ~default:Mina_signature_kind.t_DEPRECATED
  in
  Schnorr.Legacy.sign ~signature_kind sk m
