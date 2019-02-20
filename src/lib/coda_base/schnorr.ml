open Core_kernel
open Snark_params
open Fold_lib
open Bitstring_lib

module Message = struct
  module Scalar = Tick.Inner_curve.Scalar
  open Tick

  type t = User_command_payload.t

  type var = Pedersen.Checked.Section.t

  let var_of_payload payload =
    let open Let_syntax in
    let%bind bs = Transaction_union_payload.Checked.to_triples payload in
    Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty bs
      ~start:Hash_prefix.length_in_triples

  let hash t ~nonce =
    let d =
      Pedersen.digest_fold Hash_prefix.signature
        Fold.(
          User_command_payload.fold t +> group3 ~default:false (of_list nonce))
    in
    Scalar.of_bits
      (Random_oracle.digest_field d |> Random_oracle.Digest.to_bits)

  let () = assert Insecure.signature_hash_function

  let%snarkydef hash_checked t ~nonce =
    let open Let_syntax in
    let init =
      Pedersen.Checked.Section.create ~acc:(`Value Hash_prefix.signature.acc)
        ~support:
          (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
    in
    let%bind with_t = Pedersen.Checked.Section.disjoint_union_exn init t in
    let%bind digest =
      let%map final =
        Pedersen.Checked.Section.extend with_t
          (Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_
             nonce)
          ~start:
            ( Hash_prefix.length_in_triples
            + User_command_payload.length_in_triples )
      in
      let d, _ =
        Pedersen.Checked.Section.to_initial_segment_digest final
        |> Or_error.ok_exn
      in
      d
    in
    let%bind bs = Pedersen.Checked.Digest.choose_preimage digest in
    let%map d = Random_oracle.Checked.digest_bits (bs :> Boolean.var list) in
    Bitstring.Lsb_first.of_list (Array.to_list (d :> Boolean.var array))
end

include Signature_lib.Checked.Schnorr (Tick) (Snark_params.Tick.Inner_curve)
          (Message)
