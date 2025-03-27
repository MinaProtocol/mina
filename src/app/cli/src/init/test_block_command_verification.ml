open Core_kernel
open Async_kernel

let time_block_command_verification ?(test_log_filename : string option)
    ~(large_precomputed_json_file : string) =
  let logger = Logger.create () in
  let commit_id = Mina_version.commit_id in
  let transport =
    match test_log_filename with
    | None ->
        Logger.Transport.stdout ()
    | Some log_filename ->
        Logger_file_system.evergrowing ~log_filename
  in
  Logger.Consumer_registry.register ~id:Logger.Logger_id.mina
    ~processor:Internal_tracing.For_logger.processor ~commit_id ~transport () ;
  Logger.Consumer_registry.register ~commit_id ~id:"default"
    ~processor:(Logger.Processor.raw ~log_level:Logger.Level.Info ())
    ~transport () ;
  let%bind () =
    Internal_tracing.toggle ~commit_id ~force:true ~logger `Enabled
  in
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  (* TODO: Should be replaced by some to_string method for the signature_kind,
     an inverse of an of_string method that should also be created for the
     signature kind refactor, when the user-facing side of that is figured
     out. *)
  let signature_kind_string =
    match signature_kind with
    | Mina_signature_kind.Mainnet ->
        "mainnet"
    | Mina_signature_kind.Testnet ->
        "testnet"
    | Mina_signature_kind.Other_network string ->
        "other network: " ^ string
  in
  [%log info]
    "Validating block from $json_file with signature kind $signature_kind"
    ~metadata:
      [ ("json_file", `String large_precomputed_json_file)
      ; ("signature_kind", `String signature_kind_string)
      ] ;
  [%log info]
    "If validation fails you may need to compile the test with a different \
     profile" ;
  let precomputed =
    Yojson.Safe.from_string (In_channel.read_all large_precomputed_json_file)
    |> Mina_block.Precomputed.of_yojson |> Result.ok_or_failwith
  in
  let proof_cache_db = Proof_cache_tag.For_tests.create_db () in
  let commands =
    precomputed.staged_ledger_diff
    |> Staged_ledger_diff.write_all_proofs_to_disk ~proof_cache_db
    |> Staged_ledger_diff.commands
  in
  let find_vk _frozen_ledger_hash account_id =
    (let open Option.Let_syntax in
    let%bind account =
      List.find_map precomputed.accounts_accessed ~f:(fun (_idx, acnt) ->
          let acnt_id = Mina_base.Account.identifier acnt in
          if Mina_base.Account_id.equal acnt_id account_id then Some acnt
          else None )
    in
    let%bind zkapp = account.zkapp in
    zkapp.verification_key)
    |> Option.value_map
         ~default:(Or_error.error_string "Zkapp verification key not found")
         ~f:Or_error.return
  in
  let verifiable_commands =
    List.map commands ~f:(fun command ->
        let verifiable_command =
          Mina_base.User_command.to_verifiable ~failed:false ~find_vk
            command.data
          |> Or_error.ok_exn
        in
        { Mina_base.With_status.data = verifiable_command
        ; status = command.status
        } )
  in
  let proof_level = Genesis_constants.Proof_level.Full in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level

    let signature_kind = signature_kind
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let%bind blockchain_verification_key = Lazy.force B.Proof.verification_key in
  let%bind transaction_verification_key = Lazy.force T.verification_key in
  let%bind verifier =
    (* The Proof_level.Full dummy verifier uses the same
       Pickles.Side_loaded.verify function that the Prod verifier does, which is
       what we want to test here. *)
    Verifier.Dummy.create ~logger
      ~proof_level:Genesis_constants.Proof_level.Full
      ~blockchain_verification_key ~transaction_verification_key
      ~pids:(Child_processes.Termination.create_pid_table ())
      ~conf_dir:None ~commit_id ()
  in
  let start = Time_ns.now () in
  let%bind result =
    (* The dummy verifier ignores its logger argument, so we have to set the
       Context_logger here *)
    Context_logger.with_logger (Some logger)
    @@ fun () -> Verifier.Dummy.verify_commands verifier verifiable_commands
  in
  let num_valid =
    List.count (result |> Or_error.ok_exn) ~f:(function
      | `Valid _ ->
          true
      | _ ->
          false )
  in
  [%log info] "Valid commands: $num_valid/$total_commands"
    ~metadata:
      [ ("num_valid", `Int num_valid)
      ; ("total_commands", `Int (List.length verifiable_commands))
      ] ;
  let total_span = Time_ns.(Span.to_string_hum (diff (now ()) start)) in
  [%log info] "Total time: $time" ~metadata:[ ("time", `String total_span) ] ;
  return ()
