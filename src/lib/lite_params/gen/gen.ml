[%%import
"../../../config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Core

[%%if
with_snark]

let key_generation = true

[%%else]

let key_generation = false

[%%endif]

module Proof_of_signature = Consensus.Proof_of_signature.Make (struct
  module Time = Coda_base.Block_time

  let proposal_interval = Time.Span.of_ms Int64.zero

  module Ledger_builder_diff = Unit
  module Genesis_ledger = Genesis_ledger
end)

module Lite_compat = Lite_compat.Make (Proof_of_signature.Blockchain_state)

let pedersen_params ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let arr = Crypto_params.Pedersen_params.params in
  let arr_expr =
    List.init (Array.length arr) ~f:(fun i ->
        let g, _, _, _ = arr.(i) in
        estring
          (B64.encode
             (Binable.to_string
                (module Lite_base.Crypto_params.Tock.G1)
                (Lite_compat.g1 g))) )
    |> E.pexp_array
  in
  [%expr
    Array.map
      (fun s ->
        Core_kernel.Binable.of_string
          (module Lite_base.Crypto_params.Tock.G1)
          (B64.decode s) )
      [%e arr_expr]]

let wrap_vk ~loc =
  let open Async in
  let%bind keys = Snark_keys.blockchain_verification () in
  let vk = keys.wrap in
  let module V = Snark_params.Tick.Verifier_gadget in
  let vk = Lite_compat.verification_key vk in
  let vk_base64 =
    B64.encode
      (Binable.to_string
         (module Lite_base.Crypto_params.Tock.Groth_maller.Verification_key)
         vk)
  in
  let%map () =
    if not key_generation then Deferred.unit
    else
      let%bind () = Unix.mkdir ~p:() Cache_dir.autogen_path in
      Writer.save
        (Cache_dir.autogen_path ^/ "client_verification_key")
        ~contents:vk_base64
  in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%expr
    Core_kernel.Binable.of_string
      (module Lite_base.Crypto_params.Tock.Groth_maller.Verification_key)
      (B64.decode [%e estring vk_base64])]

let protocol_state (s : Proof_of_signature.Protocol_state.value) :
    Lite_base.Protocol_state.t =
  let open Proof_of_signature in
  let consensus_state =
    Protocol_state.consensus_state s
    |> Option.value_exn Consensus_state.to_lite
  in
  { Lite_base.Protocol_state.previous_state_hash=
      Lite_compat.digest
        ( Protocol_state.previous_state_hash s
          :> Snark_params.Tick.Pedersen.Digest.t )
  ; blockchain_state=
      Lite_compat.blockchain_state
        (Proof_of_signature.Protocol_state.blockchain_state s)
  ; consensus_state }

let genesis ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let protocol_state =
    protocol_state Proof_of_signature.genesis_protocol_state
  in
  let ledger =
    Sparse_ledger_lib.Sparse_ledger.of_hash ~depth:0
      protocol_state.blockchain_state.ledger_builder_hash.ledger_hash
  in
  let proof = Lite_compat.proof Precomputed_values.base_proof in
  let chain = {Lite_base.Lite_chain.protocol_state; ledger; proof} in
  [%expr
    Core_kernel.Binable.of_string
      (module Lite_base.Lite_chain)
      (B64.decode
         [%e
           estring
             (B64.encode
                (Binable.to_string (module Lite_base.Lite_chain) chain))])]

open Async

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "lite_params.ml")
  in
  let loc = Ppxlib.Location.none in
  let%map wrap_vk_expr = wrap_vk ~loc in
  let structure =
    [%str
      let pedersen_params = [%e pedersen_params ~loc]

      let wrap_vk = [%e wrap_vk_expr]

      let genesis_chain = [%e genesis ~loc]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
