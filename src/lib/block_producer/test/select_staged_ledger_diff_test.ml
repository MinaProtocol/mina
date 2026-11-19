open Core_kernel
open Async
open Mina_base
open Signature_lib
module Amount = Currency.Amount
module Fee = Currency.Fee
module Diff = Staged_ledger_diff.With_valid_signatures_and_proofs

let constraint_constants =
  Genesis_constants.For_unit_tests.Constraint_constants.t

let logger = Logger.null ()

let signature_kind = Mina_signature_kind.Testnet

let keypair name =
  Quickcheck.random_value ~seed:(`Deterministic name) Keypair.gen

let pk (kp : Keypair.t) = Public_key.compress kp.public_key

let sender = keypair "sender"

let receiver = keypair "receiver"

let producer = keypair "producer"

let prover = keypair "prover"

let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 1

let global_slot_since_hard_fork =
  Mina_numbers.Global_slot_since_hard_fork.of_int 1

let state, state_view =
  Staged_ledger.Test_helpers.dummy_state_and_view ~global_slot ()

let state_and_body_hash =
  let hashes = Mina_state.Protocol_state.hashes state in
  (hashes.state_hash, Option.value_exn hashes.state_body_hash)

let initial_staged_ledger () =
  let ledger =
    Mina_ledger.Ledger.create_ephemeral ~depth:constraint_constants.ledger_depth
      ()
  in
  List.iter [ sender; receiver; producer; prover ] ~f:(fun kp ->
      let id = Account_id.create (pk kp) Token_id.default in
      Mina_ledger.Ledger.create_new_account_exn ledger id
        (Account.create id (Currency.Balance.of_mina_int_exn 1_000_000)) ) ;
  Staged_ledger.create_exn ~constraint_constants ~ledger

let payment ~nonce ~fee : User_command.Valid.t =
  let payload =
    Signed_command.Payload.create ~fee ~fee_payer_pk:(pk sender)
      ~nonce:(Account.Nonce.of_int nonce)
      ~memo:Signed_command_memo.dummy ~valid_until:None
      ~body:
        (Payment
           { receiver_pk = pk receiver; amount = Amount.of_mina_int_exn 1 } )
  in
  Signed_command (Signed_command.sign ~signature_kind sender payload)

let work ~fee statements : Transaction_snark_work.Checked.t =
  Transaction_snark_work.Checked.create_unsafe
    { fee
    ; proofs =
        One_or_two.map statements ~f:(fun statement ->
            Ledger_proof.For_tests.Cached.mk_dummy_proof ~statement ~fee
              ~prover:(pk prover) )
    ; prover = pk prover
    }

let select ?block_reward_threshold ?slot_tx_end ~staged_ledger ~transactions
    ~get_completed_work () =
  Block_producer.select_staged_ledger_diff ~commit_id:"" ~logger
    ~constraint_constants ~staged_ledger ~global_slot_since_hard_fork
    ~global_slot ~coinbase_receiver:(pk producer)
    ~previous_state_view:state_view
    ~transactions:(Sequence.of_list transactions)
    ~get_completed_work ~log_block_creation:false ~supercharge_coinbase:false
    ~zkapp_cmd_limit:None ~block_reward_threshold ~slot_tx_end
  |> Result.map_error ~f:Staged_ledger.Staged_ledger_error.to_error
  |> Or_error.ok_exn

let apply staged_ledger diff =
  match%map
    Staged_ledger.apply_diff_unchecked staged_ledger ~constraint_constants
      ~global_slot diff ~logger ~current_state_view:state_view
      ~state_and_body_hash ~coinbase_receiver:(pk producer)
      ~supercharge_coinbase:false ~zkapp_cmd_limit_hardcap:200 ~signature_kind
  with
  | Ok (_, `Staged_ledger staged_ledger, _, _) ->
      staged_ledger
  | Error e ->
      Error.raise (Staged_ledger.Staged_ledger_error.to_error e)

let net_return diff =
  Staged_ledger_diff.net_return ~constraint_constants
    ~supercharge_coinbase:false
    (Staged_ledger_diff.forget diff)

let mina = Fee.of_mina_int_exn

let work_at fee statements = Some (work ~fee statements)

let check_net_return expected diff =
  Alcotest.(check (option string))
    "net return"
    (Some (Amount.to_mina_string (Amount.of_mina_int_exn expected)))
    (Option.map (net_return diff) ~f:Amount.to_mina_string)

let check_work_fees expected diff =
  Alcotest.(check (list string))
    "snark work fees"
    (List.map expected ~f:(fun fee -> Fee.to_mina_string (mina fee)))
    (List.map
       (Staged_ledger_diff.completed_works (Staged_ledger_diff.forget diff))
       ~f:(fun work -> Fee.to_mina_string (Transaction_snark_work.fee work)) )

let check_commands expected diff =
  Alcotest.(check int) "commands" expected (List.length (Diff.commands diff))

let check_emptied diff =
  Alcotest.(check bool)
    "replaced by the empty diff" true
    (phys_equal diff Diff.empty_diff)

let check_applies staged_ledger diff =
  Thread_safe.block_on_async_exn (fun () ->
      Deferred.ignore_m (apply staged_ledger diff) )

(* Fill the scan state with zero-fee work until there is pending work to buy. *)
let warmed_up =
  lazy
    (Thread_safe.block_on_async_exn (fun () ->
         let rec go staged_ledger nonce blocks =
           if blocks = 0 then return (staged_ledger, nonce)
           else
             let diff =
               select ~staged_ledger
                 ~transactions:
                   (List.init 20 ~f:(fun i ->
                        payment ~nonce:(nonce + i) ~fee:(mina 1) ) )
                 ~get_completed_work:(work_at Fee.zero) ()
             in
             let%bind staged_ledger = apply staged_ledger diff in
             go staged_ledger
               (nonce + List.length (Diff.commands diff))
               (blocks - 1)
         in
         go (initial_staged_ledger ()) 0 3 ) )

let payments_from_warmed_up ~fee count =
  let _, nonce = Lazy.force warmed_up in
  List.init count ~f:(fun i -> payment ~nonce:(nonce + i) ~fee:(mina fee))

let warm_up_leaves_work_to_buy () =
  let staged_ledger, _ = Lazy.force warmed_up in
  Alcotest.(check bool)
    "pending work" true
    (not (List.is_empty (Staged_ledger.all_work_statements_exn staged_ledger)))

let coinbase_pays_for_snark_work () =
  let staged_ledger, _ = Lazy.force warmed_up in
  let diff =
    select ~staged_ledger ~transactions:[]
      ~get_completed_work:(work_at (mina 15))
      ()
  in
  check_commands 0 diff ;
  check_work_fees [ 15 ] diff ;
  check_net_return 5 diff ;
  check_applies staged_ledger diff

let optional_snark_work_can_empty_a_block () =
  let staged_ledger, _ = Lazy.force warmed_up in
  let block_reward_threshold = Amount.of_mina_int_exn 10 in
  check_emptied
    (select ~block_reward_threshold ~staged_ledger ~transactions:[]
       ~get_completed_work:(work_at (mina 15))
       () ) ;
  let without_work_on_offer =
    select ~block_reward_threshold ~staged_ledger ~transactions:[]
      ~get_completed_work:(fun _ -> None)
      ()
  in
  check_work_fees [] without_work_on_offer ;
  check_net_return 20 without_work_on_offer ;
  check_applies staged_ledger without_work_on_offer

let transaction_fees_pay_for_expensive_then_cheap_work () =
  let staged_ledger, _ = Lazy.force warmed_up in
  let first_statement =
    List.hd_exn (Staged_ledger.all_work_statements_exn staged_ledger)
  in
  let get_completed_work statements =
    if Transaction_snark_work.Statement.equal statements first_statement then
      work_at (mina 15) statements
    else work_at (mina 1) statements
  in
  let transactions = payments_from_warmed_up ~fee:10 6 in
  let diff = select ~staged_ledger ~transactions ~get_completed_work () in
  check_commands 6 diff ;
  check_work_fees [ 15; 1; 1; 1 ] diff ;
  (* 20 coinbase + 6 * 10 fees - (15 + 3 * 1) snark work *)
  check_net_return 62 diff ;
  check_applies staged_ledger diff ;
  let kept =
    select
      ~block_reward_threshold:(Amount.of_mina_int_exn 62)
      ~staged_ledger ~transactions ~get_completed_work ()
  in
  check_net_return 62 kept ;
  check_emptied
    (select
       ~block_reward_threshold:
         (Option.value_exn Amount.(of_mina_int_exn 62 + of_nanomina_int_exn 1))
       ~staged_ledger ~transactions ~get_completed_work () )

let unaffordable_snark_work_is_left_out () =
  let staged_ledger, _ = Lazy.force warmed_up in
  let diff =
    select ~staged_ledger ~transactions:[]
      ~get_completed_work:(work_at (mina 25))
      ()
  in
  check_work_fees [] diff ;
  check_net_return 20 diff ;
  check_applies staged_ledger diff

let slot_tx_end_empties_the_block () =
  let staged_ledger, _ = Lazy.force warmed_up in
  check_emptied
    (select ~slot_tx_end:global_slot_since_hard_fork ~staged_ledger
       ~transactions:(payments_from_warmed_up ~fee:10 1)
       ~get_completed_work:(work_at Fee.zero) () )
