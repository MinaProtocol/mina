open Verifier
open Core_kernel
open Lite_base

let state_and_instance_hash =
  let salt (s: Hash_prefixes.t) =
    Pedersen.State.salt Lite_params.pedersen_params (s :> string)
  in
  let acc =
    Pedersen.State.update_fold
      (salt Hash_prefixes.transition_system_snark)
      (Proof_system.Verification_key.fold Lite_params.wrap_vk)
  in
  let hash_state s =
    Pedersen.digest_fold
      (salt Hash_prefixes.protocol_state)
      (Lite_base.Protocol_state.fold s)
  in
  fun state ->
    let state_hash = hash_state state in
    (state_hash, Pedersen.digest_fold acc (Pedersen.Digest.fold state_hash))

let wrap_pvk =
  Proof_system.Verification_key.Processed.create Lite_params.wrap_vk

(* TODO: This changes when the curves get flipped *)
let to_wrap_input instance_hash = Snarkette.Mnt6.Fq.to_bigint instance_hash

let verify_chain ({protocol_state; ledger; proof}: Lite_chain.t) =
  let check b lab = if b then Ok () else Or_error.error_string lab in
  let open Or_error.Let_syntax in
  let lb_ledger_hash =
    protocol_state.blockchain_state.ledger_builder_hash.ledger_hash
  in
  let%bind () =
    check
      (Ledger_hash.equal lb_ledger_hash
         (Lite_lib.Sparse_ledger.merkle_root ledger))
      "Incorrect ledger hash"
  in
  let state_hash, instance_hash = state_and_instance_hash protocol_state in
  let%bind () =
    Proof_system.verify wrap_pvk [to_wrap_input instance_hash] proof
  in
  return {Verifier.Response.state_hash}

let () =
  Js_of_ocaml.Worker.set_onmessage (fun (message: Js.js_string Js.t) ->
      let ((chain, _) as query) = Query.of_string (Js.to_string message) in
      let res = verify_chain chain in
      Worker.post_message (Js.string (Response.to_string (query, res))) )
