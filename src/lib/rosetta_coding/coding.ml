(* coding.ml -- hex encoding/decoding for Rosetta *)
open Core_kernel
module Field = Snark_params.Tick.Field
module Scalar = Snark_params.Tick.Inner_curve.Scalar
open Signature_lib

(* see RFC 0038, section "marshal-keys" for a specification *)

let hex_char_to_bits4 = function
  | '0' ->
      [ false; false; false; false ]
  | '1' ->
      [ false; false; false; true ]
  | '2' ->
      [ false; false; true; false ]
  | '3' ->
      [ false; false; true; true ]
  | '4' ->
      [ false; true; false; false ]
  | '5' ->
      [ false; true; false; true ]
  | '6' ->
      [ false; true; true; false ]
  | '7' ->
      [ false; true; true; true ]
  | '8' ->
      [ true; false; false; false ]
  | '9' ->
      [ true; false; false; true ]
  | 'A' | 'a' ->
      [ true; false; true; false ]
  | 'B' | 'b' ->
      [ true; false; true; true ]
  | 'C' | 'c' ->
      [ true; true; false; false ]
  | 'D' | 'd' ->
      [ true; true; false; true ]
  | 'E' | 'e' ->
      [ true; true; true; false ]
  | 'F' | 'f' ->
      [ true; true; true; true ]
  | _ ->
      failwith "Expected hex character"

let bits4_to_hex_char bits =
  List.mapi bits ~f:(fun i bit -> if bit then Int.pow 2 (3 - i) else 0)
  |> List.fold ~init:0 ~f:( + )
  |> fun n ->
  let s = sprintf "%0X" n in
  s.[0]

module type Packed = sig
  type t

  val unpack : t -> bool list
end

(* break of the bits byte by byte *)
let bits_by_n n bits =
  let rec go bits acc =
    if List.is_empty bits then List.rev acc
    else
      let bitsn, rest = List.split_n bits n in
      go rest (bitsn :: acc)
  in
  go bits []

let bits_by_4s = bits_by_n 4

let bits_by_8s = bits_by_n 8

let of_unpackable (type t) (module M : Packed with type t = t)
    ?(padding_bit = false) (packed : t) =
  let bits0 = M.unpack packed |> List.rev in
  assert (Mina_stdlib.List.Length.Compare.(bits0 = 255)) ;
  (* field elements, scalars are 255 bits, left-pad to get 32 bytes *)
  let bits = padding_bit :: bits0 in
  (* break of the bits byte by byte *)
  (* In our encoding, we want highest bytes at the end and lowest at the
     beginning. *)
  let bytes = bits_by_8s bits in
  let bytes' = List.rev bytes in
  let bits' = List.concat bytes' in
  let cs = List.map (bits_by_4s bits') ~f:bits4_to_hex_char in
  String.of_char_list cs

let of_field = of_unpackable (module Field)

let of_scalar = of_unpackable (module Scalar)

module type Unpacked = sig
  type t

  val project : bool list -> t
end

let pack (type t) (module M : Unpacked with type t = t) (raw : string) :
    bool * t =
  (* 256 bits = 64 hex chars *)
  assert (Int.equal (String.length raw) 64) ;
  let bits =
    String.to_list raw |> List.map ~f:hex_char_to_bits4 |> List.concat
  in
  (* In our encoding, we have highest bytes at the end and lowest at the
     beginning. *)
  let bytes = bits_by_8s bits in
  let bytes_rev = List.rev bytes in
  let bits' = List.concat bytes_rev in

  let padding_bit = List.hd_exn bits' in
  (* remove padding bit *)
  let bits'' = List.tl_exn bits' |> List.rev in
  (padding_bit, M.project bits'')

let to_field hex = pack (module Field) hex |> snd

let to_scalar hex = pack (module Scalar) hex |> snd

let of_public_key_compressed pk =
  let { Public_key.Compressed.Poly.x; is_odd } = pk in
  of_field ~padding_bit:is_odd x

let of_public_key pk = of_public_key_compressed (Public_key.compress pk)

let to_public_key_compressed raw =
  let is_odd, x = pack (module Field) raw in
  { Public_key.Compressed.Poly.x; is_odd }

let to_public_key raw =
  to_public_key_compressed raw |> Public_key.decompress_exn
