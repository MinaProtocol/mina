open Core
open Snark_params
open Tock

let step_vk_typ =
  Verifier.Verification_key.Compressed.typ ~input_size:Step_input.size

let input = Data_spec.[step_vk_typ; Wrap_input.typ]

let input_size = Data_spec.size input

(* The verification key is compressed so that the input to this wrap SNARK is smaller,
    which then means it has a smaller verification key and we do less work verifying it
    in the Tick SNARKs that recursively verify these (by avoiding the exponentiations
    associated with each public input.)
*)
let main (vk : _ Tock.Verifier.Verification_key.Compressed.t_)
    (x : Wrap_input.var) =
  let open Tock.Verifier in
  let%bind pi = exists Tock.Verifier.Proof.typ ~compute:As_prover.get_state
  and input = Wrap_input.Checked.to_scalar x
  and vk = Verification_key.Compressed.decompress vk in
  let%bind pvk = Verification_key.Precomputation.create vk in
  let%bind result = verify vk pvk [input] pi in
  Boolean.Assert.is_true result

let constraint_system () = constraint_system ~exposing:input main

let prove step_vk pk =
  let compressed = Step_vk_compressed.Unchecked.of_backend_vk step_vk in
  stage (fun statement proof ->
      Or_error.try_with (fun () ->
          prove pk input
            (Verifier.proof_of_backend_proof proof)
            main compressed
            (Wrap_input.of_tick_field statement) ) )

let verify step_vk vk =
  let compressed = Step_vk_compressed.Unchecked.of_backend_vk step_vk in
  stage (fun statement proof ->
      verify proof vk input compressed (Wrap_input.of_tick_field statement) )
