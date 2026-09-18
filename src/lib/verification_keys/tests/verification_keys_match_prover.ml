(** Checks that the committed verification keys are the keys a prover would hand
    out.

    Until recently the daemon got these keys by asking its prover subprocess for
    them, which is why every node ran one. Reading them from a file instead is
    only safe while the two agree, and nothing else in the build compares them:
    the file is generated from the same circuits, so a bug shared by both would
    go unnoticed. This starts a real prover and asks it, which costs around ten
    minutes of key generation and is why it runs nightly rather than per commit. *)

open Core
open Async

let compare_key ~name ~from_file ~from_prover =
  let render vk =
    Pickles.Verification_key.to_yojson vk |> Yojson.Safe.to_string
  in
  let from_file = render from_file and from_prover = render from_prover in
  if String.equal from_file from_prover then (
    printf "%s verification key matches the prover\n%!" name ;
    true )
  else (
    eprintf
      "%s verification key does not match the prover.\n\
       file:   %s\n\
       prover: %s\n\
       %!"
      name from_file from_prover ;
    false )

let main ~config_file ~keys_file () =
  (* Starting a prover means spawning this binary again as an rpc_parallel
     worker, which needs both the master server and the worker subcommand. *)
  Parallel.init_master () ;
  let logger = Logger.create () in
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let proof_level = Genesis_constants.Proof_level.Full in
  let%bind constraint_constants =
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
  let%bind from_file =
    match
      Verification_keys.of_file ~signature_kind ~constraint_constants keys_file
    with
    | Ok keys ->
        return keys
    | Error err ->
        (* Reached while the committed file is stale, which is a normal step of
           a `dune promote` cycle, so say what is wrong rather than raising a
           backtrace over it. *)
        eprintf "Cannot read %s: %s\n%!" keys_file (Error.to_string_hum err) ;
        exit 1
  in
  printf "Starting a prover; generating its keys takes several minutes\n%!" ;
  let%bind prover =
    Prover.create ~commit_id:"verification_keys_match_prover" ~logger
      ~proof_level ~constraint_constants
      ~pids:(Child_processes.Termination.create_pid_table ())
      ~conf_dir:(Filename_unix.temp_dir "verification_keys_match_prover" "")
      ~signature_kind ()
  in
  let%bind blockchain =
    Prover.get_blockchain_verification_key prover >>| Or_error.ok_exn
  in
  let%bind transaction =
    Prover.get_transaction_verification_key prover >>| Or_error.ok_exn
  in
  let ok =
    List.for_all ~f:Fn.id
      [ compare_key ~name:"blockchain" ~from_file:from_file.blockchain
          ~from_prover:blockchain
      ; compare_key ~name:"transaction" ~from_file:from_file.transaction
          ~from_prover:transaction
      ]
  in
  exit (if ok then 0 else 1)

let check_command =
  Command.async
    ~summary:
      "Check that a committed verification key file matches what a prover \
       hands out"
    (let%map_open.Command config_file =
       flag "--config-file" ~aliases:[ "config-file" ] (required string)
         ~doc:"PATH Runtime config the keys were generated for"
     and keys_file =
       flag "--keys-file" ~aliases:[ "keys-file" ] (required string)
         ~doc:"PATH The committed key file to check"
     in
     main ~config_file ~keys_file )

let () =
  Command_unix.run
    (Command.group ~summary:"Verification key checks"
       [ ("check", check_command)
       ; (Parallel.worker_command_name, Parallel.worker_command)
       ] )
