(** Verify a captured live mesa-mut block against the blockchain SNARK
    verification key built from the mesa runtime config.

    Usage:
      verify_mesa_block.exe <runtime_config.json> <block.binprot> [<ref_vk.json>]

    Diagnostic: does the mesa wrap VK we generate actually verify a real mesa
    block? Builds the VK exactly the way [print_blockchain_snark_vk] does on this
    branch (Genesis_constants.Compiled + make_constraint_constants fork fold),
    reads the captured block, sanity-checks its state hash, then calls
    [Blockchain_snark_state.verify] with both the freshly-built VK and an optional
    reference VK loaded from JSON. *)

open Core_kernel

(* Mirror print_blockchain_snark_vk.ml on this branch: fold the runtime config's
   [proof] overrides (notably the hardfork [fork]) on top of the compiled
   (DUNE_PROFILE-selected) constants. *)
let constraint_constants config_path =
  Format.eprintf "Using constraint constants from runtime config: %s@."
    config_path ;
  let json = Yojson.Safe.from_file config_path in
  match Runtime_config.of_yojson json with
  | Ok { proof = Some proof; _ } ->
      Genesis_ledger_helper.make_constraint_constants
        ~default:Genesis_constants.Compiled.constraint_constants proof
  | Ok _ ->
      Format.eprintf
        "Runtime config has no `proof` section; using compiled constants.@." ;
      Genesis_constants.Compiled.constraint_constants
  | Error e ->
      failwithf "could not parse runtime config %s: %s" config_path e ()

let expected_state_hash = "3NKg9SHnVFCbBRk3YruYUpoU8j9hoKwLfBjJgNAjYxSvsYmKasTh"

let read_block path =
  let bytes = In_channel.read_all path in
  let buf = Bigstring.of_string bytes in
  let pos_ref = ref 0 in
  let block = Mina_block.Stable.V3.bin_read_t buf ~pos_ref in
  Format.eprintf "Read block: consumed %d of %d bytes@." !pos_ref
    (String.length bytes) ;
  block

let () =
  let config_path = Stdlib.Sys.argv.(1) in
  let block_path = Stdlib.Sys.argv.(2) in
  let constraint_constants = constraint_constants config_path in
  let block = read_block block_path in
  let header = Mina_block.Stable.V3.header block in
  let protocol_state = Mina_block.Header.protocol_state header in
  let protocol_state_proof = Mina_block.Header.protocol_state_proof header in
  let hashes = Mina_state.Protocol_state.hashes protocol_state in
  let state_hash = hashes.Mina_base.State_hash.State_hashes.state_hash in
  let state_hash_str = Mina_base.State_hash.to_base58_check state_hash in
  Format.eprintf "Computed state hash: %s@." state_hash_str ;
  Format.eprintf "Expected state hash: %s@." expected_state_hash ;
  if not (String.equal state_hash_str expected_state_hash) then (
    Format.eprintf
      "STATE HASH MISMATCH: binprot read misaligned or wrong block. Aborting.@." ;
    exit 1 ) ;
  Format.eprintf "State hash sanity check PASSED.@." ;
  let key =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Format.eprintf "Generating transaction snark circuit..@." ;
        let module Transaction_snark_instance = Transaction_snark.Make (struct
          let signature_kind = Mina_signature_kind.t_DEPRECATED

          let constraint_constants = constraint_constants

          let proof_level = Genesis_constants.Proof_level.Full
        end) in
        Format.eprintf "Generating blockchain snark circuit..@." ;
        let module Blockchain_snark_instance =
        Blockchain_snark.Blockchain_snark_state.Make (struct
          let constraint_constants = constraint_constants

          let proof_level = Genesis_constants.Proof_level.Full

          let tag = Transaction_snark_instance.tag
        end) in
        Lazy.force Blockchain_snark_instance.Proof.verification_key )
  in
  let vk_json_str =
    Pickles.Verification_key.to_yojson key |> Yojson.Safe.to_string
  in
  Format.eprintf "VK md5 (json): %s@."
    (vk_json_str |> Md5.digest_string |> Md5.to_hex) ;
  let verify_with label vk =
    Format.eprintf "Verifying block with %s VK...@." label ;
    let result =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Blockchain_snark.Blockchain_snark_state.verify
            [ (protocol_state, protocol_state_proof) ]
            ~key:vk )
    in
    match result with
    | Ok () ->
        Format.printf "VERIFY RESULT (%s): Ok (verified=true)@." label
    | Error e ->
        Format.printf "VERIFY RESULT (%s): Error: %s@." label
          (Error.to_string_hum e)
  in
  verify_with "freshly-built" key ;
  ( if Array.length Stdlib.Sys.argv > 3 then
      let ref_vk_path = Stdlib.Sys.argv.(3) in
      Format.eprintf "Loading reference VK from %s@." ref_vk_path ;
      let ref_json = Yojson.Safe.from_file ref_vk_path in
      match Pickles.Verification_key.of_yojson ref_json with
      | Ok ref_vk ->
          verify_with "reference-json" ref_vk
      | Error e ->
          Format.printf "Could not parse reference VK json: %s@." e ) ;
  Format.printf "DONE@."
