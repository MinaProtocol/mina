(* raw.ml -- raw hex encoding for Rosetta *)

open Core_kernel

(* see RFC 0038, section "marshal-keys" for a specification *)

let of_field field =
  let bits0 = Snark_params_nonconsensus.Field.unpack field |> List.rev in
  (* field elements are 255 bits, left-pad to get 32 bytes *)
  let bits = false :: bits0 in
  let bits4_to_hex bits =
    List.mapi bits ~f:(fun i bit -> if bit then Int.pow 2 (3 - i) else 0)
    |> List.fold ~init:0 ~f:( + ) |> sprintf "%0X"
  in
  let bits_by_4s =
    let rec go bits acc =
      if List.is_empty bits then List.rev acc
      else
        let bits4, rest = List.split_n bits 4 in
        go rest (bits4 :: acc)
    in
    go bits []
  in
  let cs = List.map bits_by_4s ~f:bits4_to_hex in
  String.concat cs

let of_public_key pk =
  let field1, field2 = pk in
  of_field field1 ^ of_field field2

let of_public_key_compressed pk =
  let open Signature_lib_nonconsensus in
  Public_key.decompress_exn pk |> of_public_key
