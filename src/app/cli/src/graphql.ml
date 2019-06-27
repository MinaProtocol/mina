open Core
open Async
open Graphql_async
open Coda_base
open Signature_lib
open Currency
open Auxiliary_database

let result_of_exn f v ~error = try Ok (f v) with _ -> Error error

let result_of_or_error ?error v =
  Result.map_error v ~f:(fun internal_error ->
      let str_error = Error.to_string_hum internal_error in
      match error with
      | None ->
          str_error
      | Some error ->
          sprintf "%s (%s)" error str_error )

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
      !"%s (%s is the Unix form of time, which is the number of milliseconds \
        that elapsed from January 1, 1970)"
end

module Reflection = struct
  let regex = lazy (Re2.create_exn {regex|\_(\w)|regex})

  let underToCamel s =
    Re2.replace_exn (Lazy.force regex) s ~f:(fun m ->
        let s = Re2.Match.get_exn ~sub:(`Index 1) m in
        String.capitalize s )

  (** When Fields.folding, create graphql fields via reflection *)
  let reflect f ~typ acc x =
    let new_name = underToCamel (Field.name x) in
    Schema.(
      field new_name ~typ ~args:Arg.[] ~resolve:(fun _ v -> f (Field.get x v))
      :: acc)

  module Shorthand = struct
    open Schema

    (* Note: Eta expansion is needed here to combat OCaml's weak polymorphism nonsense *)

    let id ~typ a x = reflect Fn.id ~typ a x

    let nn_int a x = id ~typ:(non_null int) a x

    let int a x = id ~typ:int a x

    let nn_bool a x = id ~typ:(non_null bool) a x

    let bool a x = id ~typ:bool a x

    let nn_string a x = id ~typ:(non_null string) a x

    let string a x = id ~typ:string a x

    module F = struct
      let int f a x = reflect f ~typ:Schema.int a x

      let nn_int f a x = reflect f ~typ:Schema.(non_null int) a x

      let string f a x = reflect f ~typ:Schema.string a x

      let nn_string f a x = reflect f ~typ:Schema.(non_null string) a x
    end
  end
end

module Types = struct
  open Schema

  module Stringable = struct
    (** base58 representation of public key that is compressed to make snark computation efficent *)
    let public_key = Public_key.Compressed.to_base58_check

    (** string representation of IPv4 or IPv6 address *)
    let ip_address = Unix.Inet_addr.to_string

    (** Unix form of time, which is the number of milliseconds that elapsed from January 1, 1970 *)
    let date = Time.to_string

    (** string representation of Trust_system.Banned_status *)
    let banned_status = function
      | Trust_system.Banned_status.Unbanned ->
          None
      | Banned_until tm ->
          Some (date tm)

    (** Javascript only has 53-bit integers so we need to make them into strings  *)
    let uint64 uint64 = Unsigned.UInt64.to_string uint64

    (** Balance of Coda (a uint64 under the hood) *)
    let balance b = Balance.to_uint64 b |> uint64

    let fee fee = uint64 @@ Currency.Fee.to_uint64 fee

    let amount amount = uint64 @@ Currency.Amount.to_uint64 amount

    module State_hash = Codable.Make_base58_check (State_hash.Stable.V1)
  end

  module Id = struct
    let version_byte = Base58_check.Version_bytes.graphql

    (* The id of a user_command is the Base58Check encoding of the serialized version of the user_command *)
    let user_command user_command =
      let bigstring =
        Bin_prot.Utils.bin_dump Coda_base.User_command.Stable.V1.bin_t.writer
          user_command
      in
      let payload = Bigstring.to_string bigstring in
      Base58_check.encode ~version_byte ~payload
  end

  let uint64_arg name ~doc ~typ =
    let open Schema.Arg in
    arg name ~typ ~doc:(Doc.uint64 name doc)

  let uint64_field name ~doc =
    field name ~typ:(non_null string) ~doc:(Doc.uint64 doc name)

  let uint64_result_field name ~doc =
    result_field_no_inputs name ~typ:(non_null string)
      ~doc:(Doc.uint64 doc name)

  let sync_status : ('context, [`Offline | `Synced | `Bootstrap] option) typ =
    enum "SyncStatus" ~doc:"Sync status as daemon node"
      ~values:
        [ enum_value "BOOTSTRAP" ~value:`Bootstrap
        ; enum_value "SYNCED" ~value:`Synced
        ; enum_value "OFFLINE" ~value:`Offline ]

  module DaemonStatus = struct
    type t = Daemon_rpcs.Types.Status.t

    let interval : (_, (Time.Span.t * Time.Span.t) option) typ =
      obj "Interval" ~fields:(fun _ ->
          [ field "start" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (start, _) ->
                Time.Span.to_ms start |> Int64.of_float |> Int64.to_string )
          ; field "stop" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (_, end_) ->
                Time.Span.to_ms end_ |> Int64.of_float |> Int64.to_string ) ]
      )

    let histogram : (_, Perf_histograms.Report.t option) typ =
      obj "Histogram" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Perf_histograms.Report.Fields.fold ~init:[]
               ~values:(id ~typ:Schema.(non_null (list (non_null int))))
               ~intervals:(id ~typ:(non_null (list (non_null interval))))
               ~underflow:nn_int ~overflow:nn_int )

    module Rpc_timings = Daemon_rpcs.Types.Status.Rpc_timings
    module Rpc_pair = Rpc_timings.Rpc_pair

    let rpc_pair : (_, Perf_histograms.Report.t option Rpc_pair.t option) typ =
      let h = Reflection.Shorthand.id ~typ:histogram in
      obj "RpcPair" ~fields:(fun _ ->
          List.rev @@ Rpc_pair.Fields.fold ~init:[] ~dispatch:h ~impl:h )

    let rpc_timings : (_, Rpc_timings.t option) typ =
      let fd = Reflection.Shorthand.id ~typ:(non_null rpc_pair) in
      obj "RpcTimings" ~fields:(fun _ ->
          List.rev
          @@ Rpc_timings.Fields.fold ~init:[] ~get_staged_ledger_aux:fd
               ~answer_sync_ledger_query:fd ~get_ancestry:fd
               ~transition_catchup:fd )

    module Histograms = Daemon_rpcs.Types.Status.Histograms

    let histograms : (_, Histograms.t option) typ =
      let h = Reflection.Shorthand.id ~typ:histogram in
      obj "Histograms" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Histograms.Fields.fold ~init:[]
               ~rpc_timings:(id ~typ:(non_null rpc_timings))
               ~external_transition_latency:h
               ~accepted_transition_local_latency:h
               ~accepted_transition_remote_latency:h
               ~snark_worker_transition_time:h ~snark_worker_merge_time:h )

    let consensus_configuration : (_, Consensus.Configuration.t option) typ =
      obj "ConsensusConfiguration" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Consensus.Configuration.Fields.fold ~init:[] ~delta:nn_int
               ~k:nn_int ~c:nn_int ~c_times_k:nn_int ~slots_per_epoch:nn_int
               ~slot_duration:nn_int ~epoch_duration:nn_int
               ~acceptable_network_delay:nn_int )

    let t : (_, Daemon_rpcs.Types.Status.t option) typ =
      obj "DaemonStatus" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Daemon_rpcs.Types.Status.Fields.fold ~init:[] ~num_accounts:int
               ~blockchain_length:int ~uptime_secs:nn_int
               ~ledger_merkle_root:string ~staged_ledger_hash:string
               ~state_hash:string ~commit_id:nn_string ~conf_dir:nn_string
               ~peers:(id ~typ:Schema.(non_null @@ list (non_null string)))
               ~user_commands_sent:nn_int ~run_snark_worker:nn_bool
               ~sync_status:(id ~typ:(non_null sync_status))
               ~propose_pubkeys:
                 (Reflection.reflect
                    ~typ:Schema.(non_null @@ list (non_null string))
                    (List.map ~f:Stringable.public_key))
               ~histograms:(id ~typ:histograms) ~consensus_time_best_tip:string
               ~consensus_time_now:nn_string ~consensus_mechanism:nn_string
               ~consensus_configuration:
                 (id ~typ:(non_null consensus_configuration)) )
  end

  let user_command : (Coda_lib.t, User_command.t option) typ =
    obj "UserCommand" ~fields:(fun _ ->
        [ field "id" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ user_command -> Id.user_command user_command)
        ; field "isDelegation" ~typ:(non_null bool)
            ~doc:
              "If true, then User command is a Stake Delegation kind, \
               otherwise it is a payment kind"
            ~args:Arg.[]
            ~resolve:(fun _ user_command ->
              match
                User_command.Payload.body @@ User_command.payload user_command
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
        ; field "from" ~typ:(non_null string) ~doc:"Public key of the sender"
            ~args:Arg.[]
            ~resolve:(fun _ payment ->
              User_command.sender payment |> Stringable.public_key )
        ; field "to" ~typ:(non_null string) ~doc:"Public key of the receiver"
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
            ~doc:"Amount that sender is sending to receiver"
            ~args:Arg.[]
            ~resolve:(fun _ payment ->
              match
                User_command_payload.body (User_command.payload payment)
              with
              | Payment {Payment_payload.Poly.amount; _} ->
                  Ok (amount |> Currency.Amount.to_uint64 |> Stringable.uint64)
              | Stake_delegation _ ->
                  (* Stake delegation does not have an amount, so we set it to 0 *)
                  Ok "0" )
        ; uint64_field "fee"
            ~doc:"Fee that sender is willing to pay for making the transaction"
            ~args:Arg.[]
            ~resolve:(fun _ payment ->
              User_command.fee payment |> Currency.Fee.to_uint64
              |> Stringable.uint64 )
        ; field "memo" ~typ:(non_null string) ~doc:"Note of the transaction"
            ~args:Arg.[]
            ~resolve:(fun _ payment ->
              User_command_payload.memo @@ User_command.payload payment
              |> User_command_memo.to_string ) ] )

  let fee_transfer =
    obj "FeeTransfer" ~fields:(fun _ ->
        [ field "recipient"
            ~args:Arg.[]
            ~doc:"Receipt of fee transfer" ~typ:(non_null string)
            ~resolve:(fun _ (pk, _) -> Stringable.public_key pk)
        ; uint64_field "fee" ~doc:"Fee that the receipt receives"
            ~args:Arg.[]
            ~resolve:(fun _ (_, fee) -> Stringable.fee fee) ] )

  let delegation_update =
    obj "DelegationUpdate" ~fields:(fun _ ->
        [ field "status"
            ~args:Arg.[]
            ~typ:(non_null user_command)
            ~resolve:(fun _ user_command -> user_command)
          (* TODO: include active field *)
          (* TODO: include consensus field *)
         ] )

  let transactions =
    let open Filtered_external_transition.Transactions in
    obj "Transactions" ~doc:"Different types of transactions in a block"
      ~fields:(fun _ ->
        [ field "userCommands"
            ~typ:(non_null @@ list @@ non_null user_command)
            ~args:Arg.[]
            ~resolve:(fun _ {user_commands; _} -> user_commands)
        ; field "feeTransfer"
            ~typ:(non_null @@ list @@ non_null fee_transfer)
            ~args:Arg.[]
            ~resolve:(fun _ {fee_transfers; _} -> fee_transfers)
        ; uint64_field "coinbase" ~doc:"Coinbase amount that proposer receives"
            ~args:Arg.[]
            ~resolve:(fun _ {coinbase; _} -> Stringable.amount coinbase) ] )

  let snark_fee : (Coda_lib.t, Transaction_snark_work.t option) typ =
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

  let blockchain_state =
    obj "BlockchainState" ~fields:(fun _ ->
        [ field "date" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ {Coda_state.Blockchain_state.Poly.timestamp; _} ->
              Block_time.to_string timestamp )
        ; field "snarkedLedgerHash" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:
              (fun _ {Coda_state.Blockchain_state.Poly.snarked_ledger_hash; _} ->
              Frozen_ledger_hash.to_bytes snarked_ledger_hash )
        ; field "stagedLedgerHash" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:
              (fun _ {Coda_state.Blockchain_state.Poly.staged_ledger_hash; _} ->
              Ledger_hash.to_bytes
              @@ Staged_ledger_hash.ledger_hash staged_ledger_hash ) ] )

  let protocol_state =
    let open Filtered_external_transition.Protocol_state in
    obj "ProtocolState" ~fields:(fun _ ->
        [ field "previousStateHash" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ t ->
              Stringable.State_hash.to_base58_check t.previous_state_hash )
        ; field "blockchainState"
            ~typ:(non_null blockchain_state)
            ~args:Arg.[]
            ~resolve:(fun _ t -> t.blockchain_state) ] )

  let block :
      ( Coda_lib.t
      , (Filtered_external_transition.t, State_hash.t) With_hash.t option )
      typ =
    let open Filtered_external_transition in
    obj "Block" ~fields:(fun _ ->
        [ field "creator" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ {With_hash.data; _} ->
              Stringable.public_key data.creator )
        ; field "stateHash" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ {With_hash.hash; _} ->
              Stringable.State_hash.to_base58_check hash )
        ; field "protocolState" ~typ:(non_null protocol_state)
            ~args:Arg.[]
            ~resolve:(fun _ {With_hash.data; _} -> data.protocol_state)
        ; field "transactions" ~typ:(non_null transactions)
            ~args:Arg.[]
            ~resolve:(fun _ {With_hash.data; _} -> data.transactions) ] )

  let chain_reorganization_status : ('context, [`Changed] option) typ =
    enum "ChainReorganizationStatus"
      ~doc:"Status for whenever the blockchain is reorganized"
      ~values:[enum_value "CHANGED" ~value:`Changed]

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

    (** Hack: Account.Poly.t is only parameterized over 'pk once and so, in
        order for delegate to be optional, we must also make account
        public_key optional even though it's always Some. In an attempt to
        avoid a large refactoring, and also avoid making a new record, we'll
        deal with a value_exn here and be sad. *)
    type t =
      { account:
          ( Public_key.Compressed.t option
          , AnnotatedBalance.t
          , Account.Nonce.t option
          , Receipt.Chain_hash.t option
          , State_hash.t option )
          Account.Poly.t
      ; is_actively_staking: bool
      ; path: string }

    let wallet =
      obj "Wallet" ~doc:"An account record according to the daemon"
        ~fields:(fun _ ->
          [ pubkey_field ~resolve:(fun _ {account; _} ->
                Stringable.public_key
                @@ Option.value_exn account.Account.Poly.public_key )
          ; field "balance"
              ~typ:(non_null AnnotatedBalance.obj)
              ~doc:"A balance of Coda as a stringified uint64"
              ~args:Arg.[]
              ~resolve:(fun _ {account; _} -> account.Account.Poly.balance)
          ; field "nonce" ~typ:string
              ~doc:
                "Nonces are natural numbers that increase each transaction. \
                 Stringified uint32"
              ~args:Arg.[]
              ~resolve:(fun _ {account; _} ->
                Option.map ~f:Account.Nonce.to_string
                  account.Account.Poly.nonce )
          ; field "receiptChainHash" ~typ:string
              ~doc:"Top hash of the receipt chain merkle-list"
              ~args:Arg.[]
              ~resolve:(fun _ {account; _} ->
                Option.map ~f:Receipt.Chain_hash.to_string
                  account.Account.Poly.receipt_chain_hash )
          ; field "delegate" ~typ:string
              ~doc:
                "The public key to which you are delegating. If you are not \
                 delegating to anybody, than this would return your public \
                 key."
              ~args:Arg.[]
              ~resolve:(fun _ {account; _} ->
                Option.map ~f:Stringable.public_key
                  account.Account.Poly.delegate )
          ; field "votingFor" ~typ:string
              ~doc:
                "The previous epoch lock hash of the chain which you are \
                 voting for"
              ~args:Arg.[]
              ~resolve:(fun _ {account; _} ->
                Option.map ~f:Coda_base.State_hash.to_bytes
                  account.Account.Poly.voting_for )
          ; field "stakingActive" ~typ:(non_null bool)
              ~doc:
                "Actively staking. There is a lag between switching staking \
                 keys and them appearing here as you may be in the middle of \
                 a staking procedure with other keys."
              ~args:Arg.[]
              ~resolve:(fun _ {is_actively_staking; _} -> is_actively_staking)
          ; field "privateKeyPath" ~typ:(non_null string)
              ~doc:"The path of the private key for wallet"
              ~args:Arg.[]
              ~resolve:(fun _ {path; _} -> path) ] )
  end

  let snark_worker =
    obj "SnarkWorker" ~fields:(fun _ ->
        [ field "key" ~typ:(non_null string)
            ~doc:"Public key of current snark worker."
            ~args:Arg.[]
            ~resolve:(fun (_ : Coda_lib.t resolve_info) (key, _) ->
              Stringable.public_key key )
        ; field "fee" ~typ:(non_null string)
            ~doc:
              "Fee that snark worker is charging to generate a snark proof \
               (fee is uint64 and is coerced as a string)"
            ~args:Arg.[]
            ~resolve:(fun (_ : Coda_lib.t resolve_info) (_, fee) ->
              Stringable.uint64 (Currency.Fee.to_uint64 fee) ) ] )

  module Payload = struct
    let add_wallet : (Coda_lib.t, Account.key sexp_option) typ =
      obj "AddWalletPayload" ~fields:(fun _ ->
          [pubkey_field ~resolve:(fun _ key -> Stringable.public_key key)] )

    let delete_wallet =
      obj "DeleteWalletPayload" ~fields:(fun _ ->
          [pubkey_field ~resolve:(fun _ key -> Stringable.public_key key)] )

    let trust_status =
      obj "TrustStatusPayload" ~fields:(fun _ ->
          let open Trust_system.Peer_status in
          [ field "ip_addr" ~typ:(non_null string) ~doc:"IP address"
              ~args:Arg.[]
              ~resolve:(fun (_ : Coda_lib.t resolve_info) (ip_addr, _) ->
                Unix.Inet_addr.to_string ip_addr )
          ; field "trust" ~typ:(non_null float) ~doc:"Trust score"
              ~args:Arg.[]
              ~resolve:(fun _ (_, {trust; _}) -> trust)
          ; field "banned_status" ~typ:string ~doc:"Banned status"
              ~args:Arg.[]
              ~resolve:(fun _ (_, {banned; _}) ->
                Stringable.banned_status banned ) ] )

    let send_payment =
      obj "SendPaymentPayload" ~fields:(fun _ ->
          [ field "payment" ~typ:(non_null user_command)
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id) ] )

    let send_delegation =
      obj "SendDelegationPayload" ~fields:(fun _ ->
          [ field "delegation" ~typ:(non_null user_command)
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id) ] )

    let add_payment_receipt =
      obj "AddPaymentReceipt" ~fields:(fun _ ->
          [ field "payment" ~typ:(non_null user_command)
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id) ] )

    let set_staking =
      obj "SetStakingPayload" ~fields:(fun _ ->
          [ field "lastStaking"
              ~doc:
                "Returns the last wallet public keys that were staking before \
                 or empty if there were none"
              ~typ:(non_null (list (non_null string)))
              ~args:Arg.[]
              ~resolve:(fun _ keys -> List.map ~f:Stringable.public_key keys)
          ] )
  end

  module Arguments = struct
    let public_key ~name public_key =
      result_of_or_error
        (Public_key.Compressed.of_base58_check public_key)
        ~error:(sprintf !"%s address is not valid." name)

    let ip_address ~name ip_addr =
      result_of_exn Unix.Inet_addr.of_string ip_addr
        ~error:(sprintf !"%s is not valid." name)
  end

  module Input = struct
    open Schema.Arg

    module Fields = struct
      let from ~doc = arg "from" ~typ:(non_null string) ~doc

      let to_ ~doc = arg "to" ~typ:(non_null string) ~doc

      let fee ~doc = uint64_arg "fee" ~typ:(non_null string) ~doc

      let memo ~doc = uint64_arg "memo" ~typ:string ~doc
    end

    let send_payment =
      let open Fields in
      obj "SendPaymentInput"
        ~coerce:(fun from to_ amount fee memo -> (from, to_, amount, fee, memo))
        ~fields:
          [ from ~doc:"Public key of recipient of payment"
          ; to_ ~doc:"Public key of sender of payment"
          ; uint64_arg "amount" ~doc:"amount to send to to receiver"
              ~typ:(non_null string)
          ; fee ~doc:"Fee amount in order to send payment"
          ; memo ~doc:"Public description of payment" ]

    let send_delegation =
      let open Fields in
      obj "SendDelegationInput"
        ~coerce:(fun from to_ fee memo -> (from, to_, fee, memo))
        ~fields:
          [ from ~doc:"Public key of recipient of a stake delegation"
          ; to_ ~doc:"Public key of sender of a stake delegation"
          ; fee ~doc:"Fee amount in order to send a stake delegation"
          ; memo ~doc:"Public description of a stake delegation" ]

    let delete_wallet =
      obj "DeleteWalletInput" ~coerce:Fn.id
        ~fields:[arg "publicKey" ~typ:(non_null string)]

    let reset_trust_status =
      obj "ResetTrustStatusInput" ~coerce:Fn.id
        ~fields:[arg "ipAddress" ~typ:(non_null string)]

    (* TODO: Treat cases where filter_input has a null argument *)
    let filter_input ~title ~arg_name ~arg_doc =
      obj title ~coerce:Fn.id
        ~fields:[arg arg_name ~doc:arg_doc ~typ:(non_null string)]

    let block_filter_input =
      filter_input ~title:"BlockFilterInput" ~arg_name:"relatedTo"
        ~arg_doc:"A public key of an user who has their transaction in a block"

    let user_command_filter_input =
      obj "UserCommandFilterType"
        ~coerce:(fun public_key -> public_key)
        ~fields:
          [ arg "toOrFrom"
              ~doc:"Public key of transactions you are looking for"
              ~typ:(non_null string) ]

    let set_staking =
      obj "SetStakingInput"
        ~coerce:(fun wallets -> wallets)
        ~fields:
          [ arg "wallets"
              ~typ:(non_null (list (non_null string)))
              ~doc:"Public keys of own wallets you wish to stake" ]

    module AddPaymentReceipt = struct
      type t = {payment: string; added_time: string}

      let typ =
        obj "AddPaymentReceiptInput"
          ~coerce:(fun payment added_time -> {payment; added_time})
          ~fields:
            [ arg "payment"
                ~doc:
                  "Payment is the base58 version of a serialized payment (via \
                   Jane Street bin_prot)"
                ~typ:(non_null string)
            ; (* TODO: create a formal method for verifying that the provided added_time is correct  *)
              arg "added_time" ~typ:(non_null string)
                ~doc:
                  (Doc.date "added_time"
                     "Time that a payment gets added to another clients \
                      transaction database") ]
    end
  end

  module Pagination = struct
    module Page_info = struct
      type t =
        { has_previous_page: bool
        ; has_next_page: bool
        ; first_cursor: string option
        ; last_cursor: string option }

      let obj =
        obj "PageInfo" ~fields:(fun _ ->
            [ field "hasPreviousPage" ~typ:(non_null bool)
                ~args:Arg.[]
                ~resolve:(fun _ {has_previous_page; _} -> has_previous_page)
            ; field "hasNextPage" ~typ:(non_null bool)
                ~args:Arg.[]
                ~resolve:(fun _ {has_next_page; _} -> has_next_page)
            ; field "firstCursor" ~typ:string
                ~args:Arg.[]
                ~resolve:(fun _ {first_cursor; _} -> first_cursor)
            ; field "lastCursor" ~typ:string
                ~args:Arg.[]
                ~resolve:(fun _ {last_cursor; _} -> last_cursor) ] )
    end

    module Edge = struct
      type 'a t = {node: 'a; cursor: string}
    end

    module Connection = struct
      type 'a t =
        {edges: 'a Edge.t list; total_count: int; page_info: Page_info.t}
    end

    module type Inputs_intf = sig
      module Type : sig
        type t

        val typ : (Coda_lib.t, t option) typ

        val name : string
      end

      module Cursor : sig
        type t

        val serialize : t -> string

        val deserialize : ?error:string -> string -> (t, string) result

        val doc : string
      end

      module Pagination_database :
        Intf.Pagination
        with type value := Type.t
         and type cursor := Cursor.t
         and type time := Block_time.Time.Stable.V1.t

      val get_database : Coda_lib.t -> Pagination_database.t

      val filter_argument : string option Schema.Arg.arg_typ

      val query_name : string

      val to_cursor : Type.t -> Cursor.t
    end

    module Make (Inputs : Inputs_intf) = struct
      open Inputs

      let edge : (Coda_lib.t, Type.t Edge.t sexp_option) typ =
        obj (Type.name ^ "Edge") ~fields:(fun _ ->
            [ field "cursor" ~typ:(non_null string) ~doc:Cursor.doc
                ~args:Arg.[]
                ~resolve:(fun _ {Edge.cursor; _} -> cursor)
            ; field "node" ~typ:(non_null Type.typ)
                ~args:Arg.[]
                ~resolve:(fun _ {Edge.node; _} -> node) ] )

      let connection : (Coda_lib.t, Type.t Connection.t option) typ =
        obj (Type.name ^ "Connection") ~fields:(fun _ ->
            [ field "edges"
                ~typ:(non_null @@ list @@ non_null edge)
                ~args:Arg.[]
                ~resolve:(fun _ {Connection.edges; _} -> edges)
            ; field "nodes"
                ~typ:(non_null @@ list @@ non_null Type.typ)
                ~args:Arg.[]
                ~resolve:(fun _ {Connection.edges; _} ->
                  List.map edges ~f:(fun {Edge.node; _} -> node) )
            ; field "totalCount" ~typ:(non_null int)
                ~args:Arg.[]
                ~resolve:(fun _ {Connection.total_count; _} -> total_count)
            ; field "pageInfo" ~typ:(non_null Page_info.obj)
                ~args:Arg.[]
                ~resolve:(fun _ {Connection.page_info; _} -> page_info) ] )

      let build_connection
          ( queried_transactions
          , `Has_earlier_page has_previous_page
          , `Has_later_page has_next_page ) total_count =
        let first_cursor =
          Option.map ~f:(fun {Edge.cursor; _} -> cursor)
          @@ List.hd queried_transactions
        in
        let last_cursor =
          Option.map ~f:(fun {Edge.cursor; _} -> cursor)
          @@ List.last queried_transactions
        in
        let page_info =
          { Page_info.has_previous_page
          ; has_next_page
          ; first_cursor
          ; last_cursor }
        in
        {Connection.edges= queried_transactions; page_info; total_count}

      let query =
        io_field query_name
          ~args:
            Arg.
              [ arg "filter" ~typ:(non_null filter_argument)
              ; arg "first" ~typ:int
              ; arg "after" ~typ:string
              ; arg "last" ~typ:int
              ; arg "before" ~typ:string ]
          ~typ:(non_null connection)
          ~resolve:(fun {ctx= coda; _} () public_key first after last before ->
            let open Deferred.Result.Let_syntax in
            let%map result, total_counts =
              let%bind public_key =
                Deferred.return
                @@ Arguments.public_key ~name:"publicKey" public_key
              in
              let database = get_database coda in
              let resolve_cursor = function
                | None ->
                    Ok None
                | Some data ->
                    let open Result.Let_syntax in
                    let%map decoded = Cursor.deserialize data in
                    Some decoded
              in
              let%map queried_nodes, has_earlier_page, has_later_page =
                Deferred.return
                @@
                match (first, after, last, before) with
                | Some _n_queries_before, _, Some _n_queries_after, _ ->
                    Error
                      "Illegal query: first and last must not be non-null \
                       value at the same time"
                | num_to_query, cursor, None, _ ->
                    let open Result.Let_syntax in
                    let%map cursor = resolve_cursor cursor in
                    Pagination_database.get_earlier_values database public_key
                      cursor num_to_query
                | None, _, num_to_query, cursor ->
                    let open Result.Let_syntax in
                    let%map cursor = resolve_cursor cursor in
                    Pagination_database.get_later_values database public_key
                      cursor num_to_query
              in
              ( ( List.map queried_nodes ~f:(fun node ->
                      {Edge.node; cursor= Cursor.serialize @@ to_cursor node}
                  )
                , has_earlier_page
                , has_later_page )
              , Pagination_database.get_values database public_key )
            in
            build_connection result (List.length total_counts) )
    end

    module User_command = struct
      module Inputs = struct
        module Type = struct
          type t = User_command.t

          let typ = user_command

          let name = "UserCommand"
        end

        module Cursor = struct
          type t = User_command.t

          let serialize = Id.user_command

          let deserialize ?error serialized_payment =
            let open Result.Let_syntax in
            let%bind serialized_transaction =
              result_of_or_error
                (Base58_check.decode ~version_byte:Id.version_byte
                   serialized_payment)
                ~error:(Option.value error ~default:"Invalid cursor")
            in
            Ok
              (Coda_base.User_command.Stable.V1.bin_t.reader.read
                 (Bigstring.of_string serialized_transaction)
                 ~pos_ref:(ref 0))

          let doc =
            "Cursor is the base58 version of a serialized user command (via \
             Jane Street bin_prot)"
        end

        module Pagination_database = Transaction_database

        let get_database = Coda_lib.transaction_database

        let filter_argument = Input.user_command_filter_input

        let query_name = "userCommands"

        let to_cursor = Fn.id
      end

      include Make (Inputs)
    end

    module Blocks = struct
      module Inputs = struct
        module Type = struct
          type t = (Filtered_external_transition.t, State_hash.t) With_hash.t

          let typ = block

          let name = "Block"
        end

        module Cursor = struct
          type t = State_hash.t

          let serialize = Stringable.State_hash.to_base58_check

          let deserialize ?error data =
            result_of_or_error
              (Stringable.State_hash.of_base58_check data)
              ~error:(Option.value error ~default:"Invalid state hash data")

          let doc =
            "Cursor is the base58 version of a serialized user command (via \
             Jane Street bin_prot)"
        end

        module Pagination_database = External_transition_database

        let get_database = Coda_lib.external_transition_database

        let filter_argument = Input.block_filter_input

        let query_name = "blocks"

        let to_cursor {With_hash.hash; _} = hash
      end

      include Make (Inputs)
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
      Coda_lib.best_ledger coda |> Participating_state.active
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

module Subscriptions = struct
  open Schema

  let new_sync_update =
    subscription_field "newSyncUpdate" ~doc:"Fires on sync update from Coda"
      ~deprecated:NotDeprecated
      ~typ:(non_null Types.sync_status)
      ~args:Arg.[]
      ~resolve:(fun {ctx= coda; _} ->
        Coda_lib.sync_status coda |> Coda_incremental.Status.to_pipe
        |> Deferred.Result.return )

  let new_block =
    subscription_field "newBlock"
      ~doc:"Fires on a new block created by a proposer with a public key KEY"
      ~typ:(non_null Types.block)
      ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
      ~resolve:(fun {ctx= coda; _} public_key ->
        let open Deferred.Result.Let_syntax in
        let%map public_key =
          Deferred.return
          @@ Types.Arguments.public_key ~name:"publicKey" public_key
        in
        Coda_commands.Subscriptions.new_block coda public_key )

  let chain_reorganization =
    subscription_field "chainReorganization"
      ~doc:
        "Fires whenever the best tip changes in a way that is not a trivial \
         extension of the existing one"
      ~typ:(non_null Types.chain_reorganization_status)
      ~args:Arg.[]
      ~resolve:(fun {ctx= coda; _} ->
        Deferred.Result.return
        @@ Coda_commands.Subscriptions.reorganization coda )

  let commands = [new_sync_update; new_block]
end

module Mutations = struct
  open Schema

  let add_wallet =
    io_field "addWallet" ~doc:"Add a wallet"
      ~typ:
        (non_null Types.Payload.add_wallet)
        (* TODO: For now, not including add wallet input *)
      ~args:Arg.[]
      ~resolve:(fun {ctx= t; _} () ->
        let open Deferred.Let_syntax in
        let%map pk = Coda_lib.wallets t |> Secrets.Wallets.generate_new in
        Result.return pk )

  let delete_wallet =
    io_field "deleteWallet"
      ~doc:"Delete a wallet that you own based on its public key"
      ~typ:(non_null Types.Payload.delete_wallet)
      ~args:Arg.[arg "input" ~typ:(non_null Types.Input.delete_wallet)]
      ~resolve:(fun {ctx= coda; _} () public_key_input ->
        let open Deferred.Result.Let_syntax in
        let%bind public_key =
          Deferred.return
          @@ Types.Arguments.public_key ~name:"public_key" public_key_input
        in
        let wallets = Coda_lib.wallets coda in
        let%map () =
          Deferred.Result.map_error
            ~f:(fun `Not_found ->
              sprintf
                !"Could not find wallet with public key: %s"
                public_key_input )
            (Secrets.Wallets.delete wallets public_key)
        in
        public_key )

  let reset_trust_status =
    io_field "resetTrustStatus"
      ~doc:"Reset trust status for a given IP address"
      ~typ:(non_null Types.Payload.trust_status)
      ~args:Arg.[arg "input" ~typ:(non_null Types.Input.reset_trust_status)]
      ~resolve:(fun {ctx= coda; _} () ip_address_input ->
        let open Deferred.Result.Let_syntax in
        let%map ip_address =
          Deferred.return
          @@ Types.Arguments.ip_address ~name:"ip_address" ip_address_input
        in
        (ip_address, Coda_commands.reset_trust_status coda ip_address) )

  let build_user_command coda {Account.Poly.nonce; _} sender_kp memo
      payment_body fee =
    let payload =
      User_command.Payload.create ~fee ~nonce ~memo ~body:payment_body
    in
    let payment = User_command.sign sender_kp payload in
    let command = User_command.forget_check payment in
    match%map Coda_commands.send_user_command coda command with
    | `Active (Ok _) ->
        Ok command
    | `Active (Error e) ->
        Error ("Couldn't send user_command: " ^ Error.to_string_hum e)
    | `Bootstrapping ->
        Error "Daemon is bootstrapping"

  let parse_user_command_input ~kind coda from to_ fee maybe_memo =
    let open Result.Let_syntax in
    let%bind receiver = Types.Arguments.public_key ~name:"to" to_ in
    let%bind sender = Types.Arguments.public_key ~name:"from" from in
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
        (Secrets.Wallets.find (Coda_lib.wallets coda) ~needle:sender)
        ~error:
          (sprintf
             "Couldn't find the private key for specified `sender`. Do you \
              own the wallet you're making a %s from?"
             kind)
    in
    let%map memo =
      Option.value_map maybe_memo ~default:(Ok User_command_memo.dummy)
        ~f:(fun memo ->
          result_of_exn User_command_memo.create_by_digesting_string_exn memo
            ~error:"Invalid `memo` provided." )
    in
    (sender_account, sender_kp, memo, receiver, fee)

  let send_delegation =
    io_field "sendDelegation" ~doc:"Send a delegation"
      ~typ:(non_null Types.Payload.send_delegation)
      ~args:Arg.[arg "input" ~typ:(non_null Types.Input.send_delegation)]
      ~resolve:(fun {ctx= coda; _} () (from, to_, fee, maybe_memo) ->
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
      ~typ:(non_null Types.Payload.send_payment)
      ~args:Arg.[arg "input" ~typ:(non_null Types.Input.send_payment)]
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
      ~args:Arg.[arg "input" ~typ:(non_null Types.Input.AddPaymentReceipt.typ)]
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
          Types.Pagination.User_command.Inputs.Cursor.deserialize
            ~error:"Invaid `payment` provided" payment
        in
        let transaction_database = Coda_lib.transaction_database coda in
        Transaction_database.add transaction_database payment added_time ;
        Some payment )

  let set_staking =
    result_field "setStaking"
      ~doc:
        "Set keys you wish to stake with. Silently fails if you pass keys we \
         aren't tracking in ownedWallets"
      ~args:Arg.[arg "input" ~typ:(non_null Types.Input.set_staking)]
      ~typ:(non_null Types.Payload.set_staking)
      ~resolve:(fun {ctx= coda; _} () pk_strings ->
        let open Result.Let_syntax in
        (* TODO: Handle errors like: duplicates, etc *)
        let%map pks =
          List.fold pk_strings ~init:(Result.return [])
            ~f:(fun acc pk_string ->
              let%bind acc = acc in
              let%map pk =
                Types.Arguments.public_key ~name:"wallets" pk_string
              in
              pk :: acc )
        in
        let kps =
          List.filter_map pks ~f:(fun pk ->
              let open Option.Let_syntax in
              let%map kps =
                Coda_lib.wallets coda |> Secrets.Wallets.find ~needle:pk
              in
              (kps, pk) )
        in
        let old_propose_keys = Coda_lib.propose_public_keys coda in
        Coda_lib.replace_propose_keypairs coda
          (Keypair.And_compressed_pk.Set.of_list kps) ;
        Public_key.Compressed.Set.to_list old_propose_keys )

  let commands =
    [ add_wallet
    ; delete_wallet
    ; send_payment
    ; send_delegation
    ; add_payment_receipt
    ; set_staking ]
end

module Queries = struct
  open Schema

  let pooled_user_commands =
    result_field "pooledUserCommands"
      ~doc:"Retrieve all the user commands sent by public key publicKey"
      ~typ:(non_null @@ list @@ non_null Types.user_command)
      ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
      ~resolve:(fun {ctx= coda; _} () pk_string ->
        let open Result.Let_syntax in
        let%map pk = Types.Arguments.public_key ~name:"publicKey" pk_string in
        let transaction_pool = Coda_lib.transaction_pool coda in
        List.map
          (Network_pool.Transaction_pool.Resource_pool.all_from_user
             (Network_pool.Transaction_pool.resource_pool transaction_pool)
             pk)
          ~f:User_command.forget_check )

  let sync_state =
    result_field_no_inputs "syncStatus" ~args:[]
      ~typ:(non_null Types.sync_status) ~resolve:(fun {ctx= coda; _} () ->
        Result.map_error
          (Coda_incremental.Status.Observer.value @@ Coda_lib.sync_status coda)
          ~f:Error.to_string_hum )

  let daemon_status =
    field "daemonStatus" ~doc:"Get running daemon status" ~args:[]
      ~typ:(non_null Types.DaemonStatus.t) ~resolve:(fun {ctx= coda; _} () ->
        Coda_commands.get_status ~flag:`Performance coda )

  let trust_status =
    field "trustStatus" ~typ:Types.Payload.trust_status
      ~args:Arg.[arg "ipAddress" ~typ:(non_null string)]
      ~doc:"Trust status for an IPv4 or IPv6 address"
      ~resolve:(fun {ctx= coda; _} () (ip_addr_string : string) ->
        match Types.Arguments.ip_address ~name:"ipAddress" ip_addr_string with
        | Ok ip_addr ->
            Some (ip_addr, Coda_commands.get_trust_status coda ip_addr)
        | Error _ ->
            None )

  let trust_status_all =
    field "trustStatusAll"
      ~typ:(non_null @@ list @@ non_null Types.Payload.trust_status)
      ~args:Arg.[]
      ~doc:"IP address and trust status for all peers"
      ~resolve:(fun {ctx= coda; _} () ->
        Coda_commands.get_trust_status_all coda )

  let version =
    field "version" ~typ:string
      ~args:Arg.[]
      ~doc:"The version of the node (git commit hash)"
      ~resolve:(fun _ _ -> Some Coda_version.commit_id)

  let owned_wallets =
    field "ownedWallets"
      ~doc:
        "Wallets for which the daemon knows the private key. If they are \
         found in our ledger, all the fields will be non-null"
      ~typ:(non_null (list (non_null Types.Wallet.wallet)))
      ~args:Arg.[]
      ~resolve:(fun {ctx= coda; _} () ->
        let wallets = Coda_lib.wallets coda in
        let propose_public_keys = Coda_lib.propose_public_keys coda in
        wallets |> Secrets.Wallets.pks
        |> List.map ~f:(fun pk ->
               { Types.Wallet.account= Partial_account.of_pk coda pk
               ; is_actively_staking=
                   Public_key.Compressed.Set.mem propose_public_keys pk
               ; path= Secrets.Wallets.get_path wallets pk } ) )

  let wallet =
    result_field "wallet"
      ~doc:"Find any wallet via a public key. Null if the key was not found."
      ~typ:
        Types.Wallet.wallet
        (* TODO: Is there anyway to describe `public_key` arg in a more typesafe way on our ocaml-side *)
      ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
      ~resolve:(fun {ctx= coda; _} () (pk_string : string) ->
        let open Result.Let_syntax in
        let propose_public_keys = Coda_lib.propose_public_keys coda in
        let%map pk = Types.Arguments.public_key ~name:"publicKey" pk_string in
        (* TODO: return null if the pubkey is not a valid base58check key *)
        Some
          { Types.Wallet.account= Partial_account.of_pk coda pk
          ; is_actively_staking=
              Public_key.Compressed.Set.mem propose_public_keys pk
          ; path= Secrets.Wallets.get_path (Coda_lib.wallets coda) pk } )

  let current_snark_worker =
    field "currentSnarkWorker" ~typ:Types.snark_worker
      ~args:Arg.[]
      ~doc:"Get information about the current snark worker."
      ~resolve:(fun {ctx= coda; _} _ ->
        Option.map (Coda_lib.snark_worker_key coda) ~f:(fun k ->
            (k, Coda_lib.snark_work_fee coda) ) )

  let user_command = Types.Pagination.User_command.query

  let blocks = Types.Pagination.Blocks.query

  let initial_peers =
    field "initialPeers"
      ~doc:
        "The initial peers that a client syncs with is an inidication of \
         specifically the network they are in"
      ~args:Arg.[]
      ~typ:(non_null @@ list @@ non_null string)
      ~resolve:(fun {ctx= coda; _} () ->
        List.map (Coda_lib.initial_peers coda)
          ~f:(fun {Host_and_port.host; port} -> sprintf !"%s:%i" host port) )

  let commands =
    [ sync_state
    ; daemon_status
    ; version
    ; owned_wallets
    ; wallet
    ; current_snark_worker
    ; user_command
    ; blocks
    ; initial_peers
    ; pooled_user_commands ]
end

let schema =
  Graphql_async.Schema.(
    schema Queries.commands ~mutations:Mutations.commands
      ~subscriptions:Subscriptions.commands)
