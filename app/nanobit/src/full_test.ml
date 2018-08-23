open Core_kernel
open Async_kernel
open Nanobit_base
open Coda_main

let pk sk = Public_key.of_private_key sk |> Public_key.compress

let sk_bigint sk =
  Private_key.to_bigstring sk |> Private_key.of_bigstring |> Or_error.ok_exn

let run_test (type ledger_proof) (with_snark: bool) (module Kernel
    : Kernel_intf with type Ledger_proof.t = ledger_proof) (module Coda
    : Coda_intf.S with type ledger_proof = ledger_proof) : unit Deferred.t =
  Parallel.init_master () ;
  let log = Logger.create () in
  let conf_dir = "/tmp" in
  let module Config = struct
    let logger = log

    let conf_dir = conf_dir

    let lbc_tree_max_depth = `Finite 50

    let transition_interval = Time.Span.of_ms 100.0

    let fee_public_key = Genesis_ledger.rich_pk

    let genesis_proof = Precomputed_values.base_proof
  end in
  let%bind (module Init) = make_init (module Config) (module Kernel) in
  let module Main = Coda.Make (Init) () in
  let module Run = Run (Main) in
  let open Main in
  let net_config =
    { Inputs.Net.Config.parent_log= log
    ; gossip_net_params=
        { Inputs.Net.Gossip_net.Config.timeout= Time.Span.of_sec 1.
        ; parent_log= log
        ; target_peer_count= 8
        ; initial_peers= []
        ; conf_dir
        ; address= Host_and_port.of_string "127.0.0.1:8001"
        ; me= Host_and_port.of_string "127.0.0.1:8000" } }
  in
  let%bind minibit =
    Main.create
      (Main.Config.make ~log ~net_config
         ~ledger_builder_persistant_location:"ledger_builder"
         ~transaction_pool_disk_location:"transaction_pool"
         ~snark_pool_disk_location:"snark_pool"
         ~time_controller:(Inputs.Time.Controller.create ())
         ())
  in
  don't_wait_for (Linear_pipe.drain (Main.strongest_ledgers minibit)) ;
  let balance_change_or_timeout ~initial_receiver_balance receiver_pk =
    let rec go () =
      match Run.get_balance minibit receiver_pk with
      | Some b when not (Currency.Balance.equal b initial_receiver_balance) ->
          return ()
      | _ ->
          let%bind () = after (Time_ns.Span.of_sec 10.) in
          go ()
    in
    Deferred.any [after (Time_ns.Span.of_min 3.); go ()]
  in
  let open Genesis_ledger in
  let assert_balance pk amount =
    match Run.get_balance minibit pk with
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
  let run_snark_worker = `With_public_key Genesis_ledger.rich_pk in
  Run.setup_local_server ~client_port ~minibit ~log ;
  Run.run_snark_worker ~log ~client_port run_snark_worker ;
  (* Let the system settle *)
  let%bind () = Async.after (Time.Span.of_ms 100.) in
  (* Check if rich-man has some balance *)
  assert_balance rich_pk initial_rich_balance ;
  assert_balance poor_pk initial_poor_balance ;
  (* Note: This is much less than half of the rich balance so we can test
   *       transaction replays being prohibited
   *)
  let send_amount = Currency.Amount.of_int 10 in
  (* Send money to someone *)
  let build_txn amount sender_sk receiver_pk =
    let nonce = Run.get_nonce minibit (pk sender_sk) |> Option.value_exn in
    let payload : Transaction.Payload.t =
      {receiver= receiver_pk; amount; fee= Currency.Fee.of_int 0; nonce}
    in
    Transaction.sign (Signature_keypair.of_private_key sender_sk) payload
  in
  let test_sending_transaction sender_sk receiver_pk =
    let transaction = build_txn send_amount sender_sk receiver_pk in
    let prev_sender_balance =
      Run.get_balance minibit (pk sender_sk) |> Option.value_exn
    in
    let prev_receiver_balance =
      Run.get_balance minibit receiver_pk
      |> Option.value ~default:Currency.Balance.zero
    in
    let%bind () = Run.send_txn log minibit (transaction :> Transaction.t) in
    (* Send a similar the transaction twice on purpose; this second one
    * will be rejected because the nonce is wrong *)
    let transaction' = build_txn send_amount sender_sk receiver_pk in
    let%bind () = Run.send_txn log minibit (transaction' :> Transaction.t) in
    (* Let the system settle, mine some blocks *)
    let%map () =
      balance_change_or_timeout ~initial_receiver_balance:prev_receiver_balance
        receiver_pk
    in
    assert_balance receiver_pk
      ( Currency.Balance.( + ) prev_receiver_balance send_amount
      |> Option.value_exn ) ;
    assert_balance (pk sender_sk)
      ( Currency.Balance.( - ) prev_sender_balance send_amount
      |> Option.value_exn )
  in
  let send_txn_update_balance_sheet sender_sk sender_pk receiver_pk amount
      balance_sheet =
    let transaction = build_txn amount sender_sk receiver_pk in
    let new_balance_sheet =
      Map.update balance_sheet sender_pk (fun v ->
          Option.value_exn
            (Currency.Balance.sub_amount (Option.value_exn v) amount) )
    in
    let new_balance_sheet' =
      Map.update new_balance_sheet receiver_pk (fun v ->
          Option.value_exn
            (Currency.Balance.add_amount (Option.value_exn v) amount) )
    in
    let%map () = Run.send_txn log minibit (transaction :> Transaction.t) in
    new_balance_sheet'
  in
  let%bind () =
    test_sending_transaction Genesis_ledger.rich_sk Genesis_ledger.poor_pk
  in
  let%bind () =
    test_sending_transaction Genesis_ledger.rich_sk Genesis_ledger.poor_pk
  in
  (*Include multiple transactions in a block*)
  let balance_sheet =
    Public_key.Compressed.Map.of_alist_exn
      (List.map sincere_pks ~f:(fun pk ->
           (pk, Currency.Balance.of_int init_balance) ))
  in
  let%bind updated_balance_sheet =
    Deferred.List.foldi sincere_pairs ~init:balance_sheet ~f:
      (fun i acc key_pair ->
        let sender_pk = Public_key.compress key_pair.public_key in
        let receiver =
          List.random_element_exn
            (List.filter sincere_pks ~f:(fun pk -> not (pk = sender_pk)))
        in
        send_txn_update_balance_sheet key_pair.private_key sender_pk receiver
          (Currency.Amount.of_int ((i + 1) * 10))
          acc )
  in
  (*After mining a few blocks and emitting a few ledger_proofs (by the parallel scan), check if the balances match *)
  let%bind () = after (Time_ns.Span.of_min 1.) in
  Map.fold updated_balance_sheet ~init:() ~f:(fun ~key ~data () ->
      assert_balance key data ) ;
  Deferred.unit

let command (type ledger_proof) (module Kernel
    : Kernel_intf with type Ledger_proof.t = ledger_proof) (module Coda
    : Coda_intf.S with type ledger_proof = ledger_proof) =
  let open Core in
  let open Async in
  Command.async ~summary:"Full minibit end-to-end test"
    (let open Command.Let_syntax in
    let%map_open with_snark = flag "with-snark" no_arg ~doc:"Produce snarks" in
    fun () -> run_test with_snark (module Kernel) (module Coda))
