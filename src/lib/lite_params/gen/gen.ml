[%%import
"../../../config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Core

[%%if
proof_level = "full"]

let key_generation = true

[%%else]

let key_generation = false

[%%endif]

module Lite_compat = Lite_compat.Make (Consensus.Blockchain_state)

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
          (Base64.encode_string
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
          (Base64.decode_exn s) )
      [%e arr_expr]]

let wrap_vk ~loc =
  let open Async in
  let%bind keys = Snark_keys.blockchain_verification () in
  let vk = keys.wrap in
  let vk = Lite_compat.verification_key vk in
  let vk_base64 =
    Base64.encode_string
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
      (Base64.decode_exn [%e estring vk_base64])]

let protocol_state (s : Consensus.Protocol_state.value) :
    Lite_base.Protocol_state.t =
  let open Consensus in
  let consensus_state =
    (* hack a stub for proof of stake right now so builds still work *)
    Protocol_state.consensus_state s
    |> Option.value Consensus_state.to_lite ~default:(fun _ ->
           let open Lite_base.Consensus_state in
           { length= Int32.of_int_exn 0
           ; signer_public_key=
               Lite_compat.public_key
                 Signature_lib.(
                   Public_key.compress @@ Public_key.of_private_key_exn
                   @@ Private_key.create ()) } )
  in
  { Lite_base.Protocol_state.previous_state_hash=
      Lite_compat.digest
        ( Protocol_state.previous_state_hash s
          :> Snark_params.Tick.Pedersen.Digest.t )
  ; body=
      { blockchain_state=
          Lite_compat.blockchain_state
            (Consensus.Protocol_state.blockchain_state s)
      ; consensus_state } }

let genesis ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let protocol_state = protocol_state Consensus.genesis_protocol_state.data in
  let ledger =
    Sparse_ledger_lib.Sparse_ledger.of_hash ~depth:0
      protocol_state.body.blockchain_state.staged_ledger_hash.ledger_hash
  in
  let proof = Lite_compat.proof Precomputed_values.base_proof in
  let chain = {Lite_base.Lite_chain.protocol_state; ledger; proof} in
  [%expr
    Core_kernel.Binable.of_string
      (module Lite_base.Lite_chain)
      (Base64.decode_exn
         [%e
           estring
             (Base64.encode_string
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
