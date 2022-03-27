val to_yojson : Graphql_parser.const_value -> Yojson.Safe.t

val result_of_exn : ('a -> 'b) -> 'a -> error:'c -> ('b, 'c) Core._result

val result_of_or_error :
     ?error:string
  -> ('a, Core.Error.t) Core.Result.t
  -> ('a, string) Core.Result.t

val result_field_no_inputs :
     resolve:('a Graphql_async.Schema.resolve_info -> 'b -> 'c)
  -> ?doc:string
  -> ?deprecated:Graphql_async.Schema.deprecated
  -> string
  -> typ:('a, 'd) Graphql_async.Schema.typ
  -> args:
       ( ('d, string) result Graphql_async.Schema.Io.t
       , 'c Async.Deferred.t )
       Graphql_async.Schema.Arg.arg_list
  -> ('a, 'b) Graphql_async.Schema.field

val result_field :
     resolve:('a Graphql_async.Schema.resolve_info -> 'b -> 'c -> 'd)
  -> ?doc:string
  -> ?deprecated:Graphql_async.Schema.deprecated
  -> string
  -> typ:('a, 'e) Graphql_async.Schema.typ
  -> args:
       ( ('e, string) result Graphql_async.Schema.Io.t
       , 'c -> 'd Async.Deferred.t )
       Graphql_async.Schema.Arg.arg_list
  -> ('a, 'b) Graphql_async.Schema.field

val result_field2 :
     resolve:('a Graphql_async.Schema.resolve_info -> 'b -> 'c -> 'd -> 'e)
  -> ?doc:string
  -> ?deprecated:Graphql_async.Schema.deprecated
  -> string
  -> typ:('a, 'f) Graphql_async.Schema.typ
  -> args:
       ( ('f, string) result Graphql_async.Schema.Io.t
       , 'c -> 'd -> 'e Async.Deferred.t )
       Graphql_async.Schema.Arg.arg_list
  -> ('a, 'b) Graphql_async.Schema.field

module Doc : sig
  val date : ?extra:string -> string -> string

  val bin_prot : string -> string
end

module Reflection : sig
  val regex : Re2.t lazy_t

  val underToCamel : string -> string

  val reflect :
       ('a -> 'b)
    -> typ:('c, 'b) Graphql_async.Schema.typ
    -> ('c, 'd) Graphql_async.Schema.field list
    -> ('e, 'd, 'a) Core.Field.t_with_perm
    -> ('c, 'd) Graphql_async.Schema.field list

  module Shorthand : sig
    val id :
         typ:('a, 'b) Graphql_async.Schema.typ
      -> ('a, 'c) Graphql_async.Schema.field list
      -> ('d, 'c, 'b) Core.Field.t_with_perm
      -> ('a, 'c) Graphql_async.Schema.field list

    val nn_int :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, int) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val int :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, int option) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val nn_bool :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, bool) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val bool :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, bool option) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val nn_string :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, string) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val nn_time :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, Block_time.t) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val nn_catchup_status :
         ('a, 'b) Graphql_async.Schema.field list
      -> ( 'c
         , 'b
         , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * 'd) list
           option )
         Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    val string :
         ('a, 'b) Graphql_async.Schema.field list
      -> ('c, 'b, string option) Core.Field.t_with_perm
      -> ('a, 'b) Graphql_async.Schema.field list

    module F : sig
      val int :
           ('a -> int option)
        -> ('b, 'c) Graphql_async.Schema.field list
        -> ('d, 'c, 'a) Core.Field.t_with_perm
        -> ('b, 'c) Graphql_async.Schema.field list

      val nn_int :
           ('a -> int)
        -> ('b, 'c) Graphql_async.Schema.field list
        -> ('d, 'c, 'a) Core.Field.t_with_perm
        -> ('b, 'c) Graphql_async.Schema.field list

      val string :
           ('a -> string option)
        -> ('b, 'c) Graphql_async.Schema.field list
        -> ('d, 'c, 'a) Core.Field.t_with_perm
        -> ('b, 'c) Graphql_async.Schema.field list

      val nn_string :
           ('a -> string)
        -> ('b, 'c) Graphql_async.Schema.field list
        -> ('d, 'c, 'a) Core.Field.t_with_perm
        -> ('b, 'c) Graphql_async.Schema.field list
    end
  end
end

module Types : sig
  val public_key :
    ( Mina_lib.t
    , Signature_lib.Public_key.Compressed.t option )
    Graphql_async.Schema.typ

  val uint64 : (Mina_lib.t, Unsigned.UInt64.t option) Graphql_async.Schema.typ

  val uint32 : (Mina_lib.t, Unsigned.UInt32.t option) Graphql_async.Schema.typ

  val token_id :
    (Mina_lib.t, Mina_base.Token_id.t option) Graphql_async.Schema.typ

  val json : (Mina_lib.t, Yojson.Basic.t option) Graphql_async.Schema.typ

  val epoch_seed :
    (Mina_lib.t, Mina_base.Epoch_seed.t option) Graphql_async.Schema.typ

  val sync_status : (Mina_lib.t, Sync_status.t option) Graphql_async.Schema.typ

  val transaction_status :
    ( Mina_lib.t
    , Transaction_inclusion_status.State.t option )
    Graphql_async.Schema.typ

  val consensus_time :
    ( Mina_lib.t
    , Consensus__Proof_of_stake.Data.Consensus_time.Stable.V1.t option )
    Graphql_async.Schema.typ

  val consensus_time_with_global_slot_since_genesis :
    ( Mina_lib.t
    , ( Consensus__Proof_of_stake.Data.Consensus_time.Stable.V1.t
      * Unsigned.UInt32.t )
      option )
    Graphql_async.Schema.typ

  val block_producer_timing :
    ( Mina_lib.t
    , Daemon_rpcs.Types.Status.Next_producer_timing.t option )
    Graphql_async.Schema.typ

  module DaemonStatus : sig
    type t = Daemon_rpcs.Types.Status.t

    val interval :
      ( Mina_lib.t
      , (Core.Time.Span.t * Core.Time.Span.t) option )
      Graphql_async.Schema.typ

    val histogram :
      (Mina_lib.t, Perf_histograms.Report.t option) Graphql_async.Schema.typ

    module Rpc_timings = Daemon_rpcs.Types.Status.Rpc_timings
    module Rpc_pair = Rpc_timings.Rpc_pair

    val rpc_pair :
      ( Mina_lib.t
      , Perf_histograms.Report.t option
        Daemon_rpcs.Types.Status.Rpc_timings.Rpc_pair.t
        option )
      Graphql_async.Schema.typ

    val rpc_timings :
      ( Mina_lib.t
      , Daemon_rpcs.Types.Status.Rpc_timings.t option )
      Graphql_async.Schema.typ

    module Histograms = Daemon_rpcs.Types.Status.Histograms

    val histograms :
      ( Mina_lib.t
      , Daemon_rpcs.Types.Status.Histograms.t option )
      Graphql_async.Schema.typ

    val consensus_configuration :
      (Mina_lib.t, Consensus.Configuration.t option) Graphql_async.Schema.typ

    val peer :
      (Mina_lib.t, Network_peer.Peer.Display.t option) Graphql_async.Schema.typ

    val addrs_and_ports :
      ( Mina_lib.t
      , Node_addrs_and_ports.Display.t option )
      Graphql_async.Schema.typ

    val t : (Mina_lib.t, t option) Graphql_async.Schema.typ
  end

  val fee_transfer :
    ( Mina_lib.t
    , ( Mina_base.Fee_transfer.single
      * Filtered_external_transition.Fee_transfer_type.t )
      option )
    Graphql_async.Schema.typ

  val account_timing :
    (Mina_lib.t, Mina_base.Account_timing.t option) Graphql_async.Schema.typ

  val completed_work :
    (Mina_lib.t, Transaction_snark_work.Info.t option) Graphql_async.Schema.typ

  val sign : (Mina_lib.t, Sgn.t option) Graphql_async.Schema.typ

  val signed_fee :
    (Mina_lib.t, Currency.Amount.Signed.t option) Graphql_async.Schema.typ

  val work_statement :
    ( Mina_lib.t
    , ( Mina_base.Frozen_ledger_hash.t
      , Currency.Amount.Stable.V1.t
      , Transaction_snark.Pending_coinbase_stack_state.Stable.V1.t
      , Mina_base.Fee_excess.Stable.V1.t
      , Mina_base.Token_id.Stable.V1.t
      , unit )
      Transaction_snark.Statement.poly
      option )
    Graphql_async.Schema.typ

  val pending_work :
    ( Mina_lib.t
    , ( Mina_base.Frozen_ledger_hash.t
      , Currency.Amount.Stable.V1.t
      , Transaction_snark.Pending_coinbase_stack_state.Stable.V1.t
      , Mina_base.Fee_excess.Stable.V1.t
      , Mina_base.Token_id.Stable.V1.t
      , unit )
      Transaction_snark.Statement.poly
      One_or_two.t
      option )
    Graphql_async.Schema.typ

  val blockchain_state :
    ( Mina_lib.t
    , (Mina_state.Blockchain_state.Value.t * Mina_base.State_hash.t) option )
    Graphql_async.Schema.typ

  val protocol_state :
    ( Mina_lib.t
    , (Filtered_external_transition.Protocol_state.t * Mina_base.State_hash.t)
      option )
    Graphql_async.Schema.typ

  val chain_reorganization_status :
    (Mina_lib.t, [ `Changed ] option) Graphql_async.Schema.typ

  val genesis_constants : (Mina_lib.t, unit option) Graphql_async.Schema.typ

  module AccountObj : sig
    module AnnotatedBalance : sig
      type t =
        { total : Currency.Balance.t
        ; unknown : Currency.Balance.t
        ; timing : Mina_base.Account_timing.t
        ; breadcrumb : Transition_frontier.Breadcrumb.t option
        }

      val min_balance : t -> Currency.Balance.Stable.Latest.t option

      val obj : (Mina_lib.t, t option) Graphql_async.Schema.typ
    end

    module Partial_account : sig
      val to_full_account :
           ( 'a Base__Option.t
           , 'b
           , 'c Base__Option.t
           , 'd
           , 'e Base__Option.t
           , 'f Base__Option.t
           , 'g Base__Option.t
           , 'h Base__Option.t
           , 'i Base__Option.t
           , 'j Base__Option.t
           , 'k Base__Option.t )
           Mina_base.Account.Poly.t
        -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i, 'j, 'k) Mina_base.Account.Poly.t
           Base__Option.t

      val of_full_account :
           ?breadcrumb:Transition_frontier.Breadcrumb.t
        -> ( 'a
           , 'b
           , 'c
           , Currency.Balance.t
           , 'd
           , 'e
           , 'f
           , 'g
           , Mina_base.Account_timing.t
           , 'h
           , 'i )
           Mina_base.Account.Poly.t
        -> ( 'a
           , 'b
           , 'c option
           , AnnotatedBalance.t
           , 'd option
           , 'e option
           , 'f
           , 'g option
           , Mina_base.Account_timing.t
           , 'h option
           , 'i )
           Mina_base.Account.Poly.t

      val of_account_id :
           Mina_lib.t
        -> Mina_base.Account_id.t
        -> ( Mina_base__Account.key
           , Mina_base.Token_id.Stable.V1.t
           , Mina_base.Token_permissions.Stable.V1.t option
           , AnnotatedBalance.t
           , Mina_numbers.Account_nonce.Stable.V1.t option
           , Mina_base.Receipt.Chain_hash.Stable.V1.t option
           , Mina_base__Account.key option
           , Mina_base.State_hash.Stable.V1.t option
           , Mina_base.Account_timing.t
           , Mina_base.Permissions.Stable.V1.t option
           , Mina_base.Snapp_account.Stable.V1.t option )
           Mina_base.Account.Poly.t

      val of_pk :
           Mina_lib.t
        -> Mina_base.Import.Public_key.Compressed.t
        -> ( Mina_base__Account.key
           , Mina_base.Token_id.Stable.V1.t
           , Mina_base.Token_permissions.Stable.V1.t option
           , AnnotatedBalance.t
           , Mina_numbers.Account_nonce.Stable.V1.t option
           , Mina_base.Receipt.Chain_hash.Stable.V1.t option
           , Mina_base__Account.key option
           , Mina_base.State_hash.Stable.V1.t option
           , Mina_base.Account_timing.t
           , Mina_base.Permissions.Stable.V1.t option
           , Mina_base.Snapp_account.Stable.V1.t option )
           Mina_base.Account.Poly.t
    end

    type t =
      { account :
          ( Signature_lib.Public_key.Compressed.t
          , Mina_base.Token_id.t
          , Mina_base.Token_permissions.t option
          , AnnotatedBalance.t
          , Mina_base.Account.Nonce.t option
          , Mina_base.Receipt.Chain_hash.t option
          , Signature_lib.Public_key.Compressed.t option
          , Mina_base.State_hash.t option
          , Mina_base.Account.Timing.t
          , Mina_base.Permissions.t option
          , Mina_base.Snapp_account.t option )
          Mina_base.Account.Poly.t
      ; locked : bool option
      ; is_actively_staking : bool
      ; path : string
      ; index : Mina_base.Account.Index.t option
      }

    val lift :
         Mina_lib.t
      -> Signature_lib.Public_key.Compressed.t
      -> ( Signature_lib.Public_key.Compressed.t
         , Mina_base.Token_id.t
         , Mina_base.Token_permissions.t option
         , AnnotatedBalance.t
         , Mina_base.Account.Nonce.t option
         , Mina_base.Receipt.Chain_hash.t option
         , Signature_lib.Public_key.Compressed.t option
         , Mina_base.State_hash.t option
         , Mina_base.Account.Timing.t
         , Mina_base.Permissions.t option
         , Mina_base.Snapp_account.t option )
         Mina_base.Account.Poly.t
      -> t

    val get_best_ledger_account : Mina_lib.t -> Mina_base.Account_id.t -> t

    val get_best_ledger_account_pk :
      Mina_lib.t -> Signature_lib.Public_key.Compressed.t -> t

    val account_id :
         ( Mina_base.Import.Public_key.Compressed.t
         , Mina_base.Token_id.t
         , 'a
         , 'b
         , 'c
         , 'd
         , 'e
         , 'f
         , 'g
         , 'h
         , 'i )
         Mina_base.Account.Poly.t
      -> Mina_base.Account_id.t

    val account : (Mina_lib.t, t Base__Option.t) Graphql_async.Schema.typ
  end

  module UserCommand : sig
    val kind :
      ( Mina_lib.t
      , [ `Create_new_token
        | `Create_token_account
        | `Mint_tokens
        | `Payment
        | `Stake_delegation ]
        option )
      Graphql_async.Schema.typ

    val to_kind :
         Mina_base.Signed_command.t
      -> [> `Create_new_token
         | `Create_token_account
         | `Mint_tokens
         | `Payment
         | `Stake_delegation ]

    val user_command_interface :
      ( Mina_lib.t
      , ( Mina_lib.t
        , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        )
        Graphql_async.Schema.abstract_value
        option )
      Graphql_async.Schema.typ

    module Status : sig
      type t =
        | Applied
        | Included_but_failed of Mina_base.Transaction_status.Failure.t
        | Unknown
    end

    module With_status : sig
      type 'a t = { data : 'a; status : Status.t }

      val map : 'a t -> f:('a -> 'b) -> 'b t
    end

    val field_no_status :
         ?doc:string
      -> ?deprecated:Graphql_async.Schema.deprecated
      -> string
      -> typ:('a, 'b) Graphql_async.Schema.typ
      -> args:('b, 'c) Graphql_async.Schema.Arg.arg_list
      -> resolve:('a Graphql_async.Schema.resolve_info -> 'd -> 'c)
      -> ('a, 'd With_status.t) Graphql_async.Schema.field

    val user_command_shared_fields :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        With_status.t )
      Graphql_async.Schema.field
      list

    val payment :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        With_status.t
        option )
      Graphql_async.Schema.typ

    val mk_payment :
         (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
         With_status.t
      -> ( Mina_lib.t
         , ( Mina_base.Signed_command.t
           , Mina_base.Transaction_hash.t )
           With_hash.t )
         Graphql_async.Schema.abstract_value

    val stake_delegation :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        With_status.t
        option )
      Graphql_async.Schema.typ

    val mk_stake_delegation :
         (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
         With_status.t
      -> ( Mina_lib.t
         , ( Mina_base.Signed_command.t
           , Mina_base.Transaction_hash.t )
           With_hash.t )
         Graphql_async.Schema.abstract_value

    val create_new_token :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        With_status.t
        option )
      Graphql_async.Schema.typ

    val mk_create_new_token :
         (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
         With_status.t
      -> ( Mina_lib.t
         , ( Mina_base.Signed_command.t
           , Mina_base.Transaction_hash.t )
           With_hash.t )
         Graphql_async.Schema.abstract_value

    val create_token_account :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        With_status.t
        option )
      Graphql_async.Schema.typ

    val mk_create_token_account :
         (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
         With_status.t
      -> ( Mina_lib.t
         , ( Mina_base.Signed_command.t
           , Mina_base.Transaction_hash.t )
           With_hash.t )
         Graphql_async.Schema.abstract_value

    val mint_tokens :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        With_status.t
        option )
      Graphql_async.Schema.typ

    val mk_mint_tokens :
         (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
         With_status.t
      -> ( Mina_lib.t
         , ( Mina_base.Signed_command.t
           , Mina_base.Transaction_hash.t )
           With_hash.t )
         Graphql_async.Schema.abstract_value

    val mk_user_command :
         (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
         With_status.t
      -> ( Mina_lib.t
         , ( Mina_base.Signed_command.t
           , Mina_base.Transaction_hash.t )
           With_hash.t )
         Graphql_async.Schema.abstract_value
  end

  val user_command :
    ( Mina_lib.t
    , ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
      )
      Graphql_async.Schema.abstract_value
      option )
    Graphql_async.Schema.typ

  val transactions :
    ( Mina_lib.t
    , Filtered_external_transition.Transactions.t option )
    Graphql_async.Schema.typ

  val protocol_state_proof :
    (Mina_lib.t, Mina_base.Proof.t option) Graphql_async.Schema.typ

  val block :
    ( Mina_lib.t
    , (Filtered_external_transition.t, Mina_base.State_hash.t) With_hash.t
      option )
    Graphql_async.Schema.typ

  val snark_worker :
    ( Mina_lib.t
    , (Signature_lib.Public_key.Compressed.t * Currency.Fee.Stable.Latest.t)
      option )
    Graphql_async.Schema.typ

  module Payload : sig
    val peer : (Mina_lib.t, Network_peer.Peer.t option) Graphql_async.Schema.typ

    val create_account :
      (Mina_lib.t, Mina_base.Account.key option) Graphql_async.Schema.typ

    val unlock_account :
      (Mina_lib.t, Mina_base.Account.key option) Graphql_async.Schema.typ

    val lock_account :
      (Mina_lib.t, Mina_base.Account.key option) Graphql_async.Schema.typ

    val delete_account :
      ( Mina_lib.t
      , Signature_lib.Public_key.Compressed.t option )
      Graphql_async.Schema.typ

    val reload_accounts : (Mina_lib.t, bool option) Graphql_async.Schema.typ

    val import_account :
      ( Mina_lib.t
      , (Signature_lib.Public_key.Compressed.t * bool) option )
      Graphql_async.Schema.typ

    val string_of_banned_status : Trust_system.Banned_status.t -> string option

    val trust_status :
      ( Mina_lib.t
      , (Network_peer.Peer.t * Trust_system.Peer_status.t) option )
      Graphql_async.Schema.typ

    val send_payment :
      ( Mina_lib.t
      , ( Mina_lib.t
        , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        )
        Graphql_async.Schema.abstract_value
        option )
      Graphql_async.Schema.typ

    val send_delegation :
      ( Mina_lib.t
      , ( Mina_lib.t
        , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        )
        Graphql_async.Schema.abstract_value
        option )
      Graphql_async.Schema.typ

    val create_token :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        UserCommand.With_status.t
        option )
      Graphql_async.Schema.typ

    val create_token_account :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        UserCommand.With_status.t
        option )
      Graphql_async.Schema.typ

    val mint_tokens :
      ( Mina_lib.t
      , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        UserCommand.With_status.t
        option )
      Graphql_async.Schema.typ

    val send_rosetta_transaction :
      ( Mina_lib.t
      , ( Mina_lib.t
        , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        )
        Graphql_async.Schema.abstract_value
        option )
      Graphql_async.Schema.typ

    val export_logs : (Mina_lib.t, string option) Graphql_async.Schema.typ

    val add_payment_receipt :
      ( Mina_lib.t
      , ( Mina_lib.t
        , (Mina_base.Signed_command.t, Mina_base.Transaction_hash.t) With_hash.t
        )
        Graphql_async.Schema.abstract_value
        option )
      Graphql_async.Schema.typ

    val set_coinbase_receiver :
      ( Mina_lib.t
      , ( Signature_lib.Public_key.Compressed.t option
        * Signature_lib.Public_key.Compressed.t option )
        option )
      Graphql_async.Schema.typ

    val set_snark_work_fee :
      (Mina_lib.t, Unsigned.UInt64.t option) Graphql_async.Schema.typ

    val set_snark_worker :
      ( Mina_lib.t
      , Signature_lib.Public_key.Compressed.t option option )
      Graphql_async.Schema.typ

    val set_connection_gating_config :
      (Mina_lib.t, Mina_net2.connection_gating option) Graphql_async.Schema.typ
  end

  module Arguments : sig
    val ip_address :
      name:string -> string -> (Async.Unix.Inet_addr.t, string) Core._result
  end

  module Input : sig
    val peer :
      (Network_peer.Peer.t, string) Core.result option
      Graphql_async.Schema.Arg.arg_typ

    val public_key_arg :
      Signature_lib.Public_key.Compressed.t option
      Graphql_async.Schema.Arg.arg_typ

    val token_id_arg :
      Mina_base.Token_id.t option Graphql_async.Schema.Arg.arg_typ

    val precomputed_block :
      Mina_transition.External_transition.Precomputed_block.t option
      Graphql_async.Schema.Arg.arg_typ

    val extensional_block :
      Archive_lib.Extensional.Block.t option Graphql_async.Schema.Arg.arg_typ

    module type Numeric_type = sig
      type t

      val to_string : t -> string

      val of_string : string -> t

      val of_int : int -> t
    end

    val make_numeric_arg :
         name:string
      -> (module Numeric_type with type t = 't)
      -> 't option Graphql_async.Schema.Arg.arg_typ

    val uint64_arg : Unsigned.UInt64.t option Graphql_async.Schema.Arg.arg_typ

    val uint32_arg : Unsigned.UInt32.t option Graphql_async.Schema.Arg.arg_typ

    val signature_arg :
      (Mina_base__Signature.t, string) Core.Result.t option
      Graphql_async.Schema.Arg.arg_typ

    val vrf_message :
      Consensus_vrf.Layout.Message.t option Graphql_async.Schema.Arg.arg_typ

    val vrf_threshold :
      Consensus_vrf.Layout.Threshold.t option Graphql_async.Schema.Arg.arg_typ

    val vrf_evaluation :
      Consensus_vrf.Layout.Evaluation.t option Graphql_async.Schema.Arg.arg_typ

    module Fields : sig
      val from :
           doc:string
        -> Signature_lib.Public_key.Compressed.t Graphql_async.Schema.Arg.arg

      val to_ :
           doc:string
        -> Signature_lib.Public_key.Compressed.t Graphql_async.Schema.Arg.arg

      val token :
        doc:string -> Mina_base.Token_id.t Graphql_async.Schema.Arg.arg

      val token_opt :
        doc:string -> Mina_base.Token_id.t option Graphql_async.Schema.Arg.arg

      val token_owner :
           doc:string
        -> Signature_lib.Public_key.Compressed.t Graphql_async.Schema.Arg.arg

      val receiver :
           doc:string
        -> Signature_lib.Public_key.Compressed.t Graphql_async.Schema.Arg.arg

      val receiver_opt :
           doc:string
        -> Signature_lib.Public_key.Compressed.t option
           Graphql_async.Schema.Arg.arg

      val fee_payer_opt :
           doc:string
        -> Signature_lib.Public_key.Compressed.t option
           Graphql_async.Schema.Arg.arg

      val fee : doc:string -> Unsigned.UInt64.t Graphql_async.Schema.Arg.arg

      val memo : string option Graphql_async.Schema.Arg.arg

      val valid_until : Unsigned.UInt32.t option Graphql_async.Schema.Arg.arg

      val nonce : Unsigned.UInt32.t option Graphql_async.Schema.Arg.arg

      val signature :
        (Mina_base__Signature.t, string) Core.Result.t option
        Graphql_async.Schema.Arg.arg
    end

    val send_payment :
      ( Signature_lib.Public_key.Compressed.t
      * Signature_lib.Public_key.Compressed.t
      * Mina_base.Token_id.t option
      * Unsigned.UInt64.t
      * Unsigned.UInt64.t
      * Unsigned.UInt32.t option
      * string option
      * Unsigned.UInt32.t option )
      option
      Graphql_async.Schema.Arg.arg_typ

    val send_delegation :
      ( Signature_lib.Public_key.Compressed.t
      * Signature_lib.Public_key.Compressed.t
      * Unsigned.UInt64.t
      * Unsigned.UInt32.t option
      * string option
      * Unsigned.UInt32.t option )
      option
      Graphql_async.Schema.Arg.arg_typ

    val create_token :
      ( Signature_lib.Public_key.Compressed.t option
      * Signature_lib.Public_key.Compressed.t
      * Unsigned.UInt64.t
      * Unsigned.UInt32.t option
      * string option
      * Unsigned.UInt32.t option )
      option
      Graphql_async.Schema.Arg.arg_typ

    val create_token_account :
      ( Signature_lib.Public_key.Compressed.t
      * Mina_base.Token_id.t
      * Signature_lib.Public_key.Compressed.t
      * Unsigned.UInt64.t
      * Signature_lib.Public_key.Compressed.t option
      * Unsigned.UInt32.t option
      * string option
      * Unsigned.UInt32.t option )
      option
      Graphql_async.Schema.Arg.arg_typ

    val mint_tokens :
      ( Signature_lib.Public_key.Compressed.t
      * Mina_base.Token_id.t
      * Signature_lib.Public_key.Compressed.t option
      * Unsigned.UInt64.t
      * Unsigned.UInt64.t
      * Unsigned.UInt32.t option
      * string option
      * Unsigned.UInt32.t option )
      option
      Graphql_async.Schema.Arg.arg_typ

    val rosetta_transaction :
      Mina_base.Signed_command.t option Graphql_async.Schema.Arg.arg_typ

    val create_account : string option Graphql_async.Schema.Arg.arg_typ

    val unlock_account :
      (string * Signature_lib.Public_key.Compressed.t) option
      Graphql_async.Schema.Arg.arg_typ

    val create_hd_account :
      Unsigned.UInt32.t option Graphql_async.Schema.Arg.arg_typ

    val lock_account :
      Signature_lib.Public_key.Compressed.t option
      Graphql_async.Schema.Arg.arg_typ

    val delete_account :
      Signature_lib.Public_key.Compressed.t option
      Graphql_async.Schema.Arg.arg_typ

    val reset_trust_status : string option Graphql_async.Schema.Arg.arg_typ

    val block_filter_input :
      Signature_lib.Public_key.Compressed.t option
      Graphql_async.Schema.Arg.arg_typ

    val user_command_filter_input :
      Signature_lib.Public_key.Compressed.t option
      Graphql_async.Schema.Arg.arg_typ

    val set_coinbase_receiver :
      Signature_lib.Public_key.Compressed.t option option
      Graphql_async.Schema.Arg.arg_typ

    val set_snark_work_fee :
      Unsigned.UInt64.t option Graphql_async.Schema.Arg.arg_typ

    val set_snark_worker :
      Signature_lib.Public_key.Compressed.t option option
      Graphql_async.Schema.Arg.arg_typ

    module AddPaymentReceipt : sig
      type t = { payment : string; added_time : string }

      val typ : t option Graphql_async.Schema.Arg.arg_typ
    end

    val set_connection_gating_config :
      (Mina_net2.connection_gating, string) Core_kernel__Result.t option
      Graphql_async.Schema.Arg.arg_typ
  end

  val vrf_message :
    (Mina_lib.t, Consensus_vrf.Layout.Message.t option) Graphql_async.Schema.typ

  val vrf_threshold :
    ( Mina_lib.t
    , Consensus_vrf.Layout.Threshold.t option )
    Graphql_async.Schema.typ

  val vrf_evaluation :
    ( Mina_lib.t
    , Consensus_vrf.Layout.Evaluation.t option )
    Graphql_async.Schema.typ
end

module Subscriptions : sig
  val new_sync_update : Mina_lib.t Graphql_async.Schema.subscription_field

  val new_block : Mina_lib.t Graphql_async.Schema.subscription_field

  val chain_reorganization : Mina_lib.t Graphql_async.Schema.subscription_field

  val commands : Mina_lib.t Graphql_async.Schema.subscription_field list
end

module Mutations : sig
  val create_account_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> string
    -> (Signature_lib.Public_key.Compressed.t, 'a) Core.Result.t
       Async_kernel__Deferred.t

  val add_wallet : (Mina_lib.t, unit) Graphql_async.Schema.field

  val create_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val create_hd_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val unlock_account_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> string * Signature_lib.Public_key.Compressed.t
    -> (Signature_lib.Public_key.Compressed.t, string) Core._result
       Async_kernel__Deferred.t

  val unlock_wallet : (Mina_lib.t, unit) Graphql_async.Schema.field

  val unlock_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val lock_account_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> Signature_lib.Public_key.Compressed.t
    -> Signature_lib.Public_key.Compressed.t

  val lock_wallet : (Mina_lib.t, unit) Graphql_async.Schema.field

  val lock_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val delete_account_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> Signature_lib.Public_key.Compressed.t
    -> ( Signature_lib.Public_key.Compressed.t
       , string )
       Async_kernel__Deferred_result.t

  val delete_wallet : (Mina_lib.t, unit) Graphql_async.Schema.field

  val delete_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val reload_account_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> (bool, 'a) Core._result Async_kernel__Deferred.t

  val reload_wallets : (Mina_lib.t, unit) Graphql_async.Schema.field

  val reload_accounts : (Mina_lib.t, unit) Graphql_async.Schema.field

  val import_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val reset_trust_status : (Mina_lib.t, unit) Graphql_async.Schema.field

  val send_user_command :
       Mina_lib.t
    -> User_command_input.t
    -> ( Mina_base.Signed_command.Stable.V1.t Types.UserCommand.With_status.t
       , string )
       Core._result
       Async_kernel__Deferred.t

  val find_identity :
       public_key:Signature_lib.Public_key.Compressed.t
    -> Mina_lib.t
    -> ( [ `Hd_index of Mina_numbers.Hd_index.t
         | `Keypair of Signature_lib.Keypair.t ]
       , string )
       Core.Result.t

  val create_user_command_input :
       fee:Currency__.Intf.uint64
    -> fee_token:Mina_base.Token_id.t
    -> fee_payer_pk:Signature_lib.Public_key.Compressed.t
    -> nonce_opt:Mina_base.Account.Nonce.t option
    -> valid_until:Unsigned.uint32 option
    -> memo:string option
    -> signer:Signature_lib.Public_key.Compressed.t
    -> body:Mina_base.Signed_command_payload.Body.t
    -> sign_choice:User_command_input.Sign_choice.t
    -> (User_command_input.t, string) Core.result

  val make_signed_user_command :
       signature:(Mina_base.Signature.t, string) Core_kernel.Result.t
    -> nonce_opt:Mina_base.Account.Nonce.t option
    -> signer:Signature_lib.Public_key.Compressed.t
    -> memo:string option
    -> fee:Currency__.Intf.uint64
    -> fee_token:Mina_base.Token_id.t
    -> fee_payer_pk:Signature_lib.Public_key.Compressed.t
    -> valid_until:Unsigned.uint32 option
    -> body:Mina_base.Signed_command_payload.Body.t
    -> (User_command_input.t, string) Async_kernel__Deferred_result.t

  val send_signed_user_command :
       signature:(Mina_base.Signature.t, string) Core_kernel.Result.t
    -> coda:Mina_lib.t
    -> nonce_opt:Mina_base.Account.Nonce.t option
    -> signer:Signature_lib.Public_key.Compressed.t
    -> memo:string option
    -> fee:Currency__.Intf.uint64
    -> fee_token:Mina_base.Token_id.t
    -> fee_payer_pk:Signature_lib.Public_key.Compressed.t
    -> valid_until:Unsigned.uint32 option
    -> body:Mina_base.Signed_command_payload.Body.t
    -> ( ( Mina_base.Signed_command.Stable.V1.t
         , Mina_base.Transaction_hash.t )
         With_hash.t
         Types.UserCommand.With_status.t
       , string )
       Async_kernel__Deferred_result.t

  val send_unsigned_user_command :
       coda:Mina_lib.t
    -> nonce_opt:Mina_base.Account.Nonce.t option
    -> signer:Signature_lib.Public_key.Compressed.t
    -> memo:string option
    -> fee:Currency__.Intf.uint64
    -> fee_token:Mina_base.Token_id.t
    -> fee_payer_pk:Signature_lib.Public_key.Compressed.t
    -> valid_until:Unsigned.uint32 option
    -> body:Mina_base.Signed_command_payload.Body.t
    -> ( ( Mina_base.Signed_command.Stable.V1.t
         , Mina_base.Transaction_hash.t )
         With_hash.t
         Types.UserCommand.With_status.t
       , string )
       Async_kernel__Deferred_result.t

  val send_delegation : (Mina_lib.t, unit) Graphql_async.Schema.field

  val send_payment : (Mina_lib.t, unit) Graphql_async.Schema.field

  val create_token : (Mina_lib.t, unit) Graphql_async.Schema.field

  val create_token_account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val mint_tokens : (Mina_lib.t, unit) Graphql_async.Schema.field

  val send_rosetta_transaction : (Mina_lib.t, unit) Graphql_async.Schema.field

  val export_logs : (Mina_lib.t, unit) Graphql_async.Schema.field

  val set_coinbase_receiver : (Mina_lib.t, unit) Graphql_async.Schema.field

  val set_snark_worker : (Mina_lib.t, unit) Graphql_async.Schema.field

  val set_snark_work_fee : (Mina_lib.t, unit) Graphql_async.Schema.field

  val set_connection_gating_config :
    (Mina_lib.t, unit) Graphql_async.Schema.field

  val add_peer : (Mina_lib.t, unit) Graphql_async.Schema.field

  val archive_precomputed_block : (Mina_lib.t, unit) Graphql_async.Schema.field

  val archive_extensional_block : (Mina_lib.t, unit) Graphql_async.Schema.field

  val commands : (Mina_lib.t, unit) Graphql_async.Schema.field list
end

module Queries : sig
  val pooled_user_commands : (Mina_lib.t, unit) Graphql_async.Schema.field

  val sync_status : (Mina_lib.t, unit) Graphql_async.Schema.field

  val daemon_status : (Mina_lib.t, unit) Graphql_async.Schema.field

  val trust_status : (Mina_lib.t, unit) Graphql_async.Schema.field

  val trust_status_all : (Mina_lib.t, unit) Graphql_async.Schema.field

  val version : (Mina_lib.t, unit) Graphql_async.Schema.field

  val tracked_accounts_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> Types.AccountObj.t list

  val owned_wallets : (Mina_lib.t, unit) Graphql_async.Schema.field

  val tracked_accounts : (Mina_lib.t, unit) Graphql_async.Schema.field

  val account_resolver :
       Mina_lib.t Graphql_async.Schema.resolve_info
    -> unit
    -> Signature_lib.Public_key.Compressed.t
    -> Types.AccountObj.t option

  val wallet : (Mina_lib.t, unit) Graphql_async.Schema.field

  val get_ledger_and_breadcrumb :
    Mina_lib.t -> (Mina_base.Ledger.t * Transition_frontier.Breadcrumb.t) option

  val account : (Mina_lib.t, unit) Graphql_async.Schema.field

  val accounts_for_pk : (Mina_lib.t, unit) Graphql_async.Schema.field

  val token_owner : (Mina_lib.t, unit) Graphql_async.Schema.field

  val transaction_status : (Mina_lib.t, unit) Graphql_async.Schema.field

  val current_snark_worker : (Mina_lib.t, unit) Graphql_async.Schema.field

  val genesis_block : (Mina_lib.t, unit) Graphql_async.Schema.field

  val block_of_breadcrumb :
       Mina_lib.t
    -> Transition_frontier.Breadcrumb.t
    -> ( Filtered_external_transition.t
       , Mina_base.State_hash.t )
       With_hash.Stable.Latest.t

  val best_chain : (Mina_lib.t, unit) Graphql_async.Schema.field

  val block : (Mina_lib.t, unit) Graphql_async.Schema.field

  val initial_peers : (Mina_lib.t, unit) Graphql_async.Schema.field

  val get_peers : (Mina_lib.t, unit) Graphql_async.Schema.field

  val snark_pool : (Mina_lib.t, unit) Graphql_async.Schema.field

  val pending_snark_work : (Mina_lib.t, unit) Graphql_async.Schema.field

  val genesis_constants : (Mina_lib.t, unit) Graphql_async.Schema.field

  val time_offset : (Mina_lib.t, unit) Graphql_async.Schema.field

  val next_available_token : (Mina_lib.t, unit) Graphql_async.Schema.field

  val connection_gating_config : (Mina_lib.t, unit) Graphql_async.Schema.field

  val validate_payment : (Mina_lib.t, unit) Graphql_async.Schema.field

  val runtime_config : (Mina_lib.t, unit) Graphql_async.Schema.field

  val evaluate_vrf : (Mina_lib.t, unit) Graphql_async.Schema.field

  val check_vrf : (Mina_lib.t, unit) Graphql_async.Schema.field

  val commands : (Mina_lib.t, unit) Graphql_async.Schema.field list
end

val schema : Mina_lib.t Graphql_async.Schema.schema

val schema_limited : Mina_lib.t Graphql_async.Schema.schema
