open Core
open Snark_params.Tick

module Hash = struct
  include Data_hash.Make_small (struct
    let length_in_bits = 256
  end)

  let of_bytes s =
    Z.of_bits s |> Bignum_bigint.of_zarith_bigint |> Bigint.of_bignum_bigint
    |> Bigint.to_field |> of_hash |> Or_error.ok_exn

  let dummy = of_bytes (String.init (length_in_bits / 8) ~f:(fun _ -> '\000'))
end

module Aux_hash = Hash
include Hash

type sibling_hash = Hash.Stable.V1.t [@@deriving bin_io]

type ledger_builder_aux_hash = Aux_hash.Stable.V1.t [@@deriving bin_io]

let of_aux_and_ledger_hash ledger_builder_aux_hash ledger_hash =
  let h = Cryptokit.Hash.sha3 256 in
  h#add_string (Ledger_hash.to_bytes ledger_hash) ;
  h#add_string (to_bytes ledger_builder_aux_hash);
  of_bytes h#result
