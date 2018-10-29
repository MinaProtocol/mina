open Verifier
open Core_kernel
open Lite_base

let state_and_instance_hash ~wrap_vk =
  let salt (s : Hash_prefixes.t) =
    Pedersen.State.salt Lite_params.pedersen_params (s :> string)
  in
  let acc =
    Pedersen.State.update_fold
      (salt Hash_prefixes.transition_system_snark)
      (Proof_system.Verification_key.fold wrap_vk)
  in
  let hash_state s =
    Pedersen.digest_fold
      (salt Hash_prefixes.protocol_state)
      (Lite_base.Protocol_state.fold s)
  in
  stage (fun state ->
      let state_hash = hash_state state in
      (state_hash, Pedersen.digest_fold acc (Pedersen.Digest.fold state_hash))
  )

let wrap_pvk =
  Proof_system.Verification_key.Processed.create Lite_params.wrap_vk

let to_wrap_input instance_hash =
  Lite_base.Crypto_params.Tock.fq_to_scalars instance_hash

let verify_chain pvk state_and_instance_hash
    ({protocol_state; ledger; proof} : Lite_chain.t) =
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
  let%map () = Proof_system.verify pvk (to_wrap_input instance_hash) proof in
  {Verifier.Response.state_hash}

let get_verification_key on_sucess on_error =
  let url = sprintf !"%s/client_verification_key" Web_response.s3_link in
  Web_response.get url
    (fun s ->
      let vk =
        Binable.of_string (module Proof_system.Verification_key) (B64.decode s)
      in
      on_sucess vk )
    on_error

let () =
  Js_of_ocaml.Worker.set_onmessage (fun (message : Js.js_string Js.t) ->
      get_verification_key
        (fun vk ->
          let pvk = Proof_system.Verification_key.Processed.create vk in
          let ((chain, _) as query) = Query.of_string (Js.to_string message) in
          let res =
            verify_chain pvk
              (unstage (state_and_instance_hash ~wrap_vk:vk))
              chain
          in
          Worker.post_message (Js.string (Response.to_string (query, res))) )
        (fun _ -> ()) )
