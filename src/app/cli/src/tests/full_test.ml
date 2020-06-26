[%%import
"/src/config.mlh"]

open Core
open Async
open Coda_base
open Coda_state
open Signature_lib
open Pipe_lib
open O1trace
open Init
open Coda_numbers

let pk_of_sk sk = Public_key.of_private_key_exn sk |> Public_key.compress

let name = "full-test"

[%%if
proof_level = "full"]

let with_snark = true

let with_check = false

[%%elif
proof_level = "check"]

let with_snark = false

let with_check = true

[%%else]

let with_snark = false

let with_check = false

[%%endif]

[%%if
curve_size = 753]

let medium_curves = true

[%%else]

let medium_curves = false

[%%endif]

[%%if
time_offsets = true]

let setup_time_offsets consensus_constants =
  Unix.putenv ~key:"CODA_TIME_OFFSET"
    ~data:
      ( Time.Span.to_int63_seconds_round_down_exn
          (Coda_processes.offset consensus_constants)
      |> Int63.to_int
      |> Option.value_exn ?here:None ?message:None ?error:None
      |> Int.to_string )

[%%else]

let setup_time_offsets _ = ()

[%%endif]

let heartbeat_flag = ref true

[%%inject
"test_full_epoch", test_full_epoch]

let print_heartbeat logger =
  let rec loop () =
    if !heartbeat_flag then (
      Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
        "Heartbeat for CI" ;
      let%bind () = after (Time.Span.of_min 1.) in
      loop () )
    else return ()
  in
  loop ()

let run_test () : unit Deferred.t =
  let logger = Logger.create () in
  let precomputed_values = Lazy.force Precomputed_values.compiled in
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let (module Genesis_ledger) = precomputed_values.genesis_ledger in
  let pids = Child_processes.Termination.create_pid_table () in
  let consensus_constants = precomputed_values.consensus_constants in
  setup_time_offsets consensus_constants ;
  print_heartbeat logger |> don't_wait_for ;
  Parallel.init_master () ;
  File_system.with_temp_dir (Filename.temp_dir_name ^/ "full_test_config")
    ~f:(fun temp_conf_dir ->
      let keypair = Genesis_ledger.largest_account_keypair_exn () in
      let%bind () =
        match Unix.getenv "CODA_TRACING" with
        | Some trace_dir ->
            let%bind () = Async.Unix.mkdir ~p:() trace_dir in
            Coda_tracing.start trace_dir
        | None ->
            Deferred.unit
      in
      let trace_database_initialization typ location =
        Logger.trace logger "Creating %s at %s" ~module_:__MODULE__ ~location
          typ
      in
      let%bind trust_dir = Async.Unix.mkdtemp (temp_conf_dir ^/ "trust_db") in
      let trust_system = Trust_system.create trust_dir in
      trace_database_initialization "trust_system" __LOC__ trust_dir ;
      let%bind receipt_chain_dir_name =
        Async.Unix.mkdtemp (temp_conf_dir ^/ "receipt_chain")
      in
      trace_database_initialization "receipt_chain_database" __LOC__
        receipt_chain_dir_name ;
      let receipt_chain_database =
        Receipt_chain_database.create receipt_chain_dir_name
      in
      let%bind transaction_database_dir =
        Async.Unix.mkdtemp (temp_conf_dir ^/ "transaction_database")
      in
      trace_database_initialization "transaction_database" __LOC__
        receipt_chain_dir_name ;
      let transaction_database =
        Auxiliary_database.Transaction_database.create ~logger
          transaction_database_dir
      in
      let%bind external_transition_database_dir =
        Async.Unix.mkdtemp (temp_conf_dir ^/ "external_transition_database")
      in
      trace_database_initialization "external_transition_database" __LOC__
        external_transition_database_dir ;
      let external_transition_database =
        Auxiliary_database.External_transition_database.create ~logger
          external_transition_database_dir
      in
      let time_controller = Block_time.Controller.(create @@ basic ~logger) in
      let consensus_local_state =
        Consensus.Data.Local_state.create ~genesis_ledger:Genesis_ledger.t
          (Public_key.Compressed.Set.singleton
             (Public_key.compress keypair.public_key))
      in
      let client_port = 8123 in
      let libp2p_port = 8002 in
      let gossip_net_params =
        Gossip_net.Libp2p.Config.
          { timeout= Time.Span.of_sec 3.
          ; logger
          ; initial_peers= []
          ; unsafe_no_trust_ip= true
          ; flood= false
          ; conf_dir= temp_conf_dir
          ; chain_id= "bogus chain id for testing"
          ; addrs_and_ports=
              { external_ip= Unix.Inet_addr.localhost
              ; bind_ip= Unix.Inet_addr.localhost
              ; peer= None
              ; libp2p_port
              ; client_port }
          ; trust_system
          ; keypair= None }
      in
      let net_config =
        Coda_networking.Config.
          { logger
          ; trust_system
          ; time_controller
          ; consensus_local_state
          ; is_seed= true
          ; genesis_ledger_hash=
              Ledger.merkle_root (Lazy.force Genesis_ledger.t)
          ; constraint_constants
          ; log_gossip_heard=
              { snark_pool_diff= false
              ; transaction_pool_diff= false
              ; new_state= false }
          ; creatable_gossip_net=
              Coda_networking.Gossip_net.(
                Any.Creatable ((module Libp2p), Libp2p.create gossip_net_params))
          }
      in
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      let largest_account_keypair =
        Genesis_ledger.largest_account_keypair_exn ()
      in
      let fee = Currency.Fee.of_int in
      let snark_work_fee, transaction_fee =
        if with_snark then (fee 0, fee 0) else (fee 1, fee 2)
      in
      let%bind coda =
        Coda_lib.create
          (Coda_lib.Config.make ~logger ~pids ~trust_system ~net_config
             ~coinbase_receiver:`Producer ~conf_dir:temp_conf_dir
             ~gossip_net_params ~is_seed:true ~disable_telemetry:true
             ~initial_protocol_version:Protocol_version.zero
             ~proposed_protocol_version_opt:None
             ~work_selection_method:
               (module Work_selector.Selection_methods.Sequence)
             ~initial_block_production_keypairs:(Keypair.Set.singleton keypair)
             ~snark_worker_config:
               Coda_lib.Config.Snark_worker_config.
                 { initial_snark_worker_key=
                     Some
                       (Public_key.compress largest_account_keypair.public_key)
                 ; shutdown_on_disconnect= true
                 ; num_threads= None }
             ~snark_pool_disk_location:(temp_conf_dir ^/ "snark_pool")
             ~wallets_disk_location:(temp_conf_dir ^/ "wallets")
             ~persistent_root_location:(temp_conf_dir ^/ "root")
             ~persistent_frontier_location:(temp_conf_dir ^/ "frontier")
             ~time_controller ~receipt_chain_database ~snark_work_fee
             ~consensus_local_state ~transaction_database
             ~external_transition_database ~work_reassignment_wait:420000
             ~precomputed_values ())
      in
      don't_wait_for
        (Strict_pipe.Reader.iter_without_pushback
           (Coda_lib.validated_transitions coda)
           ~f:ignore) ;
      let%bind () = Ivar.read @@ Coda_lib.initialization_finish_signal coda in
      let wait_until_cond ~(f : Coda_lib.t -> bool) ~(timeout_min : Float.t) =
        let rec go () =
          if f coda then return ()
          else
            let%bind () = after (Time.Span.of_sec 10.) in
            go ()
        in
        Deferred.any [after (Time.Span.of_min timeout_min); go ()]
      in
      let balance_change_or_timeout ~initial_receiver_balance receiver_id =
        let cond t =
          match
            Coda_commands.get_balance t receiver_id
            |> Participating_state.active_exn
          with
          | Some b when not (Currency.Balance.equal b initial_receiver_balance)
            ->
              true
          | _ ->
              false
        in
        wait_until_cond ~f:cond ~timeout_min:3.
      in
      let assert_balance account_id amount =
        match
          Coda_commands.get_balance coda account_id
          |> Participating_state.active_exn
        with
        | Some balance ->
            if not (Currency.Balance.equal balance amount) then
              failwithf
                !"Balance in account (%{sexp: Account_id.t}) %{sexp: \
                  Currency.Balance.t} is not asserted balance %{sexp: \
                  Currency.Balance.t}"
                account_id balance amount ()
        | None ->
            failwith
              (sprintf !"Invalid Account: %{sexp: Account_id.t}" account_id)
      in
      Coda_run.setup_local_server coda ;
      let%bind () = Coda_lib.start coda in
      (* Let the system settle *)
      let%bind () = Async.after (Time.Span.of_ms 100.) in
      (* No proof emitted by the parallel scan at the begining *)
      assert (Option.is_none @@ Coda_lib.staged_ledger_ledger_proof coda) ;
      (* Note: This is much less than half of the high balance account so we can test
       *       payment replays being prohibited
      *)
      let send_amount = Currency.Amount.of_int 10 in
      (* Send money to someone *)
      let build_payment ?nonce amount sender_sk receiver_pk fee =
        trace_recurring "build_payment" (fun () ->
            let signer = pk_of_sk sender_sk in
            let memo =
              User_command_memo.create_from_string_exn
                "A memo created in full-test"
            in
            User_command_input.create ?nonce ~signer ~fee ~fee_payer_pk:signer
              ~fee_token:Token_id.default ~memo
              ~valid_until:Coda_numbers.Global_slot.max_value
              ~body:
                (Payment
                   { source_pk= signer
                   ; receiver_pk
                   ; token_id= Token_id.default
                   ; amount })
              ~sign_choice:
                (User_command_input.Sign_choice.Keypair
                   (Keypair.of_private_key_exn sender_sk))
              () )
      in
      let assert_ok x = assert (Or_error.is_ok x) in
      let send_payment (payment : User_command_input.t) =
        Coda_commands.setup_and_submit_user_command coda payment
        |> Participating_state.to_deferred_or_error
        |> Deferred.map ~f:Or_error.join
      in
      let test_sending_payment sender_sk receiver_pk =
        let sender_id =
          Account_id.create (pk_of_sk sender_sk) Token_id.default
        in
        let receiver_id = Account_id.create receiver_pk Token_id.default in
        let payment =
          build_payment send_amount sender_sk receiver_pk transaction_fee
        in
        let prev_sender_balance =
          Option.value_exn
            ( Coda_commands.get_balance coda sender_id
            |> Participating_state.active_exn )
        in
        let prev_receiver_balance =
          Coda_commands.get_balance coda receiver_id
          |> Participating_state.active_exn
          |> Option.value ~default:Currency.Balance.zero
        in
        let%bind p1_res = send_payment payment in
        assert_ok p1_res ;
        let user_cmd, _receipt = p1_res |> Or_error.ok_exn in
        (* Send a similar payment twice on purpose; this second one will be rejected
           because the nonce is wrong *)
        let payment' =
          build_payment
            ~nonce:(User_command.nonce user_cmd)
            send_amount sender_sk receiver_pk transaction_fee
        in
        let%bind p2_res = send_payment payment' in
        assert (Or_error.is_error p2_res) ;
        (* Let the system settle, mine some blocks *)
        let%map () =
          balance_change_or_timeout
            ~initial_receiver_balance:prev_receiver_balance receiver_id
        in
        assert_balance receiver_id
          (Option.value_exn
             (Currency.Balance.( + ) prev_receiver_balance send_amount)) ;
        assert_balance sender_id
          (Option.value_exn
             (Currency.Balance.( - ) prev_sender_balance
                (Option.value_exn
                   (Currency.Amount.add_fee send_amount transaction_fee))))
      in
      let send_payment_update_balance_sheet sender_sk sender_pk receiver_pk
          amount balance_sheet fee =
        let payment = build_payment amount sender_sk receiver_pk fee in
        let new_balance_sheet =
          Map.update balance_sheet sender_pk ~f:(fun v ->
              Option.value_exn
                (Currency.Balance.sub_amount (Option.value_exn v)
                   (Option.value_exn (Currency.Amount.add_fee amount fee))) )
        in
        let new_balance_sheet' =
          Map.update new_balance_sheet receiver_pk ~f:(fun v ->
              Option.value_exn
                (Currency.Balance.add_amount (Option.value_exn v) amount) )
        in
        let%map p_res = send_payment payment in
        assert_ok p_res ; new_balance_sheet'
      in
      let pks accounts =
        List.map accounts ~f:(fun ((keypair : Signature_lib.Keypair.t), _) ->
            Public_key.compress keypair.public_key )
      in
      let send_payments accounts ~txn_count balance_sheet f_amount =
        let pks = pks accounts in
        Deferred.List.foldi (List.take accounts txn_count) ~init:balance_sheet
          ~f:(fun i acc ((keypair : Signature_lib.Keypair.t), _) ->
            let sender_pk = Public_key.compress keypair.public_key in
            let receiver =
              List.random_element_exn
                (List.filter pks ~f:(fun pk -> not (pk = sender_pk)))
            in
            send_payment_update_balance_sheet keypair.private_key sender_pk
              receiver (f_amount i) acc (Currency.Fee.of_int 0) )
      in
      let blockchain_length t =
        Coda_lib.best_protocol_state t
        |> Participating_state.active_exn |> Protocol_state.consensus_state
        |> Consensus.Data.Consensus_state.blockchain_length
      in
      let wait_for_proof_or_timeout timeout_min () =
        let cond t = Option.is_some @@ Coda_lib.staged_ledger_ledger_proof t in
        wait_until_cond ~f:cond ~timeout_min
      in
      let test_multiple_payments accounts ~txn_count timeout_min =
        let balance_sheet =
          Public_key.Compressed.Map.of_alist_exn
            (List.map accounts
               ~f:(fun ((keypair : Signature_lib.Keypair.t), account) ->
                 ( Public_key.compress keypair.public_key
                 , account.Account.Poly.balance ) ))
        in
        let%bind updated_balance_sheet =
          send_payments accounts ~txn_count balance_sheet (fun i ->
              Currency.Amount.of_int ((i + 1) * 10) )
        in
        (*After mining a few blocks and emitting a ledger_proof (by the parallel scan), check if the balances match *)
        let%map () = wait_for_proof_or_timeout timeout_min () in
        assert (Option.is_some @@ Coda_lib.staged_ledger_ledger_proof coda) ;
        Map.fold updated_balance_sheet ~init:() ~f:(fun ~key ~data () ->
            let account_id = Account_id.create key Token_id.default in
            assert_balance account_id data ) ;
        blockchain_length coda
      in
      let test_duplicate_payments (sender_keypair : Signature_lib.Keypair.t)
          (receiver_keypair : Signature_lib.Keypair.t) =
        let%bind () =
          test_sending_payment sender_keypair.private_key
            (Public_key.compress receiver_keypair.public_key)
        in
        test_sending_payment sender_keypair.private_key
          (Public_key.compress receiver_keypair.public_key)
      in
      (*Need some accounts from the genesis ledger to test payment replays and
        sending multiple payments*)
      let receiver_keypair =
        let receiver =
          Genesis_ledger.find_new_account_record_exn
            [largest_account_keypair.public_key]
        in
        Genesis_ledger.keypair_of_account_record_exn receiver
      in
      let sender_keypair =
        let sender =
          Genesis_ledger.find_new_account_record_exn
            [largest_account_keypair.public_key; receiver_keypair.public_key]
        in
        Genesis_ledger.keypair_of_account_record_exn sender
      in
      let other_accounts =
        List.filter (Lazy.force Genesis_ledger.accounts)
          ~f:(fun (_, account) ->
            let reserved_public_keys =
              [ largest_account_keypair.public_key
              ; receiver_keypair.public_key
              ; sender_keypair.public_key ]
            in
            not
              (List.exists reserved_public_keys ~f:(fun pk ->
                   Public_key.equal pk
                     (Public_key.decompress_exn @@ Account.public_key account)
               )) )
        |> List.map ~f:(fun (sk, account) ->
               ( Genesis_ledger.keypair_of_account_record_exn (sk, account)
               , account ) )
      in
      let timeout_mins =
        if (with_snark || with_check) && medium_curves then 90.
        else if with_snark then 15.
        else 7.
      in
      let wait_till_length =
        if medium_curves then Length.of_int 1
        else if test_full_epoch then
          (*Note: wait to produce (2*slots_per_epoch) blocks. This could take a while depending on what k and c are*)
          Length.(to_int consensus_constants.slots_per_epoch * 2 |> of_int)
        else Length.of_int 5
      in
      let%map () =
        if with_snark then
          let accounts = List.take other_accounts 2 in
          let%bind blockchain_length' =
            test_multiple_payments accounts ~txn_count:2 timeout_mins
          in
          (*wait for some blocks after the ledger_proof is emitted*)
          let%map () =
            wait_until_cond
              ~f:(fun t ->
                blockchain_length t
                > Length.add blockchain_length' wait_till_length )
              ~timeout_min:
                ( ( Length.to_int consensus_constants.delta
                  + Length.to_int consensus_constants.c )
                  * ( ( Block_time.Span.to_ms
                          consensus_constants.block_window_duration_ms
                      |> Int64.to_int_exn )
                    * (Length.to_int wait_till_length + 1) )
                  / 1000 / 60
                |> Float.of_int )
          in
          assert (
            blockchain_length coda
            > Length.add blockchain_length' wait_till_length )
        else if with_check then
          let%bind _ =
            test_multiple_payments other_accounts
              ~txn_count:(List.length other_accounts / 2)
              timeout_mins
          in
          test_duplicate_payments sender_keypair receiver_keypair
        else
          let%bind _ =
            test_multiple_payments other_accounts
              ~txn_count:(List.length other_accounts)
              timeout_mins
          in
          test_duplicate_payments sender_keypair receiver_keypair
      in
      heartbeat_flag := false )

let command =
  let open Async in
  Command.async ~summary:"Full coda end-to-end test"
    (Command.Param.return run_test)
