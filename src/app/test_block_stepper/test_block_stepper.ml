open Core
open Async
open Signature_lib
open Mina_base

let blockchain_of_breadcrumb breadcrumb =
  let block = Frontier_base.Breadcrumb.block breadcrumb in
  let header = Mina_block.header block in
  Blockchain_snark.Blockchain.create
    ~state:(Mina_block.Header.protocol_state header)
    ~proof:(Mina_block.Header.protocol_state_proof header)

let load_and_initialize_config ~logger ~config_file ~genesis_dir =
  let%bind runtime_config_json =
    Genesis_ledger_helper.load_config_json config_file >>| Or_error.ok_exn
  in
  let runtime_config =
    Runtime_config.of_yojson runtime_config_json
    |> Result.map_error ~f:Error.of_string
    |> Or_error.ok_exn
  in
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Compiled.proof_level in
  Genesis_ledger_helper.init_from_config_file ~genesis_constants
    ~constraint_constants ~logger ~proof_level ~cli_proof_level:None
    ~genesis_dir runtime_config
  >>| Or_error.ok_exn

let generate_event =
  Snark_params.Tick.Field.gen |> Quickcheck.Generator.map ~f:(fun x -> [| x |])

let mk_payment ~signature_kind
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t) ~signer_pk ~nonce
    signer_keypair =
  let fresh_keypair = Keypair.create () in
  let receiver_pk = Public_key.compress fresh_keypair.Keypair.public_key in
  let common =
    { Signed_command_payload.Common.Poly.fee =
        Currency.Fee.of_nanomina_int_exn 1_000_000
    ; fee_payer_pk = signer_pk
    ; nonce
    ; valid_until
    ; memo = Signed_command_memo.empty
    }
  in
  let payload =
    { Signed_command_payload.Poly.common
    ; body =
        Signed_command_payload.Body.Payment
          { receiver_pk; amount = Currency.Amount.of_mina_int_exn 3 }
    }
  in
  let signature =
    Signed_command.sign_payload ~signature_kind
      signer_keypair.Keypair.private_key payload
  in
  { Signed_command.Poly.signer = signer_keypair.public_key; signature; payload }

let mk_zkapp_tx ~constraint_constants keypair nonce =
  let num_acc_updates = 8 in
  let event_elements = 12 in
  let action_elements = 12 in
  let signaturespec : Transaction_snark.For_tests.Signature_transfers_spec.t =
    let fee_payer = None in
    let generated_values =
      let open Base_quickcheck.Generator.Let_syntax in
      let%bind receivers =
        Base_quickcheck.Generator.list_with_length ~length:num_acc_updates
        @@ let%map kp = Keypair.gen in
           (First kp, Currency.Amount.zero)
      in
      let%bind events =
        Quickcheck.Generator.list_with_length event_elements generate_event
      in
      let%map actions =
        Quickcheck.Generator.list_with_length action_elements generate_event
      in
      (receivers, events, actions)
    in
    let receivers, events, actions =
      Quickcheck.random_value
        ~seed:(`Deterministic ("test-apply-" ^ Unsigned.UInt32.to_string nonce))
        generated_values
    in
    let zkapp_account_keypairs = [] in
    let new_zkapp_account = false in
    let snapp_update = Account_update.Update.dummy in
    let call_data = Snark_params.Tick.Field.zero in
    let preconditions = Some Account_update.Preconditions.accept in
    { fee = Currency.Fee.of_mina_int_exn 1
    ; sender = (keypair, nonce)
    ; fee_payer
    ; receivers
    ; amount =
        Currency.Amount.(
          scale
            (of_fee
               constraint_constants
                 .Genesis_constants.Constraint_constants.account_creation_fee )
            num_acc_updates)
        |> Option.value_exn ~here:[%here]
    ; zkapp_account_keypairs
    ; memo = Signed_command_memo.empty
    ; new_zkapp_account
    ; snapp_update
    ; actions
    ; events
    ; transfer_parties_get_actions_events = true
    ; call_data
    ; preconditions
    }
  in
  let receiver_auth = Some Control.Tag.Signature in
  Transaction_snark.For_tests.signature_transfers ?receiver_auth
    ~constraint_constants signaturespec

let generate_txs ~signature_kind ~valid_until ~init_nonce ~n_zkapp_txs
    ~n_payments ~n_blocks ~constraint_constants keypair :
    User_command.Valid.t Sequence.t list =
  let signer_pk = Public_key.compress keypair.Keypair.public_key in
  let generate_for_block block_i =
    Sequence.init (n_payments + n_zkapp_txs) ~f:(fun i ->
        let nonce =
          Mina_numbers.Account_nonce.(
            add init_nonce @@ of_int
            @@ ((block_i * (n_payments + n_zkapp_txs)) + i))
        in
        let command =
          if i < n_payments then
            User_command.Signed_command
              (mk_payment ~signature_kind ~valid_until ~nonce ~signer_pk keypair)
          else Zkapp_command (mk_zkapp_tx ~constraint_constants keypair nonce)
        in
        let (`If_this_is_used_it_should_have_a_comment_justifying_it
              valid_command ) =
          User_command.to_valid_unsafe command
        in
        valid_command )
  in
  List.init n_blocks ~f:generate_for_block

let generate_all_transactions ~(precomputed_values : Precomputed_values.t)
    ~n_blocks ~n_zkapp_txs ~n_payments ~keypair breadcrumb =
  let genesis_ledger =
    Staged_ledger.ledger (Frontier_base.Breadcrumb.staged_ledger breadcrumb)
  in
  let signer_account_id = Account_id.of_public_key keypair.Keypair.public_key in
  let init_nonce =
    Mina_ledger.Ledger.location_of_account genesis_ledger signer_account_id
    |> Option.value_exn ~message:"Sender's account not found in ledger"
    |> Mina_ledger.Ledger.get genesis_ledger
    |> Option.value_exn
         ~message:"Sender's account not found in ledger by location"
    |> Account.nonce
  in
  let genesis_slot =
    Frontier_base.Breadcrumb.protocol_state breadcrumb
    |> Mina_state.Protocol_state.consensus_state
    |> Consensus.Data.Consensus_state.global_slot_since_genesis
  in
  let valid_until =
    Mina_numbers.Global_slot_since_genesis.add genesis_slot
      (Mina_numbers.Global_slot_span.of_int @@ (n_blocks * 10))
  in
  generate_txs ~signature_kind:precomputed_values.signature_kind ~valid_until
    ~init_nonce ~n_payments ~n_zkapp_txs ~n_blocks
    ~constraint_constants:precomputed_values.constraint_constants keypair

let run ~logger ~keypair ~config_file ~num_blocks ~genesis_dir ~state_dir
    ~n_payments ~n_zkapp_txs =
  let%bind precomputed_values =
    load_and_initialize_config ~logger ~config_file ~genesis_dir
  in
  [%log info] "Creating genesis breadcrumb (this involves proving)" ;
  let%bind genesis_breadcrumb =
    Block_stepper.create_genesis_breadcrumb ~logger ~precomputed_values ()
  in
  [%log info] "Genesis breadcrumb created" ;
  let module Keys = Block_stepper.Keys (struct
    let signature_kind = precomputed_values.Precomputed_values.signature_kind

    let constraint_constants = precomputed_values.constraint_constants

    let proof_level = precomputed_values.proof_level
  end) in
  let keys_module = (module Keys : Block_stepper.Keys_S) in
  let%bind blockchain_verification_key =
    Lazy.force Keys.B.Proof.verification_key
  in
  let%bind transaction_verification_key = Lazy.force Keys.T.verification_key in
  let verifier_dir = Filename.concat state_dir "verifier" in
  let%bind verifier =
    Verifier.create ~logger ~commit_id:"" ~blockchain_verification_key
      ~transaction_verification_key ~proof_level:precomputed_values.proof_level
      ~pids:(Child_processes.Termination.create_pid_table ())
      ~conf_dir:(Some verifier_dir)
      ~signature_kind:precomputed_values.signature_kind ()
  in
  let start =
    Block_stepper.start_state_of_genesis genesis_breadcrumb ~keys_module
  in
  [%log info] "Initializing block stepper" ;
  let%bind stepper =
    Block_stepper.create ~precomputed_values ~keypair ~start ~logger ~state_dir
      ()
  in
  [%log info] "Verifying genesis block proof" ;
  let genesis_blockchain = blockchain_of_breadcrumb genesis_breadcrumb in
  let%bind genesis_result =
    Verifier.verify_blockchain_snarks verifier [ genesis_blockchain ]
  in
  ( match genesis_result with
  | Ok (Ok ()) ->
      [%log info] "Genesis block proof verification: PASSED"
  | Ok (Error e) ->
      [%log error] "Genesis block proof verification: FAILED - %s"
        (Error.to_string_hum e) ;
      failwith "Genesis block proof verification failed"
  | Error e ->
      [%log error]
        "Genesis block proof verification: ERROR (verifier issue) - %s"
        (Error.to_string_hum e) ;
      failwith "Genesis block proof verification error" ) ;
  let all_transactions =
    if n_payments > 0 || n_zkapp_txs > 0 then (
      [%log info]
        "Generating transactions: %d payments + %d zkapp txs per block"
        n_payments n_zkapp_txs ;
      generate_all_transactions ~precomputed_values ~n_blocks:num_blocks
        ~n_zkapp_txs ~n_payments ~keypair genesis_breadcrumb )
    else (
      [%log info] "No transactions requested, blocks will be empty" ;
      List.init num_blocks ~f:(fun _ -> Sequence.empty) )
  in
  [%log info] "Generating and verifying %d blocks" num_blocks ;
  let%map _final_stepper =
    Deferred.List.foldi (List.init num_blocks ~f:Fn.id) ~init:stepper
      ~f:(fun i stepper _block_index ->
        let block_num = i + 1 in
        let transactions = List.nth_exn all_transactions i in
        [%log info] "Stepping block %d/%d with %d transactions" block_num
          num_blocks
          (Sequence.length transactions) ;
        let%bind breadcrumb, stepper =
          Block_stepper.step stepper ~transactions
        in
        [%log info] "Block %d produced, verifying proof" block_num ;
        let blockchain = blockchain_of_breadcrumb breadcrumb in
        let%map result =
          Verifier.verify_blockchain_snarks verifier [ blockchain ]
        in
        ( match result with
        | Ok (Ok ()) ->
            [%log info] "Block %d/%d proof verification: PASSED" block_num
              num_blocks
        | Ok (Error e) ->
            [%log error] "Block %d/%d proof verification: FAILED - %s" block_num
              num_blocks (Error.to_string_hum e) ;
            failwithf "Block %d proof verification failed" block_num ()
        | Error e ->
            [%log error]
              "Block %d/%d proof verification: ERROR (verifier issue) - %s"
              block_num num_blocks (Error.to_string_hum e) ;
            failwithf "Block %d proof verification error" block_num () ) ;
        stepper )
  in
  [%log info] "All %d blocks passed proof verification" num_blocks

let command =
  Command.async
    ~summary:
      "Generate blocks using the block stepper and verify each block's SNARK \
       proof"
    (let open Command.Let_syntax in
    let%map_open config_file =
      flag "--config-file" ~doc:"FILE Path to the runtime configuration file"
        (required string)
    and privkey_path = Cli_lib.Flag.privkey_read_path
    and num_blocks =
      flag "--num-blocks"
        ~doc:"NUM Number of blocks to generate and verify (default: 3)"
        (optional_with_default 3 int)
    and state_dir_flag =
      flag "--state-dir"
        ~doc:
          "DIR Directory for all stepper state (verifier, epoch ledger, \
           internal tracing). Created if absent. Defaults to current \
           directory."
        (optional string)
    and genesis_ledger_dir =
      flag "--genesis-ledger-dir"
        ~doc:
          "DIR Directory containing genesis ledger tarballs (default: \
           <state-dir>/genesis)"
        (optional string)
    and n_payments =
      flag "--num-payments"
        ~doc:"NUM Number of payment transactions per block (default: 0)"
        (optional_with_default 0 int)
    and n_zkapp_txs =
      flag "--num-zkapp-txs"
        ~doc:"NUM Number of zkApp transactions per block (default: 0)"
        (optional_with_default 0 int)
    in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let logger = Logger.create ~id:Logger.Logger_id.mina () in
    let%bind state_dir =
      match state_dir_flag with Some dir -> return dir | None -> Sys.getcwd ()
    in
    let genesis_dir =
      match genesis_ledger_dir with
      | Some dir ->
          dir
      | None ->
          Filename.concat state_dir "genesis"
    in
    let%bind () = Unix.mkdir ~p:() state_dir in
    [%log info] "Starting block stepper verification test"
      ~metadata:
        [ ("config_file", `String config_file)
        ; ("num_blocks", `Int num_blocks)
        ] ;
    let log_processor =
      Logger.Processor.pretty ~log_level:Info
        ~config:
          { Interpolator_lib.Interpolator.mode = After
          ; max_interpolation_length = 50
          ; pretty_print = true
          }
    in
    Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
      ~id:Logger.Logger_id.mina ~processor:log_processor
      ~transport:(Logger.Transport.stdout ())
      () ;
    let internal_tracing_directory =
      Filename.concat state_dir "internal-tracing"
    in
    Logger.Consumer_registry.register ~commit_id:"" ~id:Logger.Logger_id.mina
      ~processor:Internal_tracing.For_logger.processor
      ~transport:
        (Internal_tracing.For_logger.json_lines_rotate_transport
           ~directory:internal_tracing_directory () )
      () ;
    let%bind () = Internal_tracing.toggle ~commit_id:"" ~logger `Enabled in
    [%log info] "Loading keypair from %s" privkey_path ;
    let%bind keypair =
      Secrets.Keypair.Terminal_stdin.read_exn ~which:"Mina keypair" privkey_path
    in
    Parallel.init_master () ;
    run ~logger ~keypair ~config_file ~num_blocks ~genesis_dir ~state_dir
      ~n_payments ~n_zkapp_txs)

let () =
  Command.group ~summary:"Block stepper test"
    [ ("run", command)
    ; (Parallel.worker_command_name, Parallel.worker_command)
    ]
  |> Command.run
