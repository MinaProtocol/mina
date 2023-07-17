(* itn.ml -- code for incentivized testnet *)

open Core
open Async
open Signature_lib
open Mina_base
open Mina_transaction

let create_accounts port (privkey_path, key_prefix, num_accounts, fee, amount) =
  let keys_per_zkapp = 8 in
  let zkapps_per_block = 10 in
  let pk_check_wait = Time.Span.of_sec 10. in
  let pk_check_timeout = Time.Span.of_min 30. in
  let min_fee =
    Currency.Fee.to_nanomina_int Currency.Fee.minimum_user_command_fee
  in
  let account_creation_fee_int =
    let constraint_constants =
      Genesis_constants.Constraint_constants.compiled
    in
    Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee
  in
  if fee < min_fee then (
    Format.eprintf "Minimum fee is %d@." min_fee ;
    Core.exit 1 ) ;
  if not @@ Option.is_some @@ Sys.getenv Secrets.Keypair.env then (
    Format.eprintf "Please set environment variable %s@." Secrets.Keypair.env ;
    Core.exit 1 ) ;
  let%bind fee_payer_keypair =
    Secrets.Keypair.Terminal_stdin.read_exn ~which:"Mina fee payer keypair"
      privkey_path
  in
  let fee_payer_account_id =
    let pk =
      fee_payer_keypair.public_key |> Signature_lib.Public_key.compress
    in
    Account_id.create pk Token_id.default
  in
  let%bind fee_payer_balance =
    match%bind
      Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_balance.rpc
        fee_payer_account_id port
    with
    | Ok (Ok (Some balance)) ->
        Deferred.return balance
    | Ok (Ok None) ->
        Format.eprintf "Could not get fee payer balance" ;
        exit 1
    | Ok (Error err) ->
        Format.eprintf "Error getting fee payer balance: %s@."
          (Error.to_string_hum err) ;
        exit 1
    | Error err ->
        Format.eprintf "Failed to get fee payer balance, error: %s@."
          (Error.to_string_hum err) ;
        exit 1
  in
  let fee_payer_balance_as_amount =
    Currency.Balance.to_amount fee_payer_balance
  in
  let%bind fee_payer_initial_nonce =
    (* inferred nonce considers txns in pool, in addition to ledger *)
    match%map
      Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_inferred_nonce.rpc
        fee_payer_account_id port
    with
    | Ok (Ok (Some nonce)) ->
        Account.Nonce.of_uint32 nonce
    | Ok (Ok None) ->
        Format.eprintf "No account found for fee payer@." ;
        Core.exit 1
    | Ok (Error err) | Error err ->
        Format.eprintf "Failed to get fee payer nonce: %s@."
          (Error.to_string_hum err) ;
        Core.exit 1
  in
  Format.printf "Fee payer public key: %s, initial nonce = %d@."
    ( Account_id.public_key fee_payer_account_id
    |> Public_key.Compressed.to_base58_check )
    (Account.Nonce.to_int fee_payer_initial_nonce) ;
  let fee_payer_current_nonce = ref fee_payer_initial_nonce in
  let keypairs =
    List.init num_accounts ~f:(fun _n -> Signature_lib.Keypair.create ())
  in
  let%bind () =
    Deferred.List.iteri keypairs ~f:(fun i kp ->
        let privkey_path = sprintf "%s-%d" key_prefix i in
        let pk =
          Signature_lib.Public_key.compress kp.public_key
          |> Signature_lib.Public_key.Compressed.to_base58_check
        in
        Format.printf "Writing key file %s for public key %s@." privkey_path pk ;
        Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path )
  in
  let keypair_chunks = List.chunks_of keypairs ~length:keys_per_zkapp in
  let num_chunks = List.length keypair_chunks in
  (* amount + fees must not be more than fee payer balance *)
  let amount_and_fees =
    let total_fees = num_chunks * fee in
    Currency.Amount.of_nanomina_int_exn (amount + total_fees)
  in
  if Currency.Amount.( > ) amount_and_fees fee_payer_balance_as_amount then (
    Format.eprintf
      !"Amount plus fees (%{sexp: Currency.Amount.t}) is greater than fee \
        payer balance (%{sexp: Currency.Amount.t})@."
      amount_and_fees fee_payer_balance_as_amount ;
    Core.exit 1 ) ;
  let amount_per_key = amount / num_accounts in
  let chunk_amounts =
    Array.init num_chunks ~f:(fun i ->
        let chunk_len = List.length (List.nth_exn keypair_chunks i) in
        chunk_len * amount_per_key )
  in
  let rec top_off_chunks i total =
    if total < amount then (
      chunk_amounts.(i) <- chunk_amounts.(i) + 1 ;
      top_off_chunks ((i + 1) mod num_chunks) (total + 1) )
  in
  let chunk_total = Array.fold chunk_amounts ~init:0 ~f:( + ) in
  top_off_chunks 0 chunk_total ;
  assert (Array.fold chunk_amounts ~init:0 ~f:( + ) = amount) ;
  let zkapps =
    List.mapi keypair_chunks ~f:(fun i kps ->
        let num_updates = List.length kps in
        let chunk_amount = chunk_amounts.(i) in
        if Int.is_negative chunk_amount then (
          Format.eprintf
            "Calculated negative amount for chunk of account updates; increase \
             amount or lower fee@." ;
          Core.exit 1 ) ;
        let amount_per_update =
          (chunk_amount / num_updates) - account_creation_fee_int
        in
        let update_rem = chunk_amount mod num_updates in
        let update_amounts =
          Array.init num_updates ~f:(fun i ->
              if i < update_rem then amount_per_update + 1
              else amount_per_update )
        in
        assert (
          Array.fold update_amounts ~init:0 ~f:( + )
          = chunk_amount - (num_updates * account_creation_fee_int) ) ;
        let memo_str = sprintf "ITN account funder, chunk %d" i in
        let memo = Signed_command_memo.create_from_string_exn memo_str in
        let multispec : Transaction_snark.For_tests.Multiple_transfers_spec.t =
          let fee = Currency.Fee.of_nanomina_int_exn fee in
          let sender = (fee_payer_keypair, !fee_payer_current_nonce) in
          let fee_payer = None in
          let receivers =
            List.mapi kps ~f:(fun j kp ->
                let pk = kp.public_key |> Signature_lib.Public_key.compress in
                let amount =
                  update_amounts.(j) |> Currency.Amount.of_nanomina_int_exn
                in
                (pk, amount) )
          in
          let amount = chunk_amount |> Currency.Amount.of_nanomina_int_exn in
          let zkapp_account_keypairs = [] in
          let new_zkapp_account = false in
          let snapp_update = Account_update.Update.dummy in
          let actions = [] in
          let events = [] in
          let call_data = Snark_params.Tick.Field.zero in
          let preconditions = Some Account_update.Preconditions.accept in
          { fee
          ; sender
          ; fee_payer
          ; receivers
          ; amount
          ; zkapp_account_keypairs
          ; memo
          ; new_zkapp_account
          ; snapp_update
          ; actions
          ; events
          ; call_data
          ; preconditions
          }
        in
        fee_payer_current_nonce := Account.Nonce.succ !fee_payer_current_nonce ;
        Transaction_snark.For_tests.multiple_transfers multispec )
  in
  let zkapps_batches = List.chunks_of zkapps ~length:zkapps_per_block in
  Deferred.List.iter zkapps_batches ~f:(fun zkapps_batch ->
      Format.printf "Processing batch of %d zkApps@." (List.length zkapps_batch) ;
      List.iteri zkapps_batch ~f:(fun i zkapp ->
          let txn_hash =
            Transaction_hash.hash_command (Zkapp_command zkapp)
            |> Transaction_hash.to_base58_check
          in
          Format.printf " zkApp %d, transaction hash: %s@." i txn_hash ;
          Format.printf " Fee payer: %s, nonce: %d@."
            (Signature_lib.Public_key.Compressed.to_base58_check
               zkapp.fee_payer.body.public_key )
            (Account.Nonce.to_int zkapp.fee_payer.body.nonce) ;
          Format.printf " Account updates@." ;
          Zkapp_command.Call_forest.iteri zkapp.account_updates
            ~f:(fun _i acct_update ->
              let pk =
                Signature_lib.Public_key.Compressed.to_base58_check
                  acct_update.body.public_key
              in
              let balance_change = acct_update.body.balance_change in
              let sgn =
                if Currency.Amount.Signed.is_negative balance_change then "-"
                else ""
              in
              let balance_change_str =
                match
                  Currency.Amount.to_yojson
                  @@ Currency.Amount.Signed.magnitude balance_change
                with
                | `String s ->
                    s
                | _ ->
                    failwith "Expected string"
              in
              Format.printf "  Public key: %s  Balance change: %s%s@." pk sgn
                balance_change_str ) ) ;
      let%bind res =
        Daemon_rpcs.Client.dispatch Daemon_rpcs.Send_zkapp_commands.rpc
          zkapps_batch port
      in
      ( match res with
      | Ok res_inner -> (
          match res_inner with
          | Ok zkapps ->
              Format.printf "Successfully sent %d zkApps to transaction pool@."
                (List.length zkapps)
          | Error err ->
              Format.eprintf "When sending zkApps, got error: %s@."
                (Error.to_string_hum err) ;
              Core.exit 1 )
      | Error err ->
          Format.printf "Failed to send zkApps, error: %s@."
            (Error.to_string_hum err) ;
          Core.exit 1 ) ;
      let batch_pks =
        List.map zkapps_batch ~f:(fun zkapp ->
            let acct_update_pks =
              List.map (Zkapp_command.Call_forest.to_list zkapp.account_updates)
                ~f:(fun acct_update -> acct_update.body.public_key)
            in
            zkapp.fee_payer.body.public_key :: acct_update_pks )
        |> List.concat
        |> List.dedup_and_sort
             ~compare:Signature_lib.Public_key.Compressed.compare
      in
      let num_batch_pks = List.length batch_pks in
      Format.eprintf "Number of batch keys: %d@." num_batch_pks ;
      (* check ledger at intervals for presence of all pks *)
      let rec check_for_pks () =
        let%bind res =
          Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_ledger.rpc None port
        in
        match res with
        | Ok (Ok accounts) ->
            Format.printf "Succesfully downloaded daemon ledger@." ;
            let key_set =
              Signature_lib.Public_key.Compressed.Hash_set.of_list
                (List.map accounts ~f:(fun acct -> acct.public_key))
            in
            let pk_count =
              List.count batch_pks ~f:(fun pk -> Hash_set.mem key_set pk)
            in
            Format.eprintf "Number of batch keys in ledger: %d@." pk_count ;
            Deferred.return (pk_count = num_batch_pks)
        | Ok (Error err) ->
            Format.eprintf "Error in getting daemon ledger: %s@."
              (Error.to_string_hum err) ;
            let%bind () = after (Time.Span.of_sec 10.) in
            check_for_pks ()
        | Error err ->
            Format.eprintf "Error in getting daemon ledger: %s@."
              (Error.to_string_hum err) ;
            let%bind () = after (Time.Span.of_sec 10.) in
            check_for_pks ()
      in
      let rec check_loop () =
        let%bind got_pks = check_for_pks () in
        if got_pks then (
          Format.printf "Found all batch public keys in daemon ledger@." ;
          Deferred.unit )
        else (
          Format.printf
            "Did not find all batch public keys in daemon ledger, will retry@." ;
          let%bind () = after pk_check_wait in
          check_loop () )
      in
      Format.printf "Checking daemon ledger for batch public keys ...@." ;
      match%bind Async.with_timeout pk_check_timeout (check_loop ()) with
      | `Result _ ->
          Deferred.unit
      | `Timeout ->
          Format.eprintf
            "Timed out (%s) waiting to find batch public keys in daemon \
             ledger@."
            (Time.Span.to_string pk_check_timeout) ;
          exit 1 )
