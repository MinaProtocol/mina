(* values.ml -- values for heap_usage app *)

open Core_kernel

let sample_pk = Quickcheck.random_value Signature_lib.Public_key.gen

let sample_pk_compressed = Signature_lib.Public_key.compress sample_pk

let account : Mina_base.Account.t =
  (* if there's a zkApp account, size is almost constant
     the zkapp_uri field is not currently bounded in size
  *)
  let zkapp_account : Mina_base.Zkapp_account.t =
    let app_state =
      Pickles_types.Vector.to_list Mina_base.Zkapp_account.default.app_state
      |> Pickles_types.Vector.Vector_8.of_list_exn
    in
    { Mina_base.Zkapp_account.default with
      app_state
    ; verification_key =
        Some
          With_hash.
            { data = Pickles.Side_loaded.Verification_key.dummy
            ; hash = Mina_base.Zkapp_account.dummy_vk_hash ()
            }
    ; zkapp_uri =
        "https://www.example.com/this-is-a-decently-long-url/latest-zkapp-implementation.html"
    }
  in
  { Mina_base.Account.empty with
    token_symbol = "123456"
  ; zkapp = Some zkapp_account
  }

(* beefy zkapp command with all proof updates *)
let zkapp_command =
  let num_updates = 16 in
  let _ledger, zkapp_commands =
    Snark_profiler_lib.create_ledger_and_zkapps ~min_num_updates:num_updates
      ~num_proof_updates:num_updates ~max_num_updates:num_updates ()
  in
  List.hd_exn zkapp_commands

let zkapp_proof =
  List.fold_until
    (Mina_base.Zkapp_command.all_account_updates_list zkapp_command)
    ~init:None
    ~f:(fun _acc a ->
      match a.Mina_base.Account_update.authorization with
      | Proof proof ->
          Stop (Some proof)
      | _ ->
          Continue None )
    ~finish:Fn.id
  |> Option.value_exn

let dummy_proof =
  Pickles.Proof.dummy Pickles_types.Nat.N2.n Pickles_types.Nat.N2.n
    Pickles_types.Nat.N2.n ~domain_log2:16

let dummy_vk = Mina_base.Side_loaded_verification_key.dummy

let verification_key =
  let `VK vk, `Prover _ =
    Transaction_snark.For_tests.create_trivial_snapp
      ~constraint_constants:Genesis_constants.Constraint_constants.compiled ()
  in
  With_hash.data vk

let applied = Mina_base.Transaction_status.Applied

let mk_scan_state_base_node
    (varying : Mina_transaction_logic.Transaction_applied.Varying.t) :
    Transaction_snark_scan_state.Transaction_with_witness.t Parallel_scan.Base.t
    =
  let weight : Parallel_scan.Weight.t = { base = 42; merge = 99 } in
  let job :
      Transaction_snark_scan_state.Transaction_with_witness.t
      Parallel_scan.Base.Job.t =
    let get = Quickcheck.random_value in
    let state_hash = get Mina_base.State_hash.gen in
    let state_body_hash = get Mina_base.State_body_hash.gen in
    let statement = get Transaction_snark.Statement.gen in
    let init_stack =
      Transaction_snark.Pending_coinbase_stack_state.Init_stack.Merge
    in
    let ledger_witness =
      let depth =
        Genesis_constants.Constraint_constants.compiled.ledger_depth
      in
      let account_access_statuses =
        match varying with
        | Command (Signed_command signed_cmd) ->
            let user_cmd = signed_cmd.common.user_command.data in
            Mina_base.Signed_command.account_access_statuses user_cmd applied
        | Command (Zkapp_command zkapp_cmd) ->
            let zkapp_cmd = zkapp_cmd.command.data in
            Mina_base.Zkapp_command.account_access_statuses zkapp_cmd applied
        | Fee_transfer ft ->
            let fee_transfer = ft.fee_transfer.data in
            List.map (Mina_base.Fee_transfer.receivers fee_transfer)
              ~f:(fun acct_id -> (acct_id, `Accessed))
        | Coinbase cb ->
            let coinbase = cb.coinbase.data in
            Mina_base.Coinbase.account_access_statuses coinbase applied
      in
      let num_accounts_accessed =
        List.count account_access_statuses ~f:(fun (_acct_id, accessed) ->
            match accessed with `Accessed -> true | `Not_accessed -> false )
      in
      (* for zkApps, some or all of the accounts will be zkApp accounts, so this
         understates mem usage
      *)
      let ledger = Mina_ledger.Ledger.create ~depth () in
      let accounts =
        Quickcheck.random_value
        @@ Quickcheck.Generator.list_with_length num_accounts_accessed
             Mina_base.Account.gen
      in
      List.iter accounts ~f:(fun acct ->
          ignore
            ( Mina_ledger.Ledger.get_or_create_account ledger
                (Mina_base.Account.identifier acct)
                acct
              : _ ) ) ;
      Mina_ledger.Sparse_ledger.of_any_ledger
        (Mina_ledger.Ledger.Any_ledger.cast (module Mina_ledger.Ledger) ledger)
    in
    let transaction_with_info : Mina_transaction_logic.Transaction_applied.t =
      let previous_hash = get Mina_base.Ledger_hash.gen in
      { previous_hash; varying }
    in
    let job : Transaction_snark_scan_state.Transaction_with_witness.t =
      { transaction_with_info
      ; state_hash = (state_hash, state_body_hash)
      ; statement
      ; init_stack
      ; first_pass_ledger_witness = ledger_witness
      ; second_pass_ledger_witness = ledger_witness
      ; block_global_slot = Mina_numbers.Global_slot_since_genesis.zero
      }
    in
    let record : _ Parallel_scan.Base.Record.t =
      { job; seq_no = 1; status = Todo }
    in
    Full record
  in
  (weight, job)

let scan_state_base_node_coinbase =
  let varying : Mina_transaction_logic.Transaction_applied.Varying.t =
    let coinbase =
      Mina_base.Coinbase.create ~amount:Currency.Amount.zero
        ~receiver:sample_pk_compressed ~fee_transfer:None
      |> Or_error.ok_exn
    in
    Coinbase
      { coinbase = Mina_base.With_status.{ data = coinbase; status = Applied }
      ; new_accounts = []
      ; burned_tokens = Currency.Amount.zero
      }
  in
  mk_scan_state_base_node varying

let scan_state_base_node_payment =
  let varying : Mina_transaction_logic.Transaction_applied.Varying.t =
    let payload : Mina_base.Signed_command_payload.t =
      let payment_payload =
        Quickcheck.random_value
          (Mina_base.Payment_payload.gen Currency.Amount.zero)
      in
      let body : Mina_base.Signed_command_payload.Body.t =
        Payment payment_payload
      in
      let common : Mina_base.Signed_command_payload.Common.t =
        { fee = Currency.Fee.zero
        ; fee_payer_pk = sample_pk_compressed
        ; nonce = Mina_numbers.Account_nonce.zero
        ; valid_until = Mina_numbers.Global_slot_since_genesis.max_value
        ; memo = Mina_base.Signed_command_memo.empty
        }
      in
      { common; body }
    in
    let user_command : _ Mina_base.With_status.t =
      let signer = sample_pk in
      let data : Mina_base.Signed_command.t =
        { payload; signer; signature = Mina_base.Signature.dummy }
      in
      { data; status = Applied }
    in
    let common :
        Mina_transaction_logic.Transaction_applied.Signed_command_applied.Common
        .t =
      { user_command }
    in
    let body :
        Mina_transaction_logic.Transaction_applied.Signed_command_applied.Body.t
        =
      Payment { new_accounts = [] }
    in
    Command (Signed_command { common; body })
  in
  mk_scan_state_base_node varying

let scan_state_base_node_zkapp =
  let varying : Mina_transaction_logic.Transaction_applied.Varying.t =
    let zkapp_command_applied :
        Mina_transaction_logic.Transaction_applied.Zkapp_command_applied.t =
      let accounts =
        (* fudge: the `accounts` calculation is more complex; see `apply_zkapp_command_unchecked_aux`
           also, we're using the same account repeatedly
        *)
        let accessed =
          Mina_base.Zkapp_command.account_access_statuses zkapp_command applied
          |> List.filter_map ~f:(fun (acct_id, accessed) ->
                 match accessed with
                 | `Accessed ->
                     Some acct_id
                 | `Not_accessed ->
                     None )
        in
        List.map accessed ~f:(fun acct_id -> (acct_id, Some account))
      in
      let command =
        Mina_base.With_status.{ data = zkapp_command; status = applied }
      in
      let new_accounts = [] in
      { accounts; command; new_accounts }
    in
    Command (Zkapp_command zkapp_command_applied)
  in
  mk_scan_state_base_node varying

let scan_state_merge_node :
    Transaction_snark_scan_state.Ledger_proof_with_sok_message.t
    Parallel_scan.Merge.t =
  let weight1 : Parallel_scan.Weight.t = { base = 42; merge = 99 } in
  let weight2 : Parallel_scan.Weight.t = { base = 88; merge = 77 } in
  let job :
      Transaction_snark_scan_state.Ledger_proof_with_sok_message.t
      Parallel_scan.Merge.Job.t =
    let left =
      let sok_msg : Mina_base.Sok_message.t =
        { fee = Currency.Fee.zero; prover = sample_pk_compressed }
      in
      let proof = Mina_base.Proof.transaction_dummy in
      let statement =
        let without_sok =
          Quickcheck.random_value ~seed:(`Deterministic "no sok left")
            Transaction_snark.Statement.gen
        in
        { without_sok with sok_digest = Mina_base.Sok_message.digest sok_msg }
      in
      let ledger_proof = Transaction_snark.create ~statement ~proof in
      (ledger_proof, sok_msg)
    in
    let right =
      let sok_msg : Mina_base.Sok_message.t =
        { fee = Currency.Fee.zero; prover = sample_pk_compressed }
      in
      (* so the left, right proofs differ, don't want sharing *)
      let proof = Mina_base.Proof.blockchain_dummy in
      let statement =
        let without_sok =
          Quickcheck.random_value ~seed:(`Deterministic "no sok right")
            Transaction_snark.Statement.gen
        in
        { without_sok with sok_digest = Mina_base.Sok_message.digest sok_msg }
      in
      let ledger_proof = Transaction_snark.create ~statement ~proof in
      (ledger_proof, sok_msg)
    in
    Full { left; right; seq_no = 1; status = Todo }
  in
  ((weight1, weight2), job)

let protocol_state =
  (* size is fixed *)
  let json =
    Yojson.Safe.from_string
      {json|
{
  "previous_state_hash": "3NKferWCWXycpwMdonyEMbbzViTgTkQrioeBKYMmLZFcYvC4CK9Y",
  "body": {
    "genesis_state_hash": "3NKv6abeNz6uwAifpH7UmYi1NoAaiJXpQx1FKoDMUM7UD3v38ycB",
    "blockchain_state": {
      "staged_ledger_hash": {
        "non_snark": {
          "ledger_hash": "jweiMPcLyK5S9gojzFySVNU7QFYqNkzd2KDd4WoHzJ5QDk6iUvv",
          "aux_hash": "VP3JQqSRC89B9jssP8oDX5otYuiK2gjqDjxnu2rLu2YmUPMnjF",
          "pending_coinbase_aux": "Wb66BTQUERqbNyqudPDrKUuxeUPAUDCFDnRFcp8psdDp9J6aWj"
        },
        "pending_coinbase_hash": "2n1wauVtowJ7AK4VM77uePevFi9VawJjpdx8Ld8f9PNDwrMBFRCQ"
      },
      "genesis_ledger_hash": "jxx14ajKiweveJ7iAxtzTiLfAm3KXj5Y4MMvkbLc2qhi2LYnzLS",
      "ledger_proof_statement": {
        "source": {
          "first_pass_ledger": "jw8by1TB1dqKwsj5NnPBZXiYnb291qe952gA7dhoeDo1VbzAAnB",
          "second_pass_ledger": "jxmWGjNGaQNfoSuCfKamSGASFso7Xvbcqzzn1E3aA9iwwPV77Zq",
          "pending_coinbase_stack": {
            "data": "4QNrZFBTDQCPfEZqBZsaPYx8qdaNFv1nebUyCUsQW9QUJqyuD3un",
            "state": {
              "init": "4Yyn1M4UrgyM5eRbAC1gVYkABx2mdTVDETmrAtAg5DsgnJYw9gNk",
              "curr": "4Yyn1M4UrgyM5eRbAC1gVYkABx2mdTVDETmrAtAg5DsgnJYw9gNk"
            }
          },
          "local_state": {
            "stack_frame": "0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C",
            "call_stack": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "full_transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "excess": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "supply_increase": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "ledger": "jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd",
            "success": true,
            "account_update_index": "0",
            "failure_status_tbl": [],
            "will_succeed": true
          }
        },
        "target": {
          "first_pass_ledger": "jwDuoXtzggxSeFpfepCqHAvoqnp7feWUPjRx5n8e2ToHey5qk59",
          "second_pass_ledger": "jwGo7QJzxT2STkRzevRYQ1d79WAzYsFSgEFpSZZwcdptR7BWbZ7",
          "pending_coinbase_stack": {
            "data": "4QPi7S6Nx2h9g4NL7pTEH4mwovbWp8BdzpmGgn2qdRgUqbWgzE3z",
            "state": {
              "init": "4Yyn1M4UrgyM5eRbAC1gVYkABx2mdTVDETmrAtAg5DsgnJYw9gNk",
              "curr": "4YywETD4jxed7LJbpcDoQutFuMKA4zZhZKv71jzYM2QM424JTjki"
            }
          },
          "local_state": {
            "stack_frame": "0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C",
            "call_stack": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "full_transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "excess": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "supply_increase": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "ledger": "jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd",
            "success": true,
            "account_update_index": "0",
            "failure_status_tbl": [],
            "will_succeed": true
          }
        },
        "connecting_ledger_left": "jxmWGjNGaQNfoSuCfKamSGASFso7Xvbcqzzn1E3aA9iwwPV77Zq",
        "connecting_ledger_right": "jwGo7QJzxT2STkRzevRYQ1d79WAzYsFSgEFpSZZwcdptR7BWbZ7",
        "supply_increase": {
          "magnitude": "7909000000000",
          "sgn": [
            "Pos"
          ]
        },
        "fee_excess": [
          {
            "token": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
            "amount": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            }
          },
          {
            "token": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
            "amount": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            }
          }
        ],
        "sok_digest": null
      },
      "timestamp": "1681333381000",
      "body_reference": "3adcbf1033e561e2db28eb5504b7245328f3a092aafd327a2ec306231ab8efb5"
    },
    "consensus_state": {
      "blockchain_length": "1654",
      "epoch_count": "0",
      "min_window_density": "36",
      "sub_window_densities": [
        "5",
        "6",
        "4",
        "5",
        "5",
        "3",
        "2",
        "3",
        "2",
        "3",
        "6"
      ],
      "last_vrf_output": "q4zrn2ZlIeTV8_8XPb3PZu4eQusG0n5ieUNy5gyZAAA=",
      "total_currency": "1014488754000001000",
      "curr_global_slot": {
        "slot_number": ["Since_hard_fork","2831"],
        "slots_per_epoch": "7140"
      },
      "global_slot_since_genesis": ["Since_genesis","2831"],
      "staking_epoch_data": {
        "ledger": {
          "hash": "jxx14ajKiweveJ7iAxtzTiLfAm3KXj5Y4MMvkbLc2qhi2LYnzLS",
          "total_currency": "1013459001000001000"
        },
        "seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
        "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
        "lock_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
        "epoch_length": "1"
      },
      "next_epoch_data": {
        "ledger": {
          "hash": "jxx14ajKiweveJ7iAxtzTiLfAm3KXj5Y4MMvkbLc2qhi2LYnzLS",
          "total_currency": "1013459001000001000"
        },
        "seed": "2vbvpHfr7VjXc5sk1TRTFUe9Nkin4TK4tgyEok51ksurkAm8a7R6",
        "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
        "lock_checkpoint": "3NKferWCWXycpwMdonyEMbbzViTgTkQrioeBKYMmLZFcYvC4CK9Y",
        "epoch_length": "1655"
      },
      "has_ancestor_in_same_checkpoint_window": true,
      "block_stake_winner": "B62qnPFcFSb14MwxDhn2fZYmqNEpHzpREijsy8CVkJY5hekzh1ghdQQ",
      "block_creator": "B62qoebzV8WgrC8Gb1csZXjZLtSQNgMYPE6QXKT743mrioj6JXRXHJ1",
      "coinbase_receiver": "B62qoebzV8WgrC8Gb1csZXjZLtSQNgMYPE6QXKT743mrioj6JXRXHJ1",
      "supercharge_coinbase": true
    },
    "constants": {
      "k": "290",
      "slots_per_epoch": "7140",
      "slots_per_sub_window": "7",
      "delta": "0",
      "genesis_state_timestamp": "1680823801000"
    }
  }
}
      |json}
  in
  Mina_state.Protocol_state.value_of_yojson json |> Result.ok_or_failwith

let pending_coinbase =
  (* size is fixed, given a particular depth *)
  let depth =
    Genesis_constants.Constraint_constants.compiled.pending_coinbase_depth
  in
  Mina_base.Pending_coinbase.create ~depth () |> Or_error.ok_exn

let staged_ledger_diff =
  (* size varies, depending on number and size of commands *)
  let json =
    Yojson.Safe.from_string
      {json|
  {
      "diff": [
        {
          "completed_works": [],
          "commands": [
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
                  "signature": "7mXFbws8zFVHDngRcRgUAs9gvWcJ4ZDmXrjXozyhhNyM1KrR2XsBzSQGDSR4ghD5Dip13iFrnweGKB5mguDmDLhk1h87etB8"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
                  "signature": "7mXJfHCobCvXcpAZRKgqmnrsewVuEcUaQ2dkjfYuodwqR2bYZUZkmJZmNoTKM9HJ8tV6hW7pRFjL7oeNvzbRiPGt9pyf93hJ"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
                  "signature": "7mX5n1jgC1m2jhuo7JMks6veDCNofPXZwFeZLv47ok83RVQkftUFKcD35k4RTo2v7fyroQjB9LSRJHm3S7RQfzesJwJtcFqS"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
                  "signature": "7mX2irhVDZy7bbc6K6q21hpQiB3x7LKw9v6jS5tZBzzEdroQFc5hzT1MwgzK2CavFX6ZkAcHYaxKAz8qwAdruerR7mbFLKa6"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
                  "signature": "7mX5N43QQWMjKoXo2bAwPo6jvHNfpVcMse51uy6eXumfWiChmWQb2hejbTn9MaNsYcpNhDpd4oFnsdzqzDveaRuq8xRRJxmK"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
                  "signature": "7mXFA6dbZCNV7bowrxiWK5zCST3YurHRNiC6m7n39jUgu6jC7VMV3g9xLEP8sraVfoUHhsfaMyYgdXAXmYEgU3WJwdZdqe8Q"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
                  "signature": "7mX4KgEbFoWZjtNn4ihvSpVaEKGMUVXWVAJuvyrPWWst1miV7eBXLnhRc1V5RfCJ2bvLDrTdCqEhJmaUJMwdTgCF7rFGYcFY"
                }
              ],
              "status": [
                "Applied"
              ]
            }
          ],
          "coinbase": [
            "One",
            null
          ],
          "internal_command_statuses": [
            [
              "Applied"
            ]
          ]
        },
        null
      ]
    }
      |json}
  in
  Staged_ledger_diff.of_yojson json |> Result.ok_or_failwith

let merkle_path =
  (* size is constant for a given length, assuming each hash is distinct *)
  let ledger_depth =
    Genesis_constants.Constraint_constants.compiled.ledger_depth
  in
  let hashes =
    Quickcheck.random_value
    @@ Quickcheck.Generator.list_with_length ledger_depth
         Mina_base.Ledger_hash.gen
  in
  let path : Mina_ledger.Ledger.Db.Path.t =
    List.mapi hashes ~f:(fun n hash ->
        if n % 2 = 0 then `Left hash else `Right hash )
  in
  path

let transaction_snark_statement =
  Quickcheck.random_value Transaction_snark.Statement.gen
