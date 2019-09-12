open Core_kernel
open Snark_params
open Bitstring_lib

module Message = struct
  module Scalar = Tick.Inner_curve.Scalar
  open Tick

  type t = User_command_payload.t

  type var = Transaction_union_payload.var

  let var_of_payload payload =
    let%bind bs = Transaction_union_payload.Checked.to_triples payload in
    Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty bs
      ~start:Hash_prefix.length_in_triples

  let challenge_length = 128

  let hash (t : t) ~nonce =
    let input =
      Random_oracle.Input.append
        (Transaction_union_payload.to_input
           (Transaction_union_payload.of_user_command_payload t))
        {field_elements= [||]; bitstrings= [|nonce|]}
    in
    let open Random_oracle in
    hash ~init:Hash_prefix.Random_oracle.signature (pack_input input)
    |> Digest.to_bits ~length:challenge_length
    |> Scalar.of_bits

  let%snarkydef hash_checked t ~nonce =
    let%bind t = Transaction_union_payload.Checked.to_input t in
    let input =
      Random_oracle.Input.append t {field_elements= [||]; bitstrings= [|nonce|]}
    in
    make_checked (fun () ->
        let open Random_oracle.Checked in
        hash ~init:Hash_prefix_states.Random_oracle.signature
          (pack_input input)
        |> Digest.to_bits ~length:challenge_length
        |> Bitstring.Lsb_first.of_list )
end

include Signature_lib.Checked.Schnorr (Tick) (Snark_params.Tick.Inner_curve)
          (Message)
