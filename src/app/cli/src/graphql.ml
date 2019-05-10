open Core
open Async
open Graphql_async
open Pipe_lib
open Coda_base
open Coda_transition
open Signature_lib
open Currency

module Make (Commands : Coda_commands.Intf) = struct
  module Program = Commands.Program
  module Config_in = Commands.Config_in
  open Program.Inputs

  let result_of_exn f v ~error = try Ok (f v) with _ -> Error error

  let result_field ~resolve =
    Schema.io_field ~resolve:(fun resolve_info src inputs ->
        Deferred.return @@ resolve resolve_info src inputs )

  let result_field_no_inputs ~resolve =
    Schema.io_field ~resolve:(fun resolve_info src ->
        Deferred.return @@ resolve resolve_info src )

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

    let uint64_doc = sprintf !"%s (%s is uint64 and is coerced as a string)"

    let uint64_field name ~doc =
      field name ~typ:(non_null string) ~doc:(uint64_doc doc name)

    let uint64_result_field name ~doc =
      result_field_no_inputs name ~typ:(non_null string)
        ~doc:(uint64_doc doc name)

    (* TODO: include submitted_at (date) and included_at (date). These two fields are not exposed in the user_command *)
    let payment : (Program.t, User_command.t option) typ =
      obj "Payment" ~fields:(fun _ ->
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
          ; result_field_no_inputs "receiver" ~typ:(non_null string)
              ~doc:"Public key of the receiver"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.receiver; _} ->
                    Ok (receiver |> Stringable.public_key)
                | Stake_delegation _ ->
                    Error "Payment should not consist of a stake delegation" )
          ; uint64_result_field "amount"
              ~doc:"Amount that sender send to receiver"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.amount; _} ->
                    Ok
                      (amount |> Currency.Amount.to_uint64 |> Stringable.uint64)
                | Stake_delegation _ ->
                    Error "Payment should not consist of a stake delegation" )
          ; uint64_field "fee"
              ~doc:
                "Fee that sender is willing to pay for making the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.fee payment |> Currency.Fee.to_uint64
                |> Stringable.uint64 )
          ; field "memo" ~typ:(non_null string) ~doc:"Note of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.memo @@ User_command.payload payment
                |> User_command_memo.to_string ) ] )

    let snark_fee : (Program.t, Transaction_snark_work.t option) typ =
      obj "SnarkFee" ~fields:(fun _ ->
          [ field "snarkCreator" ~typ:(non_null string)
              ~doc:"public key of the snarker"
              ~args:Arg.[]
              ~resolve:(fun _ {Transaction_snark_work.prover; _} ->
                Stringable.public_key prover )
          ; field "fee" ~typ:(non_null string)
              ~doc:"the cost of creating the proof"
              ~args:Arg.[]
              ~resolve:(fun _ {Transaction_snark_work.fee; _} ->
                Currency.Fee.to_uint64 fee |> Unsigned.UInt64.to_string ) ] )

    let block : ('context, External_transition.t option) typ =
      obj "Block" ~fields:(fun _ ->
          [ uint64_field "coinbase" ~doc:"Total coinbase awarded to proposer"
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                let staged_ledger_diff =
                  External_transition.staged_ledger_diff external_transition
                in
                staged_ledger_diff |> Staged_ledger_diff.coinbase
                |> Currency.Amount.to_uint64 |> Stringable.uint64 )
          ; field "creator" ~typ:(non_null string)
              ~doc:"Public key of the proposer creating the block"
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                Stringable.public_key @@ Commands.proposer external_transition
                )
          ; field "payments" ~doc:"List of payments in the block"
              ~typ:(non_null (list @@ non_null payment))
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                Commands.payments external_transition )
          ; field "snarkFees"
              ~doc:"Fees that a proposer for constructing proofs"
              ~typ:(non_null (list @@ non_null snark_fee))
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                let staged_ledger_diff =
                  External_transition.staged_ledger_diff external_transition
                in
                Staged_ledger_diff.completed_works staged_ledger_diff ) ] )

    let sync_status : ('context, [`Offline | `Synced | `Bootstrap]) typ =
      non_null
        (enum "SyncStatus" ~doc:"Sync status as daemon node"
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
            ; field "votingFor" ~typ:(non_null string)
                ~doc:
                  "The previous epoch lock hash of the chain which you are \
                   voting for"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Coda_base.State_hash.to_bytes account.Account.Poly.voting_for
                  ) ] )
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
                ~resolve:(fun _ -> Fn.id) ] )
    end

    module Pagination = struct
      module Page_info = struct
        type t = {has_previous_page: bool; has_next_page: bool}

        let typ =
          obj "PageInfo" ~fields:(fun _ ->
              [ field "hasPreviousPage" ~typ:(non_null bool)
                  ~args:Arg.[]
                  ~resolve:(fun _ {has_previous_page; _} -> has_previous_page)
              ; field "hasNextPage" ~typ:(non_null bool)
                  ~args:Arg.[]
                  ~resolve:(fun _ {has_next_page; _} -> has_next_page) ] )
      end

      module Connection = struct
        type 'a t = {edges: 'a list; total_count: int; page_info: Page_info.t}
      end

      module Payment = struct
        module Cursor = struct
          let serialize payment =
            let bigstring =
              Bin_prot.Utils.bin_dump
                Coda_base.User_command.Stable.V1.bin_t.writer payment
            in
            Base64.encode_exn @@ Bigstring.to_string bigstring

          let deserialize serialized_payment =
            let serialized_transaction =
              Base64.decode_exn serialized_payment
            in
            Coda_base.User_command.Stable.V1.bin_t.reader.read
              (Bigstring.of_string serialized_transaction)
              ~pos_ref:(ref 0)
        end

        let edge =
          obj "PaymentEdge" ~fields:(fun _ ->
              [ field "cursor" ~typ:(non_null string)
                  ~doc:
                    "Payment cursor is the base64 version of a serialized \
                     transaction (via Jane Street bin_prot)"
                  ~args:Arg.[]
                  ~resolve:(fun _ user_command -> Cursor.serialize user_command)
              ; field "node" ~typ:(non_null payment)
                  ~args:Arg.[]
                  ~resolve:(fun _ -> Fn.id) ] )

        let connection =
          obj "PaymentConnection" ~fields:(fun _ ->
              [ field "edges"
                  ~typ:(non_null @@ list @@ non_null payment)
                  ~args:Arg.[]
                  ~resolve:(fun _ {Connection.edges; _} -> edges)
              ; field "totalCount" ~typ:(non_null int)
                  ~doc:"Total number of payments that daemon holds"
                  ~args:Arg.[]
                  ~resolve:(fun _ {Connection.total_count; _} -> total_count)
              ; field "pageInfo" ~typ:(non_null Page_info.typ)
                  ~args:Arg.[]
                  ~resolve:(fun _ {Connection.page_info; _} -> page_info) ] )
      end
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

      let payment_filter_input =
        obj "PaymentFilterType"
          ~coerce:(fun public_key -> public_key)
          ~fields:
            [ arg "toOrFrom"
                ~doc:"Public key of transactions you are looking for"
                ~typ:(non_null string) ]
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
              ; voting_for }
         ->
        { Account.Poly.public_key
        ; nonce
        ; delegate
        ; balance=
            {Types.Wallet.AnnotatedBalance.total= balance; unknown= balance}
        ; receipt_chain_hash
        ; voting_for } )

  module Queries = struct
    open Schema

    let sync_state =
      result_field_no_inputs "syncStatus" ~args:[] ~typ:Types.sync_status
        ~resolve:(fun {ctx= coda; _} () ->
          Result.map_error
            (Coda_incremental.Status.Observer.value @@ Program.sync_status coda)
            ~f:Error.to_string_hum )

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
      result_field "wallet"
        ~doc:
          "Find any wallet via a public key. Null if the key was not found \
           for some reason (i.e. we're bootstrapping, or the account doesn't \
           exist)"
        ~typ:
          Types.Wallet.wallet
          (* TODO: Is there anyway to describe `public_key` arg in a more typesafe way on our ocaml-side *)
        ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
        ~resolve:(fun {ctx= coda; _} () pk_string ->
          let open Result.Let_syntax in
          let%map pk =
            result_of_exn ~error:"publicKey address is not valid."
              Public_key.Compressed.of_base64_exn pk_string
          in
          account_of_pk coda pk )

    let current_snark_worker =
      field "currentSnarkWorker" ~typ:Types.snark_worker
        ~args:Arg.[]
        ~doc:"Get information about the current snark worker."
        ~resolve:(fun {ctx= coda; _} _ ->
          Option.map (Program.snark_worker_key coda) ~f:(fun k ->
              (k, Program.snark_work_fee coda) ) )

    let build_connection ~query transaction_database public_key cursor
        num_to_query =
      let ( queried_transactions
          , `Has_earlier_page has_previous_page
          , `Has_later_page has_next_page ) =
        query transaction_database public_key
          (Option.map ~f:Types.Pagination.Payment.Cursor.deserialize cursor)
          num_to_query
      in
      let page_info =
        {Types.Pagination.Page_info.has_previous_page; has_next_page}
      in
      let total_count =
        Option.value_exn
          (Transaction_database.get_total_transactions transaction_database
             public_key)
      in
      { Types.Pagination.Connection.edges= queried_transactions
      ; page_info
      ; total_count }

    let payments =
      io_field "payments"
        ~args:
          Arg.
            [ arg "filter" ~typ:(non_null Types.Input.payment_filter_input)
            ; arg "first" ~typ:int
            ; arg "after" ~typ:string
            ; arg "last" ~typ:int
            ; arg "before" ~typ:string ]
        ~typ:(non_null Types.Pagination.Payment.connection)
        ~resolve:(fun {ctx= coda; _} () public_key first after last before ->
          let open Deferred.Result.Let_syntax in
          let%bind public_key =
            Deferred.return
            @@ result_of_exn Public_key.Compressed.of_base64_exn public_key
                 ~error:"publicKey address is not valid."
          in
          let transaction_database = Program.transaction_database coda in
          Deferred.return
          @@
          match (first, after, last, before) with
          | Some _n_queries_before, _, Some _n_queries_after, _ ->
              Error
                "Illegal query: first and last must not be non-null value at \
                 the same time"
          | num_to_query, cursor, None, _ ->
              Ok
                (build_connection
                   ~query:Transaction_database.get_earlier_transactions
                   transaction_database public_key cursor num_to_query)
          | None, _, num_to_query, cursor ->
              Ok
                (build_connection
                   ~query:Transaction_database.get_later_transactions
                   transaction_database public_key cursor num_to_query) )

    let initial_peers =
      field "initialPeers"
        ~doc:
          "The initial peers that a client syncs with is an inidication of \
           specifically the network they are in"
        ~args:Arg.[]
        ~typ:(non_null @@ list @@ non_null string)
        ~resolve:(fun {ctx= coda; _} () ->
          List.map (Program.initial_peers coda)
            ~f:(fun {Host_and_port.host; port} -> sprintf !"%s:%i" host port)
          )

    let commands =
      [ sync_state
      ; version
      ; owned_wallets
      ; wallet
      ; current_snark_worker
      ; payments
      ; initial_peers ]
  end

  module Subscriptions = struct
    open Schema

    let new_sync_update =
      subscription_field "newSyncUpdate"
        ~doc:"Subscribes on sync update from Coda" ~deprecated:NotDeprecated
        ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} ->
          Program.sync_status coda |> Coda_incremental.Status.to_pipe
          |> Deferred.Result.return )

    let new_block =
      subscription_field "newBlock"
        ~doc:
          "Subscribes on a new block created by a proposer with a public key \
           KEY"
        ~typ:(non_null Types.block)
        ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
        ~resolve:(fun {ctx= coda; _} public_key ->
          let open Deferred.Result.Let_syntax in
          let%bind public_key =
            Deferred.return
            @@ result_of_exn Public_key.Compressed.of_base64_exn public_key
                 ~error:"publicKey is not valid"
          in
          (* Pipes that will alert a subscriber of any new blocks throughout the entire time the daemon is on *)
          Deferred.Result.return
          @@ Commands.Subscriptions.new_block coda public_key )

    let new_payment_update =
      subscription_field "newPaymentUpdate"
        ~doc:
          "Subscribes for payments with the sender's public key KEY whenever \
           we receive a block"
        ~typ:(non_null Types.payment)
        ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
        ~resolve:(fun {ctx= coda; _} public_key ->
          let public_key = Public_key.Compressed.of_base64_exn public_key in
          Deferred.Result.return
          @@ Commands.Subscriptions.new_payment coda public_key )

    let commands = [new_sync_update; new_block; new_payment_update]
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
              let sent = Commands.send_payment coda command in
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
