(** Print the blockchain snark verification key as JSON.

    This is used to generate reference verification key files for each profile.
    The output file is named based on the current profile (dev, devnet, lightnet,
    mainnet). *)

open Core_kernel

let () =
  Format.eprintf "Profile: %s@." Node_config.profile ;
  let (module G) = Genesis_constants.profiled () in
  Async.Thread_safe.block_on_async_exn (fun () ->
      let () = Format.eprintf "Generating transaction snark circuit..@." in
      let module Transaction_snark_instance = Transaction_snark.Make (struct
        let signature_kind = Mina_signature_kind.t_DEPRECATED

        let constraint_constants = G.constraint_constants

        let proof_level = Genesis_constants.Proof_level.Full
      end) in
      let () = Format.eprintf "Generating blockchain snark circuit..@." in
      let before = Time.now () in
      let module Blockchain_snark_instance =
      Blockchain_snark.Blockchain_snark_state.Make (struct
        let constraint_constants = G.constraint_constants

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
