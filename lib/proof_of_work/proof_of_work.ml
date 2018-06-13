open Core_kernel
open Nanobit_base
open Util
open Snark_params.Tick

include Data_hash.Make_small (struct
  let length_in_bits = Target.bit_length
end)

let create state nonce =
  of_hash
    (Pedersen.digest_fold Hash_prefix.proof_of_work
       (Blockchain_state.fold state +> Block.Nonce.Bits.fold nonce))

let meets_target_unchecked (pow: t) (target: Target.t) =
  Bigint.(compare (of_field (pow :> Field.t)) (of_field (target :> Field.t)))
  < 0

let meets_target_var (pow: var) (target: Target.Packed.var) =
  let open Let_syntax in
  let%map {less; _} =
    Checked.compare ~bit_length:length_in_bits (var_to_hash_packed pow)
      (target :> Cvar.t)
  in
  less
