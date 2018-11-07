open Core_kernel
open Snark_params
open Tuple_lib
open Fold_lib
open Bitstring_lib

module type Message_intf = sig
  type t

  val fold : t -> bool Triple.t Fold.t

  val length_in_triples : int
end

module Make (Prefix : sig
  val t : Tick.Pedersen.State.t
end)
(Message : Message_intf) =
  Signature_lib.Checked.Schnorr (Tick) (Snark_params.Tick.Inner_curve)
    (struct
      open Tick
      module Scalar = Inner_curve.Scalar

      type t = Message.t

      type var = Pedersen.Checked.Section.t

      let hash t ~nonce =
        let d =
          Pedersen.digest_fold Prefix.t
            Fold.(Message.fold t +> group3 ~default:false (of_list nonce))
        in
        Scalar.of_bits (Sha256_lib.Sha256.digest (Field.unpack d))

      let hash_checked t ~nonce =
        let open Let_syntax in
        with_label __LOC__
          (let init =
             Pedersen.Checked.Section.create ~acc:(`Value Prefix.t.acc)
               ~support:
                 (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
           in
           let%bind with_t =
             Pedersen.Checked.Section.disjoint_union_exn init t
           in
           let%bind digest =
             let%map final =
               Pedersen.Checked.Section.extend with_t
                 (Bitstring_lib.Bitstring.pad_to_triple_list
                    ~default:Boolean.false_ nonce)
                 ~start:
                   (Hash_prefix.length_in_triples + Message.length_in_triples)
             in
             let d, _ =
               Pedersen.Checked.Section.to_initial_segment_digest final
               |> Or_error.ok_exn
             in
             d
           in
           let%bind bs = Pedersen.Checked.Digest.choose_preimage digest in
           let%map d =
             Sha256_lib.Sha256.Checked.digest (bs :> Boolean.var list)
           in
           Bitstring.Lsb_first.of_list (d :> Boolean.var list))
    end)

(*
  let var_of_payload payload =
    let open Let_syntax in
    let%bind bs = Payment_payload.var_to_triples payload in
    Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty bs
      ~start:Hash_prefix.length_in_triples

*)
