open Core
open Signature_lib
open Mina_base
module U = Transaction_snark_tests.Util

(* add a comment to make git happy *)
let mk_ledgers_and_fee_payers ~num_of_fee_payers =
  let fee_payer_keypairs =
    Array.init num_of_fee_payers ~f:(fun _ -> Keypair.create ())
  in
  let fee_payer_pks =
    Array.map fee_payer_keypairs ~f:(fun fee_payer_keypair ->
        Public_key.compress fee_payer_keypair.public_key)
  in
  let fee_payer_account_ids =
    Array.map fee_payer_pks ~f:(fun fee_payer_pk ->
        Account_id.create fee_payer_pk Token_id.default)
  in
  let (initial_balance : Currency.Balance.t) =
    Currency.Balance.of_int 1_000_000_000_000_000
  in
  let (fee_payer_accounts : Account.t array) =
    Array.map fee_payer_account_ids ~f:(fun fee_payer_account_id ->
        Account.create fee_payer_account_id initial_balance)
  in
  let ledger = Mina_ledger.Ledger.create ~depth:10 () in
  Array.iter2_exn fee_payer_accounts fee_payer_account_ids
    ~f:(fun fee_payer_account fee_payer_account_id ->
      Mina_ledger.Ledger.get_or_create_account ledger fee_payer_account_id
        fee_payer_account
      |> Or_error.ok_exn
      |> fun _ -> ()) ;
  let keys = List.init 1000 ~f:(fun _ -> Keypair.create ()) in
  let keymap =
    List.map
      (Array.to_list fee_payer_keypairs @ keys)
      ~f:(fun { public_key; private_key } ->
        (Public_key.compress public_key, private_key))
    |> Public_key.Compressed.Map.of_alist_exn
  in
  (ledger, fee_payer_keypairs, keymap)

let `VK vk, `Prover prover = Lazy.force U.trivial_zkapp

let generate_parties_and_apply_them_consecutively () =
  let num_of_fee_payers = 5 in
  let trials = 6 in
  let ledger, fee_payer_keypairs, keymap =
    mk_ledgers_and_fee_payers ~num_of_fee_payers
  in
  Test_util.with_randomness 123456789 (fun () ->
      let test i =
        Quickcheck.test ~trials:1
          (Mina_generators.Parties_generators.gen_parties_from
             ~protocol_state_view:U.genesis_state_view
             ~fee_payer_keypair:fee_payer_keypairs.(i / 2)
             ~keymap ~ledger ~vk ~prover ())
          ~f:(fun parties ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                U.check_parties_with_merges_exn ledger [ parties ]))
      in
      for i = 0 to trials - 1 do
        test i
      done)

let generate_parties_and_apply_them_freshly () =
  let num_of_fee_payers = 5 in
  let trials = 6 in
  Test_util.with_randomness 123456789 (fun () ->
      let test i =
        let ledger, fee_payer_keypairs, keymap =
          mk_ledgers_and_fee_payers ~num_of_fee_payers
        in
        Quickcheck.test ~trials:1
          (Mina_generators.Parties_generators.gen_parties_from
             ~protocol_state_view:U.genesis_state_view
             ~fee_payer_keypair:fee_payer_keypairs.(i / 2)
             ~keymap ~ledger ~vk ~prover ())
          ~f:(fun parties ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                U.check_parties_with_merges_exn ledger [ parties ]))
      in
      for i = 0 to trials - 1 do
        test i
      done)

let () =
  generate_parties_and_apply_them_consecutively () ;
  generate_parties_and_apply_them_freshly ()
