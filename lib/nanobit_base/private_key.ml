open Core_kernel
open Async_kernel

include Schnorr.Private_key

let create () =
  if Insecure.private_key_generation
  then
    Bignum.Std.Bigint.random
      Snark_params.Tick.Hash_curve.Params.order
  else
    failwith "Insecure.private_key_generation"

let of_bigstring bs =
  let open Or_error.Let_syntax in
  let%map elem, _ = Bigstring.read_bin_prot bs bin_reader_t in
  elem

let to_bigstring elem =
  let bs = Bigstring.create ((bin_size_t elem) + Bin_prot.Utils.size_header_length) in
  let _ = Bigstring.write_bin_prot bs bin_writer_t elem in
  bs


