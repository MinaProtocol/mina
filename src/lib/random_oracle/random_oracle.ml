open Core_kernel
open Snark_params

let digest_size_in_bits = 256

let digest_size_in_bytes = 256 / 8

module Blake2 = Digestif.Make_BLAKE2S (struct
  let digest_size = digest_size_in_bytes
end)

module Digest = struct
  open Fold_lib

  let fold_bits s =
    { Fold.fold=
        (fun ~init ~f ->
          let n = 8 * String.length s in
          let rec go acc i =
            if i = n then acc
            else
              let b = (Char.to_int s.[i / 8] lsr (i mod 8)) land 1 = 1 in
              go (f acc b) (i + 1)
          in
          go init 0 ) }

  module T = struct
    type t = string [@@deriving sexp, bin_io, compare, hash, yojson]
  end

  let to_bits = Snarky_blake2.string_to_bits

  let length_in_bytes = 32

  let length_in_bits = 8 * length_in_bytes

  let length_in_triples = (length_in_bits + 2) / 3

  let gen = String.gen_with_length length_in_bytes Char.gen

  let%test_unit "to_bits compatible with fold" =
    Quickcheck.test gen ~f:(fun t ->
        assert (Array.of_list (Fold.to_list (fold_bits t)) = to_bits t) )

  let of_bits = Snarky_blake2.bits_to_string

  let%test_unit "of_bits . to_bits = id" =
    Quickcheck.test gen ~f:(fun t ->
        assert (String.equal (of_bits (to_bits t)) t) )

  let%test_unit "to_bits . of_bits = id" =
    Quickcheck.test (List.gen_with_length length_in_bits Bool.gen) ~f:(fun t ->
        assert (Array.to_list (to_bits (of_bits (List.to_array t))) = t) )

  include T
  include Comparable.Make (T)

  let fold t = Fold_lib.Fold.group3 ~default:false (fold_bits t)

  let of_string = Fn.id

  open Tick

  module Checked = struct
    type unchecked = t

    type t = Boolean.var array

    let to_triples t =
      Fold_lib.Fold.(to_list (group3 ~default:Boolean.false_ (of_array t)))

    let constant (s : unchecked) =
      assert (Int.(String.length s = length_in_bytes)) ;
      Array.map (to_bits s) ~f:Boolean.var_of_value
  end

  let to_bits (t : t) =
    Array.to_list (Snarky_blake2.string_to_bits (t :> string))

  let typ : (Checked.t, t) Typ.t =
    Typ.transport (Typ.array ~length:digest_size_in_bits Boolean.typ)
      ~there:Snarky_blake2.string_to_bits ~back:(fun bs ->
        of_string (Snarky_blake2.bits_to_string bs) )
end

let digest_string s = (Blake2.digest_string s :> string)

let digest_field x =
  ( Blake2.digest_bigstring Tick_backend.Bigint.R.(to_bigstring (of_field x))
    :> string )

module Checked = struct
  include Snarky_blake2.Make (Tick)

  let digest_bits bs = blake2s (Array.of_list bs)

  let digest_field x =
    let open Tick.Let_syntax in
    Tick.Field.Checked.choose_preimage_var x ~length:Tick.Field.size_in_bits
    >>= digest_bits
end
