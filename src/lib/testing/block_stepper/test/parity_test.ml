open Core
open Async
open Signature_lib
open Mina_base

(* ---- Configuration constants ---- *)

let num_genesis_accounts = 10

let bp_balance_mina = "10000000"

let other_balance_mina = "1000"

let num_transactions = 5

let payment_amount_mina = 3

let payment_fee_nanomina = 1_000_000

let max_poll_attempts = 60

let poll_interval_sec = 5.0

(* ---- Account and config generation ---- *)

let generate_keypairs ~seed ~n =
  List.init n ~f:(fun i ->
      Quickcheck.random_value
        ~seed:(`Deterministic (sprintf "%s-keypair-%d" seed i))
        Keypair.gen )

let generate_runtime_config ~seed =
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
    Runtime_config.Proof_keys.make ~level:Check ~block_window_duration_ms:20_000
      ()
  in
  let genesis : Runtime_config.Genesis.t =
    { k = Some 4
    ; delta = Some 1
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

(* ---- GraphQL helpers ---- *)

let graphql_query ~rest_port query_string =
  let uri = Uri.of_string (sprintf "http://localhost:%d/graphql" rest_port) in
  let body_str =
    Yojson.Safe.to_string (`Assoc [ ("query", `String query_string) ])
  in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  let%bind _resp, body =
    Cohttp_async.Client.post ~headers
      ~body:(Cohttp_async.Body.of_string body_str)
      uri
  in
  let%map body_str = Cohttp_async.Body.to_string body in
  Yojson.Safe.from_string body_str

let best_chain_query =
  {| { bestChain(maxLength: 100) {
    stateHash
    protocolState {
      consensusState { slotSinceGenesis blockStakeWinner }
      blockchainState { stagedLedgerHash }
    }
    transactions { userCommands { hash } }
  } } |}

(* ---- JSON parsing helpers ---- *)

type block_info =
  { state_hash : string
  ; slot_since_genesis : int
  ; block_stake_winner : string
  ; staged_ledger_hash : string
  ; user_command_hashes : string list
  }

let parse_block_info json =
  let open Yojson.Safe.Util in
  let protocol_state = json |> member "protocolState" in
  let consensus_state = protocol_state |> member "consensusState" in
  let blockchain_state = protocol_state |> member "blockchainState" in
  { state_hash = json |> member "stateHash" |> to_string
  ; slot_since_genesis =
      consensus_state |> member "slotSinceGenesis" |> to_string |> Int.of_string
  ; block_stake_winner =
      consensus_state |> member "blockStakeWinner" |> to_string
  ; staged_ledger_hash =
      blockchain_state |> member "stagedLedgerHash" |> to_string
  ; user_command_hashes =
      (* The daemon's GraphQL resolver (Filtered_external_transition.of_transition)
         builds the commands list using List.fold with cons, which reverses the
         application order from the staged ledger diff. Reverse here to restore
         the original order so the stepper applies them with correct nonces. *)
      json |> member "transactions" |> member "userCommands" |> to_list
      |> List.map ~f:(fun cmd -> cmd |> member "hash" |> to_string)
      |> List.rev
  }

let parse_best_chain response =
  let open Yojson.Safe.Util in
  response |> member "data" |> member "bestChain" |> to_list
  |> List.map ~f:parse_block_info

(* ---- Transaction generation ---- *)

let generate_payments ~seed ~signature_kind ~valid_until ~bp_keypair ~n =
  let bp_pk = Public_key.compress bp_keypair.Keypair.public_key in
  List.init n ~f:(fun i ->
      let receiver_keypair =
        Quickcheck.random_value
          ~seed:(`Deterministic (sprintf "%s-receiver-%d" seed i))
          Keypair.gen
      in
      let receiver_pk =
        Public_key.compress receiver_keypair.Keypair.public_key
      in
      let nonce = Mina_numbers.Account_nonce.of_int i in
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

(* ---- Config loading (shared by daemon setup and stepper) ---- *)

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

(* ---- Transaction submission via GraphQL ---- *)

let send_payment_mutation =
  {| mutation($from: PublicKey!, $to: PublicKey!, $amount: UInt64!, $fee: UInt64!, $nonce: UInt32!) {
    sendPayment(input: { from: $from, to: $to, amount: $amount, fee: $fee, nonce: $nonce }) {
      payment { hash }
    }
  } |}

let graphql_send_payment ~logger ~rest_port ~sender ~receiver ~amount ~fee
    ~nonce =
  let uri = Uri.of_string (sprintf "http://localhost:%d/graphql" rest_port) in
  let variables =
    `Assoc
      [ ("from", `String sender)
      ; ("to", `String receiver)
      ; ("amount", `String amount)
      ; ("fee", `String fee)
      ; ("nonce", `String (string_of_int nonce))
      ]
  in
  let body_str =
    Yojson.Safe.to_string
      (`Assoc
        [ ("query", `String send_payment_mutation); ("variables", variables) ]
        )
  in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  let%bind _resp, body =
    Cohttp_async.Client.post ~headers
      ~body:(Cohttp_async.Body.of_string body_str)
      uri
  in
  let%map body_str = Cohttp_async.Body.to_string body in
  let json = Yojson.Safe.from_string body_str in
  let open Yojson.Safe.Util in
  ( match json |> member "errors" with
  | `Null ->
      ()
  | errors ->
      [%log error] "GraphQL sendPayment error: %s"
        (Yojson.Safe.to_string errors) ;
      failwith "sendPayment failed" ) ;
  json |> member "data" |> member "sendPayment" |> member "payment"
  |> member "hash" |> to_string

(* ---- Poll daemon for transaction inclusion ---- *)

let wait_for_inclusion ~logger ~rest_port ~expected_hashes =
  let expected = String.Set.of_list expected_hashes in
  let rec poll attempts seen_blocks =
    if attempts >= max_poll_attempts then
      Deferred.Or_error.error_string
        "Timed out waiting for transaction inclusion"
    else
      let%bind response = graphql_query ~rest_port best_chain_query in
      let blocks = parse_best_chain response in
      (* Merge new blocks into the accumulated map (keyed by state_hash) *)
      let seen_blocks =
        List.fold blocks ~init:seen_blocks ~f:(fun acc b ->
            Map.set acc ~key:b.state_hash ~data:b )
      in
      (* Check if all expected tx hashes appear somewhere in seen blocks *)
      let included_hashes =
        Map.data seen_blocks
        |> List.concat_map ~f:(fun b -> b.user_command_hashes)
        |> String.Set.of_list
      in
      if Set.is_subset expected ~of_:included_hashes then (
        [%log info] "All %d transactions included in best chain"
          (Set.length expected) ;
        (* Return blocks sorted by slot for replay *)
        let sorted =
          Map.data seen_blocks
          |> List.sort ~compare:(fun a b ->
                 Int.compare a.slot_since_genesis b.slot_since_genesis )
        in
        Deferred.Or_error.return sorted )
      else (
        [%log info] "Waiting for transactions: %d/%d included (attempt %d/%d)"
          (Set.length (Set.inter expected included_hashes))
          (Set.length expected) attempts max_poll_attempts ;
        let%bind () = after (Time.Span.of_sec poll_interval_sec) in
        poll (attempts + 1) seen_blocks )
  in
  poll 0 String.Map.empty

(* ---- Account-level ledger comparison ---- *)

let compare_ledger_accounts ~logger ~label ~stepper_accounts_json
    ~daemon_accounts_json =
  let stepper_len = List.length stepper_accounts_json in
  let daemon_len = List.length daemon_accounts_json in
  [%log info] "%s: stepper %d accounts, daemon %d accounts" label stepper_len
    daemon_len ;
  let common_len = min stepper_len daemon_len in
  let stepper_prefix = List.take stepper_accounts_json common_len in
  let daemon_prefix = List.take daemon_accounts_json common_len in
  let mismatch =
    List.findi (List.zip_exn stepper_prefix daemon_prefix) ~f:(fun _i (s, d) ->
        not (Yojson.Safe.equal s d) )
  in
  match mismatch with
  | Some (i, (stepper_acct, daemon_acct)) ->
      [%log error] "%s: first mismatch at index %d:" label i ;
      [%log error] "  Stepper: %s" (Yojson.Safe.to_string stepper_acct) ;
      [%log error] "  Daemon:  %s" (Yojson.Safe.to_string daemon_acct) ;
      failwithf "%s: account mismatch at index %d" label i ()
  | None ->
      if stepper_len <> daemon_len then (
        [%log error]
          "%s: all %d common accounts match, but lengths differ (stepper=%d, \
           daemon=%d)"
          label common_len stepper_len daemon_len ;
        failwithf "%s: account count mismatch" label () )
      else [%log info] "%s: all %d accounts match" label common_len

(* ---- Main test ---- *)

let run ~logger ~seed ~state_dir =
  let open Deferred.Let_syntax in
  (* Phase 1: Generate config and keys *)
  [%log info] "Phase 1: Generating config with seed '%s'" seed ;
  let bp_keypair, _keypairs, runtime_config = generate_runtime_config ~seed in
  let bp_pk =
    Public_key.Compressed.to_base58_check
      (Public_key.compress bp_keypair.public_key)
  in
  let dirs =
    Mina_automation.Daemon.Config.ConfigDirs.create ~root_path:state_dir ()
  in
  (* Write config to file *)
  let config_file = state_dir ^/ "daemon.json" in
  Yojson.Safe.to_file config_file (Runtime_config.to_yojson runtime_config) ;
  (* Write block producer keypair into a keys/ subdirectory with 0700 perms *)
  let keys_dir = state_dir ^/ "keys" in
  Core.Unix.mkdir_p ~perm:0o700 keys_dir ;
  Core.Unix.chmod keys_dir ~perm:0o700 ;
  let bp_key_path = keys_dir ^/ "bp_key" in
  let%bind () =
    Secrets.Keypair.write_exn bp_keypair ~privkey_path:bp_key_path
      ~password:(lazy (Deferred.return (Bytes.of_string "naughty blue worm")))
  in
  (* Load precomputed values (used for tx generation and stepper) *)
  let genesis_dir = state_dir ^/ "genesis" in
  let%bind () = Unix.mkdir ~p:() genesis_dir in
  let%bind precomputed_values =
    load_and_initialize_config ~logger ~config_file ~genesis_dir
  in
  (* Generate transactions *)
  let signature_kind = precomputed_values.Precomputed_values.signature_kind in
  let valid_until = Mina_numbers.Global_slot_since_genesis.of_int 1000 in
  let transactions =
    generate_payments ~seed ~signature_kind ~valid_until ~bp_keypair
      ~n:num_transactions
  in
  (* Phase 2: Start daemon *)
  [%log info] "Phase 2: Starting daemon" ;
  let daemon_config =
    Mina_automation.Daemon.Config.create ~write_config:false ~dirs
      ~config:
        (Integration_test_lib.Test_config.default
           ~constants:Integration_test_lib.Test_config.default_constants )
      ()
  in
  let%bind () = Mina_automation.Daemon.Config.generate_keys daemon_config in
  let daemon = Mina_automation.Daemon.of_config daemon_config in
  let client_port = daemon_config.client_port in
  let rest_port = daemon_config.rest_port in
  let%bind daemon_process =
    Mina_automation.Daemon.start daemon ~block_producer_key:bp_key_path
      ~config_file
    (* ~run_snark_worker:bp_pk ~snark_worker_fee:"0" *)
  in
  (* Wait for bootstrap, racing against daemon process exit *)
  [%log info] "Waiting for daemon to bootstrap" ;
  let client = Mina_automation.Daemon.Client.create ~port:client_port () in
  let daemon_exited =
    let%map exit_or_signal = Process.wait daemon_process.process in
    let msg =
      match exit_or_signal with
      | Ok () ->
          "Daemon process exited with status 0"
      | Error (`Exit_non_zero code) ->
          sprintf "Daemon process exited with code %d" code
      | Error (`Signal signal) ->
          sprintf "Daemon process killed by signal %s" (Signal.to_string signal)
    in
    Error (Error.of_string msg)
  in
  let bootstrap_poll =
    Mina_automation.Daemon.Client.wait_for_bootstrap client ~client_delay:30.
      ~retry_delay:10. ~retry_attempts:60 ()
  in
  let%bind bootstrap_result = Deferred.any [ daemon_exited; bootstrap_poll ] in
  let%bind daemon_genesis_hash =
    match bootstrap_result with
    | Ok () ->
        [%log info] "Daemon bootstrapped successfully" ;
        (* Query daemon genesis state hash *)
        let%bind daemon_genesis_response =
          graphql_query ~rest_port "{ genesisBlock { stateHash } }"
        in
        let daemon_genesis_hash =
          Yojson.Safe.Util.(
            daemon_genesis_response |> member "data" |> member "genesisBlock"
            |> member "stateHash" |> to_string)
        in
        [%log info] "Daemon genesis state hash: %s" daemon_genesis_hash ;
        return daemon_genesis_hash
    | Error e ->
        [%log error] "Bootstrap failed: %s" (Error.to_string_hum e) ;
        let%bind _ = Mina_automation.Daemon.Process.force_kill daemon_process in
        let%bind daemon_stdout =
          Reader.contents (Process.stdout daemon_process.process)
        in
        let%bind daemon_stderr =
          Reader.contents (Process.stderr daemon_process.process)
        in
        let%bind () =
          Writer.save (state_dir ^/ "daemon_stdout.log") ~contents:daemon_stdout
        in
        let%bind () =
          Writer.save (state_dir ^/ "daemon_stderr.log") ~contents:daemon_stderr
        in
        [%log error] "Daemon stdout saved to %s"
          (state_dir ^/ "daemon_stdout.log") ;
        [%log error] "Daemon stderr saved to %s"
          (state_dir ^/ "daemon_stderr.log") ;
        let mina_log =
          Mina_automation.Daemon.Config.ConfigDirs.mina_log daemon_config.dirs
        in
        let%bind () =
          match%bind Sys.file_exists mina_log with
          | `Yes ->
              let%bind contents = Reader.file_contents mina_log in
              let dest = state_dir ^/ "daemon_mina.log" in
              let%bind () = Writer.save dest ~contents in
              [%log error] "Daemon mina.log saved to %s" dest ;
              return ()
          | _ ->
              [%log error] "No mina.log found at %s" mina_log ;
              return ()
        in
        failwith "Daemon failed to bootstrap"
  in
  (* Import and unlock block producer key *)
  [%log info] "Importing and unlocking block producer key" ;
  let%bind _import_output =
    Mina_automation.Daemon.Executor.run daemon.executor
      ~args:
        [ "accounts"
        ; "import"
        ; "--privkey-path"
        ; bp_key_path
        ; "--rest-server"
        ; string_of_int rest_port
        ]
      ()
  in
  let%bind _unlock_output =
    Mina_automation.Daemon.Executor.run daemon.executor
      ~args:
        [ "accounts"
        ; "unlock"
        ; "--public-key"
        ; bp_pk
        ; "--rest-server"
        ; string_of_int rest_port
        ]
      ()
  in
  (* Submit transactions via GraphQL and collect daemon-returned hashes *)
  [%log info] "Submitting %d transactions" num_transactions ;
  let%bind tx_hashes =
    Deferred.List.mapi transactions ~f:(fun i cmd ->
        let payload =
          match User_command.forget_check cmd with
          | Signed_command sc ->
              sc.payload
          | Zkapp_command _ ->
              failwith "unexpected zkapp command"
        in
        let receiver_pk, amount =
          match payload.body with
          | Payment { receiver_pk; amount } ->
              ( Public_key.Compressed.to_base58_check receiver_pk
              , Int.to_string (Currency.Amount.to_nanomina_int amount) )
          | _ ->
              failwith "unexpected command body"
        in
        let fee =
          Int.to_string (Currency.Fee.to_nanomina_int payload.common.fee)
        in
        let nonce = Mina_numbers.Account_nonce.to_int payload.common.nonce in
        let%map hash =
          graphql_send_payment ~logger ~rest_port ~sender:bp_pk
            ~receiver:receiver_pk ~amount ~fee ~nonce
        in
        [%log info] "Submitted transaction %d/%d (nonce=%d, hash=%s)" (i + 1)
          num_transactions nonce hash ;
        hash )
  in
  (* Wait for inclusion *)
  [%log info] "Waiting for transactions to be included in best chain" ;
  let%bind daemon_blocks_result =
    wait_for_inclusion ~logger ~rest_port ~expected_hashes:tx_hashes
  in
  let daemon_blocks =
    match daemon_blocks_result with
    | Ok blocks ->
        blocks
    | Error e ->
        [%log error] "Failed waiting for inclusion: %s" (Error.to_string_hum e) ;
        failwith "Transaction inclusion timeout"
  in
  let daemon_final_hash = (List.last_exn daemon_blocks).staged_ledger_hash in
  [%log info] "Daemon final staged ledger hash: %s" daemon_final_hash ;
  (* Export daemon staged ledger for account-level comparison *)
  [%log info] "Exporting daemon staged ledger" ;
  let%bind daemon_ledger_json =
    Mina_automation.Daemon.Executor.run daemon.executor
      ~args:
        [ "ledger"
        ; "export"
        ; "staged-ledger"
        ; "--daemon-port"
        ; string_of_int client_port
        ]
      ()
  in
  let daemon_accounts_json =
    Yojson.Safe.from_string daemon_ledger_json |> Yojson.Safe.Util.to_list
  in
  [%log info] "Daemon ledger: %d accounts" (List.length daemon_accounts_json) ;
  (* Stop daemon *)
  [%log info] "Stopping daemon" ;
  let%bind () = Mina_automation.Daemon.Client.stop_daemon client in
  let%bind () = after (Time.Span.of_sec 5.0) in
  let%bind _ = Mina_automation.Daemon.Process.force_kill daemon_process in
  (* Phase 3: Stepper replay *)
  [%log info] "Phase 3: Replaying blocks through stepper" ;
  let stepper_state_dir = daemon_config.dirs.root_path ^/ "stepper" in
  let%bind () = Unix.mkdir ~p:() stepper_state_dir in
  let module Keys = Block_stepper.Keys (struct
    let signature_kind = precomputed_values.Precomputed_values.signature_kind

    let constraint_constants = precomputed_values.constraint_constants

    let proof_level = precomputed_values.proof_level
  end) in
  let keys_module = (module Keys : Block_stepper.Keys_S) in
  [%log info] "Initializing block stepper from genesis" ;
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
  if not (String.equal daemon_genesis_hash stepper_genesis_hash) then (
    [%log error] "Genesis state hash mismatch! Daemon=%s Stepper=%s"
      daemon_genesis_hash stepper_genesis_hash ;
    failwith "Genesis state hash mismatch" ) ;
  [%log info] "Genesis state hashes match" ;
  (* Build a hash-to-transaction lookup *)
  let tx_by_hash =
    List.map2_exn transactions tx_hashes ~f:(fun cmd hash -> (hash, cmd))
    |> String.Map.of_alist_exn
  in
  (* Skip genesis block (first in bestChain list), replay the rest *)
  let non_genesis_blocks =
    match daemon_blocks with
    | [] ->
        failwith "no blocks in best chain"
    | _ :: rest ->
        rest
  in
  [%log info] "Replaying %d non-genesis blocks" (List.length non_genesis_blocks) ;
  let%bind final_result =
    Deferred.List.fold non_genesis_blocks
      ~init:(Ok (stepper, None))
      ~f:(fun acc block ->
        match acc with
        | Error e ->
            return (Error e)
        | Ok (stepper, _) ->
            let slot =
              Mina_numbers.Global_slot_since_genesis.of_int
                block.slot_since_genesis
            in
            let block_stake_winner =
              Public_key.Compressed.of_base58_check_exn block.block_stake_winner
            in
            let block_txns =
              List.filter_map block.user_command_hashes ~f:(fun h ->
                  String.Map.find tx_by_hash h )
              |> Sequence.of_list
            in
            [%log info] "Stepping at slot %d with %d transactions"
              block.slot_since_genesis
              (Sequence.length block_txns) ;
            let%map result =
              Block_stepper.step_at_slot stepper ~global_slot_since_genesis:slot
                ~block_stake_winner ~transactions:block_txns
            in
            Result.map result ~f:(fun (bc, stepper, invalid_commands) ->
                if not (List.is_empty invalid_commands) then (
                  List.iter invalid_commands ~f:(fun (cmd, err) ->
                      [%log error] "Dropped transaction: %s (error: %s)"
                        ( User_command.Valid.to_yojson cmd
                        |> Yojson.Safe.to_string )
                        (Error.to_string_hum err) ) ;
                  failwithf "Slot %d: %d transactions were dropped"
                    block.slot_since_genesis
                    (List.length invalid_commands)
                    () ) ;
                (stepper, Some bc) ) )
  in
  let final_breadcrumb =
    match final_result with
    | Ok (_, Some bc) ->
        bc
    | Ok (_, None) ->
        failwith "no blocks replayed"
    | Error e ->
        [%log error] "Stepper replay failed: %s" (Error.to_string_hum e) ;
        failwith "Stepper replay failed"
  in
  (* Phase 4: Compare ledger hashes *)
  [%log info] "Phase 4: Comparing ledger hashes" ;
  let stepper_ledger_hash =
    Frontier_base.Breadcrumb.staged_ledger final_breadcrumb
    |> Staged_ledger.ledger |> Mina_ledger.Ledger.merkle_root
    |> Ledger_hash.to_base58_check
  in
  [%log info] "Stepper ledger hash: %s" stepper_ledger_hash ;
  [%log info] "Daemon ledger hash:  %s" daemon_final_hash ;
  if String.equal daemon_final_hash stepper_ledger_hash then (
    [%log info] "PASS: Ledger hashes match!" ;
    return () )
  else (
    [%log error] "FAIL: Ledger hash mismatch!" ;
    [%log error] "  Daemon:  %s" daemon_final_hash ;
    [%log error] "  Stepper: %s" stepper_ledger_hash ;
    List.iter daemon_blocks ~f:(fun b ->
        [%log error] "  Slot %d: %d user commands, staged_ledger_hash=%s"
          b.slot_since_genesis
          (List.length b.user_command_hashes)
          b.staged_ledger_hash ) ;
    let stepper_accounts_json =
      Frontier_base.Breadcrumb.staged_ledger final_breadcrumb
      |> Staged_ledger.ledger |> Mina_ledger.Ledger.to_list_sequential
      |> List.map ~f:(fun acct ->
             Genesis_ledger_helper.Accounts.Single.of_account acct None
             |> Runtime_config.Accounts.Single.to_yojson )
    in
    compare_ledger_accounts ~logger ~label:"Final ledger" ~stepper_accounts_json
      ~daemon_accounts_json ;
    failwith "Ledger hash mismatch" )

(* ---- Command-line interface ---- *)

let command =
  Command.async
    ~summary:
      "Parity test: run daemon and stepper on same config, compare ledger \
       hashes"
    (let open Command.Let_syntax in
    let%map_open seed =
      flag "--seed"
        ~doc:
          "STRING Deterministic seed for reproducible test runs. If omitted, a \
           random seed is generated and printed."
        (optional string)
    and state_dir =
      flag "--state-dir"
        ~doc:
          "DIR Directory for all test state (default: \
           /tmp/parity_test_<timestamp>)"
        (optional string)
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
            sprintf "parity-%d-%d"
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
          Filename.temp_dir ~perm:0o700 ~in_dir:"/tmp" "parity_test" ""
    in
    printf "Seed: %s\nState dir: %s\n" seed state_dir ;
    Parallel.init_master () ;
    run ~logger ~seed ~state_dir)

let () =
  Command.group ~summary:"Block stepper parity test"
    [ ("run", command)
    ; (Parallel.worker_command_name, Parallel.worker_command)
    ]
  |> Command.run
