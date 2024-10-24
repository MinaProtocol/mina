open Core
open Currency
open Genesis_ledger

let create ~(test_config : Test_config.t) ~(genesis_ledger : Genesis_ledger.t) =
  { Runtime_config.daemon =
      Some
        { Runtime_config.Daemon.default with
          txpool_max_size = Some test_config.txpool_max_size
        ; slot_tx_end = test_config.slot_tx_end
        ; slot_chain_end = test_config.slot_chain_end
        ; network_id = test_config.network_id
        }
  ; genesis =
      Some
        { k = Some test_config.k
        ; delta = Some test_config.delta
        ; slots_per_epoch = Some test_config.slots_per_epoch
        ; slots_per_sub_window = Some test_config.slots_per_sub_window
        ; grace_period_slots = Some test_config.grace_period_slots
        ; genesis_state_timestamp =
            Some Core.Time.(to_string_abs ~zone:Zone.utc (now ()))
        }
  ; proof =
      Some test_config.proof_config (* TODO: prebake ledger and only set hash *)
  ; ledger =
      Some
        { base =
            Accounts
              (List.map genesis_ledger.accounts ~f:(fun (_name, acct) -> acct))
        ; add_genesis_winner = None
        ; num_accounts = None
        ; balances = []
        ; hash = None
        ; s3_data_hash = None
        ; name = None
        }
  ; epoch_data =
      (* each staking epoch ledger account must also be a genesis ledger account, though
         the balance may be different; the converse is not necessarily true, since
         an account may have been added after the last epoch ledger was taken

         each staking epoch ledger account must also be in the next epoch ledger, if provided

         if provided, each next_epoch_ledger account must be in the genesis ledger

         in all ledgers, the accounts must be in the same order, so that accounts will
         be in the same leaf order
      *)
      Option.map test_config.epoch_data
        ~f:(fun { staking = staking_ledger; next } ->
          let ledger_is_prefix ledger1 ledger2 =
            List.is_prefix ledger2 ~prefix:ledger1
              ~equal:(fun
                       ({ account_name = name1; _ } : Test_config.Test_account.t)
                       ({ account_name = name2; _ } : Test_config.Test_account.t)
                     -> String.equal name1 name2 )
          in
          let genesis_winner_account : Runtime_config.Accounts.single =
            Runtime_config.Accounts.Single.of_account
              Mina_state.Consensus_state_hooks.genesis_winner_account
            |> Result.ok_or_failwith
          in
          let ledger_of_epoch_accounts
              (epoch_accounts : Test_config.Test_account.t list) =
            let epoch_ledger_accounts =
              List.map epoch_accounts
                ~f:(fun { account_name; balance; timing; permissions; zkapp } ->
                  let balance = Balance.of_mina_string_exn balance in
                  let timing = runtime_timing_of_timing timing in
                  let genesis_account =
                    match
                      List.Assoc.find genesis_ledger.accounts account_name
                        ~equal:String.equal
                    with
                    | Some acct ->
                        acct
                    | None ->
                        failwithf
                          "Epoch ledger account %s not in genesis ledger"
                          account_name ()
                  in
                  { genesis_account with
                    balance
                  ; timing
                  ; permissions =
                      Option.map
                        ~f:
                          Runtime_config.Accounts.Single.Permissions
                          .of_permissions permissions
                  ; zkapp =
                      Option.map
                        ~f:Runtime_config.Accounts.Single.Zkapp_account.of_zkapp
                        zkapp
                  } )
            in
            ( { base = Accounts (genesis_winner_account :: epoch_ledger_accounts)
              ; add_genesis_winner = None (* no effect *)
              ; num_accounts = None
              ; balances = []
              ; hash = None
              ; s3_data_hash = None
              ; name = None
              }
              : Runtime_config.Ledger.t )
          in
          let staking =
            let ({ epoch_ledger; epoch_seed } : Test_config.Epoch_data.Data.t) =
              staking_ledger
            in
            if not (ledger_is_prefix epoch_ledger test_config.genesis_ledger)
            then failwith "Staking epoch ledger not a prefix of genesis ledger" ;
            let ledger = ledger_of_epoch_accounts epoch_ledger in
            let seed = epoch_seed in
            ({ ledger; seed } : Runtime_config.Epoch_data.Data.t)
          in
          let next =
            Option.map next ~f:(fun { epoch_ledger; epoch_seed } ->
                if
                  not
                    (ledger_is_prefix staking_ledger.epoch_ledger epoch_ledger)
                then
                  failwith
                    "Staking epoch ledger not a prefix of next epoch ledger" ;
                if
                  not (ledger_is_prefix epoch_ledger test_config.genesis_ledger)
                then failwith "Next epoch ledger not a prefix of genesis ledger" ;
                let ledger = ledger_of_epoch_accounts epoch_ledger in
                let seed = epoch_seed in
                ({ ledger; seed } : Runtime_config.Epoch_data.Data.t) )
          in
          ({ staking; next } : Runtime_config.Epoch_data.t) )
  }
