open Core_kernel
open Util
open Snark_params

module Message = struct
  module Scalar = Tick.Signature_curve.Scalar

  open Tick

  type t = Transaction_payload.t

  type var = Pedersen_hash.Section.t

  let var_of_payload payload =
    let open Let_syntax in
    let%bind bs = Transaction_payload.var_to_bits payload in
    Pedersen_hash.Section.extend Pedersen_hash.Section.empty bs
      ~start:Hash_prefix.length_in_bits

  let hash t ~nonce =
    let d =
      Pedersen.digest_fold Hash_prefix.signature
        (Transaction_payload.fold t +> List.fold nonce)
    in
    List.take
      (Field.unpack d)
      Scalar.length
    |> Scalar.pack

  let () = assert Insecure.signature_hash_function

  let hash_checked t ~nonce =
    let open Let_syntax in
    with_label __LOC__ begin
      let init =
        Pedersen_hash.Section.create ~acc:(`Value Hash_prefix.signature.acc)
          ~support:(Interval_union.of_interval (0, Hash_prefix.length_in_bits))
      in
      let%bind with_t = 
        Pedersen_hash.Section.disjoint_union_exn init t
      in
      let%bind digest =
        let%map final =
          Pedersen_hash.Section.extend with_t nonce
            ~start:(Hash_prefix.length_in_bits + Transaction_payload.length_in_bits)
        in
        let (d, _) = Pedersen_hash.Section.to_initial_segment_digest final |> Or_error.ok_exn in
        d
      in
      let%map bs = Pedersen_hash.Digest.choose_preimage digest in
      List.take bs Scalar.length
    end
end

include Snarky.Signature.Schnorr (Tick) (Snark_params.Tick.Signature_curve) (Message)
