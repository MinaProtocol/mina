(** Print the transaction snark verification key as JSON.

    This is used to generate reference verification key files for each profile.
    The output file is named based on the current profile (dev, devnet, lightnet,
    mainnet). *)

open Core_kernel

let () =
  Format.eprintf "Profile: %s@." Node_config.profile ;
  Async.Thread_safe.block_on_async_exn (fun () ->
      let () = Format.eprintf "Generating transaction snark circuit..@." in
      let before = Time.now () in
      let module Transaction_snark_instance = Transaction_snark.Make (struct
        let signature_kind = Mina_signature_kind.t_DEPRECATED

        let constraint_constants =
          let (module G) = Genesis_constants.profiled () in
          G.constraint_constants

        let proof_level = Genesis_constants.Proof_level.Full
      end) in
      let after = Time.now () in
      let () =
        Format.eprintf "Generated transaction snark circuit in %s.@."
          (Time.Span.to_string_hum (Time.diff after before))
      in
      Lazy.force Transaction_snark_instance.verification_key )
  |> Pickles.Verification_key.to_yojson |> Yojson.Safe.to_string
  |> Format.print_string
