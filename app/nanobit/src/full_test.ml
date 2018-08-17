open Core_kernel
open Async_kernel
open Nanobit_base
open Coda_main

let pk sk = Public_key.of_private_key sk |> Public_key.compress

let sk_bigint sk =
  Private_key.to_bigstring sk |> Private_key.of_bigstring |> Or_error.ok_exn

let run_test with_snark : unit -> unit Deferred.t =
 fun () ->
  Parallel.init_master () ;
  let log = Logger.create () in
  let conf_dir = "/tmp" in
  let module Common = struct
    module Make_consensus_mechanism (Ledger_builder_diff : sig
      type t [@@deriving sexp, bin_io]
    end) =
      Consensus.Proof_of_signature.Make (Nanobit_base.Proof)
        (Ledger_builder_diff)

    let logger = log

    let conf_dir = conf_dir

    let transaction_interval = Time.Span.of_ms 100.0

    let fee_public_key = Genesis_ledger.rich_pk

    let genesis_proof = Precomputed_values.base_proof
  end in
  let%bind (module Main) =
    if with_snark then
      let%map (module Init) =
        make_init
          ( module struct
            include Common
            module Ledger_proof = Ledger_proof.Prod
          end )
      in
      (module Coda_with_snark (Storage.Memory) (Init) () : Main_intf)
    else
      let%map (module Init) =
        make_init
          ( module struct
            include Common
            module Ledger_proof = Ledger_proof.Debug
          end )
      in
      (module Coda_without_snark (Init) () : Main_intf)
  in
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
      { receiver= receiver_pk
      ; amount= send_amount
      ; fee= Currency.Fee.of_int 1
      ; nonce }
    in
    Transaction.sign (Signature_keypair.of_private_key sender_sk) payload
  in
  let test_sending_transaction () sender_sk receiver_pk =
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
    let transaction' =
      build_txn
        Currency.Amount.(send_amount + of_int 1000)
        sender_sk receiver_pk
    in
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
  let%bind () =
    test_sending_transaction () Genesis_ledger.rich_sk Genesis_ledger.poor_pk
  in
  let%bind () =
    test_sending_transaction () Genesis_ledger.rich_sk Genesis_ledger.poor_pk
  in
  let%bind () = after (Time_ns.Span.of_sec 10.) in
  let%bind () = after (Time_ns.Span.of_sec 100.) in
  Deferred.unit

let command =
  let open Core in
  let open Async in
  Command.async ~summary:"Full minibit end-to-end test"
    (let open Command.Let_syntax in
    let%map_open with_snark = flag "with-snark" no_arg ~doc:"Produce snarks" in
    run_test with_snark)
