open Core_kernel
open Snark_params
open Bitstring_lib

module Message = struct
  module Scalar = Tick.Inner_curve.Scalar
  open Tick

  type t = User_command_payload.t

  type var = Transaction_union_payload.var

  let challenge_length = 128

  let derive t ~private_key ~public_key:pk =
    let { User_command_payload.Poly.common=
            {User_command_payload.Common.Poly.fee; nonce; valid_until; memo}
        ; body= {Transaction_union_payload.Body.amount; public_key; tag} } =
      Transaction_union_payload.of_user_command_payload t
    in
    let open Coda_numbers in
    let open Currency in
    let pk_bits {Signature_lib.Public_key.Compressed.Poly.x; is_odd} =
      is_odd :: Field.unpack x
    in
    List.concat
      [ Tock.Field.unpack private_key
      ; pk_bits
          (Signature_lib.Public_key.compress (Inner_curve.to_affine_exn pk))
      ; Fee.to_bits fee
      ; Account_nonce.Bits.to_bits nonce
      ; Global_slot.to_bits valid_until
      ; User_command_memo.to_bits memo
      ; Amount.to_bits amount
      ; pk_bits public_key
      ; (let x, y = Transaction_union_tag.to_bits tag in
         [x; y]) ]
    |> Array.of_list |> Blake2.bits_to_string |> Blake2.digest_string
    |> Blake2.to_raw_string |> Blake2.string_to_bits |> Array.to_list
    |> Tock.Field.project

  let hash t ~public_key ~r =
    let input =
      let px, py = Tick.Inner_curve.to_affine_exn public_key in
      Random_oracle.Input.append
        (Transaction_union_payload.to_input
           (Transaction_union_payload.of_user_command_payload t))
        {field_elements= [|px; py; r|]; bitstrings= [||]}
    in
    let open Random_oracle in
    hash ~init:Hash_prefix.signature (pack_input input)
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
        hash ~init:Hash_prefix_states.signature (pack_input input)
        |> Digest.to_bits ~length:challenge_length
        |> Bitstring.Lsb_first.of_list )
end

include Signature_lib.Checked.Schnorr (Tick) (Snark_params.Tick.Inner_curve)
          (Message)
