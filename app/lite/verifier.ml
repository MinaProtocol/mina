open Core_kernel
open Lite_base

module Proof_system = Snarkette.Mnt6.Groth_maller

module Make_stringable_of_base64_binable(T : Binable.S) = struct
  let to_string =
    Fn.compose B64.encode (Binable.to_string (module T))

  let of_string =
    Fn.compose (Binable.of_string (module T)) B64.decode
end

module Query = struct
  module T = struct
    type t = Lite_chain.t * int
    [@@deriving bin_io]
  end
  include T
  include Make_stringable_of_base64_binable(T)
end

module Response = struct
  module T = struct
    type t = Query.t * unit Or_error.t
    [@@deriving bin_io]
  end
  include T
  include Make_stringable_of_base64_binable(T)

  let id (((_, id), _) : t) = id

  let result ((_, r) : t) = r
end

let instance_hash =
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
    Pedersen.digest_fold acc (Pedersen.Digest.fold (hash_state state))

let wrap_pvk =
  Proof_system.Verification_key.Processed.create Lite_params.wrap_vk

(* TODO: This changes when the curves get flipped *)
let to_wrap_input state = Snarkette.Mnt6.Fq.to_bigint (instance_hash state)

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
  let%bind () =
    Proof_system.verify wrap_pvk [to_wrap_input protocol_state] proof
  in
  return ()

type t = (Js.js_string Js.t, Js.js_string Js.t) Worker.worker Js.t

let verifier_main = "/_build/default/app/lite/verifier_main.bc.js"

let create () = Worker.create verifier_main

let send_verify_message (t:t) q =
  t##postMessage (Js.string (Query.to_string q))

let set_on_message (t : t) ~f =
  t##.onmessage := Dom.handler (fun q ->
    f (Response.of_string (Js.to_string (q##.data)));
    Js._false
  )
