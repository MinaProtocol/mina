open Core_kernel

(* Someday: Use Int64.t *)
type t = Bigstring.t
[@@deriving bin_io]

let byte_length = 8

let zero = Bigstring.create byte_length

let increment t : t =
  match Bigstring.read_bin_prot t Int64.bin_reader_t with
  | Ok (i64, _) ->
    let buf = Bigstring.create byte_length in
    let _ = Bigstring.write_bin_prot buf Int64.bin_writer_t i64 in
    buf
  | Error _ -> failwith "Opaque t makes this impossible"

module Snarkable (Impl : Camlsnark.Snark_intf.S) =
  Bits.Make_bigstring(Impl)(struct let byte_length = byte_length end)
