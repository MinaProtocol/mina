(** Writes the verification keys a daemon needs into a single file.

    The keys depend on the constraint constants, which a runtime config can
    change -- most importantly through its fork constants, which every live
    network sets. So the config is an input here, not an afterthought: the file
    this produces is only valid for the config it was generated from, and it
    records the constants it used so that a daemon can check. *)

open Core
open Async

let main ~config_file ~output_file () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let%bind constraint_constants =
    match config_file with
    | None ->
        return Genesis_constants.Compiled.constraint_constants
    | Some config_file ->
        let%map contents = Reader.file_contents config_file in
        let config =
          Yojson.Safe.from_string contents
          |> Runtime_config.of_yojson
          |> Result.map_error ~f:Error.of_string
          |> Or_error.ok_exn
        in
        Option.value_map config.proof
          ~default:Genesis_constants.Compiled.constraint_constants
          ~f:
            (Genesis_ledger_helper_lib.make_constraint_constants
               ~default:Genesis_constants.Compiled.constraint_constants )
  in
  eprintf
    !"Generating verification keys for profile %s (signature kind %s)\n%!"
    Node_config.profile
    (Mina_signature_kind.to_directory_name signature_kind) ;
  let%map () =
    Verification_keys.compute_and_save ~signature_kind ~constraint_constants
      ~proof_level:Genesis_constants.Proof_level.Full output_file
  in
  eprintf !"Wrote %s\n%!" output_file

let () =
  Command_unix.run
    (Command.async
       ~summary:
         "Generate the verification key file that ships alongside a runtime \
          config"
       (let%map_open.Command config_file =
          flag "--config-file" ~aliases:[ "config-file" ] (optional string)
            ~doc:
              "PATH Runtime config whose constraint constants the keys are \
               generated for (default: the compiled-in constants)"
        and output_file =
          flag "--output-file" ~aliases:[ "output-file" ] (required string)
            ~doc:"PATH Where to write the keys"
        in
        main ~config_file ~output_file ) )
