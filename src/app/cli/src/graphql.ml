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

  module Doc = struct
    let uint64 = sprintf !"%s (%s is uint64 and is coerced as a string)"

    let date =
      sprintf
        !"%s (%s is the Unix form of time, which is the number of \
          milliseconds that elapsed from January 1, 1970)"
  end

  module Types = struct
    open Schema

    module Stringable = struct
      (** base64 representation of public key that is compressed to make snark computation efficent *)
      let public_key = Public_key.Compressed.to_base64

      (** Unix form of time, which is the number of milliseconds that elapsed from January 1, 1970 *)
      let date = Time.to_string

      (** Javascript only has 53-bit integers so we need to make them into strings  *)
      let uint64 uint64 = Unsigned.UInt64.to_string uint64

      (** Balance of Coda (a uint64 under the hood) *)
      let balance b = Balance.to_uint64 b |> uint64
    end

    let uint64_arg name ~doc ~typ =
      let open Schema.Arg in
      arg name ~typ ~doc:(Doc.uint64 name doc)

    let uint64_field name ~doc =
      field name ~typ:(non_null string) ~doc:(Doc.uint64 doc name)

    let uint64_result_field name ~doc =
      result_field_no_inputs name ~typ:(non_null string)
        ~doc:(Doc.uint64 doc name)

    (* TODO: include submitted_at (date) and included_at (date). These two fields are not exposed in the user_command *)
    let user_command : (Program.t, User_command.t option) typ =
      obj "UserCommand" ~fields:(fun _ ->
          [ field "isDelegation" ~typ:(non_null bool)
              ~doc:
                "If true, then User command is a Stake Delegation kind, \
                 otherwise it is a payment kind"
              ~args:Arg.[]
              ~resolve:(fun _ user_command ->
                match
                  User_command.Payload.body
                  @@ User_command.payload user_command
                with
                | Stake_delegation _ ->
                    true
                | Payment _ ->
                    false )
          ; field "nonce" ~typ:(non_null int) ~doc:"Nonce of the transaction"
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
                    Stringable.public_key receiver
                | Stake_delegation (Set_delegate {new_delegate}) ->
                    Stringable.public_key new_delegate )
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
                    (* Stake delegation does not have an amount, so we set it to 0 *)
                    Ok "0" )
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

    let delegation_update =
      obj "DelegationUpdate" ~fields:(fun _ ->
          [ field "status"
              ~args:Arg.[]
              ~typ:(non_null user_command)
              ~resolve:(fun _ user_command -> user_command)
            (* TODO: include active field *)
            (* TODO: include consensus field *)
           ] )

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
                Stringable.public_key
                @@ External_transition.proposer external_transition )
          ; field "userCommands" ~doc:"List of user commands in the block"
              ~typ:(non_null (list @@ non_null user_command))
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                External_transition.user_commands external_transition )
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
                  (* Hack: Account.Poly.t is only parameterized over 'pk once
                   * and so, in order for delegate to be optional, we must also
                   * make account public_key optional even though it's always
                   * Some. In an attempt to avoid a large refactoring, and also
                   * avoid making a new record, we'll deal with a value_exn here
                   * and be sad. *)
                  Stringable.public_key
                  @@ Option.value_exn account.Account.Poly.public_key )
            ; field "balance"
                ~typ:(non_null AnnotatedBalance.obj)
                ~doc:"A balance of Coda as a stringified uint64"
                ~args:Arg.[]
                ~resolve:(fun _ account -> account.Account.Poly.balance)
            ; field "nonce" ~typ:string
                ~doc:
                  "Nonces are natural numbers that increase each transaction. \
                   Stringified uint32"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Option.map ~f:Account.Nonce.to_string
                    account.Account.Poly.nonce )
            ; field "receiptChainHash" ~typ:string
                ~doc:"Top hash of the receipt chain merkle-list"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Option.map ~f:Receipt.Chain_hash.to_string
                    account.Account.Poly.receipt_chain_hash )
            ; field "delegate" ~typ:string
                ~doc:
                  "The public key to which you are delegating. If you are not \
                   delegating to anybody, than this would return your public \
                   key."
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Option.map ~f:Stringable.public_key
                    account.Account.Poly.delegate )
            ; field "votingFor" ~typ:string
                ~doc:
                  "The previous epoch lock hash of the chain which you are \
                   voting for"
                ~args:Arg.[]
                ~resolve:(fun _ account ->
                  Option.map ~f:Coda_base.State_hash.to_bytes
                    account.Account.Poly.voting_for ) ] )
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
            [ field "payment" ~typ:(non_null user_command)
                ~args:Arg.[]
                ~resolve:(fun _ -> Fn.id) ] )

      let set_delegation =
        obj "SetDelegationPayload" ~fields:(fun _ ->
            [ field "delegation" ~typ:(non_null user_command)
                ~args:Arg.[]
                ~resolve:(fun _ -> Fn.id) ] )

      let add_payment_receipt =
        obj "AddPaymentReceipt" ~fields:(fun _ ->
            [ field "payment" ~typ:(non_null user_command)
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
    end

    module User_command = struct
      module Cursor = struct
        let serialize payment =
          let bigstring =
            Bin_prot.Utils.bin_dump
              Coda_base.User_command.Stable.V1.bin_t.writer payment
          in
          Base64.encode_exn @@ Bigstring.to_string bigstring

        let deserialize serialized_payment =
          let serialized_transaction = Base64.decode_exn serialized_payment in
          Coda_base.User_command.Stable.V1.bin_t.reader.read
            (Bigstring.of_string serialized_transaction)
            ~pos_ref:(ref 0)
      end

      let edge =
        obj "PaymentEdge" ~fields:(fun _ ->
            [ field "cursor" ~typ:(non_null string)
                ~doc:
                  "Cursor is the base64 version of a serialized user command \
                   (via Jane Street bin_prot)"
                ~args:Arg.[]
                ~resolve:(fun _ user_command -> Cursor.serialize user_command)
            ; field "node" ~typ:(non_null user_command)
                ~args:Arg.[]
                ~resolve:(fun _ -> Fn.id) ] )

      let connection =
        obj "PaymentConnection" ~fields:(fun _ ->
            [ field "edges"
                ~typ:(non_null @@ list @@ non_null user_command)
                ~args:Arg.[]
                ~resolve:(fun _ {Pagination.Connection.edges; _} -> edges)
            ; field "totalCount" ~typ:(non_null int)
                ~doc:"Total number of payments that daemon holds"
                ~args:Arg.[]
                ~resolve:(fun _ {Pagination.Connection.total_count; _} ->
                  total_count )
            ; field "pageInfo"
                ~typ:(non_null Pagination.Page_info.typ)
                ~args:Arg.[]
                ~resolve:(fun _ {Pagination.Connection.page_info; _} ->
                  page_info ) ] )
    end

    module Input = struct
      open Schema.Arg

      module Fields = struct
        let from ~doc = arg "from" ~typ:(non_null string) ~doc

        let to_ ~doc = arg "to" ~typ:(non_null string) ~doc

        let fee ~doc = uint64_arg "fee" ~typ:(non_null string) ~doc

        let memo ~doc = uint64_arg "memo" ~typ:string ~doc
      end

      let create_payment =
        let open Fields in
        obj "CreatePaymentInput"
          ~coerce:(fun from to_ amount fee memo ->
            (from, to_, amount, fee, memo) )
          ~fields:
            [ from ~doc:"Public key of recipient of payment"
            ; to_ ~doc:"Public key of sender of payment"
            ; uint64_arg "amount" ~doc:"amount to send to to receiver"
                ~typ:(non_null string)
            ; fee ~doc:"Fee amount in order to send payment"
            ; memo ~doc:"Public description of payment" ]

      let set_delegation =
        let open Fields in
        obj "SetDelegationInput"
          ~coerce:(fun from to_ fee memo -> (from, to_, fee, memo))
          ~fields:
            [ from ~doc:"Public key of recipient of a stake delegation"
            ; to_ ~doc:"Public key of sender of a stake delegation"
            ; fee ~doc:"Fee amount in order to send a stake delegation"
            ; memo ~doc:"Public description of a stake delegation" ]

      let user_command_filter_input =
        obj "UserCommandFilterType"
          ~coerce:(fun public_key -> public_key)
          ~fields:
            [ arg "toOrFrom"
                ~doc:"Public key of transactions you are looking for"
                ~typ:(non_null string) ]

      module AddPaymentReceipt = struct
        type t = {payment: string; added_time: string}

        let typ =
          obj "AddPaymentReceiptInput"
            ~coerce:(fun payment added_time -> {payment; added_time})
            ~fields:
              [ arg "payment"
                  ~doc:
                    "Payment is the base64 version of a serialized payment \
                     (via Jane Street bin_prot)"
                  ~typ:(non_null string)
              ; (* TODO: create a formal method for verifying that the provided added_time is correct  *)
                arg "added_time" ~typ:(non_null string)
                  ~doc:
                    (Doc.date "added_time"
                       "Time that a payment gets added to another clients \
                        transaction database") ]
      end
    end
  end

  module Partial_account = struct
    let to_full_account
        { Account.Poly.public_key
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for } =
      let open Option.Let_syntax in
      let%bind public_key = public_key in
      let%bind nonce = nonce in
      let%bind receipt_chain_hash = receipt_chain_hash in
      let%bind delegate = delegate in
      let%map voting_for = voting_for in
      { Account.Poly.public_key
      ; nonce
      ; balance
      ; receipt_chain_hash
      ; delegate
      ; voting_for }

    let of_full_account
        { Account.Poly.public_key
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for } =
      { Account.Poly.public_key= Some public_key
      ; nonce= Some nonce
      ; balance
      ; receipt_chain_hash= Some receipt_chain_hash
      ; delegate= Some delegate
      ; voting_for= Some voting_for }

    let of_pk coda pk =
      let account =
        Program.best_ledger coda |> Participating_state.active
        |> Option.bind ~f:(fun ledger ->
               Ledger.location_of_key ledger pk
               |> Option.bind ~f:(Ledger.get ledger) )
      in
      match account with
      | Some
          { Account.Poly.public_key
          ; nonce
          ; balance
          ; receipt_chain_hash
          ; delegate
          ; voting_for } ->
          { Account.Poly.public_key= Some public_key
          ; nonce= Some nonce
          ; delegate= Some delegate
          ; balance=
              {Types.Wallet.AnnotatedBalance.total= balance; unknown= balance}
          ; receipt_chain_hash= Some receipt_chain_hash
          ; voting_for= Some voting_for }
      | None ->
          { Account.Poly.public_key= Some pk
          ; nonce= None
          ; delegate= None
          ; balance=
              { Types.Wallet.AnnotatedBalance.total= Balance.zero
              ; unknown= Balance.zero }
          ; receipt_chain_hash= None
          ; voting_for= None }
  end

  module Arguments = struct
    let public_key ~name public_key =
      result_of_exn Public_key.Compressed.of_base64_exn public_key
        ~error:(sprintf !"%s address is not valid." name)
  end

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
          "Wallets for which the daemon knows the private key. If they are \
           found in our ledger, all the fields will be non-null"
        ~typ:(non_null (list (non_null Types.Wallet.wallet)))
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Program.wallets coda |> Secrets.Wallets.pks
          |> List.map ~f:(fun pk -> Partial_account.of_pk coda pk) )

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
          let%map pk = Arguments.public_key ~name:"publicKey" pk_string in
          Partial_account.(
            of_pk coda pk |> to_full_account |> Option.map ~f:of_full_account)
          )

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
          (Option.map ~f:Types.User_command.Cursor.deserialize cursor)
          num_to_query
      in
      let page_info =
        {Types.Pagination.Page_info.has_previous_page; has_next_page}
      in
      let total_count =
        Option.value
          (Transaction_database.get_total_transactions transaction_database
             public_key)
          ~default:0
      in
      { Types.Pagination.Connection.edges= queried_transactions
      ; page_info
      ; total_count }

    let user_command =
      io_field "userCommand"
        ~args:
          Arg.
            [ arg "filter" ~typ:(non_null Types.Input.user_command_filter_input)
            ; arg "first" ~typ:int
            ; arg "after" ~typ:string
            ; arg "last" ~typ:int
            ; arg "before" ~typ:string ]
        ~typ:(non_null Types.User_command.connection)
        ~resolve:(fun {ctx= coda; _} () public_key first after last before ->
          let open Deferred.Result.Let_syntax in
          let%bind public_key =
            Deferred.return
            @@ Arguments.public_key ~name:"publicKey" public_key
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
      ; user_command
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
            @@ Arguments.public_key ~name:"publicKey" public_key
          in
          (* Pipes that will alert a subscriber of any new blocks throughout the entire time the daemon is on *)
          Deferred.Result.return
          @@ Commands.Subscriptions.new_block coda public_key )

    let new_user_command_update =
      subscription_field "newUserCommandUpdate"
        ~doc:
          "Subscribes for payments with the sender's public key KEY whenever \
           we receive a block"
        ~typ:(non_null Types.user_command)
        ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
        ~resolve:(fun {ctx= coda; _} public_key ->
          let public_key = Public_key.Compressed.of_base64_exn public_key in
          Deferred.Result.return
          @@ Commands.Subscriptions.new_payment coda public_key )

    let commands = [new_sync_update; new_block; new_user_command_update]
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

    let build_user_command coda {Account.Poly.nonce; _} sender_kp memo
        payment_body fee =
      let payload =
        User_command.Payload.create ~fee ~nonce ~memo ~body:payment_body
      in
      let payment = User_command.sign sender_kp payload in
      let command = User_command.forget_check payment in
      match%map Commands.send_payment coda command with
      | `Active (Ok _) ->
          Ok command
      | `Active (Error e) ->
          Error ("Couldn't send user_command: " ^ Error.to_string_hum e)
      | `Bootstrapping ->
          Error "Daemon is bootstrapping"

    let parse_user_command_input ~kind coda from to_ fee maybe_memo =
      let open Result.Let_syntax in
      let%bind receiver = Arguments.public_key ~name:"to" to_ in
      let%bind sender = Arguments.public_key ~name:"from" from in
      let%bind sender_account =
        Result.of_option
          Partial_account.(of_pk coda sender |> to_full_account)
          ~error:"Couldn't find the account for specified `sender`."
      in
      let%bind fee =
        result_of_exn Currency.Fee.of_string fee
          ~error:(sprintf "Invalid %s `fee` provided." kind)
      in
      let%bind sender_kp =
        Result.of_option
          (Secrets.Wallets.find (Program.wallets coda) ~needle:sender)
          ~error:
            (sprintf
               "Couldn't find the private key for specified `sender`. Do you \
                own the wallet you're making a %s from?"
               kind)
      in
      let%map memo =
        Option.value_map maybe_memo ~default:(Ok User_command_memo.dummy)
          ~f:(fun memo ->
            result_of_exn User_command_memo.create_exn memo
              ~error:"Invalid `memo` provided." )
      in
      (sender_account, sender_kp, memo, receiver, fee)

    let set_delegation =
      io_field "sendPayment" ~doc:"Send a payment"
        ~typ:(non_null Types.Payload.create_payment)
        ~args:Arg.[arg "input" ~typ:(non_null Types.Input.create_payment)]
        ~resolve:(fun {ctx= coda; _} () (from, to_, amount, fee, maybe_memo) ->
          let open Deferred.Result.Let_syntax in
          let%bind sender_account, sender_kp, memo, new_delegate, fee =
            Deferred.return
            @@ parse_user_command_input ~kind:"stake delegation" coda from to_
                 fee maybe_memo
          in
          let body =
            User_command_payload.Body.Stake_delegation
              (Set_delegate {new_delegate})
          in
          build_user_command coda sender_account sender_kp memo body fee )

    let send_payment =
      io_field "sendPayment" ~doc:"Send a payment"
        ~typ:(non_null Types.Payload.create_payment)
        ~args:Arg.[arg "input" ~typ:(non_null Types.Input.create_payment)]
        ~resolve:(fun {ctx= coda; _} () (from, to_, amount, fee, maybe_memo) ->
          let open Deferred.Result.Let_syntax in
          let%bind amount =
            Deferred.return
            @@ result_of_exn Currency.Amount.of_string amount
                 ~error:"Invalid payment `amount` provided."
          in
          let%bind sender_account, sender_kp, memo, receiver, fee =
            Deferred.return
            @@ parse_user_command_input ~kind:"payment" coda from to_ fee
                 maybe_memo
          in
          let body = User_command_payload.Body.Payment {receiver; amount} in
          build_user_command coda sender_account sender_kp memo body fee )

    let add_payment_receipt =
      result_field "addPaymentReceipt"
        ~doc:"Add payment into transation database"
        ~args:
          Arg.[arg "input" ~typ:(non_null Types.Input.AddPaymentReceipt.typ)]
        ~typ:Types.Payload.add_payment_receipt
        ~resolve:
          (fun {ctx= coda; _} ()
               {Types.Input.AddPaymentReceipt.payment; added_time} ->
          let open Result.Let_syntax in
          let%bind added_time =
            result_of_exn Block_time.Time.of_string_exn added_time
              ~error:"Invalid `time` provided"
          in
          let%map payment =
            result_of_exn Types.User_command.Cursor.deserialize payment
              ~error:"Invaid `payment` provided"
          in
          let transaction_database = Program.transaction_database coda in
          Transaction_database.add transaction_database payment added_time ;
          Some payment )

    let commands =
      [add_wallet; send_payment; set_delegation; add_payment_receipt]
  end

  let schema =
    Graphql_async.Schema.(
      schema Queries.commands ~mutations:Mutations.commands
        ~subscriptions:Subscriptions.commands)
end
