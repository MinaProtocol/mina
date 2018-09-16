open Core_kernel
open Lite_base
open Js_of_ocaml

module Proof_system = Snarkette.Mnt6.Groth_maller

let rest_server_port = 8080

let url s = sprintf "http://localhost:%d/%s" rest_server_port s

let get url on_success on_error =
  let req = XmlHttpRequest.create () in
  req ##. onerror :=
    Dom.handler (fun _e ->
        on_error (Error.of_string "get request failed") ;
        Js._false ) ;
  req ##. onload :=
    Dom.handler (fun _e ->
        ( match Js.Opt.to_option (File.CoerceTo.string req ##. response) with
        | None -> on_error (Error.of_string "get request failed")
        | Some s ->
          printf "Received response %s\n" (Js.to_string s);
          on_success (Js.to_string s)) ;
        Js._false ) ;
  req ## _open (Js.string "GET") (Js.string url) Js._true ;
  req ## send Js.Opt.empty

let get_account _pk on_sucess on_error =
  let url = "/chain" in
  get url
    (fun s ->
       printf "FO\n";
       let chain = Binable.of_string (module Lite_chain) (B64.decode s) in
       printf "bar\n";
       on_sucess chain)
    on_error

let instance_hash =
  let salt (s : Hash_prefixes.t) =
    Pedersen.State.salt Lite_params.pedersen_params (s :> string)
  in
  let acc =
    Pedersen.State.update_fold (salt Hash_prefixes.transition_system_snark)
      (Proof_system.Verification_key.fold Lite_params.wrap_vk)
  in
  let hash_state s =
    Pedersen.digest_fold (salt Hash_prefixes.protocol_state)
      (Lite_base.Protocol_state.fold s)
  in
  fun state ->
    Pedersen.digest_fold acc
      (Pedersen.Digest.fold (hash_state state))

let wrap_pvk =
  Proof_system.Verification_key.Processed.create Lite_params.wrap_vk

(* TODO: This changes when the curves get flipped *)
let to_wrap_input state =
  Snarkette.Mnt6.Fq.to_bigint (instance_hash state)

let verify_chain ({ protocol_state; ledger; proof } : Lite_chain.t) =
  let check b lab = if b then Ok () else Or_error.error_string lab in
  let open Or_error.Let_syntax in
  let lb_ledger_hash = protocol_state.blockchain_state.ledger_builder_hash.ledger_hash in
  let%bind () =
    check
      (Ledger_hash.equal lb_ledger_hash
         (Lite_lib.Sparse_ledger.merkle_root ledger))
      "Incorrect ledger hash"
  in
  let%bind () =
    Proof_system.verify wrap_pvk [ to_wrap_input protocol_state ] proof
  in
  return ()

let () =
  get_account () (fun chain ->
    Printf.printf !"chain: %{sexp:Lite_chain.t}\n"
      chain;
    Printf.printf !"chain: %{sexp:unit Or_error.t}\n"
      (verify_chain chain)
  )
    (fun e ->
    Printf.printf !"error: %{sexp:Error.t}\n"
      e)
