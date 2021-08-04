open Marlin_plonk_bindings

module Bigint256 = struct
  include Bigint_256

  let num_limbs = num_limbs ()

  let bytes_per_limb = bytes_per_limb ()

  let length_in_bytes = num_limbs * bytes_per_limb

  let to_hex_string t =
    let data = to_bytes t in
    "0x" ^ Hex.encode (Bytes.to_string data)

  let of_hex_string s =
    assert (Char.equal s.[0] '0' && Char.equal s.[1] 'x') ;
    String.sub s 2 (String.length s - 2)
    |> Hex.Safe.of_hex
    |> (function Some x -> x | None -> assert false)
    |> Bytes.of_string |> of_bytes

  let of_numeral s ~base = of_numeral s (String.length s) base
end

module Fp = Pasta_fp
module Fq = Pasta_fq
