open Core_kernel
open Signature_lib
open Mina_numbers
open Currency
open Mina_base

module Hash = struct
  type t = Ledger_hash.t

  let merge = Ledger_hash.merge

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = Ledger_hash.of_digest Account.empty_digest
end

let%test_module "transaction logic consistency" =
  ( module struct
    let precomputed_values = Lazy.force Precomputed_values.compiled_inputs

    let constraint_constants = precomputed_values.constraint_constants

    let block_data = precomputed_values.protocol_state_with_hash.data

    let current_slot = Global_slot.of_int 15

    let block_data =
      (* Tweak block data to have current slot. *)
      let open Mina_state.Protocol_state in
      let consensus_state =
        Consensus.Data.Consensus_state.Value.For_tests
        .with_global_slot_since_genesis
          (consensus_state block_data)
          current_slot
      in
      create_value
        ~previous_state_hash:(previous_state_hash block_data)
        ~genesis_state_hash:(genesis_state_hash block_data)
        ~blockchain_state:(blockchain_state block_data)
        ~consensus_state ~constants:(constants block_data)
      |> body

    let txn_state_view = Mina_state.Protocol_state.Body.view block_data

    let state_body_hash = Mina_state.Protocol_state.Body.hash block_data

    let coinbase_stack_source = Pending_coinbase.Stack.empty

    let pending_coinbase_stack_target (t : Transaction.t) stack =
      let stack_with_state =
        Pending_coinbase.Stack.(push_state state_body_hash stack)
      in
      let target =
        match t with
        | Coinbase c ->
            Pending_coinbase.(Stack.push_coinbase c stack_with_state)
        | _ ->
            stack_with_state
      in
      target

    (*let next_available_token_before = Token_id.(next default)*)

    let empty_sparse_ledger account_ids =
      let base_ledger =
        Ledger.create_ephemeral ~depth:constraint_constants.ledger_depth ()
      in
      let count = ref 0 in
      List.iter account_ids ~f:(fun account_id ->
          let (_ : _ * _) = Ledger.create_empty_exn base_ledger account_id in
          incr count ) ;
      Sparse_ledger.of_ledger_subset_exn base_ledger account_ids

    (* Helpers for applying transactions *)

    module Sparse_txn_logic = Mina_transaction_logic.Make (Sparse_ledger.L)

    let sparse_ledger ledger t =
      Or_error.try_with ~backtrace:true (fun () ->
          Sparse_ledger.apply_transaction_exn ~constraint_constants
            ~txn_state_view ledger (Transaction.forget t) )

    let transaction_logic ledger t =
      let ledger = ref ledger in
      let target_ledger =
        Sparse_txn_logic.apply_transaction ~constraint_constants ~txn_state_view
          ledger (Transaction.forget t)
      in
      Or_error.map ~f:(const !ledger) target_ledger

    let transaction_snark ~source ~target transaction =
      Or_error.try_with ~backtrace:true (fun () ->
          Transaction_snark.check_transaction ~constraint_constants
            ~sok_message:
              { Sok_message.fee = Fee.zero
              ; prover = Public_key.Compressed.empty
              }
            ~source:(Sparse_ledger.merkle_root source)
            ~target:(Sparse_ledger.merkle_root target)
            ~init_stack:coinbase_stack_source
            ~pending_coinbase_stack_state:
              { source = coinbase_stack_source
              ; target =
                  pending_coinbase_stack_target
                    (Transaction.forget transaction)
                    coinbase_stack_source
              }
            ~next_available_token_before:
              (Sparse_ledger.next_available_token source)
            ~next_available_token_after:
              (Sparse_ledger.next_available_token target)
            ~zkapp_account1:None ~zkapp_account2:None
            { transaction; block_data }
            (unstage (Sparse_ledger.handler source)) )

    let check_consistent source transaction =
      let res_sparse =
        sparse_ledger source transaction
        |> Result.map_error ~f:(Error.tag ~tag:"Sparse ledger logic")
      in
      let res_txn_logic =
        transaction_logic source transaction
        |> Result.map_error ~f:(Error.tag ~tag:"Transaction logic")
      in
      let target, ledger_error =
        match (res_sparse, res_txn_logic) with
        | Error _, Error _ ->
            (source, None)
        | Ok target1, Ok target2 ->
            if
              Ledger_hash.equal
                (Sparse_ledger.merkle_root target1)
                (Sparse_ledger.merkle_root target2)
            then (target1, None)
            else
              ( target1
              , Some
                  (Error.create_s
                     (List
                        [ Atom
                            "Sparse ledger and transaction logic output \
                             ledgers do not match"
                        ; Atom
                            ( Sparse_ledger.merkle_root target1
                            |> Snark_params.Tick.Field.to_string )
                        ; Atom
                            ( Sparse_ledger.merkle_root target2
                            |> Snark_params.Tick.Field.to_string )
                        ] ) ) )
        | Ok target, _ | _, Ok target ->
            (target, None)
      in
      let res_snark =
        transaction_snark ~source ~target transaction
        |> Result.map_error ~f:(Error.tag ~tag:"Snark")
      in
      let cons_error res errors =
        match res with Ok _ -> errors | Error error -> error :: errors
      in
      match (res_sparse, res_snark, res_txn_logic, ledger_error) with
      | Ok _, Ok _, Ok _, None | Error _, Error _, Error _, None ->
          ()
      | _, _, Error _, _ ->
          (* This case doesn't present a problem for us. *)
          ()
      | _ ->
          Option.to_list ledger_error
          |> cons_error res_sparse |> cons_error res_snark
          |> cons_error res_txn_logic |> Error.of_list |> Error.raise

    let timed_specs public_key =
      let open Quickcheck.Generator.Let_syntax in
      let untimed =
        let%map balance = Balance.gen in
        Some
          (Account.create
             (Account_id.create public_key Token_id.default)
             balance )
      in
      let timed cliff_time vesting_period =
        let%bind balance = Balance.gen in
        let%bind moveable_amount = Amount.gen in
        let%bind cliff_amount = Amount.gen in
        let%map vesting_increment = Amount.gen in
        Some
          ( Account.create_timed
              (Account_id.create public_key Token_id.default)
              balance
              ~initial_minimum_balance:
                ( Balance.sub_amount balance moveable_amount
                |> Option.value ~default:Balance.zero )
              ~cliff_time:(Global_slot.of_int cliff_time)
              ~vesting_period:(Global_slot.of_int vesting_period)
              ~cliff_amount ~vesting_increment
          |> Or_error.ok_exn )
      in
      [ return None
      ; untimed
      ; timed 0 1 (* vesting, already hit cliff at 0 *)
      ; timed 0 16 (* not yet vesting, already hit cliff at 0 *)
      ; timed 5 1 (* vesting, already hit cliff *)
      ; timed 5 16 (* not yet vesting, already hit cliff *)
      ; timed 15 1 (* not yet vesting, just hit cliff *)
      ; timed 30 1 (* not yet vesting, hasn't hit cliff *)
      ]

    let gen_account pk =
      let open Quickcheck.Generator.Let_syntax in
      let choices = timed_specs pk in
      let%bind choice = Quickcheck.Generator.of_list choices in
      choice

    let transaction_specs sender_sk sender' sender receiver =
      let open Quickcheck.Generator.Let_syntax in
      let gen_user_command_common =
        let%bind fee = Fee.gen in
        let%bind nonce =
          Account_nonce.gen_incl (Account_nonce.of_int 0)
            (Account_nonce.of_int 3)
        in
        let%bind valid_until = Global_slot.gen in
        let%bind memo_length =
          Int.gen_incl 0 Signed_command_memo.max_digestible_string_length
        in
        let%map memo = String.gen_with_length memo_length Char.gen_print in
        let memo =
          Signed_command_memo.create_by_digesting_string memo |> Or_error.ok_exn
        in
        ( { fee
          ; fee_token = Token_id.default
          ; fee_payer_pk = sender
          ; nonce
          ; valid_until
          ; memo
          }
          : Signed_command_payload.Common.t )
      in
      let payment =
        let%bind common = gen_user_command_common in
        let%map amount = Amount.gen in
        let body =
          Signed_command_payload.Body.Payment
            { source_pk = sender
            ; receiver_pk = receiver
            ; token_id = Token_id.default
            ; amount
            }
        in
        let payload : Signed_command_payload.t = { common; body } in
        let signed =
          Signed_command.sign
            { public_key = sender'; private_key = sender_sk }
            payload
        in
        Transaction.Command (User_command.Signed_command signed)
      in
      let delegation =
        let%map common = gen_user_command_common in
        let body =
          Signed_command_payload.Body.Stake_delegation
            (Set_delegate { delegator = sender; new_delegate = receiver })
        in
        let payload : Signed_command_payload.t = { common; body } in
        let signed =
          Signed_command.sign
            { public_key = sender'; private_key = sender_sk }
            payload
        in
        Transaction.Command (User_command.Signed_command signed)
      in
      let coinbase =
        let%bind amount = Amount.gen in
        if%bind Quickcheck.Generator.bool then
          let%map fee = Fee.gen in
          let res =
            Coinbase.create ~amount ~receiver:sender
              ~fee_transfer:
                (Some (Coinbase_fee_transfer.create ~receiver_pk:receiver ~fee))
          in
          match res with
          | Ok res ->
              Transaction.Coinbase res
          | Error _ ->
              Transaction.Coinbase
                ( Coinbase.create ~amount ~receiver:sender ~fee_transfer:None
                |> Or_error.ok_exn )
        else
          return
            (Transaction.Coinbase
               ( Coinbase.create ~amount ~receiver:sender ~fee_transfer:None
               |> Or_error.ok_exn ) )
      in
      let fee_transfer =
        let single_ft pk =
          let%map fee = Fee.gen in
          Fee_transfer.Single.create ~receiver_pk:pk ~fee
            ~fee_token:Token_id.default
        in
        if%bind Quickcheck.Generator.bool then
          let%map fst = single_ft sender in
          Transaction.Fee_transfer
            (Fee_transfer.of_singles (`One fst) |> Or_error.ok_exn)
        else
          let%bind fst = single_ft receiver in
          let%map snd = single_ft sender in
          Transaction.Fee_transfer
            (Fee_transfer.of_singles (`Two (fst, snd)) |> Or_error.ok_exn)
      in
      ignore coinbase ;
      ignore fee_transfer ;
      [ payment; delegation (*coinbase; fee_transfer*) ]

    let gen_transaction sender_sk sender' sender receiver =
      let open Quickcheck.Generator.Let_syntax in
      let choices = transaction_specs sender_sk sender' sender receiver in
      let%bind choice = Quickcheck.Generator.of_list choices in
      choice

    let gen_ledger_and_txn =
      let open Quickcheck.Generator.Let_syntax in
      let%bind sk1 = Private_key.gen in
      let pk1' = Public_key.of_private_key_exn sk1 in
      let pk1 = Public_key.compress pk1' in
      let%bind account1 = gen_account pk1 in
      let%bind pk2, account2 =
        if%bind Quickcheck.Generator.bool then return (pk1, account1)
        else
          let%bind pk = Public_key.Compressed.gen in
          let%map account = gen_account pk in
          (pk, account)
      in
      let account_ids =
        List.map
          ~f:(fun pk -> Account_id.create pk Token_id.default)
          [ pk1; pk2 ]
        |> List.dedup_and_sort ~compare:Account_id.compare
      in
      let ledger = ref (empty_sparse_ledger account_ids) in
      let add_to_ledger pk account =
        Option.iter account ~f:(fun account ->
            Sparse_ledger.L.get_or_create_account ledger
              (Account_id.create pk Token_id.default)
              account
            |> Or_error.ok_exn |> ignore )
      in
      add_to_ledger pk1 account1 ;
      add_to_ledger pk2 account2 ;
      let ledger = !ledger in
      let%map transaction = gen_transaction sk1 pk1' pk1 pk2 in
      (ledger, transaction)

    let%test "transaction logic is consistent between implementations" =
      let passed = ref true in
      let i = ref 0 in
      let threshold = ref 100 in
      Quickcheck.test ~trials:100 gen_ledger_and_txn
        ~f:(fun (ledger, transaction) ->
          incr i ;
          if !i >= !threshold then (
            threshold := !threshold + 100 ;
            Format.eprintf "%i@." !i ) ;
          try check_consistent ledger transaction
          with exn ->
            let error = Error.of_exn ~backtrace:`Get exn in
            passed := false ;
            Format.printf
              "The following transaction was inconsistently \
               applied:@.%s@.%s@.%s@."
              (Yojson.Safe.pretty_to_string
                 (Transaction.Valid.to_yojson transaction) )
              (Yojson.Safe.to_string (Sparse_ledger.to_yojson ledger))
              (Yojson.Safe.pretty_to_string (Error_json.error_to_yojson error)) ) ;
      !passed

    let txn_jsons =
      [ ( {json|
[
  "Command",
  [
    "Signed_command",
    {
      "payload": {
        "common": {
          "fee": "0",
          "fee_token": "1",
          "fee_payer_pk":
            "B62qkgwZB95PFs1H1d16JuRK4xaeUvhNBQd3YBobCEkC9tRSVbwP3y5",
          "nonce": "0",
          "valid_until": "4294967295",
          "memo": "E4Qr2Sj5zrd8obtiCAxez7JV6Zy4NWEcWViJiRDQ58DEZKJfPY1Ld"
        },
        "body": [
          "Stake_delegation",
          [
            "Set_delegate",
            {
              "delegator":
                "B62qkgwZB95PFs1H1d16JuRK4xaeUvhNBQd3YBobCEkC9tRSVbwP3y5",
              "new_delegate":
                "B62qmqN4J84uWANzGqJk37v25DB1ukx7A84YiWPM1CMjnDcQW8fJMTW"
            }
          ]
        ]
      },
      "signer": "B62qkgwZB95PFs1H1d16JuRK4xaeUvhNBQd3YBobCEkC9tRSVbwP3y5",
      "signature":
        "7mXMcy9qNAnBkXC6wA5BpMoeie58wnJ4bAXZN2zsxcoKdDYh5d33ZKER1VyxtNJYZaci6Sr9isYKmEFJMMhAdSRJK3EyMixN"
    }
  ]
]
|json}
        , {json|
{"indexes":[[["B62qkgwZB95PFs1H1d16JuRK4xaeUvhNBQd3YBobCEkC9tRSVbwP3y5","1"],1],[["B62qmqN4J84uWANzGqJk37v25DB1ukx7A84YiWPM1CMjnDcQW8fJMTW","1"],0]],"depth":10,"tree":["Node","jwAyTvaRh912L2sLNDG3vmJCWz4cag3B2zeksXmbVwKDJyjevDq",["Node","jxABNNMH33j4ARZy3ZjmcMo1vwhApw9enUKfCN91MArv63Zf3SJ",["Node","jxj9yf7uV8V7Ck6MUoJkAxWbwr5HQrApE79VszsaNLZ5PfXbvCG",["Node","jwbsSx8xiEt3WpDhS39FNmXAhK6YFF1HToyoJaMqsh27u8Zx5Zx",["Node","jwJ1uvajpBUVvGUFW3m6HkMzJCT557xGFzhwdQZRJp1JMW7cAtK",["Node","jxSXsHu6od1eH13mUNeGPCrQFX45fZwF21szsG59D5jPyTijd6o",["Node","jxUefJcX42tmmFGQuFLnjr9mi7djWfDv92UULjN7fJZDmFjTXZm",["Node","jwAvU9i9QdHJYPTVhEtr3yViXD69KybABGZq4w9ssfFewn4G1Hu",["Node","jwV1HcdrKrGU9NY1FArq7BSc2rVnycRbX24CaELUgcySwbkPYhR",["Node","jxL4snqykkLN8wYjdFE7Mafs8Lh9FmTDsdKKNnM1uvQ1MvRVDec",["Account",{"public_key":"B62qmqN4J84uWANzGqJk37v25DB1ukx7A84YiWPM1CMjnDcQW8fJMTW","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"18446744073709551615","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":"B62qmqN4J84uWANzGqJk37v25DB1ukx7A84YiWPM1CMjnDcQW8fJMTW","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Timed",{"initial_minimum_balance":"11903370931079718836","cliff_time":"5","cliff_amount":"11056729324207590174","vesting_period":"16","vesting_increment":"3434009962718717478"}],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}],["Account",{"public_key":"B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"0","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":null,"voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}]],["Hash","jxXGdw6qfqz96eqvitzV2yJ4Tawk1PhqyjF86e3n4ZNPwmDmp5T"]],["Hash","jxPA47eC73ibqELdRRE5fN3paDzecBfiZ5Nfaj3f6xc4Rkgy2eZ"]],["Hash","jxFGQbPEuwz8DWnhAwuYypdiX6aBCkc55RPF6poUfFSikDK64GU"]],["Hash","jwSjnoWdZ2wyyUhesr6eoxbhcFjHVLBWHHiPNoVe5Q86P5yz2Ad"]],["Hash","jwdEug2AL1iCDDXQpFUbMptiryaU1BRaqV6aL4rnknp7ZcdsT8k"]],["Hash","jxfwfExD2JRGmfwaLkUS2g1HpH896umBLKq3e865m1SbLJW6CrT"]],["Hash","jw8DqJUfNarG33bpL9rUySBwrfBuz7fRHZr5TEvALMS5Rb2S7jE"]],["Hash","jxQLSBPmWYGRDRQaUE7Ye21jhsb185H25nWSSYtg8drSemrQA4P"]],["Hash","jxFokLd9y68j9htcedV8ThzPa8me8kX5FNeRmvVo75NyrqZTLgx"]],"next_available_token":"2"}
|json}
        )
      ; ( {json|
[
  "Command",
  [
    "Signed_command",
    {
      "payload": {
        "common": {
          "fee": "11715569620.84916441",
          "fee_token": "1",
          "fee_payer_pk":
            "B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q",
          "nonce": "0",
          "valid_until": "3050269529",
          "memo": "E4Qrq7yDGADR6cebAsrGEUynB1Dq9bKmca7n2fZUTM2G7XJvTZefu"
        },
        "body": [
          "Payment",
          {
            "source_pk":
              "B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q",
            "receiver_pk":
              "B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q",
            "token_id": "1",
            "amount": "17630684833315573437"
          }
        ]
      },
      "signer": "B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q",
      "signature":
        "7mX6BKK7Yf6wGD46jtds848n4ZFAt4PVEy56mjtb3kjhMCoJmkADvQBTVMhVVb54EDEiH7mjpL9LHELmdnvcDWXyKzzLzfdr"
    }
  ]
]
|json}
        , {json|
{"indexes":[[["B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q","1"],0]],"depth":10,"tree":["Node","jw9h7vsaGR17TLXdceNjsyseSqTN1fFornmvGTQsRoEBopcS9vd",["Node","jxGY7Rb5ysfA1ynJSJVzhSLNMDS2wC9qbSu8B6CdMhByADWwZD1",["Node","jwXmGKuyxTbabLnrBGyYSZxX2ufGU17BWNDnXnxVdUfquhvXPNF",["Node","jwAxd38ejJAPJpS4WQsw8mz6t52KUpu9sjBLUBdZio2Wiyq7bti",["Node","jx6D6UG9o6ba4kQpnVErN6FD1nAiguucFFBukcgXWg3mibfsATh",["Node","jxboQxfmmwxFo5mFJt6jWMMf54pwJTZLW1ykSbXXhDf3gnx7wNB",["Node","jx8mHqEAPTr5pWYXNBLG7WNYbxxLEmwwudPLngpwF866nU6fACr",["Node","jwJzdwbsYshEgW6frEdXudbYYY9F1F7JAp5XA5MTPR7eXRYxkBv",["Node","jxDtzn4TWM4q4Do4nJTb5xMisDvkCABYd3YsEHojfd3TGaSZHMz",["Node","jwbitauPgBS3vwAbC8GLpM83uaWGCVwi75kMK2DFNK3rz88LQJz",["Account",{"public_key":"B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"14192210409447790275","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":"B62qiuCvZdEYUwvNX1ofpkytqVLeNtTybQgFah7Y5DQdg6gnNgTqo3Q","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Timed",{"initial_minimum_balance":"0","cliff_time":"30","cliff_amount":"15395280777725364716","vesting_period":"1","vesting_increment":"18446744073709551615"}],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}],["Hash","jwxHKCNJsFjFJrxSusJ1SnzFLJWosGRFdR5iNznUo3VJPA3fTXX"]],["Hash","jxXGdw6qfqz96eqvitzV2yJ4Tawk1PhqyjF86e3n4ZNPwmDmp5T"]],["Hash","jxPA47eC73ibqELdRRE5fN3paDzecBfiZ5Nfaj3f6xc4Rkgy2eZ"]],["Hash","jxFGQbPEuwz8DWnhAwuYypdiX6aBCkc55RPF6poUfFSikDK64GU"]],["Hash","jwSjnoWdZ2wyyUhesr6eoxbhcFjHVLBWHHiPNoVe5Q86P5yz2Ad"]],["Hash","jwdEug2AL1iCDDXQpFUbMptiryaU1BRaqV6aL4rnknp7ZcdsT8k"]],["Hash","jxfwfExD2JRGmfwaLkUS2g1HpH896umBLKq3e865m1SbLJW6CrT"]],["Hash","jw8DqJUfNarG33bpL9rUySBwrfBuz7fRHZr5TEvALMS5Rb2S7jE"]],["Hash","jxQLSBPmWYGRDRQaUE7Ye21jhsb185H25nWSSYtg8drSemrQA4P"]],["Hash","jxFokLd9y68j9htcedV8ThzPa8me8kX5FNeRmvVo75NyrqZTLgx"]],"next_available_token":"2"}
|json}
        )
      ; ( {json|
[
  "Command",
  [
    "Signed_command",
    {
      "payload": {
        "common": {
          "fee": "6966112488.228360041",
          "fee_token": "1",
          "fee_payer_pk":
            "B62qoBJBVnaTdcSRDCdJUdpzyFikWo828fFriYb6Ye3UYAXfafv9oBJ",
          "nonce": "0",
          "valid_until": "402359895",
          "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
        },
        "body": [
          "Stake_delegation",
          [
            "Set_delegate",
            {
              "delegator":
                "B62qoBJBVnaTdcSRDCdJUdpzyFikWo828fFriYb6Ye3UYAXfafv9oBJ",
              "new_delegate":
                "B62qmyvf3QL2wy6ZQCxMH1T5oEmG2YSygCCqyWWuixpaJYPxzgtm5GK"
            }
          ]
        ]
      },
      "signer": "B62qoBJBVnaTdcSRDCdJUdpzyFikWo828fFriYb6Ye3UYAXfafv9oBJ",
      "signature":
        "7mXUZiLWBxH5rZoDu89W2itCismvcuuFpfRh5sZhaYuq2J53gtZweZGzb4aq4Xs6rPdNStWXxfHDdaWUbF6HifwBcJtRd4Bk"
    }
  ]
]
|json}
        , {json|
{"indexes":[[["B62qoBJBVnaTdcSRDCdJUdpzyFikWo828fFriYb6Ye3UYAXfafv9oBJ","1"],1],[["B62qmyvf3QL2wy6ZQCxMH1T5oEmG2YSygCCqyWWuixpaJYPxzgtm5GK","1"],0]],"depth":10,"tree":["Node","jwEp35gRQZuk69RhiVMziGRdPvuKDxYwbSGfesotUC19aoSMfmG",["Node","jx1JzvawqXs76rMkhNNdYUrdSJZDnugFQRB99N1Fcd8faCC1jEf",["Node","jxfyAK3UYNAK2PPko12XPamxvPRNtRjrZMgpqxYhVSnrWjKNXJV",["Node","jwPsKKCmdamHyWqCDATFayASaeqUXdr3YjCNfmS9vDNTUfbWEun",["Node","jwhHC2RuvnqdjVQzDL5izbmdWqYzECVhdLMVoP9Ess2Xb6BYvuy",["Node","jxr7tqgJcpMsJ9mnP98HxM8BcHkJitP9iXcvPnXdzjTtyV9WdZf",["Node","jw9UAMsNrVgYgSerkPjQAN5AmH55VRMA6ksjDAGs3tzVuTNe2VL",["Node","jwjgszwSywzUiAMZcXLAxDXYGzrSvMVuQ6ghrcBaU3B1a3g2xvd",["Node","jxeJ1Bqu7VqvgnCrDxAuN2DAHKqMUJXbEDTyk7iK9rJGhZ8fag2",["Node","jxJuoz4xN4sLTimTth3U3rf649AJ8gx73YXkoxquPhaTSXZtc9J",["Account",{"public_key":"B62qmyvf3QL2wy6ZQCxMH1T5oEmG2YSygCCqyWWuixpaJYPxzgtm5GK","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"841059136310941822","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":"B62qmyvf3QL2wy6ZQCxMH1T5oEmG2YSygCCqyWWuixpaJYPxzgtm5GK","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Timed",{"initial_minimum_balance":"0","cliff_time":"15","cliff_amount":"15038791585246435520","vesting_period":"1","vesting_increment":"3819098047186376181"}],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}],["Account",{"public_key":"B62qoBJBVnaTdcSRDCdJUdpzyFikWo828fFriYb6Ye3UYAXfafv9oBJ","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"15374217574632243291","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":"B62qoBJBVnaTdcSRDCdJUdpzyFikWo828fFriYb6Ye3UYAXfafv9oBJ","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Timed",{"initial_minimum_balance":"12514132074687763235","cliff_time":"0","cliff_amount":"2989012318809522817","vesting_period":"1","vesting_increment":"11241263741767143225"}],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}]],["Hash","jxXGdw6qfqz96eqvitzV2yJ4Tawk1PhqyjF86e3n4ZNPwmDmp5T"]],["Hash","jxPA47eC73ibqELdRRE5fN3paDzecBfiZ5Nfaj3f6xc4Rkgy2eZ"]],["Hash","jxFGQbPEuwz8DWnhAwuYypdiX6aBCkc55RPF6poUfFSikDK64GU"]],["Hash","jwSjnoWdZ2wyyUhesr6eoxbhcFjHVLBWHHiPNoVe5Q86P5yz2Ad"]],["Hash","jwdEug2AL1iCDDXQpFUbMptiryaU1BRaqV6aL4rnknp7ZcdsT8k"]],["Hash","jxfwfExD2JRGmfwaLkUS2g1HpH896umBLKq3e865m1SbLJW6CrT"]],["Hash","jw8DqJUfNarG33bpL9rUySBwrfBuz7fRHZr5TEvALMS5Rb2S7jE"]],["Hash","jxQLSBPmWYGRDRQaUE7Ye21jhsb185H25nWSSYtg8drSemrQA4P"]],["Hash","jxFokLd9y68j9htcedV8ThzPa8me8kX5FNeRmvVo75NyrqZTLgx"]],"next_available_token":"2"}
|json}
        )
      ; ( {json|
[
  "Command",
  [
    "Signed_command",
    {
      "payload": {
        "common": {
          "fee": "5103387757.91091957",
          "fee_token": "1",
          "fee_payer_pk":
            "B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb",
          "nonce": "0",
          "valid_until": "4294967295",
          "memo": "E4QsDHupQsF62TmSScGTdGRGtsozxK41h2ghcwBzvj9zLj8vmnS1W"
        },
        "body": [
          "Stake_delegation",
          [
            "Set_delegate",
            {
              "delegator":
                "B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb",
              "new_delegate":
                "B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb"
            }
          ]
        ]
      },
      "signer": "B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb",
      "signature":
        "7mX4Jr1Hk8vDLmeqzxWmoQ1ysWgHZhxfr9SiJf9dRnj8bAnnj7XSoHsdZxCnhtbZ7tQxMu8Tb7hvpYvGx8hcPL24oRjSjwj8"
    }
  ]
]
|json}
        , {json|
{"indexes":[[["B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb","1"],0]],"depth":10,"tree":["Node","jwJMLVzC3HsNgsepocU27N3oe9RjfR5uaJquPtLs8vKQYmUJhyH",["Node","jxyUPP6CdhxB2gFX46WhHK8JYw36g94xs1vuQCf1YmAzUJ5msHB",["Node","jxfViFPaZNDQZv2WkVect1y2p84wmMLhocHYp4ZGmyxpCXoXN8V",["Node","jwz8BSMKyC9nw6BRSZCKmTSPU4TeaaFWUMMrKUh8WeMUDX4wG9d",["Node","jxosnPsitXko7dyHrNsGFew5cBwgBbsXvUEqTQw9CWUF5kxvS2d",["Node","jwg9Gg3UKoQ7L27oLUZb3ey1eBzN5gqRotMTCeuHa18pHNhSc56",["Node","jxWjzcWzjA81vbXYQBZ6mdih9GRKhUaRtKZrKeAEDEyTuDwLrcs",["Node","jwaUpbugJ6wsBjpEuDAn6hvauQRz1UtB4vigysRdoReaEq24G36",["Node","jxiUXyMeqCEacdGN4LyZEoiTH1aMmrVv8HsyPDUAeodoDGwELDJ",["Node","jwchfo6bBkFNq197Ktnb3e6xK1v1SnUuqm7ECEY7qbSiuQKtS7w",["Account",{"public_key":"B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"16443235064858872408","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":"B62qmKu3zxe1p3UJM8x3UUh53MKCbBP9cUFkpR1iHJKE4Wq1FdJ9iqb","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Timed",{"initial_minimum_balance":"11729407456613440963","cliff_time":"0","cliff_amount":"2841923093531387540","vesting_period":"1","vesting_increment":"17463989331768009195"}],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}],["Hash","jwxHKCNJsFjFJrxSusJ1SnzFLJWosGRFdR5iNznUo3VJPA3fTXX"]],["Hash","jxXGdw6qfqz96eqvitzV2yJ4Tawk1PhqyjF86e3n4ZNPwmDmp5T"]],["Hash","jxPA47eC73ibqELdRRE5fN3paDzecBfiZ5Nfaj3f6xc4Rkgy2eZ"]],["Hash","jxFGQbPEuwz8DWnhAwuYypdiX6aBCkc55RPF6poUfFSikDK64GU"]],["Hash","jwSjnoWdZ2wyyUhesr6eoxbhcFjHVLBWHHiPNoVe5Q86P5yz2Ad"]],["Hash","jwdEug2AL1iCDDXQpFUbMptiryaU1BRaqV6aL4rnknp7ZcdsT8k"]],["Hash","jxfwfExD2JRGmfwaLkUS2g1HpH896umBLKq3e865m1SbLJW6CrT"]],["Hash","jw8DqJUfNarG33bpL9rUySBwrfBuz7fRHZr5TEvALMS5Rb2S7jE"]],["Hash","jxQLSBPmWYGRDRQaUE7Ye21jhsb185H25nWSSYtg8drSemrQA4P"]],["Hash","jxFokLd9y68j9htcedV8ThzPa8me8kX5FNeRmvVo75NyrqZTLgx"]],"next_available_token":"2"}
|json}
        )
      ; ( {json|
[
  "Command",
  [
    "Signed_command",
    {
      "payload": {
        "common": {
          "fee": "0",
          "fee_token": "1",
          "fee_payer_pk":
            "B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE",
          "nonce": "0",
          "valid_until": "255571053",
          "memo": "E4QsCcdyM6G1Cth5QKT14LnuGcMgJDzSdR7kPZARaSA2os67E1oRW"
        },
        "body": [
          "Stake_delegation",
          [
            "Set_delegate",
            {
              "delegator":
                "B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE",
              "new_delegate":
                "B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE"
            }
          ]
        ]
      },
      "signer": "B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE",
      "signature":
        "7mX63n8dCk3HXTZNbT7MF4cnmPJGb1xXxkg1qhMoARvijN3PMGceTi71jiVyo1f1deg9DJSpjMGTECB3mYpUB8vQ6x9CQjcB"
    }
  ]
]
|json}
        , {json|
{"indexes":[[["B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE","1"],0]],"depth":10,"tree":["Node","jwLRMxvbBU31KmLtEpApzwFFkG5U6C6Vs3XZnw8vzDQJt85EDdK",["Node","jwmhEsU9gv86qUdiyd2LLK8xFezNgc7VNenHJJrwz4xgbMNAXNP",["Node","jxZiDu3G32ckUvwwNMGLzSWHhgKF2ZHuyd9nvdCdW7g4xEy2i3Z",["Node","jxfTKqPjMYWhjoRk8u7gGPr2JeRVqT6knAjfHaQ1xN1FJzqZcQo",["Node","jxchHaqhYBkB1JyegA8q9fyxHCkLrmRNNA1DbL7ANGfB9qDFYPe",["Node","jxJ5RiQLddGxZ6LNcmGnRNhECoVqW6DhAWamZBRokC98xTfbNXY",["Node","jxCSYq3DjvasUknRdYTZyMWxKFqg2BaJ5UvKeHgeWLnuQynbABT",["Node","jxa9rRM9iJ4jq1Z3xthLyiYTLgCLDHNQeKWhJBipsxuhaMDkqyd",["Node","jxTtxGDDatStBD8spdSEgiq2JHZi6ZMDKwFE3HkV8fSXo7K64gr",["Node","jx5e2UBCPx6TMHUy6aN5i9NMfhCyBxnAJmRs2UTmATCkuCZceSK",["Account",{"public_key":"B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE","token_id":"1","token_permissions":["Not_owned",{"account_disabled":false}],"balance":"17009607841493601729","nonce":"0","receipt_chain_hash":"2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe","delegate":"B62qpeSLPUieLnbs8fJncbZ9qwxJSTFGDHDhMUWxwg1uFxG6jrBSFjE","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Timed",{"initial_minimum_balance":"4135254886733070390","cliff_time":"0","cliff_amount":"0","vesting_period":"16","vesting_increment":"8483500404270949136"}],"permissions":{"stake":true,"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"]},"snapp":null}],["Hash","jwxHKCNJsFjFJrxSusJ1SnzFLJWosGRFdR5iNznUo3VJPA3fTXX"]],["Hash","jxXGdw6qfqz96eqvitzV2yJ4Tawk1PhqyjF86e3n4ZNPwmDmp5T"]],["Hash","jxPA47eC73ibqELdRRE5fN3paDzecBfiZ5Nfaj3f6xc4Rkgy2eZ"]],["Hash","jxFGQbPEuwz8DWnhAwuYypdiX6aBCkc55RPF6poUfFSikDK64GU"]],["Hash","jwSjnoWdZ2wyyUhesr6eoxbhcFjHVLBWHHiPNoVe5Q86P5yz2Ad"]],["Hash","jwdEug2AL1iCDDXQpFUbMptiryaU1BRaqV6aL4rnknp7ZcdsT8k"]],["Hash","jxfwfExD2JRGmfwaLkUS2g1HpH896umBLKq3e865m1SbLJW6CrT"]],["Hash","jw8DqJUfNarG33bpL9rUySBwrfBuz7fRHZr5TEvALMS5Rb2S7jE"]],["Hash","jxQLSBPmWYGRDRQaUE7Ye21jhsb185H25nWSSYtg8drSemrQA4P"]],["Hash","jxFokLd9y68j9htcedV8ThzPa8me8kX5FNeRmvVo75NyrqZTLgx"]],"next_available_token":"2"}
|json}
        )
      ]

    let%test "one" =
      let passed = ref true in
      List.iter txn_jsons ~f:(fun (txn_json, ledger_json) ->
          let transaction =
            Transaction.Valid.of_yojson (Yojson.Safe.from_string txn_json)
            |> Result.ok_or_failwith
          in
          let ledger =
            Sparse_ledger.of_yojson (Yojson.Safe.from_string ledger_json)
            |> Result.ok_or_failwith
          in
          try check_consistent ledger transaction
          with exn ->
            let error = Error.of_exn ~backtrace:`Get exn in
            passed := false ;
            Format.printf
              "The following transaction was inconsistently \
               applied:@.%s@.%s@.%s@."
              (Yojson.Safe.pretty_to_string
                 (Transaction.Valid.to_yojson transaction) )
              (Yojson.Safe.to_string (Sparse_ledger.to_yojson ledger))
              (Yojson.Safe.pretty_to_string (Error_json.error_to_yojson error)) ) ;
      !passed
  end )
