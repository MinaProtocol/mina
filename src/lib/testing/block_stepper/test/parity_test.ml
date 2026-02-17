open Core
open Async
open Signature_lib
open Mina_base

(*
Currently I'm running the test like this:

DUNE_PROFILE="devnet" dune exec src/lib/testing/block_stepper/test/parity_test.exe -- run --seed test-seed-1 --state-dir /tmp/parity_test_run --num-batches 3 --payments-per-batch 5 --zkapps-per-batch 1 2>&1

but remember that the test needs a clean state directory.

Test needs to be run on devnet to have access to all the proof levels, and also
because the zkapp generator hard-codes the Testnet signature kind.

The test can be run with --proof-level full, but it takes quite a while and is
decently resource-intensive. Run it with a higher --slot-time-ms too, otherwise
the daemon's block proving competes with the snark worker's snark work proving
for resources far too much. (Slot time is irrelevant for the stepper, because
it's not tied to wall clock time at all). The example above with --proof-level
full still completes on my laptop with --slot-time-ms 90000 (90s).

Note that the transaction capacity and work delay are directly related to how
many transactions can be included in a block, the time until which snark work
starts gets demanded in the blocks, and the steady-state total snark work
demanded by blocks. (With a transaction capacity of 2^3, you get 15 works max
needed - actual work needed varies a bit).
*)

(* ---- Configuration constants ---- *)

let num_genesis_accounts = 10

let bp_balance_mina = "10000000"

let other_balance_mina = "1000"

let payment_amount_mina = 3

let max_poll_attempts = 60

let poll_interval_sec = 5.0

let graphql_timeout = Time.Span.of_sec 5.0

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

(* ---- GraphQL helpers ---- *)

let graphql_query ~rest_port query_string =
  let uri = Uri.of_string (sprintf "http://localhost:%d/graphql" rest_port) in
  let body_str =
    Yojson.Safe.to_string (`Assoc [ ("query", `String query_string) ])
  in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  match%bind
    Clock.with_timeout graphql_timeout
      (Monitor.try_with ~here:[%here] (fun () ->
           let%bind _resp, body =
             Cohttp_async.Client.post ~headers
               ~body:(Cohttp_async.Body.of_string body_str)
               uri
           in
           Cohttp_async.Body.to_string body ) )
  with
  | `Result (Ok body_str) ->
      return (Ok (Yojson.Safe.from_string body_str))
  | `Result (Error exn) ->
      return (Or_error.error_string (Exn.to_string exn))
  | `Timeout ->
      return
        (Or_error.errorf "GraphQL query timed out after %s"
           (Time.Span.to_short_string graphql_timeout) )

let best_chain_query =
  {| { bestChain(maxLength: 100) {
    stateHash
    protocolState {
      consensusState { slotSinceGenesis blockStakeWinner }
      blockchainState { stagedLedgerHash date }
    }
    transactions {
      userCommands { hash from to amount fee nonce validUntil memo }
      zkappCommands { hash }
    }
  } } |}

(* ---- JSON parsing helpers ---- *)

type daemon_command_info =
  { cmd_hash : string
  ; cmd_from : string
  ; cmd_to : string
  ; cmd_amount : string
  ; cmd_fee : string
  ; cmd_nonce : string
  ; cmd_valid_until : string
  ; cmd_memo : string
  }

type block_info =
  { state_hash : string
  ; slot_since_genesis : int
  ; block_stake_winner : string
  ; staged_ledger_hash : string
  ; timestamp : string
  ; user_commands : daemon_command_info list
  ; zkapp_command_hashes : string list
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
  ; timestamp = blockchain_state |> member "date" |> to_string
  ; user_commands =
      (* The daemon's GraphQL resolver (Filtered_external_transition.of_transition)
         builds the commands list using List.fold with cons, which reverses the
         application order from the staged ledger diff. Reverse here to restore
         the original order so the stepper applies them with correct nonces. *)
      json |> member "transactions" |> member "userCommands" |> to_list
      |> List.map ~f:(fun cmd ->
             { cmd_hash = cmd |> member "hash" |> to_string
             ; cmd_from = cmd |> member "from" |> to_string
             ; cmd_to = cmd |> member "to" |> to_string
             ; cmd_amount = cmd |> member "amount" |> to_string
             ; cmd_fee = cmd |> member "fee" |> to_string
             ; cmd_nonce = cmd |> member "nonce" |> to_int |> Int.to_string
             ; cmd_valid_until = cmd |> member "validUntil" |> to_string
             ; cmd_memo = cmd |> member "memo" |> to_string
             } )
      |> List.rev
  ; zkapp_command_hashes =
      json |> member "transactions" |> member "zkappCommands" |> to_list
      |> List.map ~f:(fun cmd -> cmd |> member "hash" |> to_string)
  }

let parse_best_chain response =
  let open Yojson.Safe.Util in
  match response |> member "data" |> member "bestChain" with
  | `Null ->
      []
  | json ->
      json |> to_list |> List.map ~f:parse_block_info

(* ---- Chain monitor ---- *)

(* TODO: both ivars and the mutable state handling here are not good *)
type chain_monitor =
  { blocks : block_info String.Map.t ref
  ; stop_ivar : unit Ivar.t
  ; fatal_error : Error.t Ivar.t
  ; mutable waiters : ((block_info list -> bool) * block_info list Ivar.t) list
  ; rest_port : int
  ; poll_interval : Time.Span.t
  ; logger : Logger.t
  }

let chain_monitor_sorted_blocks map =
  Map.data map
  |> List.sort ~compare:(fun a b ->
         Int.compare a.slot_since_genesis b.slot_since_genesis )

let create_chain_monitor ~logger ~rest_port ~poll_interval =
  { blocks = ref String.Map.empty
  ; stop_ivar = Ivar.create ()
  ; fatal_error = Ivar.create ()
  ; waiters = []
  ; rest_port
  ; poll_interval
  ; logger
  }

let start_chain_monitor monitor =
  don't_wait_for
    (let logger = monitor.logger in
     let rec loop () =
       if Ivar.is_full monitor.stop_ivar then return ()
       else
         let%bind () =
           match%bind
             graphql_query ~rest_port:monitor.rest_port best_chain_query
           with
           | Error err when not (Map.is_empty !(monitor.blocks)) ->
               (* Daemon was previously responsive but now failing *)
               [%log error]
                 "Chain monitor: query failed after daemon was responsive: %s"
                 (Error.to_string_hum err) ;
               Ivar.fill_if_empty monitor.stop_ivar () ;
               Ivar.fill_if_empty monitor.fatal_error err ;
               return ()
           | Error _err ->
               (* daemon not ready yet, silently retry *)
               return ()
           | Ok response ->
               let new_blocks = parse_best_chain response in
               let old_map = !(monitor.blocks) in
               let new_map =
                 List.fold new_blocks ~init:old_map ~f:(fun acc b ->
                     Map.set acc ~key:b.state_hash ~data:b )
               in
               let new_count = Map.length new_map - Map.length old_map in
               if new_count > 0 then
                 [%log info]
                   "Chain monitor: discovered %d new block(s) (%d total)"
                   new_count (Map.length new_map) ;
               monitor.blocks := new_map ;
               let sorted = chain_monitor_sorted_blocks new_map in
               monitor.waiters <-
                 List.filter monitor.waiters ~f:(fun (pred, ivar) ->
                     if pred sorted then (
                       Ivar.fill_if_empty ivar sorted ;
                       false )
                     else true ) ;
               return ()
         in
         let%bind () =
           Deferred.any_unit
             [ after monitor.poll_interval; Ivar.read monitor.stop_ivar ]
         in
         loop ()
     in
     loop () )

let stop_chain_monitor monitor = Ivar.fill_if_empty monitor.stop_ivar ()

let chain_monitor_wait_until monitor pred =
  let sorted = chain_monitor_sorted_blocks !(monitor.blocks) in
  if pred sorted then return (Ok sorted)
  else
    let ivar = Ivar.create () in
    (* TODO: need synchronization *)
    monitor.waiters <- (pred, ivar) :: monitor.waiters ;
    Deferred.any
      [ (Ivar.read ivar >>| fun blocks -> Ok blocks)
      ; (Ivar.read monitor.fatal_error >>| fun err -> Error err)
      ]

let chain_monitor_blocks monitor = chain_monitor_sorted_blocks !(monitor.blocks)

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
  (* TODO: source actions/events from the limits in the precomuted values too *)
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
  {| mutation($from: PublicKey!, $to: PublicKey!, $amount: UInt64!, $fee: UInt64!, $nonce: UInt32!, $validUntil: UInt32, $memo: String) {
    sendPayment(input: { from: $from, to: $to, amount: $amount, fee: $fee, nonce: $nonce, validUntil: $validUntil, memo: $memo }) {
      payment { hash }
    }
  } |}

let graphql_send_payment ~logger ~rest_port ~sender ~receiver ~amount ~fee
    ~nonce ~valid_until ~memo =
  let uri = Uri.of_string (sprintf "http://localhost:%d/graphql" rest_port) in
  let variables =
    `Assoc
      [ ("from", `String sender)
      ; ("to", `String receiver)
      ; ("amount", `String amount)
      ; ("fee", `String fee)
      ; ("nonce", `String (string_of_int nonce))
      ; ("validUntil", `String valid_until)
      ; ("memo", `String memo)
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
  match%bind
    Clock.with_timeout graphql_timeout
      (Monitor.try_with ~here:[%here] (fun () ->
           let%bind _resp, body =
             Cohttp_async.Client.post ~headers
               ~body:(Cohttp_async.Body.of_string body_str)
               uri
           in
           Cohttp_async.Body.to_string body ) )
  with
  | `Result (Ok body_str) -> (
      let json = Yojson.Safe.from_string body_str in
      let open Yojson.Safe.Util in
      match json |> member "errors" with
      | `Null ->
          return
            (Ok
               ( json |> member "data" |> member "sendPayment"
               |> member "payment" |> member "hash" |> to_string ) )
      | errors ->
          [%log error] "GraphQL sendPayment error: %s"
            (Yojson.Safe.to_string errors) ;
          return (Or_error.error_string "sendPayment failed") )
  | `Result (Error exn) ->
      return (Or_error.error_string (Exn.to_string exn))
  | `Timeout ->
      return
        (Or_error.errorf "GraphQL sendPayment timed out after %s"
           (Time.Span.to_short_string graphql_timeout) )

let send_zkapp_mutation =
  {| mutation($input: SendZkappInput!) {
    sendZkapp(input: $input) {
      zkapp { hash }
    }
  } |}

let graphql_send_zkapp ~logger ~rest_port zkapp_cmd =
  let uri = Uri.of_string (sprintf "http://localhost:%d/graphql" rest_port) in
  let zkapp_json =
    Zkapp_command.read_all_proofs_from_disk zkapp_cmd |> Zkapp_command.to_json
  in
  let variables =
    `Assoc [ ("input", `Assoc [ ("zkappCommand", zkapp_json) ]) ]
  in
  let body_str =
    Yojson.Safe.to_string
      (`Assoc
        [ ("query", `String send_zkapp_mutation); ("variables", variables) ] )
  in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  match%bind
    Clock.with_timeout graphql_timeout
      (Monitor.try_with ~here:[%here] (fun () ->
           let%bind _resp, body =
             Cohttp_async.Client.post ~headers
               ~body:(Cohttp_async.Body.of_string body_str)
               uri
           in
           Cohttp_async.Body.to_string body ) )
  with
  | `Result (Ok body_str) -> (
      let json = Yojson.Safe.from_string body_str in
      let open Yojson.Safe.Util in
      match json |> member "errors" with
      | `Null ->
          return
            (Ok
               ( json |> member "data" |> member "sendZkapp" |> member "zkapp"
               |> member "hash" |> to_string ) )
      | errors ->
          [%log error] "GraphQL sendZkapp error: %s"
            (Yojson.Safe.to_string errors) ;
          return (Or_error.error_string "sendZkapp failed") )
  | `Result (Error exn) ->
      return (Or_error.error_string (Exn.to_string exn))
  | `Timeout ->
      return
        (Or_error.errorf "GraphQL sendZkapp timed out after %s"
           (Time.Span.to_short_string graphql_timeout) )

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

(* ---- Transition extraction helpers ---- *)

let extract_daemon_transitions ~logger ~best_tip_log ~output_file =
  if Stdlib.Sys.file_exists best_tip_log then (
    let lines = In_channel.read_lines best_tip_log in
    let all_transitions =
      List.concat_map lines ~f:(fun line ->
          let json =
            try Yojson.Safe.from_string line
            with exn ->
              [%log error] "Failed to parse best-tip log line: %s" line ;
              failwithf "Best-tip log JSON parse error: %s" (Exn.to_string exn)
                ()
          in
          let open Yojson.Safe.Util in
          try json |> member "metadata" |> member "added_transitions" |> to_list
          with exn ->
            [%log error]
              "Failed to extract added_transitions from best-tip log line: %s"
              line ;
            failwithf "Best-tip log added_transitions extraction error: %s"
              (Exn.to_string exn) () )
    in
    [%log info] "Extracted %d added_transitions from daemon best-tip log"
      (List.length all_transitions) ;
    Out_channel.write_all output_file
      ~data:
        (String.concat ~sep:"\n"
           (List.map all_transitions ~f:Yojson.Safe.to_string) ) ;
    [%log info] "Wrote daemon transitions to %s" output_file )
  else [%log warn] "No best-tip log found at %s" best_tip_log

let breadcrumb_to_transition_json bc =
  let protocol_state =
    Frontier_base.Breadcrumb.protocol_state bc
    |> Mina_state.Protocol_state.value_to_yojson
  in
  let state_hash =
    Frontier_base.Breadcrumb.state_hash bc |> State_hash.to_yojson
  in
  let just_emitted_a_proof = Frontier_base.Breadcrumb.just_emitted_a_proof bc in
  `Assoc
    [ ("protocol_state", protocol_state)
    ; ("state_hash", state_hash)
    ; ("just_emitted_a_proof", `Bool just_emitted_a_proof)
    ]

(* ---- Main test ---- *)

let run ~logger ~seed ~state_dir ~num_batches ~payments_per_batch
    ~zkapps_per_batch ~proof_level ~slot_time_ms ~delta ~work_delay
    ~transaction_capacity_log2 =
  let open Deferred.Let_syntax in
  (* Phase 1: Generate config and keys *)
  [%log info] "Phase 1: Generating config with seed '%s'" seed ;
  let bp_keypair, _keypairs, runtime_config =
    generate_runtime_config ~seed ~proof_level ~slot_time_ms ~delta ~work_delay
      ~transaction_capacity_log2
  in
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
  let constraint_constants = precomputed_values.constraint_constants in
  (* Zkapp fees are set to the minimum_user_command_fee. Payment fees are
     1 nanomina higher so the daemon's fee-ordered staged ledger diff always
     places payments before zkapps. This lets us reconstruct correct
     transaction ordering without precise ordering information from the
     daemon's GraphQL API. *)
  let zkapp_fee_nanomina =
    Currency.Fee.to_nanomina_int
      precomputed_values.genesis_constants.minimum_user_command_fee
  in
  let payment_fee_nanomina = zkapp_fee_nanomina + 1 in
  let valid_until = Mina_numbers.Global_slot_since_genesis.of_int 1000 in
  let batches =
    List.init num_batches ~f:(fun b ->
        let nonce_start = b * (payments_per_batch + zkapps_per_batch) in
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
                mk_zkapp_tx ~seed ~constraint_constants ~zkapp_fee_nanomina
                  bp_keypair nonce
              in
              let zkapp_valid =
                (* Transactions are constructed from known-good keypairs via
                   signature_transfers, so to_valid_unsafe is justified. *)
                let (`If_this_is_used_it_should_have_a_comment_justifying_it
                      valid_cmd ) =
                  User_command.to_valid_unsafe (Zkapp_command zkapp_cmd)
                in
                valid_cmd
              in
              let zkapp_hash =
                Mina_transaction.Transaction_hash.hash_zkapp_command_with_hashes
                  zkapp_cmd
                |> Mina_transaction.Transaction_hash.to_base58_check
              in
              (zkapp_cmd, zkapp_valid, zkapp_hash) )
        in
        (payments, zkapps) )
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
      ~config_file ~run_snark_worker:bp_pk ~snark_worker_fee:"0"
  in
  (* Drain daemon stdout/stderr to files in the background to prevent pipe
     buffer deadlock. The daemon's logger uses synchronous writes to stdout;
     if the pipe fills up the entire Async scheduler blocks. *)
  let stdout_log_path = state_dir ^/ "daemon_stdout.log" in
  let stderr_log_path = state_dir ^/ "daemon_stderr.log" in
  let%bind stdout_writer = Writer.open_file stdout_log_path in
  let%bind stderr_writer = Writer.open_file stderr_log_path in
  don't_wait_for
    (Pipe.iter_without_pushback
       (Reader.pipe
          (Process.stdout daemon_process.Mina_automation.Daemon.Process.process) )
       ~f:(fun s -> Writer.write stdout_writer s) ) ;
  don't_wait_for
    (Pipe.iter_without_pushback
       (Reader.pipe
          (Process.stderr daemon_process.Mina_automation.Daemon.Process.process) )
       ~f:(fun s -> Writer.write stderr_writer s) ) ;
  let monitor =
    create_chain_monitor ~logger ~rest_port
      ~poll_interval:(Time.Span.of_sec poll_interval_sec)
  in
  start_chain_monitor monitor ;
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
          >>| Or_error.ok_exn
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
  (* Submit transactions in batches, waiting for each batch to be included *)
  let total_txns = num_batches * (payments_per_batch + zkapps_per_batch) in
  [%log info]
    "Submitting %d transactions in %d batch(es) (%d payments + %d zkapps each)"
    total_txns num_batches payments_per_batch zkapps_per_batch ;
  let%bind batches_with_hashes =
    Deferred.List.foldi batches ~init:[] ~f:(fun b acc (payments, zkapps) ->
        [%log info] "Batch %d/%d: submitting %d payments + %d zkapps" (b + 1)
          num_batches (List.length payments) (List.length zkapps) ;
        (* Submit payments *)
        let%bind payment_hashes =
          Deferred.List.mapi payments ~f:(fun i cmd ->
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
              let nonce =
                Mina_numbers.Account_nonce.to_int payload.common.nonce
              in
              let valid_until =
                Mina_numbers.Global_slot_since_genesis.to_string
                  payload.common.valid_until
              in
              let memo =
                Signed_command_memo.to_string_hum payload.common.memo
              in
              let%map hash =
                graphql_send_payment ~logger ~rest_port ~sender:bp_pk
                  ~receiver:receiver_pk ~amount ~fee ~nonce ~valid_until ~memo
                >>| Or_error.ok_exn
              in
              [%log info] "  Submitted payment %d/%d (nonce=%d, hash=%s)"
                (i + 1) (List.length payments) nonce hash ;
              hash )
        in
        (* Submit zkapps *)
        let%bind zkapp_hashes =
          Deferred.List.mapi zkapps ~f:(fun i (zkapp_cmd, _valid, local_hash) ->
              let%map daemon_hash =
                graphql_send_zkapp ~logger ~rest_port zkapp_cmd
                >>| Or_error.ok_exn
              in
              if not (String.equal daemon_hash local_hash) then
                failwithf "Zkapp hash mismatch: daemon=%s local=%s" daemon_hash
                  local_hash () ;
              [%log info] "  Submitted zkapp %d/%d (hash=%s)" (i + 1)
                (List.length zkapps) local_hash ;
              local_hash )
        in
        (* Wait for this batch to be included, with progress-based timeout *)
        let batch_hashes = String.Set.of_list (payment_hashes @ zkapp_hashes) in
        let total = Set.length batch_hashes in
        [%log info] "Waiting for batch %d/%d (%d txns) to be included" (b + 1)
          num_batches total ;
        let inclusion_timeout =
          Time.Span.of_sec (Float.of_int max_poll_attempts *. poll_interval_sec)
        in
        let rec wait_for_inclusion ~remaining =
          let inclusion_pred blocks =
            let included =
              List.concat_map blocks ~f:(fun b ->
                  List.map b.user_commands ~f:(fun c -> c.cmd_hash)
                  @ b.zkapp_command_hashes )
              |> String.Set.of_list
            in
            let still_remaining = Set.diff remaining included in
            Set.length still_remaining < Set.length remaining
          in
          match%bind
            Clock.with_timeout inclusion_timeout
              (chain_monitor_wait_until monitor inclusion_pred)
          with
          | `Result (Ok blocks) ->
              let included =
                List.concat_map blocks ~f:(fun b ->
                    List.map b.user_commands ~f:(fun c -> c.cmd_hash)
                    @ b.zkapp_command_hashes )
                |> String.Set.of_list
              in
              let still_remaining = Set.diff remaining included in
              if Set.is_empty still_remaining then (
                [%log info] "Batch %d/%d: all %d transactions included" (b + 1)
                  num_batches total ;
                return blocks )
              else (
                [%log info]
                  "Batch %d/%d: %d/%d transactions included so far, waiting \
                   for %d more"
                  (b + 1) num_batches
                  (total - Set.length still_remaining)
                  total
                  (Set.length still_remaining) ;
                wait_for_inclusion ~remaining:still_remaining )
          | `Result (Error err) ->
              stop_chain_monitor monitor ;
              [%log error] "Chain monitor failed while waiting for batch %d: %s"
                (b + 1) (Error.to_string_hum err) ;
              let%bind _ =
                Mina_automation.Daemon.Process.force_kill daemon_process
              in
              failwithf "Chain monitor failed while waiting for batch %d: %s"
                (b + 1) (Error.to_string_hum err) ()
          | `Timeout ->
              stop_chain_monitor monitor ;
              let included_so_far = total - Set.length remaining in
              [%log error]
                "Timed out waiting for batch %d transaction inclusion (%d/%d \
                 included)"
                (b + 1) included_so_far total ;
              let%bind _ =
                Mina_automation.Daemon.Process.force_kill daemon_process
              in
              failwithf
                "Timed out waiting for batch %d transaction inclusion (%d/%d \
                 included)"
                (b + 1) included_so_far total ()
        in
        let%bind _daemon_blocks = wait_for_inclusion ~remaining:batch_hashes in
        return ((payment_hashes, payments, zkapps) :: acc) )
  in
  let batches_with_hashes = List.rev batches_with_hashes in
  stop_chain_monitor monitor ;
  let daemon_blocks = chain_monitor_blocks monitor in
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
  (* Stop daemon and save its stdout/stderr *)
  [%log info] "Stopping daemon" ;
  let%bind () = Mina_automation.Daemon.Client.stop_daemon client in
  let%bind () = after (Time.Span.of_sec 5.0) in
  let%bind _ = Mina_automation.Daemon.Process.force_kill daemon_process in
  (* Extract daemon transitions from best-tip log *)
  let best_tip_log = daemon_config.dirs.conf ^/ "mina-best-tip.log" in
  extract_daemon_transitions ~logger ~best_tip_log
    ~output_file:(state_dir ^/ "daemon_transitions.jsonl") ;
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
    let entries =
      List.concat_map batches_with_hashes
        ~f:(fun (payment_hashes, payments, zkapps) ->
          let payment_entries =
            List.map2_exn payments payment_hashes ~f:(fun cmd hash ->
                (hash, cmd) )
          in
          let zkapp_entries =
            List.map zkapps ~f:(fun (_cmd, valid, hash) -> (hash, valid))
          in
          payment_entries @ zkapp_entries )
    in
    String.Map.of_alist_exn entries
  in
  (* Verify daemon commands match locally-generated transactions *)
  let all_daemon_commands =
    List.concat_map daemon_blocks ~f:(fun b -> b.user_commands)
  in
  List.iter all_daemon_commands ~f:(fun dc ->
      match String.Map.find tx_by_hash dc.cmd_hash with
      | None ->
          ()
      | Some local_cmd ->
          let payload =
            match User_command.forget_check local_cmd with
            | Signed_command sc ->
                sc.payload
            | Zkapp_command _ ->
                failwith "unexpected zkapp command"
          in
          let local_from =
            Public_key.Compressed.to_base58_check payload.common.fee_payer_pk
          in
          let local_fee =
            Currency.Fee.to_nanomina_int payload.common.fee |> Int.to_string
          in
          let local_nonce =
            Mina_numbers.Account_nonce.to_int payload.common.nonce
            |> Int.to_string
          in
          let local_valid_until =
            Mina_numbers.Global_slot_since_genesis.to_string
              payload.common.valid_until
          in
          let local_memo =
            Signed_command_memo.to_base58_check payload.common.memo
          in
          let local_to, local_amount =
            match payload.body with
            | Payment { receiver_pk; amount } ->
                ( Public_key.Compressed.to_base58_check receiver_pk
                , Currency.Amount.to_nanomina_int amount |> Int.to_string )
            | _ ->
                failwith "unexpected command body"
          in
          let mismatches = ref [] in
          let check field_name daemon_val local_val =
            if not (String.equal daemon_val local_val) then
              mismatches :=
                sprintf "  %s: daemon=%s stepper=%s" field_name daemon_val
                  local_val
                :: !mismatches
          in
          check "from" dc.cmd_from local_from ;
          check "to" dc.cmd_to local_to ;
          check "amount" dc.cmd_amount local_amount ;
          check "fee" dc.cmd_fee local_fee ;
          check "nonce" dc.cmd_nonce local_nonce ;
          check "valid_until" dc.cmd_valid_until local_valid_until ;
          check "memo" dc.cmd_memo local_memo ;
          if not (List.is_empty !mismatches) then (
            [%log error] "Transaction payload mismatch for hash %s:\n%s"
              dc.cmd_hash
              (String.concat ~sep:"\n" (List.rev !mismatches)) ;
            failwithf "Transaction payload mismatch for hash %s" dc.cmd_hash ()
            ) ) ;
  [%log info] "All daemon transaction payloads match local transactions" ;
  (* Verify zkapp commands from daemon *)
  let all_daemon_zkapp_hashes =
    List.concat_map daemon_blocks ~f:(fun b -> b.zkapp_command_hashes)
  in
  List.iter all_daemon_zkapp_hashes ~f:(fun h ->
      if not (String.Map.mem tx_by_hash h) then
        [%log warn] "Unknown zkapp command hash from daemon: %s" h ) ;
  let all_submitted_zkapp_hashes =
    List.concat_map batches_with_hashes
      ~f:(fun (_payment_hashes, _payments, zkapps) ->
        List.map zkapps ~f:(fun (_cmd, _valid, hash) -> hash) )
  in
  List.iter all_submitted_zkapp_hashes ~f:(fun zkapp_hash ->
      if not (List.mem all_daemon_zkapp_hashes zkapp_hash ~equal:String.equal)
      then
        failwithf "Submitted zkapp hash %s not found in daemon blocks"
          zkapp_hash () ) ;
  [%log info] "All %d zkapp command hash(es) verified in daemon blocks"
    (List.length all_submitted_zkapp_hashes) ;
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
      ~init:(Ok (stepper, None, []))
      ~f:(fun acc block ->
        match acc with
        | Error e ->
            return (Error e)
        | Ok (stepper, _, stepper_transitions_acc) ->
            let slot =
              Mina_numbers.Global_slot_since_genesis.of_int
                block.slot_since_genesis
            in
            let block_stake_winner =
              Public_key.Compressed.of_base58_check_exn block.block_stake_winner
            in
            (* Transactions are ordered: user commands first, then zkapp commands.
               This works because zkapp fees (900_000 nanomina) are intentionally
               lower than payment fees (1_000_000 nanomina), so the daemon's
               fee-ordered staged ledger diff always places payments before zkapps.
               TODO: Get precise transaction ordering from the daemon to remove
               this fee-based ordering assumption. *)
            let block_txns =
              let payment_txns =
                List.filter_map block.user_commands ~f:(fun c ->
                    String.Map.find tx_by_hash c.cmd_hash )
              in
              let zkapp_txns =
                List.filter_map block.zkapp_command_hashes ~f:(fun h ->
                    String.Map.find tx_by_hash h )
              in
              Sequence.of_list (payment_txns @ zkapp_txns)
            in
            let scheduled_time =
              Block_time.of_span_since_epoch
                (Block_time.Span.of_ms (Int64.of_string block.timestamp))
            in
            [%log info] "Stepping at slot %d with %d transactions"
              block.slot_since_genesis
              (Sequence.length block_txns) ;
            let%map result =
              Block_stepper.step_at_slot stepper ~global_slot_since_genesis:slot
                ~block_stake_winner ~transactions:block_txns ~scheduled_time
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
                let transition_json = breadcrumb_to_transition_json bc in
                (stepper, Some bc, transition_json :: stepper_transitions_acc) )
        )
  in
  let final_breadcrumb, stepper_transitions =
    match final_result with
    | Ok (_, Some bc, transitions) ->
        (bc, List.rev transitions)
    | Ok (_, None, _) ->
        failwith "no blocks replayed"
    | Error e ->
        [%log error] "Stepper replay failed: %s" (Error.to_string_hum e) ;
        failwith "Stepper replay failed"
  in
  (* Write stepper transitions *)
  let stepper_transitions_file = state_dir ^/ "stepper_transitions.jsonl" in
  Out_channel.write_all stepper_transitions_file
    ~data:
      (String.concat ~sep:"\n"
         (List.map stepper_transitions ~f:Yojson.Safe.to_string) ) ;
  [%log info] "Wrote %d stepper transitions to %s"
    (List.length stepper_transitions)
    stepper_transitions_file ;
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
        [%log error]
          "  Slot %d: %d user commands, %d zkapp commands, \
           staged_ledger_hash=%s"
          b.slot_since_genesis
          (List.length b.user_commands)
          (List.length b.zkapp_command_hashes)
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
    and num_batches =
      flag "--num-batches" ~doc:"INT Number of transaction batches (default: 1)"
        (optional_with_default 1 int)
    and payments_per_batch =
      flag "--payments-per-batch"
        ~doc:"INT Number of payments per batch (default: 5)"
        (optional_with_default 5 int)
    and zkapps_per_batch =
      flag "--zkapps-per-batch"
        ~doc:"INT Number of zkapp transactions per batch (default: 1)"
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
        ~doc:
          "INT Slot time / block window duration in milliseconds (default: \
           20000)"
        (optional_with_default 20_000 int)
    and delta =
      flag "--delta"
        ~doc:"INT Max permissible network delay in slots (default: 1)"
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
    run ~logger ~seed ~state_dir ~num_batches ~payments_per_batch
      ~zkapps_per_batch ~proof_level ~slot_time_ms ~delta ~work_delay
      ~transaction_capacity_log2)

let () =
  Command.group ~summary:"Block stepper parity test"
    [ ("run", command)
    ; (Parallel.worker_command_name, Parallel.worker_command)
    ]
  |> Command.run
