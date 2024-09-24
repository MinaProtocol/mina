open Core_kernel

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let config_file = Sys.getenv_opt "MINA_CONFIG_FILE" in
      let open Async.Deferred.Let_syntax in
      let%bind { constraint_constants; _ } =
        let logger = Logger.create () in
        Runtime_config.load_constants ~logger (Option.to_list config_file)
      in
      let () = Format.eprintf "Generating transaction snark circuit..@." in
      let module Transaction_snark_instance = Transaction_snark.Make (struct
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
