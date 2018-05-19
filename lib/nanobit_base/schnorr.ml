open Core_kernel
open Snark_params

include Snarky.Signature.Schnorr(Tick)(Snark_params.Tick.Signature_curve)(struct
    open Tick

    (* TODO: This hash function is NOT secure *)
    let hash_checked bs =
      let open Checked.Let_syntax in
      with_label __LOC__ begin
        let%map h =
          digest_bits ~init:Hash_prefix.signature bs
          >>= Pedersen.Digest.choose_preimage_var
        in
        List.take (Pedersen.Digest.Unpacked.var_to_bits h) Scalar.length
      end

    let hash bs =
      let s = Pedersen.(State.create params) in
      let s = Pedersen.State.update_fold s (List.fold bs) in
      Scalar.pack 
        (List.take (Field.unpack (Pedersen.State.digest s)) Scalar.length)
  end)
