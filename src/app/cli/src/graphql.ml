open Core
open Async
open Graphql_async
open Pipe_lib
open Coda_base
open Signature_lib
open Currency

module Make (Commands : Coda_commands.Intf) = struct
  module Program = Commands.Program
  module Config_in = Commands.Config_in
  open Program.Inputs

  module Types = struct
    open Schema

    module Stringable = struct
      (** base64 representation of public key that is compressed to make snark computation efficent *)
      let public_key = Public_key.Compressed.to_base64

      (** Unix form of time, which is the number of milliseconds that elapsed from January 1, 1970 *)
      let date time =
        Time.to_span_since_epoch time |> Time.Span.to_ms |> Int64.to_string

      (** Javascript only has 53-bit integers so we need to make them into strings  *)
      let uint64 uint64 = Unsigned.UInt64.to_string uint64

      (** Balance of Coda (a uint64 under the hood) *)
      let balance b = Balance.to_uint64 b |> uint64
    end

    (* TODO: include submitted_at (date) and included_at (date). These two fields are not exposed in the user_command *)
    let payment : (Program.t, User_command.t option) typ =
      obj "payment" ~fields:(fun _ ->
          [ field "nonce" ~typ:(non_null int) ~doc:"Nonce of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.nonce @@ User_command.payload payment
                |> Account.Nonce.to_int )
          ; field "sender" ~typ:(non_null string)
              ~doc:"Public key of the sender"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.sender payment |> Stringable.public_key )
          ; field "receiver" ~typ:(non_null string)
              ~doc:"Public key of the receiver"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.receiver; _} ->
                    receiver |> Stringable.public_key
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; field "amount" ~typ:(non_null string)
              ~doc:
                "Amount that sender send to receiver (amount is uint64 and is \
                 coerced as a string)"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.amount; _} ->
                    amount |> Currency.Amount.to_uint64 |> Stringable.uint64
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; field "fee" ~typ:(non_null string)
              ~doc:
                "Fee that sender is willing to pay for making the transaction \
                 (fee is uint64 and is coerced as a string)"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.fee payment |> Currency.Fee.to_uint64
                |> Stringable.uint64 )
          ; field "memo" ~typ:(non_null string) ~doc:"Note of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.memo @@ User_command.payload payment
                |> User_command_memo.to_string ) ] )

    let sync_status : ('context, [`Offline | `Synced | `Bootstrap]) typ =
      non_null
        (enum "sync_status" ~doc:"Sync status as daemon node"
           ~values:
             [ enum_value "BOOTSTRAP" ~value:`Bootstrap
             ; enum_value "SYNCED" ~value:`Synced
             ; enum_value "OFFLINE" ~value:`Offline ])

    let pubkey_field ~resolve =
      field "publicKey" ~typ:(non_null string)
        ~doc:"The public identity of a wallet"
        ~args:Arg.[]
        ~resolve

    module Wallet = struct
      module AnnotatedBalance = struct
        type t = {total: Balance.t; unknown: Balance.t}

        let obj =
          obj "AnnotatedBalance"
            ~doc:
              "A total balance annotated with the amount that is currently \
               unknown. Invariant: unknown <= total" ~fields:(fun _ ->
              [ field "total" ~typ:(non_null string)
                  ~doc:"A balance of Coda as a stringified uint64"
                  ~args:Arg.[]
                  ~resolve:(fun _ (b : t) -> Stringable.balance b.total)
              ; field "unknown" ~typ:(non_null string)
                  ~doc:"A balance of Coda as a stringified uint64"
                  ~args:Arg.[]
                  ~resolve:(fun _ (b : t) -> Stringable.balance b.unknown) ] )
      end

      let wallet =
        obj "Wallet" ~doc:"An account record according to the daemon"
          ~fields:(fun _ ->
            [ pubkey_field ~resolve:(fun _ account ->
                  Stringable.public_key account.Account.Poly.public_key )
            ; field "balance"
                ~typ:(non_null AnnotatedBalance.obj)
                ~doc:"A balance of Coda as a stringified uint64"
                ~args:Arg.[]
                ~resolve:(fun _ account -> account.Account.Poly.balance)
            ; field "nonce" ~typ:(non_null string)
                ~doc:
                  "Nonces are natural numbers that increase each transaction. \
                   Stringified uint32"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Account.Nonce.to_string account.Account.Poly.nonce )
            ; field "receiptChainHash" ~typ:(non_null string)
                ~doc:"Top hash of the receipt chain merkle-list"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Receipt.Chain_hash.to_string
                    account.Account.Poly.receipt_chain_hash )
            ; field "delegate" ~typ:(non_null string)
                ~doc:
                  "The public key to which you are delegating (including the \
                   empty key!)"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Stringable.public_key account.Account.Poly.delegate )
            ; field "participated" ~typ:(non_null bool)
                ~doc:"TODO, not sure what this is"
                ~args:Arg.[]
                ~resolve:(fun _ account -> account.Account.Poly.participated)
            ] )
    end

    let snark_worker =
      obj "SnarkWorker" ~fields:(fun _ ->
          [ field "key" ~typ:(non_null string)
              ~doc:"Public key of current snark worker."
              ~args:Arg.[]
              ~resolve:(fun {ctx= coda; _} (key, _) ->
                Stringable.public_key key )
          ; field "fee" ~typ:(non_null string)
              ~doc:
                "Fee that snark worker is charging to generate a snark proof \
                 (fee is uint64 and is coerced as a string)"
              ~args:Arg.[]
              ~resolve:(fun {ctx= coda; _} (_, fee) ->
                Stringable.uint64 (Currency.Fee.to_uint64 fee) ) ] )

    module Payload = struct
      let add_wallet =
        obj "AddWalletPayload" ~fields:(fun _ ->
            [pubkey_field ~resolve:(fun _ key -> Stringable.public_key key)] )

      let create_payment =
        obj "CreatePaymentPayload" ~fields:(fun _ ->
            [ field "payment" ~typ:(non_null payment)
                ~args:Arg.[]
                ~resolve:(fun _ cmd -> cmd) ] )
    end

    module Input = struct
      open Schema.Arg

      let create_payment =
        obj "CreatePaymentInput"
          ~coerce:(fun from to_ amount fee memo ->
            (from, to_, amount, fee, memo) )
          ~fields:
            [ arg "from" ~doc:"Public key of recipient of payment"
                ~typ:(non_null string)
            ; arg "to" ~doc:"Public key of sender of payment"
                ~typ:(non_null string)
            ; arg "amount"
                ~doc:"String representation of uint64 number of tokens to send"
                ~typ:(non_null string)
            ; arg "fee"
                ~doc:
                  "String representation of uint64 number of tokens to pay as \
                   a transaction fee"
                ~typ:(non_null string)
            ; arg "memo" ~doc:"Public description of payment" ~typ:string ]
    end
  end

  let account_of_pk coda pk =
    let account =
      Program.best_ledger coda |> Participating_state.active
      |> Option.bind ~f:(fun ledger ->
             Ledger.location_of_key ledger pk
             |> Option.bind ~f:(Ledger.get ledger) )
    in
    Option.map account
      ~f:(fun { Account.Poly.public_key
              ; nonce
              ; balance
              ; receipt_chain_hash
              ; delegate
              ; participated }
         ->
        { Account.Poly.public_key
        ; nonce
        ; delegate
        ; balance=
            {Types.Wallet.AnnotatedBalance.total= balance; unknown= balance}
        ; receipt_chain_hash
        ; participated } )

  module Queries = struct
    open Schema

    let sync_state =
      io_field "sync_status" ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Deferred.return
            ( Program.Inputs.Incr_status.Observer.value
            @@ Program.sync_status coda )
          >>| Result.map_error ~f:Error.to_string_hum )

    let version =
      field "version" ~typ:string
        ~args:Arg.[]
        ~doc:"The version of the node (git commit hash)"
        ~resolve:(fun _ _ -> Config_in.commit_id)

    let owned_wallets =
      field "ownedWallets"
        ~doc:
          "Wallets for which the daemon knows the private key that are found \
           in our ledger"
        ~typ:(non_null (list (non_null Types.Wallet.wallet)))
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Program.wallets coda |> Secrets.Wallets.pks
          |> List.filter_map ~f:(fun pk -> account_of_pk coda pk) )

    let wallet =
      field "wallet"
        ~doc:
          "Find any wallet via a public key. Null if the key was not found \
           for some reason (i.e. we're bootstrapping, or the account doesn't \
           exist)"
        ~typ:
          Types.Wallet.wallet
          (* TODO: Is there anyway to describe `public_key` arg in a more typesafe way on our ocaml-side *)
        ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
        ~resolve:(fun {ctx= coda; _} () pk_string ->
          let pk = Public_key.Compressed.of_base64_exn pk_string in
          account_of_pk coda pk )

    let current_snark_worker =
      field "currentSnarkWorker" ~typ:Types.snark_worker
        ~args:Arg.[]
        ~doc:"Get information about the current snark worker."
        ~resolve:(fun {ctx= coda; _} _ ->
          Option.map (Program.snark_worker_key coda) ~f:(fun k ->
              (k, Program.snark_work_fee coda) ) )

    let commands =
      [sync_state; version; owned_wallets; wallet; current_snark_worker]
  end

  module Subscriptions = struct
    open Schema

    let to_pipe observer =
      let reader, writer =
        Strict_pipe.(create (Buffered (`Capacity 1, `Overflow Drop_head)))
      in
      Incr_status.Observer.on_update_exn observer ~f:(function
        | Initialized value ->
            Strict_pipe.Writer.write writer value
        | Changed (_, value) ->
            Strict_pipe.Writer.write writer value
        | Invalidated ->
            () ) ;
      (Strict_pipe.Reader.to_linear_pipe reader).Linear_pipe.Reader.pipe

    let new_sync_update =
      subscription_field "new_sync_update"
        ~doc:"Subscripts on sync update from Coda" ~deprecated:NotDeprecated
        ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} ->
          Program.sync_status coda |> to_pipe |> Deferred.Result.return )

    let commands = [new_sync_update]
  end

  module Mutations = struct
    open Schema

    let add_wallet =
      io_field "addWallet" ~doc:"Add a wallet"
        ~typ:
          (non_null Types.Payload.add_wallet)
          (* TODO: For now, not including add wallet input *)
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          let open Deferred.Let_syntax in
          let%map pk = Program.wallets coda |> Secrets.Wallets.generate_new in
          Result.return pk )

    let result_of_exn f v ~error = try Ok (f v) with _ -> Error error

    let send_payment =
      io_field "sendPayment" ~doc:"Send a payment"
        ~typ:(non_null Types.Payload.create_payment)
        ~args:Arg.[arg "input" ~typ:(non_null Types.Input.create_payment)]
        ~resolve:(fun {ctx= coda; _} () (from, to_, amount, fee, maybe_memo) ->
          let open Result.Monad_infix in
          let maybe_info =
            result_of_exn Currency.Amount.of_string amount
              ~error:"Invalid payment `amount` provided."
            >>= fun amount ->
            result_of_exn Currency.Fee.of_string fee
              ~error:"Invalid payment `fee` provided."
            >>= fun fee ->
            result_of_exn Public_key.Compressed.of_base64_exn to_
              ~error:"`to` address is not a valid public key."
            >>= fun receiver ->
            result_of_exn Public_key.Compressed.of_base64_exn from
              ~error:"`from` address is not a valid public key."
            >>= fun sender ->
            Result.of_option
              (account_of_pk coda sender)
              ~error:"Couldn't find the account for specified `sender`."
            >>= fun account ->
            Result.of_option
              (Secrets.Wallets.find (Program.wallets coda) ~needle:sender)
              ~error:
                "Couldn't find the private key for specified `sender`. Do you \
                 own the wallet you're making a payment from?"
            >>= fun sender_kp ->
            ( match maybe_memo with
            | Some m ->
                result_of_exn User_command_memo.create_exn m
                  ~error:"Invalid `memo` provided."
            | None ->
                Ok User_command_memo.dummy )
            >>= fun memo ->
            Result.return (account, sender_kp, memo, receiver, amount, fee)
          in
          match maybe_info with
          | Ok (account, sender_kp, memo, receiver, amount, fee) ->
              let body =
                User_command_payload.Body.Payment {receiver; amount}
              in
              let payload =
                User_command.Payload.create ~fee ~nonce:account.nonce ~memo
                  ~body
              in
              let payment = User_command.sign sender_kp payload in
              let command = User_command.forget_check payment (*uhhh*) in
              let sent = Commands.send_payment Config_in.logger coda command in
              Deferred.map sent ~f:(function
                | `Active (Ok _) ->
                    Ok command
                | `Active (Error e) ->
                    Error ("Couldn't send payment: " ^ Error.to_string_hum e)
                | `Bootstrapping ->
                    Error "Daemon is bootstrapping" )
          | Error e ->
              Deferred.return (Error e) )

    let commands = [add_wallet; send_payment]
  end

  let schema =
    Graphql_async.Schema.(
      schema Queries.commands ~mutations:Mutations.commands
        ~subscriptions:Subscriptions.commands)
end
