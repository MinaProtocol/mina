open Core_kernel
open Js_of_ocaml

(* *************** *
 *    our field    *
 * *************** *)

module Field = struct
  include Snark_params.Tick.Field

  (* Converts a byterray into a [Field.t], raises an exception if the number obtained is larger than the order *)
  let of_bytes bytearray =
    let aux i acc c =
      let big = Nat.of_int @@ int_of_char c in
      let offset = Nat.shift_left big (Int.( * ) i 8) in
      Nat.(acc + offset)
    in
    let zero = Nat.of_int 0 in
    let big = Array.foldi bytearray ~init:zero ~f:aux in
    let one = Nat.of_int 1 in
    if Nat.(order - one < big) then
      failwith "the given field is larger than the order" ;
    of_bigint big

  (* Converts a field element into an hexadecimal string (encoding the field element in little-endian) *)
  let to_hex field =
    (* taken from src/lib/pickles *)
    let bits_to_bytes bits =
      let byte_of_bits bs =
        List.foldi bs ~init:0 ~f:(fun i acc b ->
            if b then acc lor (1 lsl i) else acc)
        |> Char.of_int_exn
      in
      List.map
        (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0))
        ~f:byte_of_bits
      |> String.of_char_list
    in
    let bytearray = to_bits field |> bits_to_bytes in
    Hex.encode bytearray
end

(* ********************** *
 * our permutation Config *
 * ********************** *)

module Config = struct
  module Field = Field

  let rounds_full = 54

  let initial_ark = false

  let rounds_partial = 0

  let to_the_alpha x =
    let open Field in
    let x_2 = x * x in
    let x_4 = x_2 * x_2 in
    let x_7 = x_4 * x_2 * x in
    x_7

  module Operations = struct
    let add_assign ~state i x = Field.(state.(i) <- state.(i) + x)

    let apply_affine_map (matrix, constants) v =
      let dotv row =
        Array.reduce_exn (Array.map2_exn row v ~f:Field.( * )) ~f:Field.( + )
      in
      let res = Array.map matrix ~f:dotv in
      Array.map2_exn res constants ~f:Field.( + )

    let copy a = Array.map a ~f:Fn.id
  end
end

(* ***************** *
 *   hash function   *
 * ***************** *)

module Hash = struct
  include Sponge.Make_hash (Sponge.Poseidon (Config))

  let params : Field.t Sponge.Params.t =
    Sponge.Params.(map pasta_p_kimchi ~f:Field.of_string)

  let update ~state = update ~state params

  let hash ?init = hash ?init params

  let pack_input =
    Random_oracle_input.Legacy.pack_to_fields ~size_in_bits:Field.size_in_bits
      ~pack:Field.project
end

module String_sign = String_sign

(* ************************ *
 *   javascript interface   *
 * ************************ *)

type 'a array_js = 'a Js.js_array Js.t

type u8_array_js = Js_of_ocaml.Typed_array.uint8Array Js.t

type string_js = Js.js_string Js.t

(* input is a raw string of bytes *)
let hash_bytearray (bytearray : u8_array_js) : string_js =
  let string_to_bitstring s =
    let char_bits = String_sign.char_bits in
    let x = Stdlib.(Array.of_seq (Seq.map char_bits (String.to_seq s))) in
    Random_oracle_input.Legacy.bitstrings x
  in
  let input = Js_of_ocaml.Typed_array.String.of_uint8Array bytearray in
  let input =
    if String.length input = 0 then [||]
    else input |> string_to_bitstring |> Hash.pack_input
  in
  let init = Hash.initial_state in
  let digest = Hash.hash ~init input in
  let digest_hex = Field.to_hex digest in
  Js.string digest_hex

(* input is an array of field elements encoded as bytearrays *)
let hash_field_elems (field_elems : u8_array_js array_js) : string_js =
  let field_of_js_field x =
    let field_bytes = Js_of_ocaml.Typed_array.String.of_uint8Array x in
    if String.length field_bytes = 0 then failwith "invalid field element" ;
    String.to_array field_bytes |> Field.of_bytes
  in
  let input : u8_array_js array = Js.to_array field_elems in
  let input : Field.t array =
    if Array.length input = 0 then [||]
    else Array.map input ~f:field_of_js_field
  in
  let init = Hash.initial_state in
  let digest = Hash.hash ~init input in
  let digest_hex = Field.to_hex digest in
  Js.string digest_hex
