open Core
open Async
open Graphql_async
open Mina_base
open Mina_transaction
module Ledger = Mina_ledger.Ledger
open Signature_lib
open Currency

type context_typ = Mina_lib.t

open Utils

module Doc = struct
  let date ?(extra = "") s =
    sprintf
      !"%s (stringified Unix time - number of milliseconds since January 1, \
        1970)%s"
      s extra

  let bin_prot =
    sprintf !"%s (base58-encoded janestreet/bin_prot serialization)"
end

(* open Schema *)
module Wrapper = Graphql_utils.Wrapper.Make2 (Schema)
open Wrapper
open Graphql_lib.Base_types

let public_key = public_key ()

let uint64 = uint64 ()

let uint32 = uint32 ()

let token_id = token_id ()

let account_id : (Mina_lib.t, Account_id.t option) typ =
  obj "AccountId" ~fields:(fun _ ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ id -> Mina_base.Account_id.public_key id)
      ; field "tokenId" ~typ:(non_null token_id)
          ~args:Arg.[]
          ~resolve:(fun _ id -> Mina_base.Account_id.token_id id)
      ])

let json : ('context, Yojson.Basic.t option) typ =
  scalar "JSON" ~doc:"Arbitrary JSON" ~coerce:Fn.id

let epoch_seed = epoch_seed ()

let sync_status : (context_typ, Sync_status.t option) typ =
  enum "SyncStatus" ~doc:"Sync status of daemon"
    ~values:
      (List.map Sync_status.all ~f:(fun status ->
           enum_value
             (String.map ~f:Char.uppercase @@ Sync_status.to_string status)
             ~value:status))

let transaction_status :
    (context_typ, Transaction_inclusion_status.State.t option) typ =
  enum "TransactionStatus" ~doc:"Status of a transaction"
    ~values:
      Transaction_inclusion_status.State.
        [ enum_value "INCLUDED" ~value:Included
            ~doc:"A transaction that is on the longest chain"
        ; enum_value "PENDING" ~value:Pending
            ~doc:
              "A transaction either in the transition frontier or in \
               transaction pool but is not on the longest chain"
        ; enum_value "UNKNOWN" ~value:Unknown
            ~doc:
              "The transaction has either been snarked, reached finality \
               through consensus or has been dropped"
        ]

let consensus_time =
  let module C = Consensus.Data.Consensus_time in
  obj "ConsensusTime" ~fields:(fun _ ->
      [ field "epoch" ~typ:(non_null uint32)
          ~args:Arg.[]
          ~resolve:(fun _ global_slot -> C.epoch global_slot)
      ; field "slot" ~typ:(non_null uint32)
          ~args:Arg.[]
          ~resolve:(fun _ global_slot -> C.slot global_slot)
      ; field "globalSlot" ~typ:(non_null uint32)
          ~args:Arg.[]
          ~resolve:(fun _ (global_slot : Consensus.Data.Consensus_time.t) ->
            C.to_uint32 global_slot)
      ; field "startTime" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } global_slot ->
            let constants =
              (Mina_lib.config coda).precomputed_values.consensus_constants
            in
            Block_time.to_string @@ C.start_time ~constants global_slot)
      ; field "endTime" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } global_slot ->
            let constants =
              (Mina_lib.config coda).precomputed_values.consensus_constants
            in
            Block_time.to_string @@ C.end_time ~constants global_slot)
      ])

let consensus_time_with_global_slot_since_genesis =
  obj "ConsensusTimeGlobalSlot"
    ~doc:"Consensus time and the corresponding global slot since genesis"
    ~fields:(fun _ ->
      [ field "consensusTime" ~typ:(non_null consensus_time)
          ~doc:
            "Time in terms of slot number in an epoch, start and end time of \
             the slot since UTC epoch"
          ~args:Arg.[]
          ~resolve:(fun _ (time, _) -> time)
      ; field "globalSlotSinceGenesis"
          ~args:Arg.[]
          ~typ:(non_null uint32)
          ~resolve:(fun _ (_, slot) -> slot)
      ])

let block_producer_timing :
    (_, Daemon_rpcs.Types.Status.Next_producer_timing.t option) typ =
  obj "BlockProducerTimings" ~fields:(fun _ ->
      let of_time ~consensus_constants =
        Consensus.Data.Consensus_time.of_time_exn ~constants:consensus_constants
      in
      [ field "times"
          ~typ:(non_null @@ list @@ non_null consensus_time)
          ~doc:"Next block production time"
          ~args:Arg.[]
          ~resolve:
            (fun { ctx = coda; _ }
                 { Daemon_rpcs.Types.Status.Next_producer_timing.timing; _ } ->
            let consensus_constants =
              (Mina_lib.config coda).precomputed_values.consensus_constants
            in
            match timing with
            | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again _ ->
                []
            | Evaluating_vrf _last_checked_slot ->
                []
            | Produce info ->
                [ of_time info.time ~consensus_constants ]
            | Produce_now info ->
                [ of_time ~consensus_constants info.time ])
      ; field "globalSlotSinceGenesis"
          ~typ:(non_null @@ list @@ non_null uint32)
          ~doc:"Next block production global-slot-since-genesis "
          ~args:Arg.[]
          ~resolve:
            (fun _ { Daemon_rpcs.Types.Status.Next_producer_timing.timing; _ } ->
            match timing with
            | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again _ ->
                []
            | Evaluating_vrf _last_checked_slot ->
                []
            | Produce info ->
                [ info.for_slot.global_slot_since_genesis ]
            | Produce_now info ->
                [ info.for_slot.global_slot_since_genesis ])
      ; field "generatedFromConsensusAt"
          ~typ:(non_null consensus_time_with_global_slot_since_genesis)
          ~doc:
            "Consensus time of the block that was used to determine the next \
             block production time"
          ~args:Arg.[]
          ~resolve:
            (fun { ctx = coda; _ }
                 { Daemon_rpcs.Types.Status.Next_producer_timing
                   .generated_from_consensus_at =
                     { slot; global_slot_since_genesis }
                 ; _
                 } ->
            let consensus_constants =
              (Mina_lib.config coda).precomputed_values.consensus_constants
            in
            ( Consensus.Data.Consensus_time.of_global_slot
                ~constants:consensus_constants slot
            , global_slot_since_genesis ))
      ])

let merkle_path_element :
    ( context_typ
    , [ `Left of Zkapp_basic.F.t | `Right of Zkapp_basic.F.t ] option )
    typ =
  obj "MerklePathElement" ~fields:(fun _ ->
      [ field "isRightBranch" ~typ:(non_null bool)
          ~args:Arg.[]
          ~resolve:(fun _ x ->
            match x with `Left _ -> false | `Right _ -> true)
      ; field "otherHash" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ x ->
            match x with `Left h | `Right h -> Zkapp_basic.F.to_string h)
      ])

let fee_transfer =
  obj "FeeTransfer" ~fields:(fun _ ->
      [ field "recipient"
          ~args:Arg.[]
          ~doc:"Public key of fee transfer recipient" ~typ:(non_null public_key)
          ~resolve:(fun _ ({ Fee_transfer.receiver_pk = pk; _ }, _) -> pk)
      ; field "fee" ~typ:(non_null uint64)
          ~args:Arg.[]
          ~doc:"Amount that the recipient is paid in this fee transfer"
          ~resolve:(fun _ ({ Fee_transfer.fee; _ }, _) ->
            Currency.Fee.to_uint64 fee)
      ; field "type" ~typ:(non_null string)
          ~args:Arg.[]
          ~doc:
            "Fee_transfer|Fee_transfer_via_coinbase Snark worker fees deducted \
             from the coinbase amount are of type 'Fee_transfer_via_coinbase', \
             rest are deducted from transaction fees"
          ~resolve:(fun _ (_, transfer_type) ->
            match transfer_type with
            | Filtered_external_transition.Fee_transfer_type
              .Fee_transfer_via_coinbase ->
                "Fee_transfer_via_coinbase"
            | Fee_transfer ->
                "Fee_transfer")
      ])

let account_timing : (Mina_lib.t, Account_timing.t option) typ =
  obj "AccountTiming" ~fields:(fun _ ->
      [ field "initialMinimumBalance" ~typ:uint64
          ~doc:"The initial minimum balance for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some (Balance.to_uint64 timing_info.initial_minimum_balance))
      ; field "cliffTime" ~typ:uint32
          ~doc:"The cliff time for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.cliff_time)
      ; field "cliffAmount" ~typ:uint64
          ~doc:"The cliff amount for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some (Currency.Amount.to_uint64 timing_info.cliff_amount))
      ; field "vestingPeriod" ~typ:uint32
          ~doc:"The vesting period for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.vesting_period)
      ; field "vestingIncrement" ~typ:uint64
          ~doc:"The vesting increment for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some (Currency.Amount.to_uint64 timing_info.vesting_increment))
      ])

let completed_work =
  obj "CompletedWork" ~doc:"Completed snark works" ~fields:(fun _ ->
      [ field "prover"
          ~args:Arg.[]
          ~doc:"Public key of the prover" ~typ:(non_null public_key)
          ~resolve:(fun _ { Transaction_snark_work.Info.prover; _ } -> prover)
      ; field "fee" ~typ:(non_null uint64)
          ~args:Arg.[]
          ~doc:"Amount the prover is paid for the snark work"
          ~resolve:(fun _ { Transaction_snark_work.Info.fee; _ } ->
            Currency.Fee.to_uint64 fee)
      ; field "workIds" ~doc:"Unique identifier for the snark work purchased"
          ~typ:(non_null @@ list @@ non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark_work.Info.work_ids; _ } ->
            One_or_two.to_list work_ids)
      ])

let sign =
  enum "sign"
    ~values:
      [ enum_value "PLUS" ~value:Sgn.Pos; enum_value "MINUS" ~value:Sgn.Neg ]

let signed_fee =
  obj "SignedFee" ~doc:"Signed fee" ~fields:(fun _ ->
      [ field "sign" ~typ:(non_null sign) ~doc:"+/-"
          ~args:Arg.[]
          ~resolve:(fun _ fee -> Currency.Amount.Signed.sgn fee)
      ; field "feeMagnitude" ~typ:(non_null uint64) ~doc:"Fee"
          ~args:Arg.[]
          ~resolve:(fun _ fee ->
            Currency.Amount.(to_uint64 (Signed.magnitude fee)))
      ])

let work_statement =
  let `Needs_some_work_for_zkapps_on_mainnet = Mina_base.Util.todo_zkapps in
  obj "WorkDescription"
    ~doc:
      "Transition from a source ledger to a target ledger with some fee excess \
       and increase in supply " ~fields:(fun _ ->
      [ field "sourceLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the source ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.source; _ } ->
            Frozen_ledger_hash.to_base58_check source.ledger)
      ; field "targetLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the target ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.target; _ } ->
            Frozen_ledger_hash.to_base58_check target.ledger)
      ; field "feeExcess" ~typ:(non_null signed_fee)
          ~doc:
            "Total transaction fee that is not accounted for in the transition \
             from source ledger to target ledger"
          ~args:Arg.[]
          ~resolve:
            (fun _
                 ({ fee_excess = { fee_excess_l; _ }; _ } :
                   Transaction_snark.Statement.t) ->
            (* TODO: Expose full fee excess data. *)
            { fee_excess_l with
              magnitude = Currency.Amount.of_fee fee_excess_l.magnitude
            })
      ; field "supplyIncrease" ~typ:(non_null uint64)
          ~doc:"Increase in total coinbase reward "
          ~args:Arg.[]
          ~resolve:
            (fun _ ({ supply_increase; _ } : Transaction_snark.Statement.t) ->
            Currency.Amount.to_uint64 supply_increase)
      ; field "workId" ~doc:"Unique identifier for a snark work"
          ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ w -> Transaction_snark.Statement.hash w)
      ])

let pending_work =
  obj "PendingSnarkWork"
    ~doc:"Snark work bundles that are not available in the pool yet"
    ~fields:(fun _ ->
      [ field "workBundle"
          ~args:Arg.[]
          ~doc:"Work bundle with one or two snark work"
          ~typ:(non_null @@ list @@ non_null work_statement)
          ~resolve:(fun _ w -> One_or_two.to_list w)
      ])

let blockchain_state :
    ('context, (Mina_state.Blockchain_state.Value.t * State_hash.t) option) typ
    =
  obj "BlockchainState" ~fields:(fun _ ->
      [ field "date" ~typ:(non_null string) ~doc:(Doc.date "date")
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            let timestamp =
              Mina_state.Blockchain_state.timestamp blockchain_state
            in
            Block_time.to_string timestamp)
      ; field "utcDate" ~typ:(non_null string)
          ~doc:
            (Doc.date
               ~extra:
                 ". Time offsets are adjusted to reflect true wall-clock time \
                  instead of genesis time."
               "utcDate")
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } t ->
            let blockchain_state, _ = t in
            let timestamp =
              Mina_state.Blockchain_state.timestamp blockchain_state
            in
            Block_time.to_string_system_time
              (Mina_lib.time_controller coda)
              timestamp)
      ; field "snarkedLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the snarked ledger"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            let snarked_ledger_hash =
              Mina_state.Blockchain_state.snarked_ledger_hash blockchain_state
            in
            Frozen_ledger_hash.to_base58_check snarked_ledger_hash)
      ; field "stagedLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the staged ledger"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            let staged_ledger_hash =
              Mina_state.Blockchain_state.staged_ledger_hash blockchain_state
            in
            Mina_base.Ledger_hash.to_base58_check
            @@ Staged_ledger_hash.ledger_hash staged_ledger_hash)
      ; field "stagedLedgerProofEmitted" ~typ:bool
          ~doc:
            "Block finished a staged ledger, and a proof was emitted from it \
             and included into this block's proof. If there is no transition \
             frontier available or no block found, this will return null."
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } t ->
            let open Option.Let_syntax in
            let _, hash = t in
            let%bind frontier =
              Mina_lib.transition_frontier coda
              |> Pipe_lib.Broadcast_pipe.Reader.peek
            in
            match Transition_frontier.find frontier hash with
            | None ->
                None
            | Some b ->
                Some (Transition_frontier.Breadcrumb.just_emitted_a_proof b))
      ])

let protocol_state :
    ( 'context
    , (Filtered_external_transition.Protocol_state.t * State_hash.t) option )
    typ =
  let open Filtered_external_transition.Protocol_state in
  obj "ProtocolState" ~fields:(fun _ ->
      [ field "previousStateHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the previous state"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, _ = t in
            State_hash.to_base58_check protocol_state.previous_state_hash)
      ; field "blockchainState"
          ~doc:"State which is agnostic of a particular consensus algorithm"
          ~typ:(non_null blockchain_state)
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, state_hash = t in
            (protocol_state.blockchain_state, state_hash))
      ; field "consensusState"
          ~doc:
            "State specific to the Codaboros Proof of Stake consensus algorithm"
          ~typ:(non_null @@ Consensus.Data.Consensus_state.graphql_type ())
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, _ = t in
            protocol_state.consensus_state)
      ])

let chain_reorganization_status : (context_typ, [ `Changed ] option) typ =
  enum "ChainReorganizationStatus"
    ~doc:"Status for whenever the blockchain is reorganized"
    ~values:[ enum_value "CHANGED" ~value:`Changed ]

let genesis_constants =
  obj "GenesisConstants" ~fields:(fun _ ->
      [ field "accountCreationFee" ~typ:(non_null uint64)
          ~doc:"The fee charged to create a new account"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } () ->
            (Mina_lib.config coda).precomputed_values.constraint_constants
              .account_creation_fee |> Currency.Fee.to_uint64)
      ; field "coinbase" ~typ:(non_null uint64)
          ~doc:"The amount received as a coinbase reward for producing a block"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } () ->
            (Mina_lib.config coda).precomputed_values.constraint_constants
              .coinbase_amount |> Currency.Amount.to_uint64)
      ])

module AccountObj = struct
  module AnnotatedBalance = struct
    type t =
      { total : Balance.t
      ; unknown : Balance.t
      ; timing : Mina_base.Account_timing.t
      ; breadcrumb : Transition_frontier.Breadcrumb.t option
      }

    let min_balance (b : t) =
      match (b.timing, b.breadcrumb) with
      | Untimed, _ ->
          Some Balance.zero
      | Timed _, None ->
          None
      | Timed timing_info, Some crumb ->
          let consensus_state =
            Transition_frontier.Breadcrumb.consensus_state crumb
          in
          let global_slot =
            Consensus.Data.Consensus_state.global_slot_since_genesis
              consensus_state
          in
          Some
            (Account.min_balance_at_slot ~global_slot
               ~cliff_time:timing_info.cliff_time
               ~cliff_amount:timing_info.cliff_amount
               ~vesting_period:timing_info.vesting_period
               ~vesting_increment:timing_info.vesting_increment
               ~initial_minimum_balance:timing_info.initial_minimum_balance)

    let obj =
      obj "AnnotatedBalance"
        ~doc:
          "A total balance annotated with the amount that is currently unknown \
           with the invariant unknown <= total, as well as the currently \
           liquid and locked balances." ~fields:(fun _ ->
          [ field "total" ~typ:(non_null uint64)
              ~doc:"The amount of MINA owned by the account"
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) -> Balance.to_uint64 b.total)
          ; field "unknown" ~typ:(non_null uint64)
              ~doc:
                "The amount of MINA owned by the account whose origin is \
                 currently unknown"
              ~deprecated:(Deprecated None)
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) -> Balance.to_uint64 b.unknown)
          ; field "liquid" ~typ:uint64
              ~doc:
                "The amount of MINA owned by the account which is currently \
                 available. Can be null if bootstrapping."
              ~deprecated:(Deprecated None)
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                Option.map (min_balance b) ~f:(fun min_balance ->
                    let total_balance : uint64 = Balance.to_uint64 b.total in
                    let min_balance_uint64 = Balance.to_uint64 min_balance in
                    if
                      Unsigned.UInt64.compare total_balance min_balance_uint64
                      > 0
                    then Unsigned.UInt64.sub total_balance min_balance_uint64
                    else Unsigned.UInt64.zero))
          ; field "locked" ~typ:uint64
              ~doc:
                "The amount of MINA owned by the account which is currently \
                 locked. Can be null if bootstrapping."
              ~deprecated:(Deprecated None)
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                Option.map (min_balance b) ~f:Balance.to_uint64)
          ; field "blockHeight" ~typ:(non_null uint32)
              ~doc:"Block height at which balance was measured"
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                match b.breadcrumb with
                | None ->
                    Unsigned.UInt32.zero
                | Some crumb ->
                    Transition_frontier.Breadcrumb.consensus_state crumb
                    |> Consensus.Data.Consensus_state.blockchain_length)
            (* TODO: Mutually recurse with "block" instead -- #5396 *)
          ; field "stateHash" ~typ:string
              ~doc:
                "Hash of block at which balance was measured. Can be null if \
                 bootstrapping. Guaranteed to be non-null for direct account \
                 lookup queries when not bootstrapping. Can also be null when \
                 accessed as nested properties (eg. via delegators). "
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                Option.map b.breadcrumb ~f:(fun crumb ->
                    State_hash.to_base58_check
                    @@ Transition_frontier.Breadcrumb.state_hash crumb))
          ])
  end

  module Partial_account = struct
    let to_full_account
        { Account.Poly.public_key
        ; token_id
        ; token_permissions
        ; token_symbol
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing
        ; permissions
        ; zkapp
        ; zkapp_uri
        } =
      let open Option.Let_syntax in
      let%bind public_key = public_key in
      let%bind token_permissions = token_permissions in
      let%bind token_symbol = token_symbol in
      let%bind nonce = nonce in
      let%bind receipt_chain_hash = receipt_chain_hash in
      let%bind delegate = delegate in
      let%bind voting_for = voting_for in
      let%bind timing = timing in
      let%bind permissions = permissions in
      let%bind zkapp = zkapp in
      let%map zkapp_uri = zkapp_uri in
      { Account.Poly.public_key
      ; token_id
      ; token_permissions
      ; token_symbol
      ; nonce
      ; balance
      ; receipt_chain_hash
      ; delegate
      ; voting_for
      ; timing
      ; permissions
      ; zkapp
      ; zkapp_uri
      }

    let of_full_account ?breadcrumb
        { Account.Poly.public_key
        ; token_id
        ; token_permissions
        ; token_symbol
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing
        ; permissions
        ; zkapp
        ; zkapp_uri
        } =
      { Account.Poly.public_key
      ; token_id
      ; token_permissions = Some token_permissions
      ; token_symbol = Some token_symbol
      ; nonce = Some nonce
      ; balance =
          { AnnotatedBalance.total = balance
          ; unknown = balance
          ; timing
          ; breadcrumb
          }
      ; receipt_chain_hash = Some receipt_chain_hash
      ; delegate
      ; voting_for = Some voting_for
      ; timing
      ; permissions = Some permissions
      ; zkapp
      ; zkapp_uri = Some zkapp_uri
      }

    let of_account_id coda account_id =
      let account =
        coda |> Mina_lib.best_tip |> Participating_state.active
        |> Option.bind ~f:(fun tip ->
               let ledger =
                 Transition_frontier.Breadcrumb.staged_ledger tip
                 |> Staged_ledger.ledger
               in
               Ledger.location_of_account ledger account_id
               |> Option.bind ~f:(Ledger.get ledger)
               |> Option.map ~f:(fun account -> (account, tip)))
      in
      match account with
      | Some (account, breadcrumb) ->
          of_full_account ~breadcrumb account
      | None ->
          Account.
            { Poly.public_key = Account_id.public_key account_id
            ; token_id = Account_id.token_id account_id
            ; token_permissions = None
            ; token_symbol = None
            ; nonce = None
            ; delegate = None
            ; balance =
                { AnnotatedBalance.total = Balance.zero
                ; unknown = Balance.zero
                ; timing = Timing.Untimed
                ; breadcrumb = None
                }
            ; receipt_chain_hash = None
            ; voting_for = None
            ; timing = Timing.Untimed
            ; permissions = None
            ; zkapp = None
            ; zkapp_uri = None
            }

    let of_pk coda pk =
      of_account_id coda (Account_id.create pk Token_id.default)
  end

  type t =
    { account :
        ( Public_key.Compressed.t
        , Token_id.t
        , Token_permissions.t option
        , Account.Token_symbol.t option
        , AnnotatedBalance.t
        , Account.Nonce.t option
        , Receipt.Chain_hash.t option
        , Public_key.Compressed.t option
        , State_hash.t option
        , Account.Timing.t
        , Permissions.t option
        , Zkapp_account.t option
        , string option )
        Account.Poly.t
    ; locked : bool option
    ; is_actively_staking : bool
    ; path : string
    ; index : Account.Index.t option
    }

  let lift coda pk account =
    let block_production_pubkeys = Mina_lib.block_production_pubkeys coda in
    let accounts = Mina_lib.wallets coda in
    let best_tip_ledger = Mina_lib.best_ledger coda in
    { account
    ; locked = Secrets.Wallets.check_locked accounts ~needle:pk
    ; is_actively_staking =
        ( if Token_id.(equal default) account.token_id then
          Public_key.Compressed.Set.mem block_production_pubkeys pk
        else (* Non-default token accounts cannot stake. *)
          false )
    ; path = Secrets.Wallets.get_path accounts pk
    ; index =
        ( match best_tip_ledger with
        | `Active ledger ->
            Option.try_with (fun () ->
                Ledger.index_of_account_exn ledger
                  (Account_id.create account.public_key account.token_id))
        | _ ->
            None )
    }

  let get_best_ledger_account coda aid =
    lift coda
      (Account_id.public_key aid)
      (Partial_account.of_account_id coda aid)

  let get_best_ledger_account_pk coda pk =
    lift coda pk (Partial_account.of_pk coda pk)

  let account_id { Account.Poly.public_key; token_id; _ } =
    Account_id.create public_key token_id

  let auth_required =
    let open Permissions.Auth_required in
    enum "AccountAuthRequired" ~doc:"Kind of authorization required"
      ~values:
        [ enum_value "None" ~value:None
        ; enum_value "Either" ~value:Either
        ; enum_value "Proof" ~value:Proof
        ; enum_value "Signature" ~value:Signature
        ; enum_value "Impossible" ~value:Impossible
        ]

  let account_permissions =
    obj "AccountPermissions" ~fields:(fun _ ->
        [ field "editState" ~typ:(non_null auth_required)
            ~doc:"Authorization required to edit zkApp state"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.edit_state)
        ; field "send" ~typ:(non_null auth_required)
            ~doc:"Authorization required to send tokens"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.send)
        ; field "receive" ~typ:(non_null auth_required)
            ~doc:"Authorization required to receive tokens"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.receive)
        ; field "setDelegate" ~typ:(non_null auth_required)
            ~doc:"Authorization required to set the delegate"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_delegate)
        ; field "setPermissions" ~typ:(non_null auth_required)
            ~doc:"Authorization required to change permissions"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_permissions)
        ; field "setVerificationKey" ~typ:(non_null auth_required)
            ~doc:
              "Authorization required to set the verification key of the zkApp \
               associated with the account"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_verification_key)
        ; field "setZkappUri" ~typ:(non_null auth_required)
            ~doc:
              "Authorization required to change the URI of the zkApp \
               associated with the account "
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_zkapp_uri)
        ; field "editSequenceState" ~typ:(non_null auth_required)
            ~doc:"Authorization required to edit the sequence state"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.edit_sequence_state)
        ; field "setTokenSymbol" ~typ:(non_null auth_required)
            ~doc:"Authorization required to set the token symbol"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_token_symbol)
        ; field "incrementNonce" ~typ:(non_null auth_required)
            ~doc:"Authorization required to increment the nonce"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.increment_nonce)
        ; field "setVotingFor" ~typ:(non_null auth_required)
            ~doc:
              "Authorization required to set the state hash the account is \
               voting for"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_voting_for)
        ])

  let account_vk =
    obj "AccountVerificationKeyWithHash" ~doc:"Verification key with hash"
      ~fields:(fun _ ->
        [ field "verificationKey" ~doc:"Verification key in Base58Check format"
            ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ (vk : _ With_hash.t) ->
              Pickles.Side_loaded.Verification_key.to_base58_check vk.data)
        ; field "hash" ~doc:"Hash of verification key" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ (vk : _ With_hash.t) ->
              Pickles.Backend.Tick.Field.to_string vk.hash)
        ])

  let rec account =
    lazy
      (obj "Account" ~doc:"An account record according to the daemon"
         ~fields:(fun _ ->
           [ field "publicKey" ~typ:(non_null public_key)
               ~doc:"The public identity of the account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.public_key)
           ; field "token" ~typ:(non_null token_id)
               ~doc:"The token associated with this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.token_id)
           ; field "timing" ~typ:(non_null account_timing)
               ~doc:"The timing associated with this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.timing)
           ; field "balance"
               ~typ:(non_null AnnotatedBalance.obj)
               ~doc:"The amount of MINA owned by the account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.balance)
           ; field "nonce" ~typ:string
               ~doc:
                 "A natural number that increases with each transaction \
                  (stringified uint32)"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.map ~f:Account.Nonce.to_string
                   account.Account.Poly.nonce)
           ; field "inferredNonce" ~typ:string
               ~doc:
                 "Like the `nonce` field, except it includes the scheduled \
                  transactions (transactions not yet included in a block) \
                  (stringified uint32)"
               ~args:Arg.[]
               ~resolve:(fun { ctx = coda; _ } { account; _ } ->
                 let account_id = account_id account in
                 match
                   Mina_lib.get_inferred_nonce_from_transaction_pool_and_ledger
                     coda account_id
                 with
                 | `Active (Some nonce) ->
                     Some (Account.Nonce.to_string nonce)
                 | `Active None | `Bootstrapping ->
                     None)
           ; field "epochDelegateAccount" ~typ:(Lazy.force account)
               ~doc:
                 "The account that you delegated on the staking ledger of the \
                  current block's epoch"
               ~args:Arg.[]
               ~resolve:(fun { ctx = coda; _ } { account; _ } ->
                 let open Option.Let_syntax in
                 let account_id = account_id account in
                 match%bind Mina_lib.staking_ledger coda with
                 | Genesis_epoch_ledger staking_ledger -> (
                     match
                       let open Option.Let_syntax in
                       account_id
                       |> Ledger.location_of_account staking_ledger
                       >>= Ledger.get staking_ledger
                     with
                     | Some delegate_account ->
                         let delegate_key = delegate_account.public_key in
                         Some (get_best_ledger_account_pk coda delegate_key)
                     | None ->
                         [%log' warn (Mina_lib.top_level_logger coda)]
                           "Could not retrieve delegate account from the \
                            genesis ledger. The account was not present in the \
                            ledger." ;
                         None )
                 | Ledger_db staking_ledger -> (
                     try
                       let index =
                         Ledger.Db.index_of_account_exn staking_ledger
                           account_id
                       in
                       let delegate_account =
                         Ledger.Db.get_at_index_exn staking_ledger index
                       in
                       let delegate_key = delegate_account.public_key in
                       Some (get_best_ledger_account_pk coda delegate_key)
                     with e ->
                       [%log' warn (Mina_lib.top_level_logger coda)]
                         ~metadata:[ ("error", `String (Exn.to_string e)) ]
                         "Could not retrieve delegate account from sparse \
                          ledger. The account may not be in the ledger: $error" ;
                       None ))
           ; field "receiptChainHash" ~typ:string
               ~doc:"Top hash of the receipt chain merkle-list"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.map ~f:Receipt.Chain_hash.to_base58_check
                   account.Account.Poly.receipt_chain_hash)
           ; field "delegate" ~typ:public_key
               ~doc:
                 "The public key to which you are delegating - if you are not \
                  delegating to anybody, this would return your public key"
               ~args:Arg.[]
               ~deprecated:(Deprecated (Some "use delegateAccount instead"))
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.delegate)
           ; field "delegateAccount" ~typ:(Lazy.force account)
               ~doc:
                 "The account to which you are delegating - if you are not \
                  delegating to anybody, this would return your public key"
               ~args:Arg.[]
               ~resolve:(fun { ctx = coda; _ } { account; _ } ->
                 Option.map
                   ~f:(get_best_ledger_account_pk coda)
                   account.Account.Poly.delegate)
           ; field "delegators"
               ~typ:(list @@ non_null @@ Lazy.force account)
               ~doc:
                 "The list of accounts which are delegating to you (note that \
                  the info is recorded in the last epoch so it might not be up \
                  to date with the current account status)"
               ~args:Arg.[]
               ~resolve:(fun { ctx = coda; _ } { account; _ } ->
                 let open Option.Let_syntax in
                 let pk = account.Account.Poly.public_key in
                 let%map delegators =
                   Mina_lib.current_epoch_delegators coda ~pk
                 in
                 let best_tip_ledger = Mina_lib.best_ledger coda in
                 List.map
                   ~f:(fun a ->
                     { account = Partial_account.of_full_account a
                     ; locked = None
                     ; is_actively_staking = true
                     ; path = ""
                     ; index =
                         ( match best_tip_ledger with
                         | `Active ledger ->
                             Option.try_with (fun () ->
                                 Ledger.index_of_account_exn ledger
                                   (Account.identifier a))
                         | _ ->
                             None )
                     })
                   delegators)
           ; field "lastEpochDelegators"
               ~typ:(list @@ non_null @@ Lazy.force account)
               ~doc:
                 "The list of accounts which are delegating to you in the last \
                  epoch (note that the info is recorded in the one before last \
                  epoch epoch so it might not be up to date with the current \
                  account status)"
               ~args:Arg.[]
               ~resolve:(fun { ctx = coda; _ } { account; _ } ->
                 let open Option.Let_syntax in
                 let pk = account.Account.Poly.public_key in
                 let%map delegators = Mina_lib.last_epoch_delegators coda ~pk in
                 let best_tip_ledger = Mina_lib.best_ledger coda in
                 List.map
                   ~f:(fun a ->
                     { account = Partial_account.of_full_account a
                     ; locked = None
                     ; is_actively_staking = true
                     ; path = ""
                     ; index =
                         ( match best_tip_ledger with
                         | `Active ledger ->
                             Option.try_with (fun () ->
                                 Ledger.index_of_account_exn ledger
                                   (Account.identifier a))
                         | _ ->
                             None )
                     })
                   delegators)
           ; field "votingFor" ~typ:string
               ~doc:
                 "The previous epoch lock hash of the chain which you are \
                  voting for"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.map ~f:Mina_base.State_hash.to_base58_check
                   account.Account.Poly.voting_for)
           ; field "stakingActive" ~typ:(non_null bool)
               ~doc:
                 "True if you are actively staking with this account on the \
                  current daemon - this may not yet have been updated if the \
                  staking key was changed recently"
               ~args:Arg.[]
               ~resolve:(fun _ { is_actively_staking; _ } ->
                 is_actively_staking)
           ; field "privateKeyPath" ~typ:(non_null string)
               ~doc:"Path of the private key file for this account"
               ~args:Arg.[]
               ~resolve:(fun _ { path; _ } -> path)
           ; field "locked" ~typ:bool
               ~doc:
                 "True if locked, false if unlocked, null if the account isn't \
                  tracked by the queried daemon"
               ~args:Arg.[]
               ~resolve:(fun _ { locked; _ } -> locked)
           ; field "isTokenOwner" ~typ:bool
               ~doc:"True if this account owns its associated token"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 match%map.Option account.token_permissions with
                 | Token_owned _ ->
                     true
                 | Not_owned _ ->
                     false)
           ; field "isDisabled" ~typ:bool
               ~doc:
                 "True if this account has been disabled by the owner of the \
                  associated token"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 match%map.Option account.token_permissions with
                 | Token_owned _ ->
                     false
                 | Not_owned { account_disabled } ->
                     account_disabled)
           ; field "index" ~typ:int
               ~doc:
                 "The index of this account in the ledger, or null if this \
                  account does not yet have a known position in the best tip \
                  ledger"
               ~args:Arg.[]
               ~resolve:(fun _ { index; _ } -> index)
           ; field "zkappUri" ~typ:string
               ~doc:
                 "The URI associated with this account, usually pointing to \
                  the zkApp source code"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.zkapp_uri)
           ; field "zkappState"
               ~typ:(list @@ non_null string)
               ~doc:
                 "The 8 field elements comprising the zkApp state associated \
                  with this account encoded as bignum strings"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.zkapp
                 |> Option.map ~f:(fun zkapp_account ->
                        zkapp_account.app_state |> Zkapp_state.V.to_list
                        |> List.map ~f:Zkapp_basic.F.to_string))
           ; field "permissions" ~typ:account_permissions
               ~doc:"Permissions for updating certain fields of this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.permissions)
           ; field "tokenSymbol" ~typ:string
               ~doc:"The token symbol associated with this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.token_symbol)
           ; field "verificationKey" ~typ:account_vk
               ~doc:"Verification key associated with this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.value_map account.Account.Poly.zkapp ~default:None
                   ~f:(fun zkapp_account -> zkapp_account.verification_key))
           ; field "sequenceEvents"
               ~doc:"Sequence events associated with this account"
               ~typ:(list (non_null string))
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.map account.Account.Poly.zkapp ~f:(fun zkapp_account ->
                     List.map ~f:Snark_params.Tick.Field.to_string
                       (Pickles_types.Vector.to_list
                          zkapp_account.sequence_state)))
           ]))

  let account = Lazy.force account
end

module Command_status = struct
  type t =
    | Applied
    | Enqueued
    | Included_but_failed of Transaction_status.Failure.Collection.t

  let failure_reasons =
    obj "PartiesFailureReason" ~fields:(fun _ ->
        [ field "index" ~typ:string ~args:[]
            ~doc:"List index of the party that failed"
            ~resolve:(fun _ (index, _) -> Some (Int.to_string index))
        ; field "failures"
            ~typ:(non_null @@ list @@ non_null @@ string)
            ~args:[] ~doc:"Failure reason for the party or any nested parties"
            ~resolve:(fun _ (_, failures) ->
              List.map failures ~f:Transaction_status.Failure.to_string)
        ])
end

module User_command = struct
  let kind : ('context, [ `Payment | `Stake_delegation ] option) typ =
    scalar "UserCommandKind" ~doc:"The kind of user command" ~coerce:(function
      | `Payment ->
          `String "PAYMENT"
      | `Stake_delegation ->
          `String "STAKE_DELEGATION")

  let to_kind (t : Signed_command.t) =
    match Signed_command.payload t |> Signed_command_payload.body with
    | Payment _ ->
        `Payment
    | Stake_delegation _ ->
        `Stake_delegation

  let user_command_interface :
      ( 'context
      , ( 'context
        , (Signed_command.t, Transaction_hash.t) With_hash.t )
        abstract_value
        option )
      typ =
    interface "UserCommand" ~doc:"Common interface for user commands"
      ~fields:(fun _ ->
        [ abstract_field "id" ~typ:(non_null guid) ~args:[]
        ; abstract_field "hash" ~typ:(non_null string) ~args:[]
        ; abstract_field "kind" ~typ:(non_null kind) ~args:[]
            ~doc:"String describing the kind of user command"
        ; abstract_field "nonce" ~typ:(non_null int) ~args:[]
            ~doc:"Sequence number of command for the fee-payer's account"
        ; abstract_field "source"
            ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"Account that the command is sent from"
        ; abstract_field "receiver"
            ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"Account that the command applies to"
        ; abstract_field "feePayer"
            ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"Account that pays the fees for the command"
        ; abstract_field "validUntil" ~typ:(non_null uint32) ~args:[]
            ~doc:
              "The global slot number after which this transaction cannot be \
               applied"
        ; abstract_field "token" ~typ:(non_null token_id) ~args:[]
            ~doc:"Token used by the command"
        ; abstract_field "amount" ~typ:(non_null uint64) ~args:[]
            ~doc:
              "Amount that the source is sending to receiver - 0 for commands \
               that are not associated with an amount"
        ; abstract_field "feeToken" ~typ:(non_null token_id) ~args:[]
            ~doc:"Token used to pay the fee"
        ; abstract_field "fee" ~typ:(non_null uint64) ~args:[]
            ~doc:
              "Fee that the fee-payer is willing to pay for making the \
               transaction"
        ; abstract_field "memo" ~typ:(non_null string) ~args:[]
            ~doc:"Short arbitrary message provided by the sender"
        ; abstract_field "isDelegation" ~typ:(non_null bool) ~args:[]
            ~doc:
              "If true, this represents a delegation of stake, otherwise it is \
               a payment"
            ~deprecated:(Deprecated (Some "use kind field instead"))
        ; abstract_field "from" ~typ:(non_null public_key) ~args:[]
            ~doc:"Public key of the sender"
            ~deprecated:(Deprecated (Some "use feePayer field instead"))
        ; abstract_field "fromAccount"
            ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"Account of the sender"
            ~deprecated:(Deprecated (Some "use feePayer field instead"))
        ; abstract_field "to" ~typ:(non_null public_key) ~args:[]
            ~doc:"Public key of the receiver"
            ~deprecated:(Deprecated (Some "use receiver field instead"))
        ; abstract_field "toAccount"
            ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"Account of the receiver"
            ~deprecated:(Deprecated (Some "use receiver field instead"))
        ; abstract_field "failureReason" ~typ:string ~args:[]
            ~doc:"null is no failure, reason for failure otherwise."
        ])

  module With_status = struct
    type 'a t = { data : 'a; status : Command_status.t }

    let map t ~f = { t with data = f t.data }
  end

  let field_no_status ?doc ?deprecated lab ~typ ~args ~resolve =
    field ?doc ?deprecated lab ~typ ~args ~resolve:(fun c uc ->
        resolve c uc.With_status.data)

  let user_command_shared_fields :
      (* ( Mina_lib.t *)
      (* , (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t *)
      (* ,_,_,_) *)
      (* field *)
      (* list *)
      (Mina_lib.t, _, _) Wrapper.Fields.fields =
    [ field_no_status "id" ~typ:(non_null guid) ~args:[]
        ~resolve:(fun _ user_command ->
          Signed_command.to_base58_check user_command.With_hash.data)
    ; field_no_status "hash" ~typ:(non_null string) ~args:[]
        ~resolve:(fun _ user_command ->
          Transaction_hash.to_base58_check user_command.With_hash.hash)
    ; field_no_status "kind" ~typ:(non_null kind) ~args:[]
        ~doc:"String describing the kind of user command" ~resolve:(fun _ cmd ->
          to_kind cmd.With_hash.data)
    ; field_no_status "nonce" ~typ:(non_null int) ~args:[]
        ~doc:"Sequence number of command for the fee-payer's account"
        ~resolve:(fun _ payment ->
          Signed_command_payload.nonce
          @@ Signed_command.payload payment.With_hash.data
          |> Account.Nonce.to_int)
    ; field_no_status "source" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account that the command is sent from"
        ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
            (Signed_command.source cmd.With_hash.data))
    ; field_no_status "receiver" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account that the command applies to"
        ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
            (Signed_command.receiver cmd.With_hash.data))
    ; field_no_status "feePayer" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account that pays the fees for the command"
        ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
            (Signed_command.fee_payer cmd.With_hash.data))
    ; field_no_status "validUntil" ~typ:(non_null uint32) ~args:[]
        ~doc:
          "The global slot number after which this transaction cannot be \
           applied" ~resolve:(fun _ cmd ->
          Signed_command.valid_until cmd.With_hash.data)
    ; field_no_status "token" ~typ:(non_null token_id) ~args:[]
        ~doc:"Token used for the transaction" ~resolve:(fun _ cmd ->
          Signed_command.token cmd.With_hash.data)
    ; field_no_status "amount" ~typ:(non_null uint64) ~args:[]
        ~doc:
          "Amount that the source is sending to receiver; 0 for commands \
           without an associated amount" ~resolve:(fun _ cmd ->
          match Signed_command.amount cmd.With_hash.data with
          | Some amount ->
              Currency.Amount.to_uint64 amount
          | None ->
              Unsigned.UInt64.zero)
    ; field_no_status "feeToken" ~typ:(non_null token_id) ~args:[]
        ~doc:"Token used to pay the fee" ~resolve:(fun _ cmd ->
          Signed_command.fee_token cmd.With_hash.data)
    ; field_no_status "fee" ~typ:(non_null uint64) ~args:[]
        ~doc:
          "Fee that the fee-payer is willing to pay for making the transaction"
        ~resolve:(fun _ cmd ->
          Signed_command.fee cmd.With_hash.data |> Currency.Fee.to_uint64)
    ; field_no_status "memo" ~typ:(non_null string) ~args:[]
        ~doc:
          (sprintf
             "A short message from the sender, encoded with Base58Check, \
              version byte=0x%02X; byte 2 of the decoding is the message \
              length"
             (Char.to_int Base58_check.Version_bytes.user_command_memo))
        ~resolve:(fun _ payment ->
          Signed_command_payload.memo
          @@ Signed_command.payload payment.With_hash.data
          |> Signed_command_memo.to_base58_check)
    ; field_no_status "isDelegation" ~typ:(non_null bool) ~args:[]
        ~doc:"If true, this command represents a delegation of stake"
        ~deprecated:(Deprecated (Some "use kind field instead"))
        ~resolve:(fun _ user_command ->
          match
            Signed_command.Payload.body
            @@ Signed_command.payload user_command.With_hash.data
          with
          | Stake_delegation _ ->
              true
          | _ ->
              false)
    ; field_no_status "from" ~typ:(non_null public_key) ~args:[]
        ~doc:"Public key of the sender"
        ~deprecated:(Deprecated (Some "use feePayer field instead"))
        ~resolve:(fun _ cmd -> Signed_command.fee_payer_pk cmd.With_hash.data)
    ; field_no_status "fromAccount" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account of the sender"
        ~deprecated:(Deprecated (Some "use feePayer field instead"))
        ~resolve:(fun { ctx = coda; _ } payment ->
          AccountObj.get_best_ledger_account coda
          @@ Signed_command.fee_payer payment.With_hash.data)
    ; field_no_status "to" ~typ:(non_null public_key) ~args:[]
        ~doc:"Public key of the receiver"
        ~deprecated:(Deprecated (Some "use receiver field instead"))
        ~resolve:(fun _ cmd -> Signed_command.receiver_pk cmd.With_hash.data)
    ; field_no_status "toAccount"
        ~typ:(non_null AccountObj.account)
        ~doc:"Account of the receiver"
        ~deprecated:(Deprecated (Some "use receiver field instead"))
        ~args:Arg.[]
        ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
          @@ Signed_command.receiver cmd.With_hash.data)
    ; field "failureReason" ~typ:string ~args:[]
        ~doc:
          "null is no failure or status unknown, reason for failure otherwise."
        ~resolve:(fun _ uc ->
          match uc.With_status.status with
          | Applied | Enqueued ->
              None
          | Included_but_failed failures ->
              List.concat failures |> List.hd
              |> Option.map ~f:Transaction_status.Failure.to_string)
    ]

  let payment =
    obj "UserCommandPayment" ~fields:(fun _ -> user_command_shared_fields)

  let mk_payment = add_type user_command_interface payment

  let stake_delegation =
    obj "UserCommandDelegation" ~fields:(fun _ ->
        field_no_status "delegator" ~typ:(non_null AccountObj.account) ~args:[]
          ~resolve:(fun { ctx = coda; _ } cmd ->
            AccountObj.get_best_ledger_account coda
              (Signed_command.source cmd.With_hash.data))
        :: field_no_status "delegatee" ~typ:(non_null AccountObj.account)
             ~args:[] ~resolve:(fun { ctx = coda; _ } cmd ->
               AccountObj.get_best_ledger_account coda
                 (Signed_command.receiver cmd.With_hash.data))
        :: user_command_shared_fields)

  let mk_stake_delegation = add_type user_command_interface stake_delegation

  let mk_user_command
      (cmd : (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t) =
    match
      Signed_command_payload.body @@ Signed_command.payload cmd.data.data
    with
    | Payment _ ->
        mk_payment cmd
    | Stake_delegation _ ->
        mk_stake_delegation cmd

  let user_command = user_command_interface
end

module Zkapp_command = struct
  module With_status = struct
    type 'a t = { data : 'a; status : Command_status.t }

    let map t ~f = { t with data = f t.data }
  end

  let field_no_status ?doc ?deprecated lab ~typ ~args ~resolve =
    field ?doc ?deprecated lab ~typ ~args ~resolve:(fun c cmd ->
        resolve c cmd.With_status.data)

  let zkapp_command =
    let conv (x : (Mina_lib.t, Parties.t) Fields_derivers_graphql.Schema.typ) :
        (Mina_lib.t, Parties.t) typ =
      Obj.magic x
    in
    obj "ZkappCommand" ~fields:(fun _ ->
        [ field_no_status "id"
            ~doc:"A Base58Check string representing the command"
            ~typ:(non_null guid) ~args:[] ~resolve:(fun _ parties ->
              Parties.to_base58_check parties.With_hash.data)
        ; field_no_status "hash"
            ~doc:"A cryptographic hash of the zkApp command"
            ~typ:(non_null string) ~args:[] ~resolve:(fun _ parties ->
              Transaction_hash.to_base58_check parties.With_hash.hash)
        ; field_no_status "parties"
            ~typ:(Parties.typ () |> conv)
            ~args:Arg.[]
            ~doc:"Parties representing the transaction"
            ~resolve:(fun _ parties -> parties.With_hash.data)
        ; field "failureReason" ~typ:(list @@ Command_status.failure_reasons)
            ~args:[]
            ~doc:
              "The reason for the zkApp transaction failure; null means \
               success or the status is unknown" ~resolve:(fun _ cmd ->
              match cmd.With_status.status with
              | Applied | Enqueued ->
                  None
              | Included_but_failed failures ->
                  Some
                    (List.map
                       (Transaction_status.Failure.Collection.to_display
                          failures) ~f:(fun f -> Some f)))
        ])
end

let transactions =
  let open Filtered_external_transition.Transactions in
  obj "Transactions" ~doc:"Different types of transactions in a block"
    ~fields:(fun _ ->
      [ field "userCommands"
          ~doc:
            "List of user commands (payments and stake delegations) included \
             in this block"
          ~typ:(non_null @@ list @@ non_null User_command.user_command)
          ~args:Arg.[]
          ~resolve:(fun _ { commands; _ } ->
            List.filter_map commands ~f:(fun t ->
                match t.data.data with
                | Signed_command c ->
                    let status =
                      match t.status with
                      | Applied ->
                          Command_status.Applied
                      | Failed e ->
                          Command_status.Included_but_failed e
                    in
                    Some
                      (User_command.mk_user_command
                         { status; data = { t.data with data = c } })
                | Parties _ ->
                    None))
      ; field "zkappCommands"
          ~doc:"List of zkApp commands included in this block"
          ~typ:(non_null @@ list @@ non_null Zkapp_command.zkapp_command)
          ~args:Arg.[]
          ~resolve:(fun _ { commands; _ } ->
            List.filter_map commands ~f:(fun t ->
                match t.data.data with
                | Signed_command _ ->
                    None
                | Parties parties ->
                    let status =
                      match t.status with
                      | Applied ->
                          Command_status.Applied
                      | Failed e ->
                          Command_status.Included_but_failed e
                    in
                    Some
                      { Zkapp_command.With_status.status
                      ; data = { t.data with data = parties }
                      }))
      ; field "feeTransfer" ~doc:"List of fee transfers included in this block"
          ~typ:(non_null @@ list @@ non_null fee_transfer)
          ~args:Arg.[]
          ~resolve:(fun _ { fee_transfers; _ } -> fee_transfers)
      ; field "coinbase" ~typ:(non_null uint64)
          ~doc:"Amount of MINA granted to the producer of this block"
          ~args:Arg.[]
          ~resolve:(fun _ { coinbase; _ } -> Currency.Amount.to_uint64 coinbase)
      ; field "coinbaseReceiverAccount" ~typ:AccountObj.account
          ~doc:"Account to which the coinbase for this block was granted"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } { coinbase_receiver; _ } ->
            Option.map
              ~f:(AccountObj.get_best_ledger_account_pk coda)
              coinbase_receiver)
      ])

let protocol_state_proof : (Mina_lib.t, Proof.t option) typ =
  obj "protocolStateProof" ~fields:(fun _ ->
      [ field "base64" ~typ:string ~doc:"Base-64 encoded proof"
          ~args:Arg.[]
          ~resolve:(fun _ proof ->
            (* Use the precomputed block proof encoding, for consistency. *)
            Some (Mina_block.Precomputed.Proof.to_bin_string proof))
      ; field "json" ~typ:json ~doc:"JSON-encoded proof"
          ~args:Arg.[]
          ~resolve:(fun _ proof ->
            Some (Yojson.Safe.to_basic (Proof.to_yojson_full proof)))
      ])

let block :
    ( Mina_lib.t
    , (Filtered_external_transition.t, State_hash.t) With_hash.t option )
    typ =
  let open Filtered_external_transition in
  obj "Block" ~fields:(fun _ ->
      [ field "creator" ~typ:(non_null public_key)
          ~doc:"Public key of account that produced this block"
          ~deprecated:(Deprecated (Some "use creatorAccount field instead"))
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; _ } -> data.creator)
      ; field "creatorAccount"
          ~typ:(non_null AccountObj.account)
          ~doc:"Account that produced this block"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } { With_hash.data; _ } ->
            AccountObj.get_best_ledger_account_pk coda data.creator)
      ; field "winnerAccount"
          ~typ:(non_null AccountObj.account)
          ~doc:"Account that won the slot (Delegator/Staker)"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } { With_hash.data; _ } ->
            AccountObj.get_best_ledger_account_pk coda data.winner)
      ; field "stateHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the state after this block"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.hash; _ } ->
            State_hash.to_base58_check hash)
      ; field "stateHashField" ~typ:(non_null string)
          ~doc:"Experimental: Bigint field-element representation of stateHash"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.hash; _ } ->
            State_hash.to_decimal_string hash)
      ; field "protocolState" ~typ:(non_null protocol_state)
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; With_hash.hash; _ } ->
            (data.protocol_state, hash))
      ; field "protocolStateProof"
          ~typ:(non_null protocol_state_proof)
          ~doc:"Snark proof of blockchain state"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; _ } -> data.proof)
      ; field "transactions" ~typ:(non_null transactions)
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; _ } -> data.transactions)
      ; field "commandTransactionCount" ~typ:(non_null int)
          ~doc:"Count of user command transactions in the block"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; _ } ->
            List.length data.transactions.commands)
      ; field "snarkJobs"
          ~typ:(non_null @@ list @@ non_null completed_work)
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; _ } -> data.snark_jobs)
      ])

let snark_worker =
  obj "SnarkWorker" ~fields:(fun _ ->
      [ field "key" ~typ:(non_null public_key)
          ~doc:"Public key of current snark worker"
          ~deprecated:(Deprecated (Some "use account field instead"))
          ~args:Arg.[]
          ~resolve:(fun (_ : Mina_lib.t resolve_info) (key, _) -> key)
      ; field "account"
          ~typ:(non_null AccountObj.account)
          ~doc:"Account of the current snark worker"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } (key, _) ->
            AccountObj.get_best_ledger_account_pk coda key)
      ; field "fee" ~typ:(non_null uint64)
          ~doc:"Fee that snark worker is charging to generate a snark proof"
          ~args:Arg.[]
          ~resolve:(fun (_ : Mina_lib.t resolve_info) (_, fee) ->
            Currency.Fee.to_uint64 fee)
      ])

module Arguments = struct
  let ip_address ~name ip_addr =
    result_of_exn Unix.Inet_addr.of_string ip_addr
      ~error:(sprintf !"%s is not valid." name)
end

module Input = struct
  open Wrapper.Arg

  let peer :
      ( (Network_peer.Peer.t, string) result option
      , Network_peer.Peer.t option )
      arg_typ =
    obj "NetworkPeer"
      ~doc:"Network identifiers for another protocol participant"
      ~coerce:(fun peer_id host libp2p_port ->
        try
          Ok
            Network_peer.Peer.
              { peer_id; host = Unix.Inet_addr.of_string host; libp2p_port }
        with _ -> Error "Invalid format for NetworkPeer.host")
      ~fields:
        [ arg "peerId" ~doc:"base58-encoded peer ID" ~typ:(non_null string)
        ; arg "host" ~doc:"IP address of the remote host" ~typ:(non_null string)
        ; arg "libp2pPort" ~typ:(non_null int)
        ]
      ~to_string:(fun f (p : Network_peer.Peer.t) ->
        f p.peer_id (Unix.Inet_addr.to_string p.host) p.libp2p_port)
      ~to_json:(fun f (p : Network_peer.Peer.t) ->
        f p.peer_id (Unix.Inet_addr.to_string p.host) p.libp2p_port)

  let public_key_arg =
    scalar "PublicKey" ~doc:"Public key in Base58Check format"
      ~coerce:(fun pk ->
        match pk with
        | `String s ->
            Result.map_error
              (Public_key.Compressed.of_base58_check s)
              ~f:Error.to_string_hum
        | _ ->
            Error "Expected public key as a string in Base58Check format")
      ~to_string:Public_key.Compressed.to_base58_check
      ~to_json:(function
        | k -> `String (Public_key.Compressed.to_base58_check k))

  let private_key_arg =
    scalar "PrivateKey" ~doc:"Base58Check-encoded private key"
      ~coerce:Signature_lib.Private_key.of_yojson
      ~to_string:(fun k ->
        Yojson.Basic.to_string (Signature_lib.Private_key.to_yojson k))
      ~to_json:Signature_lib.Private_key.to_yojson

  let token_id_arg =
    scalar "TokenId" ~doc:"String representation of a token's UInt64 identifier"
      ~coerce:(fun token ->
        try
          match token with
          | `String token ->
              Ok (Token_id.of_string token)
          | _ ->
              Error "Invalid format for token."
        with _ -> Error "Invalid format for token.")
      ~to_string:Token_id.to_string
      ~to_json:(function i -> `String (Token_id.to_string i))

  let sign =
    enum "Sign"
      ~values:
        [ enum_value "PLUS" ~value:Sgn.Pos; enum_value "MINUS" ~value:Sgn.Neg ]

  (* let field = *)
  (*   scalar "Field" *)
  (*     ~coerce:(fun field -> *)
  (*       match field with *)
  (*       | `String s -> *)
  (*           Ok (Snark_params.Tick.Field.of_string s) *)
  (*       | _ -> *)
  (*           Error "Expected a string representing a field element") *)
  (*     ~to_string:Snark_params.Tick.Field.to_string *)

  (* let nonce = *)
  (*   scalar "Nonce" *)
  (*     ~coerce:(fun nonce -> *)
  (*       (\* of_string might raise *\) *)
  (*       try *)
  (*         match nonce with *)
  (*         | `String s -> *)
  (*             (\* a nonce is a uint32, GraphQL ints are signed int32, so use string *\) *)
  (*             Ok (Mina_base.Account.Nonce.of_string s) *)
  (*         | _ -> *)
  (*             Error "Expected string for nonce" *)
  (*       with exn -> Error (Exn.to_string exn)) *)
  (*     ~to_string:Mina_base.Account.Nonce.to_string *)

  (* let snarked_ledger_hash = *)
  (*   scalar "SnarkedLedgerHash" *)
  (*     ~coerce:(fun hash -> *)
  (*       match hash with *)
  (*       | `String s -> *)
  (*           Result.map_error *)
  (*             (Frozen_ledger_hash.of_base58_check s) *)
  (*             ~f:Error.to_string_hum *)
  (*       | _ -> *)
  (*           Error "Expected snarked ledger hash in Base58Check format") *)
  (*     ~to_string:Frozen_ledger_hash.to_base58_check *)

  (* let block_time = *)
  (*   scalar "BlockTime" *)
  (*     ~coerce:(fun block_time -> *)
  (*       match block_time with *)
  (*       | `String s -> ( *)
  (*           try *)
  (*             (\* a block time is a uint64, GraphQL ints are signed int32, so use string *\) *)
  (*             (\* of_string might raise *\) *)
  (*             Ok (Block_time.of_string_exn s) *)
  (*           with exn -> Error (Exn.to_string exn) ) *)
  (*       | _ -> *)
  (*           Error "Expected string for block time") *)
  (*     ~to_string:Block_time.to_string *)

  (* let length = *)
  (*   scalar "Length" *)
  (*     ~coerce:(fun length -> *)
  (*       (\* of_string might raise *\) *)
  (*       match length with *)
  (*       | `String s -> ( *)
  (*           try *)
  (*             (\* a length is a uint32, GraphQL ints are signed int32, so use string *\) *)
  (*             Ok (Mina_numbers.Length.of_string s) *)
  (*           with exn -> Error (Exn.to_string exn) ) *)
  (*       | _ -> *)
  (*           Error "Expected string for length") *)
  (*     ~to_string:Mina_numbers.Length.to_string *)

  (* let currency_amount = *)
  (*   scalar "CurrencyAmount" *)
  (*     ~coerce:(fun amt -> *)
  (*       match amt with *)
  (*       | `String s -> ( *)
  (*           try Ok (Currency.Amount.of_string s) *)
  (*           with exn -> Error (Exn.to_string exn) ) *)
  (*       | _ -> *)
  (*           Error "Expected string for currency amount") *)
  (*     ~to_string:Currency.Amount.to_string *)

  (* let fee = *)
  (*   scalar "Fee" *)
  (*     ~coerce:(fun fee -> *)
  (*       match fee with *)
  (*       | `String s -> ( *)
  (*           try Ok (Currency.Fee.of_string s) *)
  (*           with exn -> Error (Exn.to_string exn) ) *)
  (*       | _ -> *)
  (*           Error "Expected string for fee") *)
  (*     ~to_string:Currency.Fee.to_string *)

  let internal_send_zkapp =
    scalar "SendTestZkappInput" ~doc:"Parties for a test zkApp"
      ~coerce:(fun json ->
        let json = to_yojson json in
        Result.try_with (fun () -> Mina_base.Parties.of_json json)
        |> Result.map_error ~f:(fun ex -> Exn.to_string ex))
      ~to_string:(fun x -> Yojson.Safe.to_string (Mina_base.Parties.to_json x))
      ~to_json:(fun x -> Yojson.Safe.to_basic @@ Mina_base.Parties.to_json x)

  let precomputed_block =
    scalar "PrecomputedBlock" ~doc:"Block encoded in precomputed block format"
      ~coerce:(fun json ->
        let json = to_yojson json in
        Mina_block.Precomputed.of_yojson json)
      ~to_string:(fun x ->
        Yojson.Safe.to_string (Mina_block.Precomputed.to_yojson x))
      ~to_json:(fun x ->
        Yojson.Safe.to_basic @@ Mina_block.Precomputed.to_yojson x)

  let extensional_block =
    scalar "ExtensionalBlock" ~doc:"Block encoded in extensional block format"
      ~coerce:(fun json ->
        let json = to_yojson json in
        Archive_lib.Extensional.Block.of_yojson json)
      ~to_string:(fun x ->
        Yojson.Safe.to_string (Archive_lib.Extensional.Block.to_yojson x))
      ~to_json:(fun x ->
        Yojson.Safe.to_basic @@ Archive_lib.Extensional.Block.to_yojson x)

  module type Numeric_type = sig
    type t

    val to_string : t -> string

    val of_string : string -> t

    val of_int : int -> t
  end

  (** Converts a type into a graphql argument type. Expect name to start with uppercase    *)
  let make_numeric_arg (type t) ~name
      (module Numeric : Numeric_type with type t = t) =
    let lower_name = String.lowercase name in
    scalar name
      ~doc:
        (sprintf
           "String or Integer representation of a %s number. If the input is a \
            string, it must represent the number in base 10"
           lower_name)
      ~to_string:Numeric.to_string
      ~to_json:(fun n -> `String (Numeric.to_string n))
      ~coerce:(fun key ->
        match key with
        | `String s -> (
            try
              let n = Numeric.of_string s in
              let s' = Numeric.to_string n in
              (* Here, we check that the string that was passed converts to
                 the numeric type, and that it is in range, by converting
                 back to a string and checking that it is equal to the one
                 passed. This prevents the following weirdnesses in the
                 [Unsigned.UInt*] parsers:
                 * if the absolute value is greater than [max_int], the value
                 returned is [max_int]
                 - ["99999999999999999999999999999999999"] is [max_int]
                 - ["-99999999999999999999999999999999999"] is [max_int]
                 * if otherwise the value is negative, the value returned is
                 [max_int - (x - 1)]
                 - ["-1"] is [max_int]
                 * if there is a non-numeric character part-way through the
                 string, the numeric prefix is treated as a number
                 - ["1_000_000"] is [1]
                 - ["-1_000_000"] is [max_int]
                 - ["1.1"] is [1]
                 - ["0x15"] is [0]
                 * leading spaces are ignored
                 - [" 1"] is [1]
                 This is annoying to document, none of these behaviors are
                 useful to users, and unexpectedly triggering one of them
                 could have nasty consequences. Thus, we raise an error
                 rather than silently misinterpreting their input.
              *)
              assert (String.equal s s') ;
              Ok n
              (* TODO: We need a better error message to the user here *)
            with _ -> Error (sprintf "Could not decode %s." lower_name) )
        | `Int n ->
            if n < 0 then
              Error
                (sprintf "Could not convert negative number to %s." lower_name)
            else Ok (Numeric.of_int n)
        | _ ->
            Error (sprintf "Invalid format for %s type." lower_name))

  let uint64_arg = make_numeric_arg ~name:"UInt64" (module Unsigned.UInt64)

  let uint32_arg = make_numeric_arg ~name:"UInt32" (module Unsigned.UInt32)

  let signature_arg =
    obj "SignatureInput"
      ~coerce:(fun field scalar rawSignature ->
        let open Snark_params.Tick in
        match rawSignature with
        | Some signature ->
            Result.of_option
              (Signature.Raw.decode signature)
              ~error:"rawSignature decoding error"
        | None -> (
            match (field, scalar) with
            | Some field, Some scalar ->
                Ok (Field.of_string field, Inner_curve.Scalar.of_string scalar)
            | _ ->
                Error "Either field+scalar or rawSignature must by non-null" ))
      ~doc:
        "A cryptographic signature -- you must provide either field+scalar or \
         rawSignature"
      ~fields:
        [ arg "field" ~typ:string ~doc:"Field component of signature"
        ; arg "scalar" ~typ:string ~doc:"Scalar component of signature"
        ; arg "rawSignature" ~typ:string ~doc:"Raw encoded signature"
        ]
      ~to_string:(fun f (s : Signature.t) ->
        f None None (Some (Signature.Raw.encode s)))
      ~to_json:(fun f (s : Signature.t) ->
        f None None (Some (Signature.Raw.encode s)))

  let vrf_message =
    obj "VrfMessageInput" ~doc:"The inputs to a vrf evaluation"
      ~coerce:(fun global_slot epoch_seed delegator_index ->
        { Consensus_vrf.Layout.Message.global_slot
        ; epoch_seed = Mina_base.Epoch_seed.of_base58_check_exn epoch_seed
        ; delegator_index
        })
      ~fields:
        [ arg "globalSlot" ~typ:(non_null uint32_arg)
        ; arg "epochSeed" ~doc:"Formatted with base58check"
            ~typ:(non_null string)
        ; arg "delegatorIndex"
            ~doc:"Position in the ledger of the delegator's account"
            ~typ:(non_null int)
        ]
      ~to_string:(fun f (t : Consensus_vrf.Layout.Message.t) ->
        f t.global_slot
          (Mina_base.Epoch_seed.to_base58_check t.epoch_seed)
          t.delegator_index)
      ~to_json:(fun f (t : Consensus_vrf.Layout.Message.t) ->
        f t.global_slot
          (Mina_base.Epoch_seed.to_base58_check t.epoch_seed)
          t.delegator_index)

  let vrf_threshold =
    obj "VrfThresholdInput"
      ~doc:
        "The amount of stake delegated, used to determine the threshold for a \
         vrf evaluation producing a block"
      ~coerce:(fun delegated_stake total_stake ->
        { Consensus_vrf.Layout.Threshold.delegated_stake =
            Currency.Balance.of_uint64 delegated_stake
        ; total_stake = Currency.Amount.of_uint64 total_stake
        })
      ~fields:
        [ arg "delegatedStake"
            ~doc:
              "The amount of stake delegated to the vrf evaluator by the \
               delegating account. This should match the amount in the epoch's \
               staking ledger, which may be different to the amount in the \
               current ledger."
            ~typ:(non_null uint64_arg)
        ; arg "totalStake"
            ~doc:
              "The total amount of stake across all accounts in the epoch's \
               staking ledger."
            ~typ:(non_null uint64_arg)
        ]
      ~to_string:(fun f (t : Consensus_vrf.Layout.Threshold.t) ->
        f
          (Currency.Balance.to_uint64 t.delegated_stake)
          (Currency.Amount.to_uint64 t.total_stake))
      ~to_json:(fun f (t : Consensus_vrf.Layout.Threshold.t) ->
        f
          (Currency.Balance.to_uint64 t.delegated_stake)
          (Currency.Amount.to_uint64 t.total_stake))

  let vrf_evaluation =
    obj "VrfEvaluationInput" ~doc:"The witness to a vrf evaluation"
      ~coerce:(fun message public_key c s scaled_message_hash vrf_threshold ->
        { Consensus_vrf.Layout.Evaluation.message
        ; public_key = Public_key.decompress_exn public_key
        ; c = Snark_params.Tick.Inner_curve.Scalar.of_string c
        ; s = Snark_params.Tick.Inner_curve.Scalar.of_string s
        ; scaled_message_hash =
            Consensus_vrf.Group.of_string_list_exn scaled_message_hash
        ; vrf_threshold
        ; vrf_output = None
        ; vrf_output_fractional = None
        ; threshold_met = None
        })
      ~fields:
        [ arg "message" ~typ:(non_null vrf_message)
        ; arg "publicKey" ~typ:(non_null public_key_arg)
        ; arg "c" ~typ:(non_null string)
        ; arg "s" ~typ:(non_null string)
        ; arg "scaledMessageHash" ~typ:(non_null (list (non_null string)))
        ; arg "vrfThreshold" ~typ:vrf_threshold
        ]
      ~to_string:(fun f (x : Consensus_vrf.Layout.Evaluation.t) ->
        f x.message
          (Public_key.compress x.public_key)
          (Snark_params.Tick.Inner_curve.Scalar.to_string x.c)
          (Snark_params.Tick.Inner_curve.Scalar.to_string x.s)
          (Consensus_vrf.Group.to_string_list_exn x.scaled_message_hash)
          x.vrf_threshold)
      ~to_json:(fun f (x : Consensus_vrf.Layout.Evaluation.t) ->
        f x.message
          (Public_key.compress x.public_key)
          (Snark_params.Tick.Inner_curve.Scalar.to_string x.c)
          (Snark_params.Tick.Inner_curve.Scalar.to_string x.s)
          (Consensus_vrf.Group.to_string_list_exn x.scaled_message_hash)
          x.vrf_threshold)

  module Fields = struct
    let from ~doc = arg "from" ~typ:(non_null public_key_arg) ~doc

    let to_ ~doc = arg "to" ~typ:(non_null public_key_arg) ~doc

    let token ~doc = arg "token" ~typ:(non_null token_id_arg) ~doc

    let token_opt ~doc = arg "token" ~typ:token_id_arg ~doc

    let token_owner ~doc = arg "tokenOwner" ~typ:(non_null public_key_arg) ~doc

    let receiver ~doc = arg "receiver" ~typ:(non_null public_key_arg) ~doc

    let receiver_opt ~doc = arg "receiver" ~typ:public_key_arg ~doc

    let fee_payer_opt ~doc = arg "feePayer" ~typ:public_key_arg ~doc

    let fee ~doc = arg "fee" ~typ:(non_null uint64_arg) ~doc

    let amount ~doc = arg "amount" ~typ:(non_null uint64_arg) ~doc

    let memo =
      arg "memo" ~typ:string
        ~doc:"Short arbitrary message provided by the sender"

    let valid_until =
      arg "validUntil" ~typ:uint32_arg
        ~doc:
          "The global slot since genesis after which this transaction cannot \
           be applied"

    let nonce =
      arg "nonce" ~typ:uint32_arg
        ~doc:
          "Should only be set when cancelling transactions, otherwise a nonce \
           is determined automatically"

    let signature =
      arg "signature" ~typ:signature_arg
        ~doc:
          "If a signature is provided, this transaction is considered signed \
           and will be broadcasted to the network without requiring a private \
           key"

    let senders =
      arg "senders"
        ~typ:(non_null (list (non_null private_key_arg)))
        ~doc:"The private keys from which to sign the payments"

    let repeat_count =
      arg "repeat_count" ~typ:(non_null uint32_arg)
        ~doc:"How many times shall transaction be repeated"

    let repeat_delay_ms =
      arg "repeat_delay_ms" ~typ:(non_null uint32_arg)
        ~doc:"Delay with which a transaction shall be repeated"
  end

  type send_payment_input =
    { from : (Epoch_seed.t, bool) Public_key.Compressed.Poly.t
    ; to_ : Account.key
    ; amount : Currency.Amount.t
    ; (* fee: uint64; *)
      fee : Currency.Fee.t
    ; valid_until : Unsigned.uint32 option
    ; memo : string option
    ; nonce : Unsigned.uint32 option
    }

  let send_payment =
    let open Fields in
    obj "SendPaymentInput"
      ~coerce:(fun from to_ amount fee valid_until memo nonce ->
        (from, to_, amount, fee, valid_until, memo, nonce))
      ~fields:
        [ from ~doc:"Public key of sender of payment"
        ; to_ ~doc:"Public key of recipient of payment"
        ; amount ~doc:"Amount of MINA to send to receiver"
        ; fee ~doc:"Fee amount in order to send payment"
        ; valid_until
        ; memo
        ; nonce
        ]
      ~to_string:(fun f x ->
        f x.from x.to_
          (Currency.Amount.to_uint64 x.amount)
          (Currency.Fee.to_uint64 x.fee)
          x.valid_until x.memo x.nonce)
      ~to_json:(fun f x ->
        f x.from x.to_
          (Currency.Amount.to_uint64 x.amount)
          (Currency.Fee.to_uint64 x.fee)
          x.valid_until x.memo x.nonce)

  let send_zkapp =
    let conv (x : Parties.t Fields_derivers_graphql.Schema.Arg.arg_typ) :
        Parties.t Schema.Arg.arg_typ =
      Obj.magic x
    in
    let my_arg_typ =
      { typ = Parties.arg_typ () |> conv
      ; to_string = Parties.arg_query_string
      ; to_json =
          (function x -> Yojson.Safe.to_basic @@ Parties.parties_to_json x)
      }
    in
    obj "SendZkappInput" ~coerce:Fn.id
      ~fields:
        [ arg "parties" ~doc:"Parties structure representing the transaction"
            ~typ:my_arg_typ
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let send_delegation =
    let open Fields in
    obj "SendDelegationInput"
      ~coerce:(fun from to_ fee valid_until memo nonce ->
        (from, to_, fee, valid_until, memo, nonce))
      ~fields:
        [ from ~doc:"Public key of sender of a stake delegation"
        ; to_ ~doc:"Public key of the account being delegated to"
        ; fee ~doc:"Fee amount in order to send a stake delegation"
        ; valid_until
        ; memo
        ; nonce
        ]
      ~to_string:(fun f (x1, x2, x3, x4, x5, x6) -> f x1 x2 x3 x4 x5 x6)
      ~to_json:(fun f (x1, x2, x3, x4, x5, x6) -> f x1 x2 x3 x4 x5 x6)

  let rosetta_transaction =
    Arg.scalar "RosettaTransaction"
      ~doc:"A transaction encoded in the Rosetta format"
      ~coerce:(fun graphql_json ->
        Rosetta_lib.Transaction.to_mina_signed (to_yojson graphql_json)
        |> Result.map_error ~f:Error.to_string_hum)
      ~to_string:(function
        | (x : Signed_command.t) ->
            Yojson.Safe.to_string (Signed_command.to_yojson x))
      ~to_json:(function
        | x -> Yojson.Safe.to_basic @@ Signed_command.to_yojson x)

  let create_account =
    obj "AddAccountInput" ~coerce:Fn.id
      ~fields:
        [ arg "password" ~doc:"Password used to encrypt the new account"
            ~typ:(non_null string)
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let unlock_account =
    obj "UnlockInput"
      ~coerce:(fun password pk -> (password, pk))
      ~fields:
        [ arg "password" ~doc:"Password for the account to be unlocked"
            ~typ:(non_null string)
        ; arg "publicKey" ~doc:"Public key specifying which account to unlock"
            ~typ:(non_null public_key_arg)
        ]
      ~to_string:(fun f (password, pk) -> f (Bytes.to_string password) pk)
      ~to_json:(fun f (password, pk) -> f (Bytes.to_string password) pk)

  let create_hd_account =
    obj "CreateHDAccountInput" ~coerce:Fn.id
      ~fields:
        [ arg "index" ~doc:"Index of the account in hardware wallet"
            ~typ:(non_null uint32_arg)
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let lock_account =
    obj "LockInput" ~coerce:Fn.id
      ~fields:
        [ arg "publicKey" ~doc:"Public key specifying which account to lock"
            ~typ:(non_null public_key_arg)
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let delete_account =
    obj "DeleteAccountInput" ~coerce:Fn.id
      ~fields:
        [ arg "publicKey" ~doc:"Public key of account to be deleted"
            ~typ:(non_null public_key_arg)
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let reset_trust_status =
    obj "ResetTrustStatusInput" ~coerce:Fn.id
      ~fields:[ arg "ipAddress" ~typ:(non_null string) ]
      ~to_string:Fn.id ~to_json:Fn.id

  (* TODO: Treat cases where filter_input has a null argument *)
  let block_filter_input =
    obj "BlockFilterInput" ~coerce:Fn.id
      ~fields:
        [ arg "relatedTo"
            ~doc:
              "A public key of a user who has their\n\
              \        transaction in the block, or produced the block"
            ~typ:(non_null public_key_arg)
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let user_command_filter_input =
    obj "UserCommandFilterType" ~coerce:Fn.id
      ~fields:
        [ arg "toOrFrom"
            ~doc:
              "Public key of sender or receiver of transactions you are \
               looking for"
            ~typ:(non_null public_key_arg)
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let set_coinbase_receiver =
    obj "SetCoinbaseReceiverInput" ~coerce:Fn.id
      ~fields:
        [ arg "publicKey" ~typ:public_key_arg
            ~doc:
              "Public key of the account to receive coinbases. Block \
               production keys will receive the coinbases if none is given"
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  let set_snark_work_fee =
    obj "SetSnarkWorkFee"
      ~fields:[ Fields.fee ~doc:"Fee to get rewarded for producing snark work" ]
      ~coerce:Fn.id ~to_string:Fn.id ~to_json:Fn.id

  let set_snark_worker =
    obj "SetSnarkWorkerInput" ~coerce:Fn.id
      ~fields:
        [ arg "publicKey" ~typ:public_key_arg
            ~doc:
              "Public key you wish to start snark-working on; null to stop \
               doing any snark work"
        ]
      ~to_string:Fn.id ~to_json:Fn.id

  module AddPaymentReceipt = struct
    type t = { payment : string; added_time : string }

    let typ =
      obj "AddPaymentReceiptInput"
        ~coerce:(fun payment added_time -> { payment; added_time })
        ~fields:
          [ arg "payment"
              ~doc:(Doc.bin_prot "Serialized payment")
              ~typ:(non_null string)
          ; (* TODO: create a formal method for verifying that the provided added_time is correct  *)
            arg "added_time" ~typ:(non_null string)
              ~doc:
                (Doc.date
                   "Time that a payment gets added to another clients \
                    transaction database")
          ]
        ~to_string:(fun f (t : t) -> f t.payment t.added_time)
        ~to_json:(fun f (t : t) -> f t.payment t.added_time)
  end

  let set_connection_gating_config =
    obj "SetConnectionGatingConfigInput"
      ~coerce:(fun trusted_peers banned_peers isolate ->
        let open Result.Let_syntax in
        let%bind trusted_peers = Result.all trusted_peers in
        let%map banned_peers = Result.all banned_peers in
        Mina_net2.{ isolate; trusted_peers; banned_peers })
      ~fields:
        Arg.
          [ arg "trustedPeers"
              ~typ:(non_null (list (non_null peer)))
              ~doc:"Peers we will always allow connections from"
          ; arg "bannedPeers"
              ~typ:(non_null (list (non_null peer)))
              ~doc:
                "Peers we will never allow connections from (unless they are \
                 also trusted!)"
          ; arg "isolate" ~typ:(non_null bool)
              ~doc:
                "If true, no connections will be allowed unless they are from \
                 a trusted peer"
          ]
      ~to_string:(fun f (t : Mina_net2.connection_gating) ->
        f t.trusted_peers t.banned_peers t.isolate)
      ~to_json:(fun f (t : Mina_net2.connection_gating) ->
        f t.trusted_peers t.banned_peers t.isolate)

  module Encoders = struct
    (** This module exposes the toplevel converters to be used by graphql-ppx *)
    let json_of_NetworkPeer = peer.to_json
    let json_of_PublicKey = public_key_arg.to_json
    let json_of_PrivateKey = private_key_arg.to_json
    let json_of_TokenId = token_id_arg.to_json
    let json_of_UInt32 = uint32_arg.to_json
    let json_of_UInt64 = uint64_arg.to_json
    (* let json_of_Field = field.to_json *)
    (* let json_of_Nonce = nonce.to_json *)
    (* let json_of_SnarkedLedgerHash = snarked_ledger_hash.to_json *)
    (* let json_of_BlockTime = block_time.to_json *)
    (* let json_of_Length = length.to_json *)
    (* let json_of_CurrencyAmount = currency_amount.to_json *)
    (* let json_of_Fee = fee.to_json *)
    let json_of_SendTestZkappInput = internal_send_zkapp.to_json
    let json_of_PrecomputedBlock = precomputed_block.to_json

    let json_of_ExtensionalBlock = extensional_block.to_json

    let json_of_SignatureInput = signature_arg.to_json

    let json_of_VrfMessageInput = vrf_message.to_json

    let json_of_VrfThresholdInput = vrf_threshold.to_json

    let  json_of_VrfEvaluationInput = vrf_evaluation.to_json

    let json_of_SendPaymentInput = send_payment.to_json

    let json_of_SendZkappInput = send_zkapp.to_json

    let json_of_SendDelegationInput = send_delegation.to_json

    let json_of_RosettaTransaction = rosetta_transaction.to_json

    let json_of_AddAccountInput = create_account.to_json

    let json_of_UnlockInput = unlock_account.to_json

    let json_of_CreateHDAccountInput  = create_hd_account.to_json

    let json_of_LockInput = lock_account.to_json

    let json_of_DeleteAccountInput = delete_account.to_json

    let json_of_ResetTrustStatusInput = reset_trust_status.to_json

    let json_of_BlockFilterInput = block_filter_input.to_json

    let json_of_UserCommandFilterType = user_command_filter_input.to_json

    let json_of_SetCoinbaseReceiverInput = set_coinbase_receiver.to_json

    let json_of_SetSnarkWorkFee = set_snark_work_fee.to_json
    let json_of_SetSnarkWorkerInput = set_snark_worker.to_json
    let json_of_AddPaymentReceiptInput = AddPaymentReceipt.typ.to_json
    let json_of_SetConnectionGatingConfigInput = set_connection_gating_config.to_json
  end
end

let vrf_message : ('context, Consensus_vrf.Layout.Message.t option) typ =
  let open Consensus_vrf.Layout.Message in
  obj "VrfMessage" ~doc:"The inputs to a vrf evaluation" ~fields:(fun _ ->
      [ field "globalSlot" ~typ:(non_null uint32)
          ~args:Arg.[]
          ~resolve:(fun _ { global_slot; _ } -> global_slot)
      ; field "epochSeed" ~typ:(non_null epoch_seed)
          ~args:Arg.[]
          ~resolve:(fun _ { epoch_seed; _ } -> epoch_seed)
      ; field "delegatorIndex"
          ~doc:"Position in the ledger of the delegator's account"
          ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ { delegator_index; _ } -> delegator_index)
      ])

let vrf_threshold =
  obj "VrfThreshold"
    ~doc:
      "The amount of stake delegated, used to determine the threshold for a \
       vrf evaluation winning a slot" ~fields:(fun _ ->
      [ field "delegatedStake"
          ~doc:
            "The amount of stake delegated to the vrf evaluator by the \
             delegating account. This should match the amount in the epoch's \
             staking ledger, which may be different to the amount in the \
             current ledger." ~args:[] ~typ:(non_null uint64)
          ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.delegated_stake; _ }
                   -> Currency.Balance.to_uint64 delegated_stake)
      ; field "totalStake"
          ~doc:
            "The total amount of stake across all accounts in the epoch's \
             staking ledger." ~args:[] ~typ:(non_null uint64)
          ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.total_stake; _ } ->
            Currency.Amount.to_uint64 total_stake)
      ])

let vrf_evaluation : ('context, Consensus_vrf.Layout.Evaluation.t option) typ =
  let open Consensus_vrf.Layout.Evaluation in
  obj "VrfEvaluation"
    ~doc:"A witness to a vrf evaluation, which may be externally verified"
    ~fields:(fun _ ->
      [ field "message" ~typ:(non_null vrf_message)
          ~args:Arg.[]
          ~resolve:(fun _ { message; _ } -> message)
      ; field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ { public_key; _ } -> Public_key.compress public_key)
      ; field "c" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ { c; _ } -> Consensus_vrf.Scalar.to_string c)
      ; field "s" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ { s; _ } -> Consensus_vrf.Scalar.to_string s)
      ; field "scaledMessageHash"
          ~typ:(non_null (list (non_null string)))
          ~doc:"A group element represented as 2 field elements"
          ~args:Arg.[]
          ~resolve:(fun _ { scaled_message_hash; _ } ->
            Consensus_vrf.Group.to_string_list_exn scaled_message_hash)
      ; field "vrfThreshold" ~typ:vrf_threshold
          ~args:Arg.[]
          ~resolve:(fun _ { vrf_threshold; _ } -> vrf_threshold)
      ; field "vrfOutput" ~typ:string
          ~doc:
            "The vrf output derived from the evaluation witness. If null, the \
             vrf witness was invalid."
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } t ->
            let vrf_opt =
              match t.vrf_output with
              | Some vrf ->
                  Some (Consensus_vrf.Output.Truncated.to_base58_check vrf)
              | None ->
                  let constraint_constants =
                    (Mina_lib.config mina).precomputed_values
                      .constraint_constants
                  in
                  to_vrf ~constraint_constants t
                  |> Option.map ~f:Consensus_vrf.Output.truncate
            in
            Option.map ~f:Consensus_vrf.Output.Truncated.to_base58_check vrf_opt)
      ; field "vrfOutputFractional" ~typ:float
          ~doc:
            "The vrf output derived from the evaluation witness, as a \
             fraction. This represents a won slot if vrfOutputFractional <= (1 \
             - (1 / 4)^(delegated_balance / total_stake)). If null, the vrf \
             witness was invalid."
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } t ->
            match t.vrf_output_fractional with
            | Some f ->
                Some f
            | None ->
                let vrf_opt =
                  match t.vrf_output with
                  | Some vrf ->
                      Some vrf
                  | None ->
                      let constraint_constants =
                        (Mina_lib.config mina).precomputed_values
                          .constraint_constants
                      in
                      to_vrf ~constraint_constants t
                      |> Option.map ~f:Consensus_vrf.Output.truncate
                in
                Option.map
                  ~f:(fun vrf ->
                    Consensus_vrf.Output.Truncated.to_fraction vrf
                    |> Bignum.to_float)
                  vrf_opt)
      ; field "thresholdMet" ~typ:bool
          ~doc:"Whether the threshold to produce a block was met, if specified"
          ~args:
            Arg.
              [ arg "input" ~doc:"Override for delegation threshold"
                  ~typ:Input.vrf_threshold
              ]
          ~resolve:(fun { ctx = mina; _ } t input ->
            match input with
            | Some { delegated_stake; total_stake } ->
                let constraint_constants =
                  (Mina_lib.config mina).precomputed_values.constraint_constants
                in
                (Consensus_vrf.Layout.Evaluation.compute_vrf
                   ~constraint_constants t ~delegated_stake ~total_stake)
                  .threshold_met
            | None ->
                t.threshold_met)
      ])
