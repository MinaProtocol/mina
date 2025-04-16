open Core_kernel
open Async_kernel

let time_block_command_verification ~(large_precomputed_json_file : string)
    ~(log_directory : string) =
  printf "Reading block from %s\n" large_precomputed_json_file ;
  let json =
    Yojson.Safe.from_string (In_channel.read_all large_precomputed_json_file)
  in
  let precomputed =
    match Mina_block.Precomputed.of_yojson json with
    | Ok json ->
        json
    | Error err ->
        failwith err
  in
  let logger = Logger.create () in
  let commit_id = "<commit>" in
  Logger.Consumer_registry.register ~id:Logger.Logger_id.mina
    ~processor:Internal_tracing.For_logger.processor ~commit_id
    ~transport:
      (Logger_file_system.dumb_logrotate ~directory:log_directory
         ~log_filename:"internal-tracing.log"
         ~max_size:(1024 * 1024 * 10)
         ~num_rotate:50 )
    () ;
  let%bind () =
    Internal_tracing.toggle ~commit_id ~force:true ~logger `Enabled
  in
  let commands =
    precomputed.staged_ledger_diff |> Staged_ledger_diff.commands
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
        ( 0 (* this id is irrelevant to verify_commands *)
        , { Mina_base.With_status.data = verifiable_command
          ; status = command.status
          } ) )
  in
  let proof_level = Genesis_constants.Proof_level.Full in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let%bind blockchain_verification_key = Lazy.force B.Proof.verification_key in
  let%bind transaction_verification_key = Lazy.force T.verification_key in
  let%bind verifier =
    Verifier.Prod.Worker_state.create
      { conf_dir = None
      ; enable_internal_tracing = false
      ; internal_trace_filename = None
      ; logger
      ; commit_id
      ; blockchain_verification_key
      ; transaction_verification_key
      ; proof_level
      }
  in
  let start = Time_ns.now () in
  let%bind result =
    Verifier.Prod.Worker_state.verify_commands verifier verifiable_commands
  in
  let num_valid =
    List.count result ~f:(function _, `Valid -> true | _ -> false)
  in
  printf "Valid commands: %d/%d\n" num_valid (List.length verifiable_commands) ;
  printf "Time: %s\n" Time_ns.(Span.to_string_hum (diff (Time_ns.now ()) start)) ;
  return ()
