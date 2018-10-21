[%%import
"../../../config.mlh"]

open Core
open Async_kernel
open Coda_base
open Coda_main
open Signature_lib

let pk_of_sk sk = Public_key.of_private_key_exn sk |> Public_key.compress

[%%if
with_snark]

let with_snark = true

[%%else]

let with_snark = false

[%%endif]

let run_test (module Kernel : Kernel_intf) : unit Deferred.t =
  Parallel.init_master () ;
  let log = Logger.create () in
  let%bind temp_conf_dir =
    Async.Unix.mkdtemp (Filename.temp_dir_name ^/ "full_test_config")
  in
  let keypair = Genesis_ledger.largest_account_keypair_exn () in
  let module Config = struct
    let logger = log

    let conf_dir = temp_conf_dir

    let lbc_tree_max_depth = `Finite 50

    let keypair = keypair

    let genesis_proof = Precomputed_values.base_proof

    let transaction_capacity_log_2 = 3

    let commit_id = None
  end in
  let should_propose_bool = true in
  let%bind (module Init) =
    make_init ~should_propose:should_propose_bool
      (module Config)
      (module Kernel)
  in
  let module Main = Coda_main.Make_coda (Init) in
  let module Run = Run (Config) (Main) in
  let open Main in
  let banlist_dir_name = temp_conf_dir ^/ "banlist" in
  let%bind () = Async.Unix.mkdir banlist_dir_name in
  let%bind suspicious_dir =
    Async.Unix.mkdtemp (banlist_dir_name ^/ "suspicious")
  in
  let%bind punished_dir = Async.Unix.mkdtemp (banlist_dir_name ^/ "banned") in
  let banlist = Coda_base.Banlist.create ~suspicious_dir ~punished_dir in
  let net_config =
    { Inputs.Net.Config.parent_log= log
    ; gossip_net_params=
        { Inputs.Net.Gossip_net.Config.timeout= Time.Span.of_sec 1.
        ; parent_log= log
        ; target_peer_count= 8
        ; initial_peers= []
        ; conf_dir= temp_conf_dir
        ; me= (Host_and_port.of_string "127.0.0.1:8001", 8000)
        ; banlist } }
  in
  let%bind coda =
    Main.create
      (Main.Config.make ~log ~net_config ~should_propose:should_propose_bool
         ~run_snark_worker:with_snark
         ~ledger_builder_persistant_location:(temp_conf_dir ^/ "ledger_builder")
         ~transaction_pool_disk_location:(temp_conf_dir ^/ "transaction_pool")
         ~snark_pool_disk_location:(temp_conf_dir ^/ "snark_pool")
         ~time_controller:(Inputs.Time.Controller.create ())
         ~keypair () ~banlist)
  in
  don't_wait_for (Linear_pipe.drain (Main.strongest_ledgers coda)) ;
  let balance_change_or_timeout ~initial_receiver_balance receiver_pk =
    let rec go () =
      match Run.get_balance coda receiver_pk with
      | Some b when not (Currency.Balance.equal b initial_receiver_balance) ->
          return ()
      | _ ->
          let%bind () = after (Time_ns.Span.of_sec 10.) in
          go ()
    in
    Deferred.any [after (Time_ns.Span.of_min 3.); go ()]
  in
  let assert_balance pk amount =
    match Run.get_balance coda pk with
    | Some balance ->
        if not (Currency.Balance.equal balance amount) then
          failwithf
            !"Balance in account %{sexp: Currency.Balance.t} is not asserted \
              balance %{sexp: Currency.Balance.t}"
            balance amount ()
    | None ->
        failwith
          (sprintf !"Invalid Account: %{sexp: Public_key.Compressed.t}" pk)
  in
  let client_port = 8123 in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  let run_snark_worker =
    `With_public_key (Public_key.compress largest_account_keypair.public_key)
  in
  Run.setup_local_server ~client_port ~coda ~log () ;
  Run.run_snark_worker ~log ~client_port run_snark_worker ;
  (* Let the system settle *)
  let%bind () = Async.after (Time.Span.of_ms 100.) in
  (* Check if high balance account has expected balance *)
  (* Note: This is much less than half of the high balance account so we can test
   *       transaction replays being prohibited
   *)
  let send_amount = Currency.Amount.of_int 10 in
  let receiver =
    Genesis_ledger.find_new_account_record_exn
      [largest_account_keypair.public_key]
  in
  let receiver_keypair =
    Genesis_ledger.keypair_of_account_record_exn receiver
  in
  let sender =
    Genesis_ledger.find_new_account_record_exn
      [largest_account_keypair.public_key; receiver_keypair.public_key]
  in
  let sender_keypair = Genesis_ledger.keypair_of_account_record_exn sender in
  let other_accounts =
    List.filter Genesis_ledger.accounts ~f:(fun (_, account) ->
        let reserved_public_keys =
          [ largest_account_keypair.public_key
          ; receiver_keypair.public_key
          ; sender_keypair.public_key ]
        in
        not
          (List.exists reserved_public_keys ~f:(fun pk ->
               Public_key.equal pk
                 (Public_key.decompress_exn @@ Account.public_key account) ))
    )
    |> List.map ~f:(fun (sk, account) ->
           (Genesis_ledger.keypair_of_account_record_exn (sk, account), account)
       )
  in
  (* No proof emitted by the parallel scan at the begining *)
  assert (Option.is_none @@ Run.For_tests.ledger_proof coda) ;
  (* Send money to someone *)
  let build_txn amount sender_sk receiver_pk fee =
    let nonce = Run.get_nonce coda (pk_of_sk sender_sk) |> Option.value_exn in
    let payload : Transaction.Payload.t =
      {receiver= receiver_pk; amount; fee; nonce}
    in
    Transaction.sign (Keypair.of_private_key_exn sender_sk) payload
  in
  let test_sending_transaction sender_sk receiver_pk =
    let transaction =
      build_txn send_amount sender_sk receiver_pk (Currency.Fee.of_int 0)
    in
    let prev_sender_balance =
      Run.get_balance coda (pk_of_sk sender_sk) |> Option.value_exn
    in
    let prev_receiver_balance =
      Run.get_balance coda receiver_pk
      |> Option.value ~default:Currency.Balance.zero
    in
    let%bind () = Run.send_txn log coda (transaction :> Transaction.t) in
    (* Send a similar the transaction twice on purpose; this second one
    * will be rejected because the nonce is wrong *)
    let transaction' =
      build_txn send_amount sender_sk receiver_pk (Currency.Fee.of_int 0)
    in
    let%bind () = Run.send_txn log coda (transaction' :> Transaction.t) in
    (* Let the system settle, mine some blocks *)
    let%map () =
      balance_change_or_timeout ~initial_receiver_balance:prev_receiver_balance
        receiver_pk
    in
    assert_balance receiver_pk
      ( Currency.Balance.( + ) prev_receiver_balance send_amount
      |> Option.value_exn ) ;
    assert_balance (pk_of_sk sender_sk)
      ( Currency.Balance.( - ) prev_sender_balance send_amount
      |> Option.value_exn )
  in
  let send_txn_update_balance_sheet sender_sk sender_pk receiver_pk amount
      balance_sheet fee =
    let transaction = build_txn amount sender_sk receiver_pk fee in
    let new_balance_sheet =
      Map.update balance_sheet sender_pk (fun v ->
          Option.value_exn
            (Currency.Balance.sub_amount (Option.value_exn v)
               (Option.value_exn (Currency.Amount.add_fee amount fee))) )
    in
    let new_balance_sheet' =
      Map.update new_balance_sheet receiver_pk (fun v ->
          Option.value_exn
            (Currency.Balance.add_amount (Option.value_exn v) amount) )
    in
    let%map () = Run.send_txn log coda (transaction :> Transaction.t) in
    new_balance_sheet'
  in
  let send_txns balance_sheet f_amount =
    Deferred.List.foldi other_accounts ~init:balance_sheet ~f:
      (fun i acc (sender_keypair, _) ->
        let receiver_keypair, _ =
          List.random_element_exn
            (List.filter other_accounts ~f:(fun (keypair, _) ->
                 not
                   (Public_key.equal keypair.public_key
                      sender_keypair.public_key) ))
        in
        send_txn_update_balance_sheet sender_keypair.private_key
          (Public_key.compress sender_keypair.public_key)
          (Public_key.compress receiver_keypair.public_key)
          (f_amount i) acc (Currency.Fee.of_int 0) )
  in
  let wait_for_proof_or_timeout () =
    let rec go () =
      if Option.is_some @@ Run.For_tests.ledger_proof coda then (
        Core.printf "Ledger_proof emitted\n %!" ;
        return true )
      else
        let%bind () = after (Time_ns.Span.of_sec 10.) in
        go ()
    in
    let timeout =
      let%map () = after (Time_ns.Span.of_min 3.) in
      false
    in
    Deferred.any [timeout; go ()]
  in
  (*Include multiple transactions in a block*)
  let balance_sheet =
    Public_key.Compressed.Map.of_alist_exn
      (List.map other_accounts ~f:(fun (keypair, account) ->
           (Public_key.compress keypair.public_key, Account.balance account) ))
  in
  let%bind updated_balance_sheet =
    send_txns balance_sheet (fun i -> Currency.Amount.of_int ((i + 1) * 10))
  in
  (* After mining a few blocks and emitting a ledger_proof (by the parallel scan), check if the balances match *)
  let%bind emitted = wait_for_proof_or_timeout () in
  assert emitted ;
  Map.fold updated_balance_sheet ~init:() ~f:(fun ~key ~data () ->
      assert_balance key data ) ;
  (* test duplicate transactions *)
  let%bind () =
    test_sending_transaction sender_keypair.private_key
      (Public_key.compress receiver_keypair.public_key)
  in
  let%bind () =
    test_sending_transaction sender_keypair.private_key
      (Public_key.compress receiver_keypair.public_key)
  in
  (* wait for a second proof to be emitted; this makes the test run longer, allowing us to run through more cases in proof of stake *)
  let%bind emitted = wait_for_proof_or_timeout () in
  assert emitted ;
  Deferred.unit

let command (module Kernel : Kernel_intf) =
  let open Core in
  let open Async in
  Command.async_spec ~summary:"Full coda end-to-end test" Command.Spec.empty
    (fun () -> run_test (module Kernel) )
