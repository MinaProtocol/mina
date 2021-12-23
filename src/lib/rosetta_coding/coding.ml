(* coding.ml -- hex encoding/decoding for Rosetta *)

[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

module Field = Snark_params.Tick.Field
module Scalar = Snark_params.Tick.Inner_curve.Scalar
open Signature_lib

[%%else]

module Field = Snark_params_nonconsensus.Field
module Scalar = Snark_params_nonconsensus.Inner_curve.Scalar
open Signature_lib_nonconsensus

[%%endif]

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

let of_unpackable (type t) (module M : Packed with type t = t) (packed : t) =
  let bits0 = M.unpack packed |> List.rev in
  assert (List.length bits0 = 255) ;
  (* field elements, scalars are 255 bits, left-pad to get 32 bytes *)
  let bits = false :: bits0 in
  let bits_by_4s =
    let rec go bits acc =
      if List.is_empty bits then List.rev acc
      else
        let bits4, rest = List.split_n bits 4 in
        go rest (bits4 :: acc)
    in
    go bits []
  in
  let cs = List.map bits_by_4s ~f:bits4_to_hex_char in
  String.of_char_list cs

let of_field = of_unpackable (module Field)

let of_scalar = of_unpackable (module Scalar)

module type Unpacked = sig
  type t

  val project : bool list -> t
end

let pack (type t) (module M : Unpacked with type t = t) raw =
  (* 256 bits = 64 hex chars *)
  assert (Int.equal (String.length raw) 64) ;
  let bits0 =
    String.to_list raw |> List.map ~f:hex_char_to_bits4 |> List.concat
  in
  (* remove padding bit *)
  let bits = List.tl_exn bits0 |> List.rev in
  M.project bits

let to_field = pack (module Field)

let to_scalar = pack (module Scalar)

let of_public_key pk =
  let field1, field2 = pk in
  of_field field1 ^ of_field field2

(* differs from [encode_public_key_compressed], below, which does not convert to public key first *)
let of_public_key_compressed pk = Public_key.decompress_exn pk |> of_public_key

let to_public_key raw =
  let len = String.length raw in
  let field_len = len / 2 in
  let raw1 = String.sub raw ~pos:0 ~len:field_len in
  let raw2 = String.sub raw ~pos:field_len ~len:field_len in
  (to_field raw1, to_field raw2)

module Public_key_compressed_direct = struct
  (* direct hex encoding and decoding of bits in compressed public key
     [encode] differs from [of_public_key_compressed], which converts to an uncompressed key first
  *)
  let encode (pk_compressed : Public_key.Compressed.t) =
    (* of_unpackable assumes a 255-bit value, but we want  *)
    let { Public_key.Compressed.Poly.x; is_odd } = pk_compressed in
    let field_bits = Field.unpack x |> List.rev in
    (* insert parity bit as high bit in last byte *)
    let before_bits, after_bits = List.split_n field_bits 248 in
    let bits = before_bits @ (is_odd :: after_bits) in
    let bits_by_4s =
      let rec go bits acc =
        if List.is_empty bits then List.rev acc
        else
          let bits4, rest = List.split_n bits 4 in
          go rest (bits4 :: acc)
      in
      go bits []
    in
    let cs = List.map bits_by_4s ~f:bits4_to_hex_char in
    let result = String.of_char_list cs in
    result

  let decode raw : Public_key.Compressed.t =
    assert (String.length raw = 64) ;
    let bits =
      String.to_list raw |> List.map ~f:hex_char_to_bits4 |> List.concat
    in
    (* high bit of high byte *)
    let is_odd = Bool.equal (List.nth_exn bits 248) true in
    (* 0 parity bit, remove padding bit *)
    let field_bits =
      List.sub bits ~pos:1 ~len:248 @ (false :: List.sub bits ~pos:249 ~len:7)
    in
    let x = Field.project field_bits in
    { Public_key.Compressed.Poly.x; is_odd }
end

let to_public_key_compressed raw =
  let len = String.length raw in
  if len = 64 then
    (* compressed encoding *)
    Public_key_compressed_direct.decode raw
  else (* uncompressed encoding *)
    to_public_key raw |> Public_key.compress

(* inline tests hard-to-impossible to setup with JS *)

let field_example_test () =
  (* from RFC 0038 *)
  let field = Field.of_int 123123 in
  let hex = of_field field in
  let last_part = "01E0F3" in
  (* left-pad with 0s *)
  let expected = String.make (64 - String.length last_part) '0' ^ last_part in
  String.equal hex expected

let field_hex_roundtrip_test () =
  let field0 = Field.of_int 123123 in
  let hex = of_field field0 in
  let field1 = to_field hex in
  Field.equal field0 field1

let pk_roundtrip_test () =
  let field0 = Field.of_int 123123 in
  let field1 = Field.of_int 234234 in
  let hex = of_public_key (field0, field1) in
  let field0', field1' = to_public_key hex in
  Public_key.equal (field0, field1) (field0', field1')

let hex_key = "834f83195c9480aa1bde8e8b2e24a2cd9186a3825d6ca967ffecc9f9befe1c20"

let test_pk =
  Public_key.Compressed.of_base58_check
    "B62qovbUAE4SAq8bT88PZUAyoZDFh65NELvgRf519pHPP3mu7rhrx3z"

let pk_compressed_roundtrip_test () =
  let field0 = Field.of_int 123123 in
  let field1 = Field.of_int 234234 in
  let pk_compressed = Public_key.compress (field0, field1) in
  let hex = Public_key_compressed_direct.encode pk_compressed in
  (* do not use of_public_key_compressed *)
  let pk_compressed' = Public_key_compressed_direct.decode hex in
  Format.eprintf "ORIG@." ;
  Format.eprintf "IS_ODD: %B@." pk_compressed.is_odd ;
  Format.eprintf "FIELD:@." ;
  List.iter (Field.unpack pk_compressed.x) ~f:(fun b -> Format.eprintf "%B " b) ;
  Format.eprintf "@." ;

  Format.eprintf "NEW@." ;
  Format.eprintf "IS_ODD: %B@." pk_compressed'.is_odd ;
  Format.eprintf "FIELD:@." ;
  List.iter (Field.unpack pk_compressed'.x) ~f:(fun b -> Format.eprintf "%B " b) ;
  Format.eprintf "@." ;

  Public_key.Compressed.equal pk_compressed pk_compressed'

let%test "field_example" = field_example_test ()

let%test "field_hex round-trip" = field_hex_roundtrip_test ()

let%test "public key round-trip" = pk_roundtrip_test ()

let%test "public key compressed roundtrip" = pk_compressed_roundtrip_test ()

[%%ifndef consensus_mechanism]

(* for running tests from JS *)

let unit_tests =
  [ ("field example", field_example_test)
  ; ("field-hex round-trip", field_hex_roundtrip_test)
  ; ("public key round-trip", pk_roundtrip_test)
  ; ("public key compressed round-trip", pk_compressed_roundtrip_test)
  ]

let run_unit_tests () =
  List.iter unit_tests ~f:(fun (name, test) ->
      printf "Running %s test\n%!" name ;
      assert (test ()))

[%%endif]
