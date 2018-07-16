open Core_kernel
open Async_kernel
open Nanobit_base
open Main

let run_test with_snark : unit -> unit Deferred.t =
 fun () ->
  let log = Logger.create () in
  let conf_dir = "/tmp" in
  let%bind prover = Prover.create ~conf_dir in
  let%bind genesis_proof = Prover.genesis_proof prover >>| Or_error.ok_exn in
  let module Init = struct
    type proof = Proof.Stable.V1.t [@@deriving bin_io]

    let conf_dir = conf_dir

    let prover = prover

    let genesis_proof = genesis_proof

    let fee_public_key = Genesis_ledger.rich_pk
  end in
  let module Main = ( val if with_snark then
                            (module Main_with_snark (Storage.Memory) (Init)
                            : Main_intf )
                          else (module Main_without_snark (Init) : Main_intf)
  ) in
  let module Run = Run (Main) in
  let open Main in
  let net_config =
    { Inputs.Net.Config.parent_log= log
    ; gossip_net_params=
        { timeout= Time.Span.of_sec 1.
        ; target_peer_count= 8
        ; address= Host_and_port.of_string "127.0.0.1:8001" }
    ; initial_peers= []
    ; me= Host_and_port.of_string "127.0.0.1:8000"
    ; remap_addr_port= Fn.id }
  in
  let%bind minibit =
    Main.create
      { log
      ; net_config
      ; ledger_disk_location= "ledgers"
      ; pool_disk_location= "transaction_pool" }
  in
  let balance_change_or_timeout =
    let rec go () =
      match%bind Run.get_balance minibit Genesis_ledger.poor_pk with
      | Some b
        when not (Currency.Balance.equal b Genesis_ledger.initial_poor_balance) ->
          return ()
      | _ ->
          let%bind () = after (Time_ns.Span.of_sec 10.) in
          go ()
    in
    Deferred.any [after (Time_ns.Span.of_min 5.); go ()]
  in
  let open Genesis_ledger in
  let assert_balance pk amount =
    match%map Run.get_balance minibit pk with
    | Some balance ->
        if not (Currency.Balance.equal balance amount) then
          failwithf
            !"Balance in account %{sexp: Currency.Balance.t} is not asserted \
              balance %{sexp: Currency.Balance.t}"
            balance amount ()
    | None -> failwith "No balance in ledger"
  in
  let client_port = 8123 in
  let run_snark_worker = `With_public_key Genesis_ledger.rich_pk in
  Run.setup_local_server ~client_port ~minibit ~log ;
  Run.run_snark_worker ~client_port run_snark_worker ;
  Run.run ~minibit ~log ;
  (* Let the system settle *)
  let%bind () = Async.after (Time.Span.of_ms 100.) in
  (* Check if rich-man has some balance *)
  let%bind () = assert_balance rich_pk initial_rich_balance in
  let%bind () = assert_balance poor_pk initial_poor_balance in
  (* Note: This is much less than half of the rich balance so we can test
   *       transaction replays being prohibited
   *)
  let send_amount = Currency.Amount.of_int 10 in
  (* Send money to someone *)
  let build_txn amount =
    let poor_pk = Genesis_ledger.poor_pk in
    let payload : Transaction.Payload.t =
      { receiver= poor_pk
      ; amount= send_amount
      ; fee= Currency.Fee.of_int 0
      ; nonce= Account.Nonce.zero }
    in
    Transaction.sign (Signature_keypair.of_private_key rich_sk) payload
  in
  let transaction = build_txn send_amount in
  let%bind o = Run.send_txn log minibit (transaction :> Transaction.t) in
  let () = Option.value_exn o in
  (* Send a similar the transaction twice on purpose; this second one
   * will be rejected because the nonce is wrong *)
  let transaction' = build_txn Currency.Amount.(send_amount + of_int 1) in
  let%bind o = Run.send_txn log minibit (transaction' :> Transaction.t) in
  let () = Option.value_exn o in
  (* Let the system settle, mine some blocks *)
  let%bind () = balance_change_or_timeout in
  let%bind () =
    assert_balance poor_pk
      ( Currency.Balance.( + ) Genesis_ledger.initial_poor_balance send_amount
      |> Option.value_exn )
  in
  let%map () =
    assert_balance rich_pk
      ( Currency.Balance.( - ) Genesis_ledger.initial_rich_balance send_amount
      |> Option.value_exn )
  in
  ()

let command =
  let open Core in
  let open Async in
  Command.async ~summary:"Full minibit end-to-end test"
    (let open Command.Let_syntax in
    let%map_open with_snark = flag "with-snark" no_arg ~doc:"Produce snarks" in
    run_test with_snark)
