open Core
open Async
open Graphql_async
open Mina_base
open Mina_transaction
module Ledger = Mina_ledger.Ledger
open Signature_lib
open Currency
open Utils
module Wrapper = Graphql_utils.Wrapper.Make2 (Schema)

module Subscriptions = struct
  open Wrapper

  let new_sync_update =
    subscription_field "newSyncUpdate"
      ~doc:"Event that triggers when the network sync status changes"
      ~deprecated:NotDeprecated
      ~typ:(non_null Types.sync_status)
      ~args:Arg.[]
      ~resolve:(fun { ctx = coda; _ } ->
        Mina_lib.sync_status coda |> Mina_incremental.Status.to_pipe
        |> Deferred.Result.return)

  let new_block =
    subscription_field "newBlock"
      ~doc:
        "Event that triggers when a new block is created that either contains \
         a transaction with the specified public key, or was produced by it. \
         If no public key is provided, then the event will trigger for every \
         new block received"
      ~typ:(non_null Types.block)
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key that is included in the block"
              ~typ:Types.Input.public_key_arg
          ]
      ~resolve:(fun { ctx = coda; _ } public_key ->
        Deferred.Result.return
        @@ Mina_commands.Subscriptions.new_block coda public_key)

  let chain_reorganization =
    subscription_field "chainReorganization"
      ~doc:
        "Event that triggers when the best tip changes in a way that is not a \
         trivial extension of the existing one"
      ~typ:(non_null Types.chain_reorganization_status)
      ~args:Arg.[]
      ~resolve:(fun { ctx = coda; _ } ->
        Deferred.Result.return
        @@ Mina_commands.Subscriptions.reorganization coda)

  let commands =
    Subscription_fields.to_ocaml_grapql_server_fields
      [ new_sync_update; new_block; chain_reorganization ]
end

module Mutations = struct
  open Wrapper

  let create_account_resolver { ctx = t; _ } () password =
    let password = lazy (return (Bytes.of_string password)) in
    let%map pk = Mina_lib.wallets t |> Secrets.Wallets.generate_new ~password in
    Mina_lib.subscriptions t |> Mina_lib.Subscriptions.add_new_subscription ~pk ;
    Result.return pk

  let add_wallet =
    io_field "addWallet"
      ~doc:
        "Add a wallet - this will create a new keypair and store it in the \
         daemon"
      ~deprecated:(Deprecated (Some "use createAccount instead"))
      ~typ:(non_null Payload.create_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.create_account) ]
      ~resolve:create_account_resolver

  let create_account =
    io_field "createAccount"
      ~doc:
        "Create a new account - this will create a new keypair and store it in \
         the daemon"
      ~typ:(non_null Payload.create_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.create_account) ]
      ~resolve:create_account_resolver

  let create_hd_account : (Mina_lib.t, unit, _, _, _) Fields.field =
    io_field "createHDAccount"
      ~doc:Secrets.Hardware_wallets.create_hd_account_summary
      ~typ:(non_null Payload.create_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.create_hd_account) ]
      ~resolve:(fun { ctx = coda; _ } () hd_index ->
        Mina_lib.wallets coda |> Secrets.Wallets.create_hd_account ~hd_index)

  let unlock_account_resolver { ctx = t; _ } () (password, pk) =
    let password = lazy (return (Bytes.of_string password)) in
    match%map
      Mina_lib.wallets t |> Secrets.Wallets.unlock ~needle:pk ~password
    with
    | Error `Not_found ->
        Error "Could not find owned account associated with provided key"
    | Error `Bad_password ->
        Error "Wrong password provided"
    | Error (`Key_read_error e) ->
        Error
          (sprintf "Error reading the secret key file: %s"
             (Secrets.Privkey_error.to_string e))
    | Ok () ->
        Ok pk

  let unlock_wallet =
    io_field "unlockWallet"
      ~doc:"Allow transactions to be sent from the unlocked account"
      ~deprecated:(Deprecated (Some "use unlockAccount instead"))
      ~typ:(non_null Payload.Unlock_account.typ)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.unlock_account) ]
      ~resolve:unlock_account_resolver

  module Unlock_account = struct
    let unlock_account =
      io_field "unlockAccount"
        ~doc:"Allow transactions to be sent from the unlocked account"
        ~typ:(non_null Payload.Unlock_account.typ)
        ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.unlock_account) ]
        ~resolve:unlock_account_resolver

    type gql_arg = string * Account.key

    type 'a subquery = 'a Payload.Unlock_account.query
  end

  let lock_account_resolver { ctx = t; _ } () pk =
    Mina_lib.wallets t |> Secrets.Wallets.lock ~needle:pk ;
    pk

  let lock_wallet =
    field "lockWallet"
      ~doc:"Lock an unlocked account to prevent transaction being sent from it"
      ~deprecated:(Deprecated (Some "use lockAccount instead"))
      ~typ:(non_null Payload.lock_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.lock_account) ]
      ~resolve:lock_account_resolver

  let lock_account =
    field "lockAccount"
      ~doc:"Lock an unlocked account to prevent transaction being sent from it"
      ~typ:(non_null Payload.lock_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.lock_account) ]
      ~resolve:lock_account_resolver

  let delete_account_resolver { ctx = coda; _ } () public_key =
    let open Deferred.Result.Let_syntax in
    let wallets = Mina_lib.wallets coda in
    let%map () =
      Deferred.Result.map_error
        ~f:(fun `Not_found ->
          "Could not find account with specified public key")
        (Secrets.Wallets.delete wallets public_key)
    in
    public_key

  let delete_wallet =
    io_field "deleteWallet"
      ~doc:"Delete the private key for an account that you track"
      ~deprecated:(Deprecated (Some "use deleteAccount instead"))
      ~typ:(non_null Payload.delete_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.delete_account) ]
      ~resolve:delete_account_resolver

  let delete_account =
    io_field "deleteAccount"
      ~doc:"Delete the private key for an account that you track"
      ~typ:(non_null Payload.delete_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.delete_account) ]
      ~resolve:delete_account_resolver

  let reload_account_resolver { ctx = coda; _ } () =
    let%map _ =
      Secrets.Wallets.reload ~logger:(Logger.create ()) (Mina_lib.wallets coda)
    in
    Ok true

  let reload_wallets =
    io_field "reloadWallets" ~doc:"Reload tracked account information from disk"
      ~deprecated:(Deprecated (Some "use reloadAccounts instead"))
      ~typ:(non_null Payload.reload_accounts)
      ~args:Arg.[]
      ~resolve:reload_account_resolver

  let reload_accounts =
    io_field "reloadAccounts"
      ~doc:"Reload tracked account information from disk"
      ~typ:(non_null Payload.reload_accounts)
      ~args:Arg.[]
      ~resolve:reload_account_resolver

  let import_account =
    io_field "importAccount" ~doc:"Reload tracked account information from disk"
      ~typ:(non_null Payload.import_account)
      ~args:
        Arg.
          [ arg "path"
              ~doc:
                "Path to the wallet file, relative to the daemon's current \
                 working directory."
              ~typ:(non_null string)
          ; arg "password" ~doc:"Password for the account to import"
              ~typ:(non_null string)
          ]
      ~resolve:(fun { ctx = coda; _ } () privkey_path password ->
        let open Deferred.Result.Let_syntax in
        (* the Keypair.read zeroes the password, so copy for use in import step below *)
        let saved_password =
          Lazy.return (Deferred.return (Bytes.of_string password))
        in
        let password =
          Lazy.return (Deferred.return (Bytes.of_string password))
        in
        let%bind ({ Keypair.public_key; _ } as keypair) =
          Secrets.Keypair.read ~privkey_path ~password
          |> Deferred.Result.map_error ~f:Secrets.Privkey_error.to_string
        in
        let pk = Public_key.compress public_key in
        let wallets = Mina_lib.wallets coda in
        match Secrets.Wallets.check_locked wallets ~needle:pk with
        | Some _ ->
            return (pk, true)
        | None ->
            let%map.Async.Deferred pk =
              Secrets.Wallets.import_keypair wallets keypair
                ~password:saved_password
            in
            Ok (pk, false))

  let reset_trust_status =
    io_field "resetTrustStatus"
      ~doc:"Reset trust status for all peers at a given IP address"
      ~typ:(list (non_null Payload.trust_status))
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.reset_trust_status) ]
      ~resolve:(fun { ctx = coda; _ } () ip_address_input ->
        let open Deferred.Result.Let_syntax in
        let%map ip_address =
          Deferred.return
          @@ Types.Arguments.ip_address ~name:"ip_address" ip_address_input
        in
        Some (Mina_commands.reset_trust_status coda ip_address))

  let send_user_command coda user_command_input =
    match
      Mina_commands.setup_and_submit_user_command coda user_command_input
    with
    | `Active f -> (
        match%map f with
        | Ok user_command ->
            Ok
              { Types.User_command.With_status.data = user_command
              ; status = Enqueued
              }
        | Error e ->
            Error
              (sprintf "Couldn't send user command: %s" (Error.to_string_hum e))
        )
    | `Bootstrapping ->
        return (Error "Daemon is bootstrapping")

  let send_zkapp_command mina parties =
    match Mina_commands.setup_and_submit_snapp_command mina parties with
    | `Active f -> (
        match%map f with
        | Ok parties ->
            let cmd =
              { Types.Zkapp_command.With_status.data = parties
              ; status = Enqueued
              }
            in
            let cmd_with_hash =
              Types.Zkapp_command.With_status.map cmd ~f:(fun cmd ->
                  { With_hash.data = cmd
                  ; hash = Transaction_hash.hash_command (Parties cmd)
                  })
            in
            Ok cmd_with_hash
        | Error e ->
            Error
              (sprintf "Couldn't send zkApp command: %s"
                 (Error.to_string_hum e)) )
    | `Bootstrapping ->
        return (Error "Daemon is bootstrapping")

  let mock_zkapp_command mina parties :
      ( (Parties.t, Transaction_hash.t) With_hash.t
        Types.Zkapp_command.With_status.t
      , string )
      result
      Io.t =
    (* instead of adding the parties to the transaction pool, as we would for an actual zkapp,
       apply the zkapp using an ephemeral ledger
    *)
    match Mina_lib.best_tip mina with
    | `Active breadcrumb -> (
        let best_tip_ledger =
          Transition_frontier.Breadcrumb.staged_ledger breadcrumb
          |> Staged_ledger.ledger
        in
        let accounts = Ledger.to_list best_tip_ledger in
        let constraint_constants =
          Genesis_constants.Constraint_constants.compiled
        in
        let depth = constraint_constants.ledger_depth in
        let ledger = Ledger.create_ephemeral ~depth () in
        (* Ledger.copy doesn't actually copy
           N.B.: The time for this copy grows with the number of accounts
        *)
        List.iter accounts ~f:(fun account ->
            let pk = Account.public_key account in
            let token = Account.token account in
            let account_id = Account_id.create pk token in
            match Ledger.get_or_create_account ledger account_id account with
            | Ok (`Added, _loc) ->
                ()
            | Ok (`Existed, _loc) ->
                (* should be unreachable *)
                failwithf
                  "When creating ledger for mock zkApp, account with public \
                   key %s and token %s already existed"
                  (Signature_lib.Public_key.Compressed.to_string pk)
                  (Token_id.to_string token) ()
            | Error err ->
                (* should be unreachable *)
                Error.tag_arg err
                  "When creating ledger for mock zkApp, error when adding \
                   account"
                  (("public_key", pk), ("token", token))
                  [%sexp_of:
                    (string * Signature_lib.Public_key.Compressed.t)
                    * (string * Token_id.t)]
                |> Error.raise) ;
        match
          Pipe_lib.Broadcast_pipe.Reader.peek
            (Mina_lib.transition_frontier mina)
        with
        | None ->
            (* should be unreachable *)
            return (Error "Transition frontier not available")
        | Some tf -> (
            let parent_hash =
              Transition_frontier.Breadcrumb.parent_hash breadcrumb
            in
            match Transition_frontier.find_protocol_state tf parent_hash with
            | None ->
                (* should be unreachable *)
                return (Error "Could not get parent breadcrumb")
            | Some prev_state ->
                let state_view =
                  Mina_state.Protocol_state.body prev_state
                  |> Mina_state.Protocol_state.Body.view
                in
                let applied =
                  Ledger.apply_parties_unchecked ~constraint_constants
                    ~state_view ledger parties
                in
                (* rearrange data to match result type of `send_zkapp_command` *)
                let applied_ok =
                  Result.map applied
                    ~f:(fun (parties_applied, _local_state_and_amount) ->
                      let ({ data = parties; status } : Parties.t With_status.t)
                          =
                        parties_applied.command
                      in
                      let hash =
                        Transaction_hash.hash_command (Parties parties)
                      in
                      let (with_hash : _ With_hash.t) =
                        { data = parties; hash }
                      in
                      let (status : Types.Command_status.t) =
                        match status with
                        | Applied ->
                            Applied
                        | Failed failure ->
                            Included_but_failed failure
                      in
                      ( { data = with_hash; status }
                        : _ Types.Zkapp_command.With_status.t ))
                in
                return @@ Result.map_error applied_ok ~f:Error.to_string_hum ) )
    | `Bootstrapping ->
        return (Error "Daemon is bootstrapping")

  let find_identity ~public_key coda =
    Result.of_option
      (Secrets.Wallets.find_identity (Mina_lib.wallets coda) ~needle:public_key)
      ~error:
        "Couldn't find an unlocked key for specified `sender`. Did you unlock \
         the account you're making a transaction from?"

  let create_user_command_input ~fee ~fee_payer_pk ~nonce_opt ~valid_until ~memo
      ~signer ~body ~sign_choice : (User_command_input.t, string) result =
    let open Result.Let_syntax in
    (* TODO: We should put a more sensible default here. *)
    let valid_until =
      Option.map ~f:Mina_numbers.Global_slot.of_uint32 valid_until
    in
    let%bind fee =
      result_of_exn Currency.Fee.of_uint64 fee
        ~error:(sprintf "Invalid `fee` provided.")
    in
    let%bind () =
      Result.ok_if_true
        Currency.Fee.(fee >= Signed_command.minimum_fee)
        ~error:
          (* IMPORTANT! Do not change the content of this error without
           * updating Rosetta's construction API to handle the changes *)
          (sprintf
             !"Invalid user command. Fee %s is less than the minimum fee, %s."
             (Currency.Fee.to_formatted_string fee)
             (Currency.Fee.to_formatted_string Signed_command.minimum_fee))
    in
    let%map memo =
      Option.value_map memo ~default:(Ok Signed_command_memo.empty)
        ~f:(fun memo ->
          result_of_exn Signed_command_memo.create_from_string_exn memo
            ~error:"Invalid `memo` provided.")
    in
    User_command_input.create ~signer ~fee ~fee_payer_pk ?nonce:nonce_opt
      ~valid_until ~memo ~body ~sign_choice ()

  let make_signed_user_command ~signature ~nonce_opt ~signer ~memo ~fee
      ~fee_payer_pk ~valid_until ~body =
    let open Deferred.Result.Let_syntax in
    let%bind signature = signature |> Deferred.return in
    let%map user_command_input =
      create_user_command_input ~nonce_opt ~signer ~memo ~fee ~fee_payer_pk
        ~valid_until ~body
        ~sign_choice:(User_command_input.Sign_choice.Signature signature)
      |> Deferred.return
    in
    user_command_input

  let send_signed_user_command ~signature ~coda ~nonce_opt ~signer ~memo ~fee
      ~fee_payer_pk ~valid_until ~body =
    let open Deferred.Result.Let_syntax in
    let%bind user_command_input =
      make_signed_user_command ~signature ~nonce_opt ~signer ~memo ~fee
        ~fee_payer_pk ~valid_until ~body
    in
    let%map cmd = send_user_command coda user_command_input in
    Types.User_command.With_status.map cmd ~f:(fun cmd ->
        { With_hash.data = cmd
        ; hash = Transaction_hash.hash_command (Signed_command cmd)
        })

  let send_unsigned_user_command ~coda ~nonce_opt ~signer ~memo ~fee
      ~fee_payer_pk ~valid_until ~body =
    let open Deferred.Result.Let_syntax in
    let%bind user_command_input =
      (let open Result.Let_syntax in
      let%bind sign_choice =
        match%map find_identity ~public_key:signer coda with
        | `Keypair sender_kp ->
            User_command_input.Sign_choice.Keypair sender_kp
        | `Hd_index hd_index ->
            Hd_index hd_index
      in
      create_user_command_input ~nonce_opt ~signer ~memo ~fee ~fee_payer_pk
        ~valid_until ~body ~sign_choice)
      |> Deferred.return
    in
    let%map cmd = send_user_command coda user_command_input in
    Types.User_command.With_status.map cmd ~f:(fun cmd ->
        { With_hash.data = cmd
        ; hash = Transaction_hash.hash_command (Signed_command cmd)
        })

  let export_logs ~coda basename_opt =
    let open Mina_lib in
    let Config.{ conf_dir; _ } = Mina_lib.config coda in
    Conf_dir.export_logs_to_tar ?basename:basename_opt ~conf_dir

  let send_delegation =
    io_field "sendDelegation"
      ~doc:"Change your delegate by sending a transaction"
      ~typ:(non_null Payload.send_delegation)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.send_delegation)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = coda; _ } () (from, to_, fee, valid_until, memo, nonce_opt)
             signature ->
        let body =
          Signed_command_payload.Body.Stake_delegation
            (Set_delegate { delegator = from; new_delegate = to_ })
        in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_payer_pk:from ~valid_until ~body
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command
        | Some signature ->
            let%bind signature = signature |> Deferred.return in
            send_signed_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_payer_pk:from ~valid_until ~body ~signature
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command)

  let send_payment =
    io_field "sendPayment" ~doc:"Send a payment"
      ~typ:(non_null Payload.send_payment)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.send_payment)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = coda; _ } ()
             (from, to_, amount, fee, valid_until, memo, nonce_opt) signature ->
        let body =
          Signed_command_payload.Body.Payment
            { source_pk = from
            ; receiver_pk = to_
            ; amount = Amount.of_uint64 amount
            }
        in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_payer_pk:from ~valid_until ~body
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command
        | Some signature ->
            send_signed_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_payer_pk:from ~valid_until ~body ~signature
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command)

  let make_zkapp_endpoint ~name ~doc ~f =
    io_field name ~doc
      ~typ:(non_null Payload.send_zkapp)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.send_zkapp) ]
      ~resolve:(fun { ctx = coda; _ } () parties ->
        f coda parties (* TODO: error handling? *))

  let send_zkapp =
    make_zkapp_endpoint ~name:"sendZkapp" ~doc:"Send a zkApp transaction"
      ~f:send_zkapp_command

  let mock_zkapp =
    make_zkapp_endpoint ~name:"mockZkapp"
      ~doc:"Mock a zkApp transaction, no effect on blockchain"
      ~f:mock_zkapp_command

  let internal_send_zkapp =
    io_field "internalSendZkapp"
      ~doc:"Send a zkApp (for internal testing purposes)"
      ~args:
        Arg.[ arg "parties" ~typ:(non_null Types.Input.internal_send_zkapp) ]
      ~typ:(non_null Payload.send_zkapp)
      ~resolve:(fun { ctx = mina; _ } () parties ->
        send_zkapp_command mina parties)

  let send_test_payments =
    io_field "sendTestPayments" ~doc:"Send a series of test payments"
      ~typ:(non_null int)
      ~args:
        Types.Input.Fields.
          [ senders
          ; receiver ~doc:"The receiver of the payments"
          ; amount ~doc:"The amount of each payment"
          ; fee ~doc:"The fee of each payment"
          ; repeat_count
          ; repeat_delay_ms
          ]
      ~resolve:
        (fun { ctx = coda; _ } () senders_list receiver_pk amount fee
             repeat_count repeat_delay_ms ->
        let dumb_password = lazy (return (Bytes.of_string "dumb")) in
        let senders = Array.of_list senders_list in
        let repeat_delay =
          Time.Span.of_ms @@ float_of_int
          @@ Unsigned.UInt32.to_int repeat_delay_ms
        in
        let start = Time.now () in
        let send_tx i =
          let source_privkey = senders.(i % Array.length senders) in
          let source_pk_decompressed =
            Signature_lib.Public_key.of_private_key_exn source_privkey
          in
          let source_pk =
            Signature_lib.Public_key.compress source_pk_decompressed
          in
          let body =
            Signed_command_payload.Body.Payment
              { source_pk; receiver_pk; amount = Amount.of_uint64 amount }
          in
          let memo = "" in
          let kp =
            Keypair.
              { private_key = source_privkey
              ; public_key = source_pk_decompressed
              }
          in
          let%bind _ =
            Secrets.Wallets.import_keypair (Mina_lib.wallets coda) kp
              ~password:dumb_password
          in
          send_unsigned_user_command ~coda ~nonce_opt:None ~signer:source_pk
            ~memo:(Some memo) ~fee ~fee_payer_pk:source_pk ~valid_until:None
            ~body
          |> Deferred.Result.map ~f:(const 0)
        in

        let do_ i =
          let pause =
            Time.diff
              (Time.add start @@ Time.Span.scale repeat_delay @@ float_of_int i)
            @@ Time.now ()
          in
          (if Time.Span.(pause > zero) then after pause else Deferred.unit)
          >>= fun () -> send_tx i >>| const ()
        in
        for i = 2 to Unsigned.UInt32.to_int repeat_count do
          don't_wait_for (do_ i)
        done ;
        (* don't_wait_for (Deferred.for_ 2 ~to_:repeat_count ~do_) ; *)
        send_tx 1)

  let send_rosetta_transaction =
    io_field "sendRosettaTransaction"
      ~doc:"Send a transaction in Rosetta format"
      ~typ:(non_null Payload.send_rosetta_transaction)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.rosetta_transaction) ]
      ~resolve:(fun { ctx = mina; _ } () signed_command ->
        match%map
          Mina_lib.add_full_transactions mina
            [ User_command.Signed_command signed_command ]
        with
        | Ok ([ (User_command.Signed_command signed_command as transaction) ], _)
          ->
            Ok
              (Types.User_command.mk_user_command
                 { status = Enqueued
                 ; data =
                     { With_hash.data = signed_command
                     ; hash = Transaction_hash.hash_command transaction
                     }
                 })
        | Error err ->
            Error (Error.to_string_hum err)
        | Ok ([], [ (_, diff_error) ]) ->
            let diff_error =
              Network_pool.Transaction_pool.Resource_pool.Diff.Diff_error
              .to_string_hum diff_error
            in
            Error
              (sprintf "Transaction could not be entered into the pool: %s"
                 diff_error)
        | Ok _ ->
            Error "Internal error: response from transaction pool was malformed")

  let export_logs =
    io_field "exportLogs" ~doc:"Export daemon logs to tar archive"
      ~args:Arg.[ arg "basename" ~typ:string ]
      ~typ:(non_null Payload.export_logs)
      ~resolve:(fun { ctx = coda; _ } () basename_opt ->
        let%map result = export_logs ~coda basename_opt in
        Result.map_error result
          ~f:(Fn.compose Yojson.Safe.to_string Error_json.error_to_yojson))

  let set_coinbase_receiver =
    field "setCoinbaseReceiver" ~doc:"Set the key to receive coinbases"
      ~args:
        Arg.[ arg "input" ~typ:(non_null Types.Input.set_coinbase_receiver) ]
      ~typ:(non_null Payload.set_coinbase_receiver)
      ~resolve:(fun { ctx = mina; _ } () coinbase_receiver ->
        let old_coinbase_receiver =
          match Mina_lib.coinbase_receiver mina with
          | `Producer ->
              None
          | `Other pk ->
              Some pk
        in
        let coinbase_receiver_full =
          match coinbase_receiver with
          | None ->
              `Producer
          | Some pk ->
              `Other pk
        in
        Mina_lib.replace_coinbase_receiver mina coinbase_receiver_full ;
        (old_coinbase_receiver, coinbase_receiver))

  let set_snark_worker =
    io_field "setSnarkWorker"
      ~doc:"Set key you wish to snark work with or disable snark working"
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.set_snark_worker) ]
      ~typ:(non_null Payload.set_snark_worker)
      ~resolve:(fun { ctx = coda; _ } () pk ->
        let old_snark_worker_key = Mina_lib.snark_worker_key coda in
        let%map () = Mina_lib.replace_snark_worker_key coda pk in
        Ok old_snark_worker_key)

  let set_snark_work_fee =
    result_field "setSnarkWorkFee"
      ~doc:"Set fee that you will like to receive for doing snark work"
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.set_snark_work_fee) ]
      ~typ:(non_null Payload.set_snark_work_fee)
      ~resolve:(fun { ctx = coda; _ } () raw_fee ->
        let open Result.Let_syntax in
        let%map fee =
          result_of_exn Currency.Fee.of_uint64 raw_fee
            ~error:"Invalid snark work `fee` provided."
        in
        let last_fee = Mina_lib.snark_work_fee coda in
        Mina_lib.set_snark_work_fee coda fee ;
        Currency.Fee.to_uint64 last_fee)

  let set_connection_gating_config =
    io_field "setConnectionGatingConfig"
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.set_connection_gating_config)
          ]
      ~doc:
        "Set the connection gating config, returning the current config after \
         the application (which may have failed)"
      ~typ:(non_null Payload.set_connection_gating_config)
      ~resolve:(fun { ctx = coda; _ } () config ->
        let open Deferred.Result.Let_syntax in
        let%bind config = Deferred.return config in
        let open Deferred.Let_syntax in
        Mina_networking.set_connection_gating_config (Mina_lib.net coda) config
        >>| Result.return)

  module Add_peer = struct
    let add_peer =
      let myargs =
        Arg.
          [ arg "peers" ~typ:(non_null @@ list @@ non_null @@ Types.Input.peer)
          ; arg "seed" ~typ:bool
          ]
      in
      io_field "addPeers" ~args:myargs ~doc:"Connect to the given peers"
        ~typ:(non_null @@ list @@ non_null DaemonStatus.Peer.peer)
        ~resolve:(fun { ctx = coda; _ } () peers seed ->
          let open Deferred.Result.Let_syntax in
          let%bind peers =
            Result.combine_errors peers
            |> Result.map_error ~f:(fun errs ->
                   Option.value ~default:"Empty peers list" (List.hd errs))
            |> Deferred.return
          in
          let net = Mina_lib.net coda in
          let is_seed = Option.value ~default:true seed in
          let%bind.Async.Deferred maybe_failure =
            (* Add peers until we find an error *)
            Deferred.List.find_map peers ~f:(fun peer ->
                match%map.Async.Deferred
                  Mina_networking.add_peer net peer ~is_seed
                with
                | Ok () ->
                    None
                | Error err ->
                    Some (Error (Error.to_string_hum err)))
          in
          let%map () =
            match maybe_failure with
            | None ->
                return ()
            | Some err ->
                Deferred.return err
          in
          List.map ~f:Network_peer.Peer.to_display peers)

    type gql_arguments =
      { peers : Network_peer.Peer.t list; seed : bool option }

    type 'a gql_subquery = 'a DaemonStatus.Peer.query
  end

  type 'add_peers r_mut = { add_peers : 'add_peers }

  type _ mutation =
    | Add_peers :
        { subquery : 'sub Add_peer.gql_subquery
        ; arguments : Add_peer.gql_arguments
        }
        -> 'sub r_mut mutation

  let string_of_mutation = function
    | Add_peers { subquery; arguments } ->
        Format.sprintf "%s {%s}"
          (Add_peer.add_peer.to_string arguments.peers arguments.seed)
          (DaemonStatus.Peer.string_of_query subquery)

  let response_of_json query json =
    match query with
    | Add_peers { subquery; _ } ->
        { add_peers =
            (Graphql_utils.Json.non_null_list_of_json
               DaemonStatus.Peer.response_of_json_non_null)
              subquery
              (Graphql_utils.Json.get Add_peer.add_peer.name json)
        }

  let archive_precomputed_block =
    io_field "archivePrecomputedBlock"
      ~args:
        Arg.
          [ arg "block" ~doc:"Block encoded in precomputed block format"
              ~typ:(non_null Types.Input.precomputed_block)
          ]
      ~typ:
        (non_null
           (obj "Applied" ~fields:(fun _ ->
                [ field "applied" ~typ:(non_null bool)
                    ~args:Arg.[]
                    ~resolve:(fun _ _ -> true)
                ])))
      ~resolve:(fun { ctx = coda; _ } () block ->
        let open Deferred.Result.Let_syntax in
        let%bind archive_location =
          match (Mina_lib.config coda).archive_process_location with
          | Some archive_location ->
              return archive_location
          | None ->
              Deferred.Result.fail
                "Could not find an archive process to connect to"
        in
        let%map () =
          Mina_lib.Archive_client.dispatch_precomputed_block archive_location
            block
          |> Deferred.Result.map_error ~f:Error.to_string_hum
        in
        ())

  let archive_extensional_block =
    io_field "archiveExtensionalBlock"
      ~args:
        Arg.
          [ arg "block" ~doc:"Block encoded in extensional block format"
              ~typ:(non_null Types.Input.extensional_block)
          ]
      ~typ:
        (non_null
           (obj "Applied" ~fields:(fun _ ->
                [ field "applied" ~typ:(non_null bool)
                    ~args:Arg.[]
                    ~resolve:(fun _ _ -> true)
                ])))
      ~resolve:(fun { ctx = coda; _ } () block ->
        let open Deferred.Result.Let_syntax in
        let%bind archive_location =
          match (Mina_lib.config coda).archive_process_location with
          | Some archive_location ->
              return archive_location
          | None ->
              Deferred.Result.fail
                "Could not find an archive process to connect to"
        in
        let%map () =
          Mina_lib.Archive_client.dispatch_extensional_block archive_location
            block
          |> Deferred.Result.map_error ~f:Error.to_string_hum
        in
        ())

  let commands =
    Fields.to_ocaml_grapql_server_fields
      [ add_wallet
      ; create_account
      ; create_hd_account
      ; Unlock_account.unlock_account
      ; unlock_wallet
      ; lock_account
      ; lock_wallet
      ; delete_account
      ; delete_wallet
      ; reload_accounts
      ; import_account
      ; reload_wallets
      ; send_payment
      ; send_test_payments
      ; send_delegation
      ; send_zkapp
      ; mock_zkapp
      ; internal_send_zkapp
      ; export_logs
      ; set_coinbase_receiver
      ; set_snark_worker
      ; set_snark_work_fee
      ; set_connection_gating_config
      ; Add_peer.add_peer
      ; archive_precomputed_block
      ; archive_extensional_block
      ; send_rosetta_transaction
      ]
end

module Queries = struct
  open Wrapper

  (* helper for pooledUserCommands, pooledZkappCommands *)
  let get_commands ~resource_pool ~pk_opt ~hashes_opt ~txns_opt =
    match (pk_opt, hashes_opt, txns_opt) with
    | None, None, None ->
        Network_pool.Transaction_pool.Resource_pool.get_all resource_pool
    | Some pk, None, None ->
        let account_id = Account_id.create pk Token_id.default in
        Network_pool.Transaction_pool.Resource_pool.all_from_account
          resource_pool account_id
    | _ -> (
        let hashes_txns =
          (* Transactions identified by hashes. *)
          match hashes_opt with
          | Some hashes ->
              List.filter_map hashes ~f:(fun hash ->
                  hash |> Transaction_hash.of_base58_check |> Result.ok
                  |> Option.bind
                       ~f:
                         (Network_pool.Transaction_pool.Resource_pool
                          .find_by_hash resource_pool))
          | None ->
              []
        in
        let txns =
          (* Transactions as identified by IDs.
             This is a little redundant, but it makes our API more
             consistent.
          *)
          match txns_opt with
          | Some txns ->
              List.filter_map txns ~f:(fun serialized_txn ->
                  Signed_command.of_base58_check serialized_txn
                  |> Result.map ~f:(fun signed_command ->
                         (* These commands get piped through [forget_check]
                            below; this is just to make the types work
                            without extra unnecessary mapping in the other
                            branches above.
                         *)
                         let (`If_this_is_used_it_should_have_a_comment_justifying_it
                               cmd) =
                           User_command.to_valid_unsafe
                             (Signed_command signed_command)
                         in
                         Transaction_hash.User_command_with_valid_signature
                         .create cmd)
                  |> Result.ok)
          | None ->
              []
        in
        let all_txns = hashes_txns @ txns in
        match pk_opt with
        | None ->
            all_txns
        | Some pk ->
            (* Only return commands paid for by the given public key. *)
            List.filter all_txns ~f:(fun txn ->
                txn
                |> Transaction_hash.User_command_with_valid_signature.command
                |> User_command.fee_payer |> Account_id.public_key
                |> Public_key.Compressed.equal pk) )

  let pooled_user_commands =
    field "pooledUserCommands"
      ~doc:
        "Retrieve all the scheduled user commands for a specified sender that \
         the current daemon sees in its transaction pool. All scheduled \
         commands are queried if no sender is specified"
      ~typ:(non_null @@ list @@ non_null Types.User_command.user_command)
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key of sender of pooled user commands"
              ~typ:Types.Input.public_key_arg
          ; arg "hashes" ~doc:"Hashes of the commands to find in the pool"
              ~typ:(list (non_null string))
          ; arg "ids" ~typ:(list (non_null guid)) ~doc:"Ids of User commands"
          ]
      ~resolve:(fun { ctx = coda; _ } () pk_opt hashes_opt txns_opt ->
        let transaction_pool = Mina_lib.transaction_pool coda in
        let resource_pool =
          Network_pool.Transaction_pool.resource_pool transaction_pool
        in
        let signed_cmds =
          get_commands ~resource_pool ~pk_opt ~hashes_opt ~txns_opt
        in
        List.filter_map signed_cmds ~f:(fun txn ->
            let cmd_with_hash =
              Transaction_hash.User_command_with_valid_signature.forget_check
                txn
            in
            match cmd_with_hash.data with
            | Signed_command user_cmd ->
                Some
                  (Types.User_command.mk_user_command
                     { status = Enqueued
                     ; data = { cmd_with_hash with data = user_cmd }
                     })
            | Parties _ ->
                None))

  let pooled_zkapp_commands =
    field "pooledZkappCommands"
      ~doc:
        "Retrieve all the scheduled zkApp commands for a specified sender that \
         the current daemon sees in its transaction pool. All scheduled \
         commands are queried if no sender is specified"
      ~typ:(non_null @@ list @@ non_null Types.Zkapp_command.zkapp_command)
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key of sender of pooled zkApp commands"
              ~typ:Types.Input.public_key_arg
          ; arg "hashes" ~doc:"Hashes of the zkApp commands to find in the pool"
              ~typ:(list (non_null string))
          ; arg "ids" ~typ:(list (non_null guid)) ~doc:"Ids of zkApp commands"
          ]
      ~resolve:(fun { ctx = coda; _ } () pk_opt hashes_opt txns_opt ->
        let transaction_pool = Mina_lib.transaction_pool coda in
        let resource_pool =
          Network_pool.Transaction_pool.resource_pool transaction_pool
        in
        let signed_cmds =
          get_commands ~resource_pool ~pk_opt ~hashes_opt ~txns_opt
        in
        List.filter_map signed_cmds ~f:(fun txn ->
            let cmd_with_hash =
              Transaction_hash.User_command_with_valid_signature.forget_check
                txn
            in
            match cmd_with_hash.data with
            | Signed_command _ ->
                None
            | Parties zkapp_cmd ->
                Some
                  { Types.Zkapp_command.With_status.status = Enqueued
                  ; data = { cmd_with_hash with data = zkapp_cmd }
                  }))

  let sync_status =
    io_field "syncStatus" ~doc:"Network sync status" ~args:[]
      ~typ:(non_null Types.sync_status) ~resolve:(fun { ctx = coda; _ } () ->
        let open Deferred.Let_syntax in
        (* pull out sync status from status, so that result here
             agrees with status; see issue #8251
        *)
        let%map { sync_status; _ } =
          Mina_commands.get_status ~flag:`Performance coda
        in
        Ok sync_status)

  let daemon_status =
    io_field "daemonStatus" ~doc:"Get running daemon status" ~args:[]
      ~typ:(non_null DaemonStatus.t) ~resolve:(fun { ctx = coda; _ } () ->
        Mina_commands.get_status ~flag:`Performance coda >>| Result.return)

  let trust_status =
    field "trustStatus"
      ~typ:(list (non_null Payload.trust_status))
      ~args:Arg.[ arg "ipAddress" ~typ:(non_null string) ]
      ~doc:"Trust status for an IPv4 or IPv6 address"
      ~resolve:(fun { ctx = coda; _ } () (ip_addr_string : string) ->
        match Types.Arguments.ip_address ~name:"ipAddress" ip_addr_string with
        | Ok ip_addr ->
            Some (Mina_commands.get_trust_status coda ip_addr)
        | Error _ ->
            None)

  let trust_status_all =
    field "trustStatusAll"
      ~typ:(non_null @@ list @@ non_null Payload.trust_status)
      ~args:Arg.[]
      ~doc:"IP address and trust status for all peers"
      ~resolve:(fun { ctx = coda; _ } () ->
        Mina_commands.get_trust_status_all coda)

  let version =
    field "version" ~typ:string
      ~args:Arg.[]
      ~doc:"The version of the node (git commit hash)"
      ~resolve:(fun _ _ -> Some Mina_version.commit_id)

  let tracked_accounts_resolver { ctx = coda; _ } () =
    let wallets = Mina_lib.wallets coda in
    let block_production_pubkeys = Mina_lib.block_production_pubkeys coda in
    let best_tip_ledger = Mina_lib.best_ledger coda in
    wallets |> Secrets.Wallets.pks
    |> List.map ~f:(fun pk ->
           { Types.AccountObj.account =
               Types.AccountObj.Partial_account.of_pk coda pk
           ; locked = Secrets.Wallets.check_locked wallets ~needle:pk
           ; is_actively_staking =
               Public_key.Compressed.Set.mem block_production_pubkeys pk
           ; path = Secrets.Wallets.get_path wallets pk
           ; index =
               ( match best_tip_ledger with
               | `Active ledger ->
                   Option.try_with (fun () ->
                       Ledger.index_of_account_exn ledger
                         (Account_id.create pk Token_id.default))
               | _ ->
                   None )
           })

  let owned_wallets =
    field "ownedWallets"
      ~doc:"Wallets for which the daemon knows the private key"
      ~typ:(non_null (list (non_null Types.AccountObj.account)))
      ~deprecated:(Deprecated (Some "use trackedAccounts instead"))
      ~args:Arg.[]
      ~resolve:tracked_accounts_resolver

  let tracked_accounts =
    field "trackedAccounts"
      ~doc:"Accounts for which the daemon tracks the private key"
      ~typ:(non_null (list (non_null Types.AccountObj.account)))
      ~args:Arg.[]
      ~resolve:tracked_accounts_resolver

  let account_resolver { ctx = coda; _ } () pk =
    Some
      (Types.AccountObj.lift coda pk
         (Types.AccountObj.Partial_account.of_pk coda pk))

  let wallet =
    field "wallet" ~doc:"Find any wallet via a public key"
      ~typ:Types.AccountObj.account
      ~deprecated:(Deprecated (Some "use account instead"))
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key of account being retrieved"
              ~typ:(non_null Types.Input.public_key_arg)
          ]
      ~resolve:account_resolver

  let get_ledger_and_breadcrumb coda =
    coda |> Mina_lib.best_tip |> Participating_state.active
    |> Option.map ~f:(fun tip ->
           ( Transition_frontier.Breadcrumb.staged_ledger tip
             |> Staged_ledger.ledger
           , tip ))

  let account =
    field "account" ~doc:"Find any account via a public key and token"
      ~typ:Types.AccountObj.account
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key of account being retrieved"
              ~typ:(non_null Types.Input.public_key_arg)
          ; arg' "token"
              ~doc:"Token of account being retrieved (defaults to CODA)"
              ~typ:Types.Input.token_id_arg ~default:Token_id.default
          ]
      ~resolve:(fun { ctx = coda; _ } () pk token ->
        Option.bind (get_ledger_and_breadcrumb coda)
          ~f:(fun (ledger, breadcrumb) ->
            let open Option.Let_syntax in
            let%bind location =
              Ledger.location_of_account ledger (Account_id.create pk token)
            in
            let%map account = Ledger.get ledger location in
            Types.AccountObj.Partial_account.of_full_account ~breadcrumb account
            |> Types.AccountObj.lift coda pk))

  let account_merkle_path =
    field "accountMerklePath" ~doc:"Get the merkle path for an account"
      ~typ:(list (non_null Types.merkle_path_element))
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key of account being retrieved"
              ~typ:(non_null Types.Input.public_key_arg)
          ; arg' "token"
              ~doc:"Token of account being retrieved (defaults to MINA)"
              ~typ:Types.Input.token_id_arg ~default:Token_id.default
          ]
      ~resolve:(fun { ctx = mina; _ } () pk token ->
        let open Option.Let_syntax in
        let%bind ledger, _breadcrumb = get_ledger_and_breadcrumb mina in
        let%map location =
          Ledger.location_of_account ledger (Account_id.create pk token)
        in
        Ledger.merkle_path ledger location)

  let accounts_for_pk =
    field "accounts" ~doc:"Find all accounts for a public key"
      ~typ:(non_null (list (non_null Types.AccountObj.account)))
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key to find accounts for"
              ~typ:(non_null Types.Input.public_key_arg)
          ]
      ~resolve:(fun { ctx = coda; _ } () pk ->
        match get_ledger_and_breadcrumb coda with
        | Some (ledger, breadcrumb) ->
            let tokens = Ledger.tokens ledger pk |> Set.to_list in
            List.filter_map tokens ~f:(fun token ->
                let open Option.Let_syntax in
                let%bind location =
                  Ledger.location_of_account ledger (Account_id.create pk token)
                in
                let%map account = Ledger.get ledger location in
                Types.AccountObj.Partial_account.of_full_account ~breadcrumb
                  account
                |> Types.AccountObj.lift coda pk)
        | None ->
            [])

  let token_owner =
    field "tokenOwner" ~doc:"Find the account ID that owns a given token"
      ~typ:Types.account_id
      ~args:
        Arg.
          [ arg "token" ~doc:"Token to find the owner for"
              ~typ:(non_null Types.Input.token_id_arg)
          ]
      ~resolve:(fun { ctx = coda; _ } () token ->
        coda |> Mina_lib.best_tip |> Participating_state.active
        |> Option.bind ~f:(fun tip ->
               let ledger =
                 Transition_frontier.Breadcrumb.staged_ledger tip
                 |> Staged_ledger.ledger
               in
               Ledger.token_owner ledger token))

  let transaction_status =
    result_field2 "transactionStatus" ~doc:"Get the status of a transaction"
      ~typ:(non_null Types.transaction_status)
      ~args:
        Arg.
          [ arg "payment" ~typ:guid ~doc:"Id of a Payment"
          ; arg "zkappTransaction" ~typ:guid ~doc:"Id of a zkApp transaction"
          ]
      ~resolve:
        (fun { ctx = coda; _ } () (serialized_payment : string option)
             (serialized_zkapp : string option) ->
        let open Result.Let_syntax in
        let deserialize_txn serialized_txn =
          let res =
            match serialized_txn with
            | `Signed_command x ->
                Or_error.(
                  Signed_command.of_base58_check x
                  >>| fun c -> User_command.Signed_command c)
            | `Parties ps ->
                Or_error.(
                  Parties.of_base58_check ps >>| fun c -> User_command.Parties c)
          in
          result_of_or_error res ~error:"Invalid transaction provided"
          |> Result.map ~f:(fun cmd ->
                 { With_hash.data = cmd
                 ; hash = Transaction_hash.hash_command cmd
                 })
        in
        let%bind txn =
          match (serialized_payment, serialized_zkapp) with
          | None, None | Some _, Some _ ->
              Error
                "Invalid query: Specify either a payment ID or a zkApp \
                 transaction ID"
          | Some payment, None ->
              deserialize_txn (`Signed_command payment)
          | None, Some zkapp_txn ->
              deserialize_txn (`Parties zkapp_txn)
        in
        let frontier_broadcast_pipe = Mina_lib.transition_frontier coda in
        let transaction_pool = Mina_lib.transaction_pool coda in
        Result.map_error
          (Transaction_inclusion_status.get_status ~frontier_broadcast_pipe
             ~transaction_pool txn.data)
          ~f:Error.to_string_hum)

  let current_snark_worker =
    field "currentSnarkWorker" ~typ:Types.snark_worker
      ~args:Arg.[]
      ~doc:"Get information about the current snark worker"
      ~resolve:(fun { ctx = coda; _ } _ ->
        Option.map (Mina_lib.snark_worker_key coda) ~f:(fun k ->
            (k, Mina_lib.snark_work_fee coda)))

  let genesis_block =
    field "genesisBlock" ~typ:(non_null Types.block) ~args:[]
      ~doc:"Get the genesis block" ~resolve:(fun { ctx = coda; _ } () ->
        let open Mina_state in
        let { Precomputed_values.genesis_ledger
            ; constraint_constants
            ; consensus_constants
            ; genesis_epoch_data
            ; proof_data
            ; _
            } =
          (Mina_lib.config coda).precomputed_values
        in
        let { With_hash.data = genesis_state
            ; hash = { State_hash.State_hashes.state_hash = hash; _ }
            } =
          Genesis_protocol_state.t
            ~genesis_ledger:(Genesis_ledger.Packed.t genesis_ledger)
            ~genesis_epoch_data ~constraint_constants ~consensus_constants
        in
        let winner = fst Consensus_state_hooks.genesis_winner in
        { With_hash.data =
            { Filtered_external_transition.creator = winner
            ; winner
            ; protocol_state =
                { previous_state_hash =
                    Protocol_state.previous_state_hash genesis_state
                ; blockchain_state =
                    Protocol_state.blockchain_state genesis_state
                ; consensus_state = Protocol_state.consensus_state genesis_state
                }
            ; transactions =
                { commands = []
                ; fee_transfers = []
                ; coinbase = constraint_constants.coinbase_amount
                ; coinbase_receiver =
                    Some (fst Consensus_state_hooks.genesis_winner)
                }
            ; snark_jobs = []
            ; proof =
                ( match proof_data with
                | Some { genesis_proof; _ } ->
                    genesis_proof
                | None ->
                    (* It's nearly never useful to have a specific genesis
                       proof to pass here -- anyone can create one as needed --
                       and we don't want this GraphQL query to trigger an
                       expensive proof generation step if we don't have one
                       available.
                    *)
                    Proof.blockchain_dummy )
            }
        ; hash
        })

  (* used by best_chain, block below *)
  let block_of_breadcrumb coda breadcrumb =
    let hash = Transition_frontier.Breadcrumb.state_hash breadcrumb in
    let block = Transition_frontier.Breadcrumb.block breadcrumb in
    let transactions =
      Mina_block.transactions
        ~constraint_constants:
          (Mina_lib.config coda).precomputed_values.constraint_constants block
    in
    { With_hash.Stable.Latest.data =
        Filtered_external_transition.of_transition block `All transactions
    ; hash
    }

  let best_chain =
    io_field "bestChain"
      ~doc:
        "Retrieve a list of blocks from transition frontier's root to the \
         current best tip. Returns an error if the system is bootstrapping."
      ~typ:(list @@ non_null Types.block)
      ~args:
        Arg.
          [ arg "maxLength"
              ~doc:
                "The maximum number of blocks to return. If there are more \
                 blocks in the transition frontier from root to tip, the n \
                 blocks closest to the best tip will be returned"
              ~typ:int
          ]
      ~resolve:(fun { ctx = coda; _ } () max_length ->
        match Mina_lib.best_chain ?max_length coda with
        | Some best_chain ->
            let%map blocks =
              Deferred.List.map best_chain ~f:(fun bc ->
                  Deferred.return @@ block_of_breadcrumb coda bc)
            in
            Ok (Some blocks)
        | None ->
            return
            @@ Error "Could not obtain best chain from transition frontier")

  let block =
    result_field2 "block"
      ~doc:
        "Retrieve a block with the given state hash or height, if contained in \
         the transition frontier."
      ~typ:(non_null Types.block)
      ~args:
        Arg.
          [ arg "stateHash" ~doc:"The state hash of the desired block"
              ~typ:string
          ; arg "height"
              ~doc:"The height of the desired block in the best chain" ~typ:int
          ]
      ~resolve:
        (fun { ctx = coda; _ } () (state_hash_base58_opt : string option)
             (height_opt : int option) ->
        let open Result.Let_syntax in
        let get_transition_frontier () =
          let transition_frontier_pipe = Mina_lib.transition_frontier coda in
          Pipe_lib.Broadcast_pipe.Reader.peek transition_frontier_pipe
          |> Result.of_option ~error:"Could not obtain transition frontier"
        in
        let block_from_state_hash state_hash_base58 =
          let%bind state_hash =
            State_hash.of_base58_check state_hash_base58
            |> Result.map_error ~f:Error.to_string_hum
          in
          let%bind transition_frontier = get_transition_frontier () in
          let%map breadcrumb =
            Transition_frontier.find transition_frontier state_hash
            |> Result.of_option
                 ~error:
                   (sprintf
                      "Block with state hash %s not found in transition \
                       frontier"
                      state_hash_base58)
          in
          block_of_breadcrumb coda breadcrumb
        in
        let block_from_height height =
          let height_uint32 =
            (* GraphQL int is signed 32-bit
                 empirically, conversion does not raise even if
               - the number is negative
               - the number is not representable using 32 bits
            *)
            Unsigned.UInt32.of_int height
          in
          let%bind transition_frontier = get_transition_frontier () in
          let best_chain_breadcrumbs =
            Transition_frontier.best_tip_path transition_frontier
          in
          let%map desired_breadcrumb =
            List.find best_chain_breadcrumbs ~f:(fun bc ->
                let validated_transition =
                  Transition_frontier.Breadcrumb.validated_transition bc
                in
                let block_height =
                  Mina_block.(
                    blockchain_length @@ With_hash.data
                    @@ Validated.forget validated_transition)
                in
                Unsigned.UInt32.equal block_height height_uint32)
            |> Result.of_option
                 ~error:
                   (sprintf
                      "Could not find block in transition frontier with height \
                       %d"
                      height)
          in
          block_of_breadcrumb coda desired_breadcrumb
        in
        match (state_hash_base58_opt, height_opt) with
        | Some state_hash_base58, None ->
            block_from_state_hash state_hash_base58
        | None, Some height ->
            block_from_height height
        | None, None | Some _, Some _ ->
            Error "Must provide exactly one of state hash, height")

  let initial_peers =
    field "initialPeers"
      ~doc:"List of peers that the daemon first used to connect to the network"
      ~args:Arg.[]
      ~typ:(non_null @@ list @@ non_null string)
      ~resolve:(fun { ctx = coda; _ } () ->
        List.map (Mina_lib.initial_peers coda) ~f:Mina_net2.Multiaddr.to_string)

  let get_peers =
    io_field "getPeers"
      ~doc:"List of peers that the daemon is currently connected to"
      ~args:Arg.[]
      ~typ:(non_null @@ list @@ non_null DaemonStatus.Peer.peer)
      ~resolve:(fun { ctx = coda; _ } () ->
        let%map peers = Mina_networking.peers (Mina_lib.net coda) in
        Ok (List.map ~f:Network_peer.Peer.to_display peers))

  let snark_pool =
    field "snarkPool"
      ~doc:"List of completed snark works that have the lowest fee so far"
      ~args:Arg.[]
      ~typ:(non_null @@ list @@ non_null Types.completed_work)
      ~resolve:(fun { ctx = coda; _ } () ->
        Mina_lib.snark_pool coda |> Network_pool.Snark_pool.resource_pool
        |> Network_pool.Snark_pool.Resource_pool.all_completed_work)

  let pending_snark_work =
    field "pendingSnarkWork" ~doc:"List of snark works that are yet to be done"
      ~args:Arg.[]
      ~typ:(non_null @@ list @@ non_null Types.pending_work)
      ~resolve:(fun { ctx = coda; _ } () ->
        let snark_job_state = Mina_lib.snark_job_state coda in
        let snark_pool = Mina_lib.snark_pool coda in
        let fee_opt =
          Mina_lib.(
            Option.map (snark_worker_key coda) ~f:(fun _ -> snark_work_fee coda))
        in
        let (module S) = Mina_lib.work_selection_method coda in
        S.pending_work_statements ~snark_pool ~fee_opt snark_job_state)

  let genesis_constants =
    field "genesisConstants"
      ~doc:
        "The constants used to determine the configuration of the genesis \
         block and all of its transitive dependencies"
      ~args:Arg.[]
      ~typ:(non_null Types.genesis_constants)
      ~resolve:(fun _ () -> ())

  let time_offset =
    field "timeOffset"
      ~doc:
        "The time offset in seconds used to convert real times into blockchain \
         times"
      ~args:Arg.[]
      ~typ:(non_null int)
      ~resolve:(fun { ctx = coda; _ } () ->
        Block_time.Controller.get_time_offset
          ~logger:(Mina_lib.config coda).logger
        |> Time.Span.to_sec |> Float.to_int)

  let connection_gating_config =
    io_field "connectionGatingConfig"
      ~doc:
        "The rules that the libp2p helper will use to determine which \
         connections to permit"
      ~args:Arg.[]
      ~typ:(non_null Payload.set_connection_gating_config)
      ~resolve:(fun { ctx = coda; _ } _ ->
        let net = Mina_lib.net coda in
        let%map config = Mina_networking.connection_gating_config net in
        Ok config)

  let validate_payment =
    io_field "validatePayment"
      ~doc:"Validate the format and signature of a payment" ~typ:(non_null bool)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.send_payment)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = mina; _ } ()
             (from, to_, amount, fee, valid_until, memo, nonce_opt) signature ->
        let open Deferred.Result.Let_syntax in
        let body =
          Signed_command_payload.Body.Payment
            { source_pk = from
            ; receiver_pk = to_
            ; amount = Amount.of_uint64 amount
            }
        in
        let%bind signature =
          match signature with
          | Some signature ->
              return signature
          | None ->
              Deferred.Result.fail "Signature field is missing"
        in
        let%bind user_command_input =
          Mutations.make_signed_user_command ~nonce_opt ~signer:from ~memo ~fee
            ~fee_payer_pk:from ~valid_until ~body ~signature
        in
        let%map user_command, _ =
          User_command_input.to_user_command
            ~get_current_nonce:(Mina_lib.get_current_nonce mina)
            ~get_account:(Mina_lib.get_account mina)
            ~constraint_constants:
              (Mina_lib.config mina).precomputed_values.constraint_constants
            ~logger:(Mina_lib.top_level_logger mina)
            user_command_input
          |> Deferred.Result.map_error ~f:Error.to_string_hum
        in
        Signed_command.check_signature user_command)

  let runtime_config =
    field "runtimeConfig"
      ~doc:"The runtime configuration passed to the daemon at start-up"
      ~typ:(non_null Types.json)
      ~args:Arg.[]
      ~resolve:(fun { ctx = mina; _ } () ->
        Mina_lib.runtime_config mina
        |> Runtime_config.to_yojson |> Yojson.Safe.to_basic)

  let thread_graph =
    field "threadGraph"
      ~doc:
        "A graphviz dot format representation of the deamon's internal thread \
         graph"
      ~typ:(non_null string)
      ~args:Arg.[]
      ~resolve:(fun _ () ->
        Bytes.unsafe_to_string
          ~no_mutation_while_string_reachable:
            (O1trace.Thread.dump_thread_graph ()))

  let evaluate_vrf =
    io_field "evaluateVrf"
      ~doc:
        "Evaluate a vrf for the given public key. This includes a witness \
         which may be verified without access to the private key for this vrf \
         evaluation."
      ~typ:(non_null Types.vrf_evaluation)
      ~args:
        Arg.
          [ arg "message" ~typ:(non_null Types.Input.vrf_message)
          ; arg "publicKey" ~typ:(non_null Types.Input.public_key_arg)
          ; arg "vrfThreshold" ~typ:Types.Input.vrf_threshold
          ]
      ~resolve:(fun { ctx = mina; _ } () message public_key vrf_threshold ->
        Deferred.return
        @@
        let open Result.Let_syntax in
        let%map sk =
          match%bind Mutations.find_identity ~public_key mina with
          | `Keypair { private_key; _ } ->
              Ok private_key
          | `Hd_index _ ->
              Error
                "Computing a vrf evaluation from a hardware wallet is not \
                 supported"
        in
        let constraint_constants =
          (Mina_lib.config mina).precomputed_values.constraint_constants
        in
        let t =
          { (Consensus_vrf.Layout.Evaluation.of_message_and_sk
               ~constraint_constants message sk)
            with
            vrf_threshold
          }
        in
        match vrf_threshold with
        | Some _ ->
            Consensus_vrf.Layout.Evaluation.compute_vrf ~constraint_constants t
        | None ->
            t)

  let check_vrf =
    field "checkVrf"
      ~doc:
        "Check a vrf evaluation commitment. This can be used to check vrf \
         evaluations without needing to reveal the private key, in the format \
         returned by evaluateVrf"
      ~typ:(non_null Types.vrf_evaluation)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.vrf_evaluation) ]
      ~resolve:(fun { ctx = mina; _ } () evaluation ->
        let constraint_constants =
          (Mina_lib.config mina).precomputed_values.constraint_constants
        in
        Consensus_vrf.Layout.Evaluation.compute_vrf ~constraint_constants
          evaluation)

  let blockchain_verification_key =
    io_field "blockchainVerificationKey"
      ~doc:"The pickles verification key for the protocol state proof"
      ~typ:(non_null Types.json)
      ~args:Arg.[]
      ~resolve:(fun { ctx = mina; _ } () ->
        let open Deferred.Result.Let_syntax in
        Mina_lib.verifier mina |> Verifier.get_blockchain_verification_key
        |> Deferred.Result.map_error ~f:Error.to_string_hum
        >>| Pickles.Verification_key.to_yojson >>| Yojson.Safe.to_basic)

  let commands =
    Fields.to_ocaml_grapql_server_fields
      [ sync_status
      ; daemon_status
      ; version
      ; owned_wallets (* deprecated *)
      ; tracked_accounts
      ; wallet (* deprecated *)
      ; connection_gating_config
      ; account
      ; accounts_for_pk
      ; account_merkle_path
      ; token_owner
      ; current_snark_worker
      ; best_chain
      ; block
      ; genesis_block
      ; initial_peers
      ; get_peers
      ; pooled_user_commands
      ; pooled_zkapp_commands
      ; transaction_status
      ; trust_status
      ; trust_status_all
      ; snark_pool
      ; pending_snark_work
      ; genesis_constants
      ; time_offset
      ; validate_payment
      ; evaluate_vrf
      ; check_vrf
      ; runtime_config
      ; thread_graph
      ; blockchain_verification_key
      ]
end

let schema =
  Graphql_async.Schema.(
    schema Queries.commands ~mutations:Mutations.commands
      ~subscriptions:Subscriptions.commands)

let schema_limited =
  (*including version because that's the default query*)
  Graphql_async.Schema.(
    schema
      (Wrapper.Fields.to_ocaml_grapql_server_fields
         [ Queries.daemon_status; Queries.block; Queries.version ])
      ~mutations:[] ~subscriptions:[])

module Reflection = Reflection
module Types = Types
