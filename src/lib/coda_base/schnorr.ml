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

  let derive t ~private_key ~public_key =
    let key_bits =
      let px, py = Tick.Inner_curve.to_affine_exn public_key in
      Tock.Field.unpack private_key @ Field.unpack px @ Field.unpack py
    in
    let bits f =
      Fold_lib.Fold.to_list f
      |> List.concat_map ~f:(fun (x, y, z) -> [x; y; z])
      |> List.append key_bits |> Array.of_list |> Blake2.bits_to_string
    in
    let blake2 s =
      s |> Blake2.digest_string |> Blake2.to_raw_string
      |> Blake2.string_to_bits |> Array.to_list
    in
    Transaction_union_payload.(fold (of_user_command_payload t))
    |> bits |> blake2 |> Tock.Field.project

  let hash t ~public_key ~r =
    let input =
      let px, py = Tick.Inner_curve.to_affine_exn public_key in
      Random_oracle.Input.append
        (Transaction_union_payload.to_input
           (Transaction_union_payload.of_user_command_payload t))
        {field_elements= [|px; py; r|]; bitstrings= [||]}
    in
    let open Random_oracle in
    hash ~init:Hash_prefix.Random_oracle.signature (pack_input input)
    |> Digest.to_bits ~length:challenge_length
    |> Scalar.of_bits

  let%snarkydef hash_checked t ~public_key ~r =
    let%bind t = Transaction_union_payload.Checked.to_input t in
    let input =
      let px, py = public_key in
      Random_oracle.Input.append t
        {field_elements= [|px; py; r|]; bitstrings= [||]}
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
