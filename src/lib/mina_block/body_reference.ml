(** This module defines how a block header refers to the body of its block.
    At the moment, this is merely a hash of the body. But in an upcoming
    hard fork, we will be updating this to reference to point to the root
    "Bitswap block" CID along with a signature attesting to ownership over
    this association (for punishment and manipuluation prevention). This will
    allow us to upgrade block gossip to happen over Bitswap in a future
    soft fork release. *)

open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Blake2.Stable.V1.t * Mina_base.Signature.Stable.V1.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t

[%%define_locally Stable.Latest.(t_of_sexp, sexp_of_t, to_yojson, of_yojson)]

let message_for_sign ref :
    (Snark_params.Tick.Field.t, bool) Random_oracle.Legacy.Input.t =
  let field_elements = [||] in
  let bitstrings =
    [| Blake2.to_raw_string ref |> Blake2.string_to_bits |> Array.to_list |]
  in
  { field_elements; bitstrings }

let sign_reference ~private_key =
  Fn.compose (Signature_lib.Schnorr.Legacy.sign private_key) message_for_sign

let compute_reference b =
  let sz = Body.Stable.V1.bin_size_t b in
  let buf = Bin_prot.Common.create_buf sz in
  ignore (Body.Stable.V1.bin_write_t buf ~pos:0 b : int) ;
  Tuple2.get2 @@ Mina_net2.Bitswap_block.blocks_of_data ~max_block_size:1024 buf

let of_body ~private_key b : t =
  let body_ref = compute_reference b in
  (body_ref, sign_reference ~private_key body_ref)

let verify ~(public_key : Signature_lib.Public_key.t) ((ref, signature) : t) =
  Signature_lib.Schnorr.Legacy.verify signature
    (Snark_params.Tick.Inner_curve.of_affine public_key)
    (message_for_sign ref)

let reference = fst
