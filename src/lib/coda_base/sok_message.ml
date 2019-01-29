open Core
open Snark_params
open Tick
open Fold_lib
open Import
open Coda_digestif

module T = struct
  type t =
    {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
  [@@deriving bin_io, sexp]
end

include T

let create ~fee ~prover = {fee; prover}

module Digest = struct
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving sexp, compare, eq, bin_io, hash]
    end
  end

  include Stable.V1

  let fold s =
    { Fold.fold=
        (fun ~init ~f ->
          let n = 8 * String.length s in
          let rec go acc i =
            if i = n then acc
            else
              let b = (Char.to_int s.[i / 8] lsr (7 - (i % 8))) land 1 = 1 in
              go (f acc b) (i + 1)
          in
          go init 0 ) }

  let length_in_bytes = 32

  let length_in_bits = 8 * length_in_bytes

  let length_in_triples = (length_in_bits + 2) / 3

  let to_bits s =
    List.init length_in_bits ~f:(fun i ->
        (Char.to_int s.[i / 8] lsr (7 - (i % 8))) land 1 = 1 )

  let gen = String.gen_with_length length_in_bytes Char.gen

  let%test_unit "to_bits compatible with fold" =
    Quickcheck.test gen ~f:(fun t -> assert (Fold.to_list (fold t) = to_bits t))

  let of_bits = Sha256_lib.Sha256.bits_to_string

  let%test_unit "of_bits . to_bits = id" =
    Quickcheck.test gen ~f:(fun t -> assert (equal (of_bits (to_bits t)) t))

  let%test_unit "to_bits . of_bits = id" =
    Quickcheck.test (List.gen_with_length length_in_bits Bool.gen) ~f:(fun t ->
        assert (to_bits (of_bits t) = t) )

  let fold t = Fold.group3 ~default:false (fold t)

  module Checked = struct
    type t = Boolean.var list

    let to_triples t =
      Fold.(to_list (group3 ~default:Boolean.false_ (of_list t)))
  end

  let typ =
    Typ.transport
      (Typ.list ~length:length_in_bits Boolean.typ)
      ~there:to_bits ~back:of_bits

  let default = String.init length_in_bytes ~f:(fun _ -> '\000')
end

let digest t =
  (Digestif.SHA256.digest_string (Binable.to_string (module T) t) :> string)
