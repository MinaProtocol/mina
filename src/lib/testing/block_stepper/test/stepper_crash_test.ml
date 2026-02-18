open Core
open Async
open Signature_lib
open Mina_base

(*
Minimal stepper-only crash reproduction test.

Run like this (needs a clean state directory):

  rm -rf /tmp/stepper_crash_test && \
  DUNE_PROFILE="devnet" dune exec \
    src/lib/testing/block_stepper/test/stepper_crash_test.exe -- \
    run --seed test-seed-1 --state-dir /tmp/stepper_crash_test

Should crash with "unhandled request" almost immediately when using
Check proof level, because extend_blockchain calls
Blockchain_snark.Blockchain_snark_state.check which requires a running
verifier process.
*)

(* ---- Configuration constants ---- *)

let num_genesis_accounts = 10

let bp_balance_mina = "10000000"

let other_balance_mina = "1000"

let payment_amount_mina = 3

(* ---- Account and config generation ---- *)

let generate_keypairs ~seed ~n =
  List.init n ~f:(fun i ->
      Quickcheck.random_value
        ~seed:(`Deterministic (sprintf "%s-keypair-%d" seed i))
        Keypair.gen )

let generate_runtime_config ~seed ~proof_level ~slot_time_ms ~delta ~work_delay
    ~transaction_capacity_log2 =
  let keypairs = generate_keypairs ~seed ~n:num_genesis_accounts in
  let bp_keypair = List.hd_exn keypairs in
  let accounts =
    List.mapi keypairs ~f:(fun i kp ->
        let balance = if i = 0 then bp_balance_mina else other_balance_mina in
        let default = Runtime_config.Accounts.Single.default in
        { default with
          pk =
            Public_key.Compressed.to_base58_check
              (Public_key.compress kp.public_key)
        ; sk = Some (Private_key.to_base58_check kp.private_key)
        ; balance = Currency.Balance.of_mina_string_exn balance
        } )
  in
  let ledger : Runtime_config.Ledger.t =
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = None
    ; s3_data_hash = None
    ; name = None
    ; add_genesis_winner = Some true
    }
  in
  let proof =
    Runtime_config.Proof_keys.make ~level:proof_level
      ~block_window_duration_ms:slot_time_ms ~work_delay
      ~transaction_capacity:(Log_2 transaction_capacity_log2) ()
  in
  let genesis : Runtime_config.Genesis.t =
    { k = Some 4
    ; delta = Some delta
    ; slots_per_epoch = Some 48
    ; slots_per_sub_window = Some 2
    ; grace_period_slots = Some 8
    ; genesis_state_timestamp =
        (let now_unix_ts = Unix.time () |> Float.to_int in
         let delay_minutes = 1 in
         let genesis_unix_ts =
           now_unix_ts - (now_unix_ts mod 60) + (delay_minutes * 60)
         in
         Some
           ( Time.of_span_since_epoch (Time.Span.of_int_sec genesis_unix_ts)
           |> Time.to_string_iso8601_basic ~zone:Time.Zone.utc ) )
    }
  in
  let runtime_config = Runtime_config.make ~ledger ~proof ~genesis () in
  (bp_keypair, keypairs, runtime_config)

(* ---- Config loading ---- *)

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

(* ---- Transaction generation ---- *)

let generate_payments ~seed ~signature_kind ~valid_until ~bp_keypair
    ~payment_fee_nanomina ~nonce_start ~n =
  let bp_pk = Public_key.compress bp_keypair.Keypair.public_key in
  List.init n ~f:(fun i ->
      let receiver_keypair =
        Quickcheck.random_value
          ~seed:
            (`Deterministic (sprintf "%s-receiver-%d" seed (nonce_start + i)))
          Keypair.gen
      in
      let receiver_pk =
        Public_key.compress receiver_keypair.Keypair.public_key
      in
      let nonce = Mina_numbers.Account_nonce.of_int (nonce_start + i) in
      let common =
        { Signed_command_payload.Common.Poly.fee =
            Currency.Fee.of_nanomina_int_exn payment_fee_nanomina
        ; fee_payer_pk = bp_pk
        ; nonce
        ; valid_until
        ; memo = Signed_command_memo.empty
        }
      in
      let payload =
        { Signed_command_payload.Poly.common
        ; body =
            Signed_command_payload.Body.Payment
              { receiver_pk
              ; amount = Currency.Amount.of_mina_int_exn payment_amount_mina
              }
        }
      in
      let signature =
        Signed_command.sign_payload ~signature_kind
          bp_keypair.Keypair.private_key payload
      in
      let cmd : Signed_command.t =
        { Signed_command.Poly.signer = bp_keypair.public_key
        ; signature
        ; payload
        }
      in
      let user_cmd = User_command.Signed_command cmd in
      (* Transactions are constructed correctly from known-good keypairs,
         so to_valid_unsafe is justified here. *)
      let (`If_this_is_used_it_should_have_a_comment_justifying_it valid_cmd) =
        User_command.to_valid_unsafe user_cmd
      in
      valid_cmd )

let generate_event =
  Snark_params.Tick.Field.gen |> Quickcheck.Generator.map ~f:(fun x -> [| x |])

let mk_zkapp_tx ~seed ~constraint_constants ~zkapp_fee_nanomina keypair nonce =
  let num_acc_updates = 8 in
  let event_elements = 10 in
  let action_elements = 10 in
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
        ~seed:
          (`Deterministic
            (sprintf "%s-zkapp-%s" seed (Unsigned.UInt32.to_string nonce)) )
        generated_values
    in
    let zkapp_account_keypairs = [] in
    let new_zkapp_account = false in
    let snapp_update = Account_update.Update.dummy in
    let call_data = Snark_params.Tick.Field.zero in
    let preconditions = Some Account_update.Preconditions.accept in
    { fee = Currency.Fee.of_nanomina_int_exn zkapp_fee_nanomina
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

(* ---- Main test ---- *)

let run ~logger ~seed ~state_dir ~payments_per_batch ~zkapps_per_batch
    ~proof_level ~slot_time_ms ~delta ~work_delay ~transaction_capacity_log2 =
  let open Deferred.Let_syntax in
  (* Phase 1: Generate config *)
  [%log info] "Phase 1: Generating config with seed '%s'" seed ;
  let bp_keypair, _keypairs, runtime_config =
    generate_runtime_config ~seed ~proof_level ~slot_time_ms ~delta ~work_delay
      ~transaction_capacity_log2
  in
  (* Write config to file *)
  let config_file = state_dir ^/ "daemon.json" in
  Yojson.Safe.to_file config_file (Runtime_config.to_yojson runtime_config) ;
  (* Load precomputed values *)
  let genesis_dir = state_dir ^/ "genesis" in
  let%bind () = Unix.mkdir ~p:() genesis_dir in
  let%bind precomputed_values =
    load_and_initialize_config ~logger ~config_file ~genesis_dir
  in
  (* Phase 2: Generate transactions *)
  [%log info] "Phase 2: Generating transactions" ;
  let signature_kind = precomputed_values.Precomputed_values.signature_kind in
  let constraint_constants = precomputed_values.constraint_constants in
  let zkapp_fee_nanomina =
    Currency.Fee.to_nanomina_int
      precomputed_values.genesis_constants.minimum_user_command_fee
  in
  let payment_fee_nanomina = zkapp_fee_nanomina + 1 in
  let valid_until = Mina_numbers.Global_slot_since_genesis.of_int 1000 in
  let nonce_start = 0 in
  let payments =
    generate_payments ~seed ~signature_kind ~valid_until ~bp_keypair
      ~payment_fee_nanomina ~nonce_start ~n:payments_per_batch
  in
  let zkapps =
    List.init zkapps_per_batch ~f:(fun z ->
        let nonce =
          Mina_numbers.Account_nonce.of_int
            (nonce_start + payments_per_batch + z)
        in
        let zkapp_cmd =
          mk_zkapp_tx ~seed ~constraint_constants ~zkapp_fee_nanomina bp_keypair
            nonce
        in
        (* Transactions are constructed from known-good keypairs via
           signature_transfers, so to_valid_unsafe is justified. *)
        let (`If_this_is_used_it_should_have_a_comment_justifying_it valid_cmd)
            =
          User_command.to_valid_unsafe (Zkapp_command zkapp_cmd)
        in
        valid_cmd )
  in
  let transactions = Sequence.of_list (payments @ zkapps) in
  [%log info] "Generated %d payments + %d zkapps" (List.length payments)
    (List.length zkapps) ;
  (* Phase 3: Create stepper and step *)
  [%log info] "Phase 3: Creating stepper from genesis" ;
  let stepper_state_dir = state_dir ^/ "stepper" in
  let%bind () = Unix.mkdir ~p:() stepper_state_dir in
  let module Keys = Block_stepper.Keys (struct
    let signature_kind = precomputed_values.Precomputed_values.signature_kind

    let constraint_constants = precomputed_values.constraint_constants

    let proof_level = precomputed_values.proof_level
  end) in
  let keys_module = (module Keys : Block_stepper.Keys_S) in
  let _bp = Lazy.force Mina_base.Proof.blockchain_dummy in
  let _tp = Lazy.force Mina_base.Proof.transaction_dummy in
  let%bind stepper =
    Block_stepper.create_from_genesis ~precomputed_values ~keypair:bp_keypair
      ~keys_module ~logger ~state_dir:stepper_state_dir ()
    >>| Or_error.ok_exn
  in
  let stepper_genesis_hash =
    State_hash.With_state_hashes.state_hash
      precomputed_values.protocol_state_with_hashes
    |> State_hash.to_base58_check
  in
  [%log info] "Stepper genesis state hash: %s" stepper_genesis_hash ;
  [%log info] "Stepping at slot 1 with %d transactions"
    (Sequence.length transactions) ;
  let bp_pk = Public_key.compress bp_keypair.public_key in
  let slot = Mina_numbers.Global_slot_since_genesis.of_int 1 in
  let scheduled_time =
    precomputed_values.consensus_constants.genesis_state_timestamp
  in
  let%bind result =
    Block_stepper.step_at_slot stepper ~global_slot_since_genesis:slot
      ~block_stake_winner:bp_pk ~transactions ~snark_work_count:0
      ~scheduled_time
  in
  match result with
  | Ok (bc, _stepper, invalid_commands) ->
      let state_hash =
        Frontier_base.Breadcrumb.state_hash bc |> State_hash.to_base58_check
      in
      [%log info] "Step succeeded! State hash: %s" state_hash ;
      if not (List.is_empty invalid_commands) then
        [%log warn] "%d transactions were dropped"
          (List.length invalid_commands) ;
      return ()
  | Error e ->
      [%log error] "Step failed: %s" (Error.to_string_hum e) ;
      failwith "Stepper step_at_slot failed"

(* ---- Command-line interface ---- *)

let command =
  Command.async
    ~summary:
      "Minimal stepper crash test: exercises stepper without a daemon to \
       reproduce the 'unhandled request' crash at Check proof level"
    (let open Command.Let_syntax in
    let%map_open seed =
      flag "--seed" ~doc:"STRING Deterministic seed for reproducible test runs"
        (optional string)
    and state_dir =
      flag "--state-dir" ~doc:"DIR Directory for test state" (optional string)
    and payments_per_batch =
      flag "--payments-per-batch" ~doc:"INT Number of payments (default: 5)"
        (optional_with_default 5 int)
    and zkapps_per_batch =
      flag "--zkapps-per-batch"
        ~doc:"INT Number of zkapp transactions (default: 1)"
        (optional_with_default 1 int)
    and proof_level =
      flag "--proof-level"
        ~doc:"LEVEL Proof level: full, check, or none (default: check)"
        (optional_with_default Runtime_config.Proof_keys.Level.Check
           (Command.Arg_type.create (fun s ->
                match Runtime_config.Proof_keys.Level.of_string s with
                | Ok level ->
                    level
                | Error msg ->
                    failwith msg ) ) )
    and slot_time_ms =
      flag "--slot-time-ms"
        ~doc:"INT Slot time in milliseconds (default: 20000)"
        (optional_with_default 20_000 int)
    and delta =
      flag "--delta" ~doc:"INT Network delay in slots (default: 1)"
        (optional_with_default 1 int)
    and work_delay =
      flag "--work-delay" ~doc:"INT Scan state work delay (default: 1)"
        (optional_with_default 1 int)
    and transaction_capacity_log2 =
      flag "--transaction-capacity-log2"
        ~doc:"INT Log2 of transaction capacity per block (default: 3)"
        (optional_with_default 3 int)
    in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let logger = Logger.create ~id:Logger.Logger_id.mina () in
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
    let seed =
      match seed with
      | Some s ->
          s
      | None ->
          let s =
            sprintf "stepper-crash-%d-%d"
              (Unix.getpid () |> Pid.to_int)
              (Float.to_int (Unix.gettimeofday ()))
          in
          printf "Generated seed: %s\n" s ;
          s
    in
    let state_dir =
      match state_dir with
      | Some d ->
          Core.Unix.mkdir_p ~perm:0o700 d ;
          d
      | None ->
          Filename.temp_dir ~perm:0o700 ~in_dir:"/tmp" "stepper_crash_test" ""
    in
    printf "Seed: %s\nState dir: %s\n" seed state_dir ;
    Parallel.init_master () ;
    run ~logger ~seed ~state_dir ~payments_per_batch ~zkapps_per_batch
      ~proof_level ~slot_time_ms ~delta ~work_delay ~transaction_capacity_log2)

let () =
  Command.group ~summary:"Stepper crash reproduction test"
    [ ("run", command)
    ; (Parallel.worker_command_name, Parallel.worker_command)
    ]
  |> Command.run
