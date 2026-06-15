(** Print the blockchain snark verification key as JSON.

    With no argument, uses the compiled profile's constraint constants (and writes
    the per-profile reference file used for regression testing).

    With a runtime-config path argument, applies that config's [proof] overrides
    (notably the hardfork [fork] constants) on top of the compiled constants — so a
    hardfork verification key (e.g. mesa) can be produced from its runtime config
    without a dedicated build profile:

      print_blockchain_snark_vk.exe <runtime_config.json> > mesa_blockchain_snark_vk.json

    The [fork] field changes the constraint system, hence the verification key. *)

open Core_kernel

(* Compiled constants by default; with a runtime-config argument, fold in its
   [proof] overrides (the fork) the same way the daemon does at startup. *)
let constraint_constants () =
  match Stdlib.Sys.argv with
  | [| _; config_path |] ->
      Format.eprintf "Using constraint constants from runtime config: %s@."
        config_path ;
      let json = Yojson.Safe.from_file config_path in
      ( match Runtime_config.of_yojson json with
      | Ok { proof = Some proof; _ } ->
          Genesis_ledger_helper.make_constraint_constants
            ~default:Genesis_constants.Compiled.constraint_constants proof
      | Ok _ ->
          Format.eprintf
            "Runtime config has no `proof` section; using compiled constants.@." ;
          Genesis_constants.Compiled.constraint_constants
      | Error e ->
          failwithf "could not parse runtime config %s: %s" config_path e () )
  | _ ->
      Format.eprintf "Profile: %s (compiled constraint constants)@."
        Node_config.profile ;
      Genesis_constants.Compiled.constraint_constants

let () =
  let constraint_constants = constraint_constants () in
  Async.Thread_safe.block_on_async_exn (fun () ->
      let () = Format.eprintf "Generating transaction snark circuit..@." in
      let module Transaction_snark_instance = Transaction_snark.Make (struct
        let signature_kind = Mina_signature_kind.t_DEPRECATED

        let constraint_constants = constraint_constants

        let proof_level = Genesis_constants.Proof_level.Full
      end) in
      let () = Format.eprintf "Generating blockchain snark circuit..@." in
      let before = Time.now () in
      let module Blockchain_snark_instance =
      Blockchain_snark.Blockchain_snark_state.Make (struct
        let constraint_constants = constraint_constants

        let proof_level = Genesis_constants.Proof_level.Full

        let tag = Transaction_snark_instance.tag
      end) in
      let after = Time.now () in
      let () =
        Format.eprintf "Generated blockchain snark circuit in %s.@."
          (Time.Span.to_string_hum (Time.diff after before))
      in
      Lazy.force Blockchain_snark_instance.Proof.verification_key )
  |> Pickles.Verification_key.to_yojson |> Yojson.Safe.to_string
  |> Format.print_string
