open Core
open Async
open Mina_base
open Mina_transaction
module Ledger = Mina_ledger.Ledger
open Signature_lib
open Currency
open Schema
module Scalars = Graphql_lib.Scalars

let private_key : (Mina_lib.t, Scalars.PrivateKey.t option) typ =
  Scalars.PrivateKey.typ ()

let public_key = Scalars.PublicKey.typ ()

let uint16 = Scalars.UInt16.typ ()

let uint32 = Scalars.UInt32.typ ()

let token_id = Scalars.TokenId.typ ()

let json = Scalars.JSON.typ ()

let epoch_seed = Scalars.EpochSeed.typ ()

let balance = Scalars.Balance.typ ()

let amount = Scalars.Amount.typ ()

let fee = Scalars.Fee.typ ()

let block_time = Scalars.BlockTime.typ ()

let global_slot_since_genesis = Scalars.GlobalSlotSinceGenesis.typ ()

(* type annotation required because we're not using this yet *)
let global_slot_since_hard_fork :
    (Mina_lib.t, Scalars.GlobalSlotSinceHardFork.t option) typ =
  Scalars.GlobalSlotSinceHardFork.typ ()

let global_slot_span = Scalars.GlobalSlotSpan.typ ()

let length = Scalars.Length.typ ()

let span = Scalars.Span.typ ()

let ledger_hash = Scalars.LedgerHash.typ ()

let state_hash = Scalars.StateHash.typ ()

let account_nonce = Scalars.AccountNonce.typ ()

let chain_hash = Scalars.ChainHash.typ ()

let transaction_hash = Scalars.TransactionHash.typ ()

let transaction_id = Scalars.TransactionId.typ ()

let precomputed_block_proof = Scalars.PrecomputedBlockProof.typ ()

let account_id : (Mina_lib.t, Account_id.t option) typ =
  obj "AccountId" ~fields:(fun _ ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ id -> Mina_base.Account_id.public_key id)
      ; field "tokenId" ~typ:(non_null token_id)
          ~args:Arg.[]
          ~resolve:(fun _ id -> Mina_base.Account_id.token_id id)
      ] )

let sync_status : (Mina_lib.t, Sync_status.t option) typ =
  enum "SyncStatus" ~doc:"Sync status of daemon"
    ~values:
      (List.map Sync_status.all ~f:(fun status ->
           enum_value
             (String.map ~f:Char.uppercase @@ Sync_status.to_string status)
             ~value:status ) )

let transaction_status :
    (Mina_lib.t, Transaction_inclusion_status.State.t option) typ =
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
      ; field "globalSlot"
          ~typ:(non_null global_slot_since_hard_fork)
          ~args:Arg.[]
          ~resolve:(fun _ (global_slot : Consensus.Data.Consensus_time.t) ->
            C.to_global_slot global_slot )
      ; field "startTime" ~typ:(non_null block_time)
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } global_slot ->
            let constants =
              (Mina_lib.config mina).precomputed_values.consensus_constants
            in
            C.start_time ~constants global_slot )
      ; field "endTime" ~typ:(non_null block_time)
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } global_slot ->
            let constants =
              (Mina_lib.config mina).precomputed_values.consensus_constants
            in
            C.end_time ~constants global_slot )
      ] )

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
          ~typ:(non_null global_slot_since_genesis)
          ~resolve:(fun _ (_, slot) -> slot)
      ] )

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
          ~resolve:(fun { ctx = mina; _ }
                        { Daemon_rpcs.Types.Status.Next_producer_timing.timing
                        ; _
                        } ->
            let consensus_constants =
              (Mina_lib.config mina).precomputed_values.consensus_constants
            in
            match timing with
            | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again _ ->
                []
            | Evaluating_vrf _last_checked_slot ->
                []
            | Produce info ->
                [ of_time info.time ~consensus_constants ]
            | Produce_now info ->
                [ of_time ~consensus_constants info.time ] )
      ; field "globalSlotSinceGenesis"
          ~typ:(non_null @@ list @@ non_null global_slot_since_genesis)
          ~doc:"Next block production global-slot-since-genesis "
          ~args:Arg.[]
          ~resolve:(fun _
                        { Daemon_rpcs.Types.Status.Next_producer_timing.timing
                        ; _
                        } ->
            match timing with
            | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again _ ->
                []
            | Evaluating_vrf _last_checked_slot ->
                []
            | Produce info ->
                [ info.for_slot.global_slot_since_genesis ]
            | Produce_now info ->
                [ info.for_slot.global_slot_since_genesis ] )
      ; field "generatedFromConsensusAt"
          ~typ:(non_null consensus_time_with_global_slot_since_genesis)
          ~doc:
            "Consensus time of the block that was used to determine the next \
             block production time"
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ }
                        { Daemon_rpcs.Types.Status.Next_producer_timing
                          .generated_from_consensus_at =
                            { slot; global_slot_since_genesis }
                        ; _
                        } ->
            let consensus_constants =
              (Mina_lib.config mina).precomputed_values.consensus_constants
            in
            ( Consensus.Data.Consensus_time.of_global_slot
                ~constants:consensus_constants slot
            , global_slot_since_genesis ) )
      ] )

let merkle_path_element :
    (_, [ `Left of Zkapp_basic.F.t | `Right of Zkapp_basic.F.t ] option) typ =
  let field_elem = Mina_base_unix.Graphql_scalars.FieldElem.typ () in
  obj "MerklePathElement" ~fields:(fun _ ->
      [ field "left" ~typ:field_elem
          ~args:Arg.[]
          ~resolve:(fun _ x ->
            match x with `Left h -> Some h | `Right _ -> None )
      ; field "right" ~typ:field_elem
          ~args:Arg.[]
          ~resolve:(fun _ x ->
            match x with `Left _ -> None | `Right h -> Some h )
      ] )

module DaemonStatus = struct
  type t = Daemon_rpcs.Types.Status.t

  let interval : (_, (Time.Span.t * Time.Span.t) option) typ =
    obj "Interval" ~fields:(fun _ ->
        [ field "start" ~typ:(non_null span)
            ~args:Arg.[]
            ~resolve:(fun _ (start, _) -> start)
        ; field "stop" ~typ:(non_null span)
            ~args:Arg.[]
            ~resolve:(fun _ (_, end_) -> end_)
        ] )

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
             ~get_transition_chain_proof:fd ~get_transition_chain:fd )

  module Histograms = Daemon_rpcs.Types.Status.Histograms

  let histograms : (_, Histograms.t option) typ =
    let h = Reflection.Shorthand.id ~typ:histogram in
    obj "Histograms" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Histograms.Fields.fold ~init:[]
             ~rpc_timings:(id ~typ:(non_null rpc_timings))
             ~external_transition_latency:h ~accepted_transition_local_latency:h
             ~accepted_transition_remote_latency:h
             ~snark_worker_transition_time:h ~snark_worker_merge_time:h )

  let consensus_configuration : (_, Consensus.Configuration.t option) typ =
    obj "ConsensusConfiguration" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Consensus.Configuration.Fields.fold ~init:[] ~delta:nn_int ~k:nn_int
             ~slots_per_epoch:nn_int ~slot_duration:nn_int
             ~epoch_duration:nn_int ~acceptable_network_delay:nn_int
             ~genesis_state_timestamp:nn_time )

  let peer : (_, Network_peer.Peer.Display.t option) typ =
    obj "Peer" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Network_peer.Peer.Display.Fields.fold ~init:[] ~host:nn_string
             ~libp2p_port:nn_int ~peer_id:nn_string )

  let addrs_and_ports : (_, Node_addrs_and_ports.Display.t option) typ =
    obj "AddrsAndPorts" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Node_addrs_and_ports.Display.Fields.fold ~init:[]
             ~external_ip:nn_string ~bind_ip:nn_string ~client_port:nn_int
             ~libp2p_port:nn_int ~peer:(id ~typ:peer) )

  let metrics : (_, Daemon_rpcs.Types.Status.Metrics.t option) typ =
    obj "Metrics" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Daemon_rpcs.Types.Status.Metrics.Fields.fold ~init:[]
             ~block_production_delay:nn_int_list
             ~transaction_pool_diff_received:nn_int
             ~transaction_pool_diff_broadcasted:nn_int
             ~transactions_added_to_pool:nn_int ~transaction_pool_size:nn_int
             ~snark_pool_diff_received:nn_int
             ~snark_pool_diff_broadcasted:nn_int ~pending_snark_work:nn_int
             ~snark_pool_size:nn_int )

  let t : (_, Daemon_rpcs.Types.Status.t option) typ =
    obj "DaemonStatus" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Daemon_rpcs.Types.Status.Fields.fold ~init:[] ~num_accounts:int
             ~catchup_status:nn_catchup_status ~chain_id:nn_string
             ~next_block_production:(id ~typ:block_producer_timing)
             ~blockchain_length:int ~uptime_secs:nn_int
             ~ledger_merkle_root:string ~state_hash:string ~commit_id:nn_string
             ~conf_dir:nn_string
             ~peers:(id ~typ:(non_null (list (non_null peer))))
             ~user_commands_sent:nn_int ~snark_worker:string
             ~snark_work_fee:nn_int
             ~sync_status:(id ~typ:(non_null sync_status))
             ~block_production_keys:
               (id ~typ:(non_null @@ list (non_null Schema.string)))
             ~coinbase_receiver:(id ~typ:Schema.string)
             ~histograms:(id ~typ:histograms)
             ~consensus_time_best_tip:(id ~typ:consensus_time)
             ~global_slot_since_genesis_best_tip:int
             ~consensus_time_now:(id ~typ:Schema.(non_null consensus_time))
             ~consensus_mechanism:nn_string
             ~addrs_and_ports:(id ~typ:(non_null addrs_and_ports))
             ~consensus_configuration:
               (id ~typ:(non_null consensus_configuration))
             ~highest_block_length_received:nn_int
             ~highest_unvalidated_block_length_received:nn_int
             ~metrics:(id ~typ:(non_null metrics)) )
end

module Itn = struct
  let auth =
    obj "ItnAuth" ~fields:(fun _ ->
        [ field "serverUuid"
            ~args:Arg.[]
            ~doc:"Uuid of the ITN GraphQL server" ~typ:(non_null string)
            ~resolve:(fun _ (uuid, _) -> uuid)
        ; field "signerSequenceNumber"
            ~args:Arg.[]
            ~doc:"Sequence number for the signer of the auth query"
            ~typ:(non_null uint16)
            ~resolve:(fun _ (_, n) -> n)
        ; field "libp2pPort"
            ~args:Arg.[]
            ~doc:"Libp2p port" ~typ:(non_null uint16)
            ~resolve:(fun { ctx = (_ : bool), mina; _ } _ ->
              Mina_lib.config mina
              |> fun Mina_lib.Config.{ gossip_net_params; _ } ->
              gossip_net_params.addrs_and_ports.libp2p_port
              |> Unsigned.UInt16.of_int )
        ; field "peerId"
            ~args:Arg.[]
            ~doc:"Peer id" ~typ:(non_null string)
            ~resolve:(fun { ctx = (_ : bool), mina; _ } _ ->
              Mina_lib.config mina
              |> fun Mina_lib.Config.{ gossip_net_params; _ } ->
              Mina_net2.Keypair.to_peer_id gossip_net_params.keypair )
        ; field "isBlockProducer"
            ~args:Arg.[]
            ~doc:"Is the node a block producer" ~typ:(non_null bool)
            ~resolve:(fun { ctx = (_ : bool), mina; _ } _ ->
              let bp_keys = Mina_lib.block_production_pubkeys mina in
              not (Public_key.Compressed.Set.is_empty bp_keys) )
        ] )

  let metadatum =
    (* different type than `json` above *)
    let json = Graphql_lib.Scalars.JSON.typ () in
    obj "logMetadatum" ~fields:(fun _ ->
        [ field "item"
            ~args:Arg.[]
            ~doc:"metadatum item" ~typ:(non_null string)
            ~resolve:(fun (_ : (bool * Mina_lib.t) resolve_info) (item, _) ->
              item )
        ; field "value"
            ~args:Arg.[]
            ~doc:"metadatum value" ~typ:(non_null json)
            ~resolve:(fun _ (_, value) -> value)
        ] )

  let log =
    obj "ItnLog" ~fields:(fun _ ->
        [ field "id"
            ~args:Arg.[]
            ~doc:"the log ID" ~typ:(non_null int)
            ~resolve:(fun (_ : (bool * Mina_lib.t) resolve_info)
                          (log : Itn_logger.t) -> log.sequence_no )
        ; field "timestamp"
            ~args:Arg.[]
            ~doc:"timestamp of the log" ~typ:(non_null string)
            ~resolve:(fun _ (log : Itn_logger.t) -> log.timestamp)
        ; field "message"
            ~args:Arg.[]
            ~doc:"the log message" ~typ:(non_null string)
            ~resolve:(fun _ (log : Itn_logger.t) -> log.message)
        ; field "metadata"
            ~args:Arg.[]
            ~doc:"metadata for the log"
            ~typ:(non_null (list (non_null metadatum)))
            ~resolve:(fun _ (log : Itn_logger.t) -> log.metadata)
        ; field "process"
            ~args:Arg.[]
            ~doc:
              "if not the daemon, which process sent the log (prover or \
               verifier)"
            ~typ:string
            ~resolve:(fun _ (log : Itn_logger.t) -> log.process)
        ] )
end

let fee_transfer =
  obj "FeeTransfer" ~fields:(fun _ ->
      [ field "recipient"
          ~args:Arg.[]
          ~doc:"Public key of fee transfer recipient" ~typ:(non_null public_key)
          ~resolve:(fun _ ({ Fee_transfer.receiver_pk = pk; _ }, _) -> pk)
      ; field "fee" ~typ:(non_null fee)
          ~args:Arg.[]
          ~doc:"Amount that the recipient is paid in this fee transfer"
          ~resolve:(fun _ ({ Fee_transfer.fee; _ }, _) -> fee)
      ; field "type"
          ~typ:
            ( non_null
            @@ Filtered_external_transition_unix.Graphql_scalars.FeeTransferType
               .typ () )
          ~args:Arg.[]
          ~doc:
            "Fee_transfer|Fee_transfer_via_coinbase Snark worker fees deducted \
             from the coinbase amount are of type 'Fee_transfer_via_coinbase', \
             rest are deducted from transaction fees"
          ~resolve:(fun _ (_, transfer_type) -> transfer_type)
      ] )

let account_timing : (Mina_lib.t, Account_timing.t option) typ =
  obj "AccountTiming" ~fields:(fun _ ->
      [ field "initialMinimumBalance" ~typ:balance
          ~doc:"The initial minimum balance for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.initial_minimum_balance )
      ; field "cliffTime" ~typ:global_slot_since_genesis
          ~doc:"The cliff time for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.cliff_time )
      ; field "cliffAmount" ~typ:amount
          ~doc:"The cliff amount for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.cliff_amount )
      ; field "vestingPeriod" ~typ:global_slot_span
          ~doc:"The vesting period for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.vesting_period )
      ; field "vestingIncrement" ~typ:amount
          ~doc:"The vesting increment for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Account_timing.Untimed ->
                None
            | Timed timing_info ->
                Some timing_info.vesting_increment )
      ] )

let completed_work =
  obj "CompletedWork" ~doc:"Completed snark works" ~fields:(fun _ ->
      [ field "prover"
          ~args:Arg.[]
          ~doc:"Public key of the prover" ~typ:(non_null public_key)
          ~resolve:(fun _ { Transaction_snark_work.Info.prover; _ } -> prover)
      ; field "fee" ~typ:(non_null fee)
          ~args:Arg.[]
          ~doc:"Amount the prover is paid for the snark work"
          ~resolve:(fun _ { Transaction_snark_work.Info.fee; _ } -> fee)
      ; field "workIds" ~doc:"Unique identifier for the snark work purchased"
          ~typ:(non_null @@ list @@ non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark_work.Info.work_ids; _ } ->
            One_or_two.to_list work_ids )
      ] )

let sign =
  enum "sign"
    ~values:
      [ enum_value "PLUS" ~value:Sgn.Pos; enum_value "MINUS" ~value:Sgn.Neg ]

let signed_fee =
  obj "SignedFee" ~doc:"Signed fee" ~fields:(fun _ ->
      [ field "sign" ~typ:(non_null sign) ~doc:"+/-"
          ~args:Arg.[]
          ~resolve:(fun _ fee -> Currency.Amount.Signed.sgn fee)
      ; field "feeMagnitude" ~typ:(non_null amount) ~doc:"Fee"
          ~args:Arg.[]
          ~resolve:(fun _ fee -> Currency.Amount.Signed.magnitude fee)
      ] )

let work_statement =
  obj "WorkDescription"
    ~doc:
      "Transition from a source ledger to a target ledger with some fee excess \
       and increase in supply " ~fields:(fun _ ->
      [ field "sourceFirstPassLedgerHash" ~typ:(non_null ledger_hash)
          ~doc:"Base58Check-encoded hash of the source first-pass ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.Poly.source; _ } ->
            source.first_pass_ledger )
      ; field "targetFirstPassLedgerHash" ~typ:(non_null ledger_hash)
          ~doc:"Base58Check-encoded hash of the target first-pass ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.Poly.target; _ } ->
            target.first_pass_ledger )
      ; field "sourceSecondPassLedgerHash" ~typ:(non_null ledger_hash)
          ~doc:"Base58Check-encoded hash of the source second-pass ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.Poly.source; _ } ->
            source.second_pass_ledger )
      ; field "targetSecondPassLedgerHash" ~typ:(non_null ledger_hash)
          ~doc:"Base58Check-encoded hash of the target second-pass ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.Poly.target; _ } ->
            target.second_pass_ledger )
      ; field "feeExcess" ~typ:(non_null signed_fee)
          ~doc:
            "Total transaction fee that is not accounted for in the transition \
             from source ledger to target ledger"
          ~args:Arg.[]
          ~resolve:(fun _
                        ({ fee_excess = { fee_excess_l; _ }; _ } :
                          Transaction_snark.Statement.t ) ->
            (* TODO: Expose full fee excess data. *)
            { fee_excess_l with
              magnitude = Currency.Amount.of_fee fee_excess_l.magnitude
            } )
      ; field "supplyIncrease" ~typ:(non_null amount)
          ~doc:"Increase in total supply"
          ~args:Arg.[]
          ~deprecated:(Deprecated (Some "Use supplyChange"))
          ~resolve:(fun _
                        ({ supply_increase; _ } : Transaction_snark.Statement.t) ->
            supply_increase.magnitude )
      ; field "supplyChange" ~typ:(non_null signed_fee)
          ~doc:"Increase/Decrease in total supply"
          ~args:Arg.[]
          ~resolve:(fun _
                        ({ supply_increase; _ } : Transaction_snark.Statement.t) ->
            supply_increase )
      ; field "workId" ~doc:"Unique identifier for a snark work"
          ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ w -> Transaction_snark.Statement.hash w)
      ] )

let pending_work =
  obj "PendingSnarkWork"
    ~doc:"Snark work bundles that are not available in the pool yet"
    ~fields:(fun _ ->
      [ field "workBundle"
          ~args:Arg.[]
          ~doc:"Work bundle with one or two snark work"
          ~typ:(non_null @@ list @@ non_null work_statement)
          ~resolve:(fun _ w -> One_or_two.to_list w)
      ] )

let blockchain_state :
    ( Mina_lib.t
    , (Mina_state.Blockchain_state.Value.t * State_hash.t) option )
    typ =
  let staged_ledger_hash t =
    let blockchain_state, _ = t in
    Mina_state.Blockchain_state.staged_ledger_hash blockchain_state
  in
  obj "BlockchainState" ~fields:(fun _ ->
      [ field "date" ~typ:(non_null block_time) ~doc:(Doc.date "date")
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            Mina_state.Blockchain_state.timestamp blockchain_state )
      ; field "utcDate" ~typ:(non_null block_time)
          ~doc:
            (Doc.date
               ~extra:
                 ". Time offsets are adjusted to reflect true wall-clock time \
                  instead of genesis time."
               "utcDate" )
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } t ->
            let blockchain_state, _ = t in
            let timestamp =
              Mina_state.Blockchain_state.timestamp blockchain_state
            in
            Block_time.to_system_time (Mina_lib.time_controller mina) timestamp
            )
      ; field "snarkedLedgerHash" ~typ:(non_null ledger_hash)
          ~doc:"Base58Check-encoded hash of the snarked ledger"
          ~args:Arg.[]
          ~resolve:(fun _ (blockchain_state, _) ->
            Mina_state.Blockchain_state.snarked_ledger_hash blockchain_state )
      ; field "stagedLedgerHash" ~typ:(non_null ledger_hash)
          ~doc:
            "Base58Check-encoded hash of the staged ledger hash's main ledger \
             hash"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let staged_ledger_hash = staged_ledger_hash t in
            Staged_ledger_hash.ledger_hash staged_ledger_hash )
      ; field "stagedLedgerAuxHash"
          ~typ:(non_null @@ Graphql_lib.Scalars.StagedLedgerAuxHash.typ ())
          ~doc:"Base58Check-encoded hash of the staged ledger hash's aux_hash"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let staged_ledger_hash = staged_ledger_hash t in
            Staged_ledger_hash.aux_hash staged_ledger_hash )
      ; field "stagedLedgerPendingCoinbaseAux"
          ~typ:(non_null @@ Graphql_lib.Scalars.PendingCoinbaseAuxHash.typ ())
          ~doc:"Base58Check-encoded staged ledger hash's pending_coinbase_aux"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let staged_ledger_hash = staged_ledger_hash t in
            Staged_ledger_hash.pending_coinbase_aux staged_ledger_hash )
      ; field "stagedLedgerPendingCoinbaseHash"
          ~typ:(non_null @@ Graphql_lib.Scalars.PendingCoinbaseHash.typ ())
          ~doc:
            "Base58Check-encoded hash of the staged ledger hash's \
             pending_coinbase_hash"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            Staged_ledger_hash.pending_coinbase_hash (staged_ledger_hash t) )
      ; field "stagedLedgerProofEmitted" ~typ:bool
          ~doc:
            "Block finished a staged ledger, and a proof was emitted from it \
             and included into this block's proof. If there is no transition \
             frontier available or no block found, this will return null."
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } t ->
            let open Option.Let_syntax in
            let _, hash = t in
            let%bind frontier =
              Mina_lib.transition_frontier mina
              |> Pipe_lib.Broadcast_pipe.Reader.peek
            in
            match Transition_frontier.find frontier hash with
            | None ->
                None
            | Some b ->
                Some (Transition_frontier.Breadcrumb.just_emitted_a_proof b) )
      ; field "bodyReference"
          ~typ:(non_null @@ Graphql_lib.Scalars.BodyReference.typ ())
          ~doc:
            "A reference to how the block header refers to the body of the \
             block as a hex-encoded string"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            Mina_state.Blockchain_state.body_reference blockchain_state )
      ] )

let protocol_state :
    ( Mina_lib.t
    , (Filtered_external_transition.Protocol_state.t * State_hash.t) option )
    typ =
  let open Filtered_external_transition.Protocol_state in
  obj "ProtocolState" ~fields:(fun _ ->
      [ field "previousStateHash" ~typ:(non_null state_hash)
          ~doc:"Base58Check-encoded hash of the previous state"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, _ = t in
            protocol_state.previous_state_hash )
      ; field "blockchainState"
          ~doc:"State which is agnostic of a particular consensus algorithm"
          ~typ:(non_null blockchain_state)
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, state_hash = t in
            (protocol_state.blockchain_state, state_hash) )
      ; field "consensusState"
          ~doc:
            "State specific to the minaboros Proof of Stake consensus algorithm"
          ~typ:(non_null @@ Consensus.Data.Consensus_state.graphql_type ())
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, _ = t in
            protocol_state.consensus_state )
      ] )

let chain_reorganization_status : (Mina_lib.t, [ `Changed ] option) typ =
  enum "ChainReorganizationStatus"
    ~doc:"Status for whenever the blockchain is reorganized"
    ~values:[ enum_value "CHANGED" ~value:`Changed ]

let genesis_constants =
  obj "GenesisConstants" ~fields:(fun _ ->
      [ field "accountCreationFee" ~typ:(non_null fee)
          ~doc:"The fee charged to create a new account"
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } () ->
            (Mina_lib.config mina).precomputed_values.constraint_constants
              .account_creation_fee )
      ; field "coinbase" ~typ:(non_null amount)
          ~doc:"The amount received as a coinbase reward for producing a block"
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } () ->
            (Mina_lib.config mina).precomputed_values.constraint_constants
              .coinbase_amount )
      ; field "genesisTimestamp" ~typ:(non_null string)
          ~doc:"The genesis timestamp in ISO 8601 format"
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } () ->
            (Mina_lib.config mina).precomputed_values.genesis_constants.protocol
              .genesis_state_timestamp
            |> Genesis_constants.genesis_timestamp_to_string )
      ] )

let protocol_version =
  obj "ProtocolVersion" ~fields:(fun _ ->
      [ field "transaction" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ version -> Protocol_version.transaction version)
      ; field "network" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ version -> Protocol_version.network version)
      ; field "patch" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ version -> Protocol_version.patch version)
      ] )

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
               ~initial_minimum_balance:timing_info.initial_minimum_balance )

    let obj =
      obj "AnnotatedBalance"
        ~doc:
          "A total balance annotated with the amount that is currently unknown \
           with the invariant unknown <= total, as well as the currently \
           liquid and locked balances." ~fields:(fun _ ->
          [ field "total" ~typ:(non_null balance)
              ~doc:"The amount of MINA owned by the account"
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) -> b.total)
          ; field "unknown" ~typ:(non_null balance)
              ~doc:
                "The amount of MINA owned by the account whose origin is \
                 currently unknown"
              ~deprecated:(Deprecated None)
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) -> b.unknown)
          ; field "liquid" ~typ:balance
              ~doc:
                "The amount of MINA owned by the account which is currently \
                 available. Can be null if bootstrapping."
              ~deprecated:(Deprecated None)
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                Option.map (min_balance b) ~f:(fun min_balance ->
                    let total_balance : uint64 = Balance.to_uint64 b.total in
                    let min_balance_uint64 = Balance.to_uint64 min_balance in
                    Balance.of_uint64
                      ( if
                        Unsigned.UInt64.compare total_balance min_balance_uint64
                        > 0
                      then Unsigned.UInt64.sub total_balance min_balance_uint64
                      else Unsigned.UInt64.zero ) ) )
          ; field "locked" ~typ:balance
              ~doc:
                "The amount of MINA owned by the account which is currently \
                 locked. Can be null if bootstrapping."
              ~deprecated:(Deprecated None)
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) -> min_balance b)
          ; field "blockHeight" ~typ:(non_null length)
              ~doc:"Block height at which balance was measured"
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                match b.breadcrumb with
                | None ->
                    Unsigned.UInt32.zero
                | Some crumb ->
                    Transition_frontier.Breadcrumb.consensus_state crumb
                    |> Consensus.Data.Consensus_state.blockchain_length )
            (* TODO: Mutually recurse with "block" instead -- #5396 *)
          ; field "stateHash" ~typ:state_hash
              ~doc:
                "Hash of block at which balance was measured. Can be null if \
                 bootstrapping. Guaranteed to be non-null for direct account \
                 lookup queries when not bootstrapping. Can also be null when \
                 accessed as nested properties (eg. via delegators). "
              ~args:Arg.[]
              ~resolve:(fun _ (b : t) ->
                Option.map b.breadcrumb ~f:(fun crumb ->
                    Transition_frontier.Breadcrumb.state_hash crumb ) )
          ] )
  end

  module Partial_account = struct
    let to_full_account
        { Account.Poly.public_key
        ; token_id
        ; token_symbol
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing
        ; permissions
        ; zkapp
        } =
      let open Option.Let_syntax in
      let%bind token_symbol = token_symbol in
      let%bind nonce = nonce in
      let%bind receipt_chain_hash = receipt_chain_hash in
      let%bind voting_for = voting_for in
      let%map permissions = permissions in
      { Account.Poly.public_key
      ; token_id
      ; token_symbol
      ; nonce
      ; balance = balance.AnnotatedBalance.total
      ; receipt_chain_hash
      ; delegate
      ; voting_for
      ; timing
      ; permissions
      ; zkapp
      }

    let of_full_account ?breadcrumb
        { Account.Poly.public_key
        ; token_id
        ; token_symbol
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing
        ; permissions
        ; zkapp
        } =
      { Account.Poly.public_key
      ; token_id
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
      }

    let of_account_id mina account_id =
      let account =
        mina |> Mina_lib.best_tip |> Participating_state.active
        |> Option.bind ~f:(fun tip ->
               let ledger =
                 Transition_frontier.Breadcrumb.staged_ledger tip
                 |> Staged_ledger.ledger
               in
               Ledger.location_of_account ledger account_id
               |> Option.bind ~f:(Ledger.get ledger)
               |> Option.map ~f:(fun account -> (account, tip)) )
      in
      match account with
      | Some (account, breadcrumb) ->
          of_full_account ~breadcrumb account
      | None ->
          Account.
            { Poly.public_key = Account_id.public_key account_id
            ; token_id = Account_id.token_id account_id
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
            }

    let of_pk mina pk =
      of_account_id mina (Account_id.create pk Token_id.default)
  end

  type t =
    { account :
        ( Public_key.Compressed.t
        , Token_id.t
        , Account.Token_symbol.t option
        , AnnotatedBalance.t
        , Account.Nonce.t option
        , Receipt.Chain_hash.t option
        , Public_key.Compressed.t option
        , State_hash.t option
        , Account.Timing.t
        , Permissions.t option
        , Zkapp_account.t option )
        Account.Poly.t
    ; locked : bool option
    ; is_actively_staking : bool
    ; path : string
    ; index : Account.Index.t option
    }

  let lift mina pk account =
    let block_production_pubkeys = Mina_lib.block_production_pubkeys mina in
    let accounts = Mina_lib.wallets mina in
    let best_tip_ledger = Mina_lib.best_ledger mina in
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
                  (Account_id.create account.public_key account.token_id) )
        | _ ->
            None )
    }

  let get_best_ledger_account mina aid =
    lift mina
      (Account_id.public_key aid)
      (Partial_account.of_account_id mina aid)

  let get_best_ledger_account_pk mina pk =
    lift mina pk (Partial_account.of_pk mina pk)

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

  let verification_key_permission =
    obj "VerificationKeyPermission" ~fields:(fun _ ->
        [ field "auth" ~typ:(non_null auth_required)
            ~doc:
              "Authorization required to set the verification key of the zkApp \
               associated with the account"
            ~args:Arg.[]
            ~resolve:(fun _ (auth, _) -> auth)
        ; field "version"
            ~typ:(non_null protocol_version)
            ~args:Arg.[]
            ~resolve:(fun _ (_, version) -> version)
        ] )

  let account_permissions =
    obj "AccountPermissions" ~fields:(fun _ ->
        [ field "editState" ~typ:(non_null auth_required)
            ~doc:"Authorization required to edit zkApp state"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.edit_state)
        ; field "send" ~typ:(non_null auth_required)
            ~doc:"Authorization required to send tokens"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.send)
        ; field "receive" ~typ:(non_null auth_required)
            ~doc:"Authorization required to receive tokens"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.receive)
        ; field "access" ~typ:(non_null auth_required)
            ~doc:"Authorization required to access the account"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.access)
        ; field "setDelegate" ~typ:(non_null auth_required)
            ~doc:"Authorization required to set the delegate"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_delegate )
        ; field "setPermissions" ~typ:(non_null auth_required)
            ~doc:"Authorization required to change permissions"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_permissions )
        ; field "setVerificationKey"
            ~typ:(non_null verification_key_permission)
            ~doc:
              "Authorization required to set the verification key of the zkApp \
               associated with the account"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_verification_key )
        ; field "setZkappUri" ~typ:(non_null auth_required)
            ~doc:
              "Authorization required to change the URI of the zkApp \
               associated with the account "
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_zkapp_uri )
        ; field "editActionState" ~typ:(non_null auth_required)
            ~doc:"Authorization required to edit the action state"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.edit_action_state )
        ; field "setTokenSymbol" ~typ:(non_null auth_required)
            ~doc:"Authorization required to set the token symbol"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_token_symbol )
        ; field "incrementNonce" ~typ:(non_null auth_required)
            ~doc:"Authorization required to increment the nonce"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.increment_nonce )
        ; field "setVotingFor" ~typ:(non_null auth_required)
            ~doc:
              "Authorization required to set the state hash the account is \
               voting for"
            ~args:Arg.[]
            ~resolve:(fun _ permission ->
              permission.Permissions.Poly.set_voting_for )
        ; field "setTiming" ~typ:(non_null auth_required)
            ~doc:"Authorization required to set the timing of the account"
            ~args:Arg.[]
            ~resolve:(fun _ permission -> permission.Permissions.Poly.set_timing)
        ] )

  let account_vk =
    obj "AccountVerificationKeyWithHash" ~doc:"Verification key with hash"
      ~fields:(fun _ ->
        [ field "verificationKey" ~doc:"verification key in Base64 format"
            ~typ:
              (non_null @@ Pickles_unix.Graphql_scalars.VerificationKey.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ (vk : _ With_hash.t) -> vk.data)
        ; field "hash" ~doc:"Hash of verification key"
            ~typ:
              ( non_null
              @@ Pickles_unix.Graphql_scalars.VerificationKeyHash.typ () )
            ~args:Arg.[]
            ~resolve:(fun _ (vk : _ With_hash.t) -> vk.hash)
        ] )

  let rec account =
    lazy
      (obj "Account" ~doc:"An account record according to the daemon"
         ~fields:(fun _ ->
           [ field "publicKey" ~typ:(non_null public_key)
               ~doc:"The public identity of the account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.public_key)
           ; field "tokenId" ~typ:(non_null token_id)
               ~doc:"The token associated with this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.token_id)
           ; field "token" ~typ:(non_null token_id)
               ~doc:"The token associated with this account"
               ~deprecated:(Deprecated (Some "Use tokenId"))
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
           ; field "nonce" ~typ:account_nonce
               ~doc:
                 "A natural number that increases with each transaction \
                  (stringified uint32)"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.nonce)
           ; field "inferredNonce" ~typ:account_nonce
               ~doc:
                 "Like the `nonce` field, except it includes the scheduled \
                  transactions (transactions not yet included in a block) \
                  (stringified uint32)"
               ~args:Arg.[]
               ~resolve:(fun { ctx = mina; _ } { account; _ } ->
                 let account_id = account_id account in
                 match
                   Mina_lib.get_inferred_nonce_from_transaction_pool_and_ledger
                     mina account_id
                 with
                 | `Active n ->
                     n
                 | `Bootstrapping ->
                     None )
           ; field "epochDelegateAccount" ~typ:(Lazy.force account)
               ~doc:
                 "The account that you delegated on the staking ledger of the \
                  current block's epoch"
               ~args:Arg.[]
               ~resolve:(fun { ctx = mina; _ } { account; _ } ->
                 let open Option.Let_syntax in
                 let account_id = account_id account in
                 match%bind Mina_lib.staking_ledger mina with
                 | Genesis_epoch_ledger staking_ledger -> (
                     match
                       let open Option.Let_syntax in
                       account_id
                       |> Ledger.location_of_account staking_ledger
                       >>= Ledger.get staking_ledger
                     with
                     | Some delegate_account ->
                         let delegate_key = delegate_account.public_key in
                         Some (get_best_ledger_account_pk mina delegate_key)
                     | None ->
                         [%log' warn (Mina_lib.top_level_logger mina)]
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
                       Some (get_best_ledger_account_pk mina delegate_key)
                     with e ->
                       [%log' warn (Mina_lib.top_level_logger mina)]
                         ~metadata:[ ("error", `String (Exn.to_string e)) ]
                         "Could not retrieve delegate account from sparse \
                          ledger. The account may not be in the ledger: $error" ;
                       None ) )
           ; field "receiptChainHash" ~typ:chain_hash
               ~doc:"Top hash of the receipt chain Merkle-list"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.receipt_chain_hash )
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
               ~resolve:(fun { ctx = mina; _ } { account; _ } ->
                 Option.map
                   ~f:(get_best_ledger_account_pk mina)
                   account.Account.Poly.delegate )
           ; field "delegators"
               ~typ:(list @@ non_null @@ Lazy.force account)
               ~doc:
                 "The list of accounts which are delegating to you (note that \
                  the info is recorded in the last epoch so it might not be up \
                  to date with the current account status)"
               ~args:Arg.[]
               ~resolve:(fun { ctx = mina; _ } { account; _ } ->
                 let open Option.Let_syntax in
                 let pk = account.Account.Poly.public_key in
                 let%map delegators =
                   Mina_lib.current_epoch_delegators mina ~pk
                 in
                 let best_tip_ledger = Mina_lib.best_ledger mina in
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
                                   (Account.identifier a) )
                         | _ ->
                             None )
                     } )
                   delegators )
           ; field "lastEpochDelegators"
               ~typ:(list @@ non_null @@ Lazy.force account)
               ~doc:
                 "The list of accounts which are delegating to you in the last \
                  epoch (note that the info is recorded in the one before last \
                  epoch epoch so it might not be up to date with the current \
                  account status)"
               ~args:Arg.[]
               ~resolve:(fun { ctx = mina; _ } { account; _ } ->
                 let open Option.Let_syntax in
                 let pk = account.Account.Poly.public_key in
                 let%map delegators = Mina_lib.last_epoch_delegators mina ~pk in
                 let best_tip_ledger = Mina_lib.best_ledger mina in
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
                                   (Account.identifier a) )
                         | _ ->
                             None )
                     } )
                   delegators )
           ; field "votingFor" ~typ:chain_hash
               ~doc:
                 "The previous epoch lock hash of the chain which you are \
                  voting for"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } -> account.Account.Poly.voting_for)
           ; field "stakingActive" ~typ:(non_null bool)
               ~doc:
                 "True if you are actively staking with this account on the \
                  current daemon - this may not yet have been updated if the \
                  staking key was changed recently"
               ~args:Arg.[]
               ~resolve:(fun _ { is_actively_staking; _ } -> is_actively_staking)
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
               ~resolve:(fun _ { account; _ } ->
                 Option.value_map account.zkapp ~default:None ~f:(fun zkapp ->
                     Some zkapp.zkapp_uri ) )
           ; field "zkappState"
               ~typ:
                 ( list @@ non_null
                 @@ Mina_base_unix.Graphql_scalars.FieldElem.typ () )
               ~doc:
                 "The 8 field elements comprising the zkApp state associated \
                  with this account encoded as bignum strings"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.zkapp
                 |> Option.map ~f:(fun zkapp_account ->
                        zkapp_account.app_state |> Zkapp_state.V.to_list ) )
           ; field "provedState" ~typ:bool
               ~doc:
                 "Boolean indicating whether all 8 fields on zkAppState were \
                  last set by a proof-authorized account update"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.zkapp
                 |> Option.map ~f:(fun zkapp_account ->
                        zkapp_account.proved_state ) )
           ; field "permissions" ~typ:account_permissions
               ~doc:"Permissions for updating certain fields of this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.permissions )
           ; field "tokenSymbol" ~typ:string
               ~doc:
                 "The symbol for the token owned by this account, if there is \
                  one"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 account.Account.Poly.token_symbol )
           ; field "verificationKey" ~typ:account_vk
               ~doc:"Verification key associated with this account"
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.value_map account.Account.Poly.zkapp ~default:None
                   ~f:(fun zkapp_account -> zkapp_account.verification_key) )
           ; field "actionState"
               ~doc:"Action state associated with this account"
               ~typ:
                 (list
                    (non_null @@ Snark_params_unix.Graphql_scalars.Action.typ ()) )
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 Option.map account.Account.Poly.zkapp ~f:(fun zkapp_account ->
                     Pickles_types.Vector.to_list zkapp_account.action_state )
                 )
           ; field "leafHash"
               ~doc:
                 "The base58Check-encoded hash of this account to bootstrap \
                  the merklePath"
               ~typ:(Mina_base_unix.Graphql_scalars.FieldElem.typ ())
               ~args:Arg.[]
               ~resolve:(fun _ { account; _ } ->
                 let open Option.Let_syntax in
                 let%map account = Partial_account.to_full_account account in
                 Ledger_hash.of_digest (Account.digest account) )
           ; field "merklePath"
               ~doc:
                 "Merkle path is a list of path elements that are either the \
                  left or right hashes up to the root"
               ~typ:(list (non_null merkle_path_element))
               ~args:Arg.[]
               ~resolve:(fun { ctx = mina; _ } { index; _ } ->
                 let open Option.Let_syntax in
                 let%bind ledger, _breadcrumb =
                   Utils.get_ledger_and_breadcrumb mina
                 in
                 let%bind index = index in
                 Option.try_with (fun () ->
                     Ledger.merkle_path_at_index_exn ledger index ) )
           ] ) )

  let account = Lazy.force account
end

module Command_status = struct
  type t =
    | Applied
    | Enqueued
    | Included_but_failed of Transaction_status.Failure.Collection.t

  let failure_reasons =
    obj "ZkappCommandFailureReason" ~fields:(fun _ ->
        [ field "index" ~typ:(Graphql_basic_scalars.Index.typ ())
            ~args:[] ~doc:"List index of the account update that failed"
            ~resolve:(fun _ (index, _) -> Some index)
        ; field "failures"
            ~typ:
              ( non_null @@ list @@ non_null
              @@ Mina_base_unix.Graphql_scalars.TransactionStatusFailure.typ ()
              )
            ~args:[]
            ~doc:
              "Failure reason for the account update or any nested zkapp \
               command"
            ~resolve:(fun _ (_, failures) -> failures)
        ] )
end

module User_command = struct
  let kind : (Mina_lib.t, [ `Payment | `Stake_delegation ] option) typ =
    scalar "UserCommandKind" ~doc:"The kind of user command" ~coerce:(function
      | `Payment ->
          `String "PAYMENT"
      | `Stake_delegation ->
          `String "STAKE_DELEGATION" )

  let to_kind (t : Signed_command.t) =
    match Signed_command.payload t |> Signed_command_payload.body with
    | Payment _ ->
        `Payment
    | Stake_delegation _ ->
        `Stake_delegation

  let user_command_interface :
      ( Mina_lib.t
      , ( Mina_lib.t
        , (Signed_command.t, Transaction_hash.t) With_hash.t )
        abstract_value
        option )
      typ =
    interface "UserCommand" ~doc:"Common interface for user commands"
      ~fields:(fun _ ->
        [ abstract_field "id" ~typ:(non_null transaction_id) ~args:[]
        ; abstract_field "hash" ~typ:(non_null transaction_hash) ~args:[]
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
        ; abstract_field "validUntil"
            ~typ:(non_null global_slot_since_genesis)
            ~args:[]
            ~doc:
              "The global slot number after which this transaction cannot be \
               applied"
        ; abstract_field "token" ~typ:(non_null token_id) ~args:[]
            ~doc:"Token used by the command"
        ; abstract_field "amount" ~typ:(non_null amount) ~args:[]
            ~doc:
              "Amount that the source is sending to receiver - 0 for commands \
               that are not associated with an amount"
        ; abstract_field "feeToken" ~typ:(non_null token_id) ~args:[]
            ~doc:"Token used to pay the fee"
        ; abstract_field "fee" ~typ:(non_null fee) ~args:[]
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
        ; abstract_field "failureReason"
            ~typ:
              (Mina_base_unix.Graphql_scalars.TransactionStatusFailure.typ ())
            ~args:[] ~doc:"null is no failure, reason for failure otherwise."
        ] )

  module With_status = struct
    type 'a t = { data : 'a; status : Command_status.t }

    let map t ~f = { t with data = f t.data }
  end

  let field_no_status ?doc ?deprecated lab ~typ ~args ~resolve =
    field ?doc ?deprecated lab ~typ ~args ~resolve:(fun c uc ->
        resolve c uc.With_status.data )

  let user_command_shared_fields :
      ( Mina_lib.t
      , (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t )
      field
      list =
    [ field_no_status "id" ~typ:(non_null transaction_id) ~args:[]
        ~resolve:(fun _ user_command ->
          Signed_command user_command.With_hash.data )
    ; field_no_status "hash" ~typ:(non_null transaction_hash) ~args:[]
        ~resolve:(fun _ user_command -> user_command.With_hash.hash)
    ; field_no_status "kind" ~typ:(non_null kind) ~args:[]
        ~doc:"String describing the kind of user command" ~resolve:(fun _ cmd ->
          to_kind cmd.With_hash.data )
    ; field_no_status "nonce" ~typ:(non_null int) ~args:[]
        ~doc:"Sequence number of command for the fee-payer's account"
        ~resolve:(fun _ payment ->
          Signed_command_payload.nonce
          @@ Signed_command.payload payment.With_hash.data
          |> Account.Nonce.to_int )
    ; field_no_status "source" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account that the command is sent from"
        ~resolve:(fun { ctx = mina; _ } cmd ->
          AccountObj.get_best_ledger_account mina
            (Signed_command.fee_payer cmd.With_hash.data) )
    ; field_no_status "receiver" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account that the command applies to"
        ~resolve:(fun { ctx = mina; _ } cmd ->
          AccountObj.get_best_ledger_account mina
            (Signed_command.receiver cmd.With_hash.data) )
    ; field_no_status "feePayer" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account that pays the fees for the command"
        ~deprecated:(Deprecated (Some "use source field instead"))
        ~resolve:(fun { ctx = mina; _ } cmd ->
          AccountObj.get_best_ledger_account mina
            (Signed_command.fee_payer cmd.With_hash.data) )
    ; field_no_status "validUntil" ~typ:(non_null global_slot_since_genesis)
        ~args:[]
        ~doc:
          "The global slot number after which this transaction cannot be \
           applied" ~resolve:(fun _ cmd ->
          Signed_command.valid_until cmd.With_hash.data )
    ; field_no_status "token" ~typ:(non_null token_id) ~args:[]
        ~doc:"Token used for the transaction" ~resolve:(fun _ cmd ->
          Signed_command.token cmd.With_hash.data )
    ; field_no_status "amount" ~typ:(non_null amount) ~args:[]
        ~doc:
          "Amount that the source is sending to receiver; 0 for commands \
           without an associated amount" ~resolve:(fun _ cmd ->
          match Signed_command.amount cmd.With_hash.data with
          | Some amount ->
              amount
          | None ->
              Currency.Amount.zero )
    ; field_no_status "feeToken" ~typ:(non_null token_id) ~args:[]
        ~doc:"Token used to pay the fee" ~resolve:(fun _ cmd ->
          Signed_command.fee_token cmd.With_hash.data )
    ; field_no_status "fee" ~typ:(non_null fee) ~args:[]
        ~doc:
          "Fee that the fee-payer is willing to pay for making the transaction"
        ~resolve:(fun _ cmd -> Signed_command.fee cmd.With_hash.data)
    ; field_no_status "memo" ~typ:(non_null string) ~args:[]
        ~doc:
          (sprintf
             "A short message from the sender, encoded with Base58Check, \
              version byte=0x%02X; byte 2 of the decoding is the message \
              length"
             (Char.to_int Base58_check.Version_bytes.user_command_memo) )
        ~resolve:(fun _ payment ->
          Signed_command_payload.memo
          @@ Signed_command.payload payment.With_hash.data
          |> Signed_command_memo.to_base58_check )
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
              false )
    ; field_no_status "from" ~typ:(non_null public_key) ~args:[]
        ~doc:"Public key of the sender"
        ~deprecated:(Deprecated (Some "use feePayer field instead"))
        ~resolve:(fun _ cmd -> Signed_command.fee_payer_pk cmd.With_hash.data)
    ; field_no_status "fromAccount" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"Account of the sender"
        ~deprecated:(Deprecated (Some "use feePayer field instead"))
        ~resolve:(fun { ctx = mina; _ } payment ->
          AccountObj.get_best_ledger_account mina
          @@ Signed_command.fee_payer payment.With_hash.data )
    ; field_no_status "to" ~typ:(non_null public_key) ~args:[]
        ~doc:"Public key of the receiver"
        ~deprecated:(Deprecated (Some "use receiver field instead"))
        ~resolve:(fun _ cmd -> Signed_command.receiver_pk cmd.With_hash.data)
    ; field_no_status "toAccount"
        ~typ:(non_null AccountObj.account)
        ~doc:"Account of the receiver"
        ~deprecated:(Deprecated (Some "use receiver field instead"))
        ~args:Arg.[]
        ~resolve:(fun { ctx = mina; _ } cmd ->
          AccountObj.get_best_ledger_account mina
          @@ Signed_command.receiver cmd.With_hash.data )
    ; field "failureReason"
        ~typ:(Mina_base_unix.Graphql_scalars.TransactionStatusFailure.typ ())
        ~args:[]
        ~doc:
          "null is no failure or status unknown, reason for failure otherwise."
        ~resolve:(fun _ uc ->
          match uc.With_status.status with
          | Applied | Enqueued ->
              None
          | Included_but_failed failures ->
              List.concat failures |> List.hd )
    ]

  let payment =
    obj "UserCommandPayment" ~fields:(fun _ -> user_command_shared_fields)

  let mk_payment = add_type user_command_interface payment

  let stake_delegation =
    obj "UserCommandDelegation" ~fields:(fun _ ->
        field_no_status "delegator" ~typ:(non_null AccountObj.account) ~args:[]
          ~resolve:(fun { ctx = mina; _ } cmd ->
            AccountObj.get_best_ledger_account mina
              (Signed_command.fee_payer cmd.With_hash.data) )
        :: field_no_status "delegatee" ~typ:(non_null AccountObj.account)
             ~args:[] ~resolve:(fun { ctx = mina; _ } cmd ->
               AccountObj.get_best_ledger_account mina
                 (Signed_command.receiver cmd.With_hash.data) )
        :: user_command_shared_fields )

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
        resolve c cmd.With_status.data )

  let zkapp_command =
    let conv
        (x : (Mina_lib.t, Zkapp_command.t) Fields_derivers_graphql.Schema.typ) :
        (Mina_lib.t, Zkapp_command.t) typ =
      Obj.magic x
    in
    obj "ZkappCommandResult" ~fields:(fun _ ->
        [ field_no_status "id"
            ~doc:"A Base64 string representing the zkApp command"
            ~typ:(non_null transaction_id) ~args:[]
            ~resolve:(fun _ zkapp_command ->
              Zkapp_command zkapp_command.With_hash.data )
        ; field_no_status "hash"
            ~doc:"A cryptographic hash of the zkApp command"
            ~typ:(non_null transaction_hash) ~args:[]
            ~resolve:(fun _ zkapp_command -> zkapp_command.With_hash.hash)
        ; field_no_status "zkappCommand"
            ~typ:(Zkapp_command.typ () |> conv)
            ~args:Arg.[]
            ~doc:"zkApp command representing the transaction"
            ~resolve:(fun _ zkapp_command -> zkapp_command.With_hash.data)
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
                          failures ) ~f:(fun f -> Some f) ) )
        ] )
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
                         { status; data = { t.data with data = c } } )
                | Zkapp_command _ ->
                    None ) )
      ; field "zkappCommands"
          ~doc:"List of zkApp commands included in this block"
          ~typ:(non_null @@ list @@ non_null Zkapp_command.zkapp_command)
          ~args:Arg.[]
          ~resolve:(fun _ { commands; _ } ->
            List.filter_map commands ~f:(fun t ->
                match t.data.data with
                | Signed_command _ ->
                    None
                | Zkapp_command zkapp_command ->
                    let status =
                      match t.status with
                      | Applied ->
                          Command_status.Applied
                      | Failed e ->
                          Command_status.Included_but_failed e
                    in
                    Some
                      { Zkapp_command.With_status.status
                      ; data = { t.data with data = zkapp_command }
                      } ) )
      ; field "feeTransfer" ~doc:"List of fee transfers included in this block"
          ~typ:(non_null @@ list @@ non_null fee_transfer)
          ~args:Arg.[]
          ~resolve:(fun _ { fee_transfers; _ } -> fee_transfers)
      ; field "coinbase" ~typ:(non_null amount)
          ~doc:"Amount of MINA granted to the producer of this block"
          ~args:Arg.[]
          ~resolve:(fun _ { coinbase; _ } -> coinbase)
      ; field "coinbaseReceiverAccount" ~typ:AccountObj.account
          ~doc:"Account to which the coinbase for this block was granted"
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } { coinbase_receiver; _ } ->
            Option.map
              ~f:(AccountObj.get_best_ledger_account_pk mina)
              coinbase_receiver )
      ] )

let protocol_state_proof : (Mina_lib.t, Proof.t option) typ =
  obj "protocolStateProof" ~fields:(fun _ ->
      [ field "base64" ~typ:precomputed_block_proof ~doc:"Base-64 encoded proof"
          ~args:Arg.[]
          ~resolve:(fun _ proof ->
            (* Use the precomputed block proof encoding, for consistency. *)
            Some proof )
      ; field "json" ~typ:json ~doc:"JSON-encoded proof"
          ~args:Arg.[]
          ~resolve:(fun _ proof ->
            Some (Yojson.Safe.to_basic (Proof.to_yojson_full proof)) )
      ] )

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
          ~resolve:(fun { ctx = mina; _ } { With_hash.data; _ } ->
            AccountObj.get_best_ledger_account_pk mina data.creator )
      ; field "winnerAccount"
          ~typ:(non_null AccountObj.account)
          ~doc:"Account that won the slot (Delegator/Staker)"
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } { With_hash.data; _ } ->
            AccountObj.get_best_ledger_account_pk mina data.winner )
      ; field "stateHash" ~typ:(non_null state_hash)
          ~doc:"Base58Check-encoded hash of the state after this block"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.hash; _ } -> hash)
      ; field "stateHashField"
          ~typ:
            ( non_null
            @@ Data_hash_lib_unix.Graphql_scalars.StateHashAsDecimal.typ () )
          ~doc:"Experimental: Bigint field-element representation of stateHash"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.hash; _ } -> hash)
      ; field "protocolState" ~typ:(non_null protocol_state)
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; With_hash.hash; _ } ->
            (data.protocol_state, hash) )
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
            List.length data.transactions.commands )
      ; field "snarkJobs"
          ~typ:(non_null @@ list @@ non_null completed_work)
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; _ } -> data.snark_jobs)
      ] )

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
          ~resolve:(fun { ctx = mina; _ } (key, _) ->
            AccountObj.get_best_ledger_account_pk mina key )
      ; field "fee" ~typ:(non_null fee)
          ~doc:"Fee that snark worker is charging to generate a snark proof"
          ~args:Arg.[]
          ~resolve:(fun (_ : Mina_lib.t resolve_info) (_, fee) -> fee)
      ] )

module Payload = struct
  let peer : (Mina_lib.t, Network_peer.Peer.t option) typ =
    obj "NetworkPeerPayload" ~fields:(fun _ ->
        [ field "peerId" ~doc:"base58-encoded peer ID" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ peer -> peer.Network_peer.Peer.peer_id)
        ; field "host" ~doc:"IP address of the remote host"
            ~typ:(non_null @@ Graphql_basic_scalars.InetAddr.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ peer -> peer.Network_peer.Peer.host)
        ; field "libp2pPort" ~typ:(non_null int)
            ~args:Arg.[]
            ~resolve:(fun _ peer -> peer.Network_peer.Peer.libp2p_port)
        ] )

  let create_account : (Mina_lib.t, Account.key option) typ =
    obj "AddAccountPayload" ~fields:(fun _ ->
        [ field "publicKey" ~typ:(non_null public_key)
            ~doc:"Public key of the created account"
            ~deprecated:(Deprecated (Some "use account field instead"))
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ; field "account"
            ~typ:(non_null AccountObj.account)
            ~doc:"Details of created account"
            ~args:Arg.[]
            ~resolve:(fun { ctx = mina; _ } key ->
              AccountObj.get_best_ledger_account_pk mina key )
        ] )

  let unlock_account : (Mina_lib.t, Account.key option) typ =
    obj "UnlockPayload" ~fields:(fun _ ->
        [ field "publicKey" ~typ:(non_null public_key)
            ~doc:"Public key of the unlocked account"
            ~deprecated:(Deprecated (Some "use account field instead"))
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ; field "account"
            ~typ:(non_null AccountObj.account)
            ~doc:"Details of unlocked account"
            ~args:Arg.[]
            ~resolve:(fun { ctx = mina; _ } key ->
              AccountObj.get_best_ledger_account_pk mina key )
        ] )

  let lock_account : (Mina_lib.t, Account.key option) typ =
    obj "LockPayload" ~fields:(fun _ ->
        [ field "publicKey" ~typ:(non_null public_key)
            ~doc:"Public key of the locked account"
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ; field "account"
            ~typ:(non_null AccountObj.account)
            ~doc:"Details of locked account"
            ~args:Arg.[]
            ~resolve:(fun { ctx = mina; _ } key ->
              AccountObj.get_best_ledger_account_pk mina key )
        ] )

  let delete_account =
    obj "DeleteAccountPayload" ~fields:(fun _ ->
        [ field "publicKey" ~typ:(non_null public_key)
            ~doc:"Public key of the deleted account"
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let reload_accounts =
    obj "ReloadAccountsPayload" ~fields:(fun _ ->
        [ field "success" ~typ:(non_null bool)
            ~doc:"True when the reload was successful"
            ~args:Arg.[]
            ~resolve:(fun (_ : Mina_lib.t resolve_info) -> Fn.id)
        ] )

  let import_account =
    obj "ImportAccountPayload" ~fields:(fun _ ->
        [ field "publicKey" ~doc:"The public key of the imported account"
            ~typ:(non_null public_key)
            ~args:Arg.[]
            ~resolve:(fun _ -> fst)
        ; field "alreadyImported"
            ~doc:"True if the account had already been imported"
            ~typ:(non_null bool)
            ~args:Arg.[]
            ~resolve:(fun _ -> snd)
        ; field "success" ~typ:(non_null bool)
            ~args:Arg.[]
            ~resolve:(fun _ _ -> true)
        ] )

  let time_of_banned_status = function
    | Trust_system.Banned_status.Unbanned ->
        None
    | Banned_until tm ->
        Some tm

  let trust_status =
    obj "TrustStatusPayload" ~fields:(fun _ ->
        let open Trust_system.Peer_status in
        [ field "ipAddr"
            ~typ:(non_null @@ Graphql_basic_scalars.InetAddr.typ ())
            ~doc:"IP address"
            ~args:Arg.[]
            ~resolve:(fun (_ : Mina_lib.t resolve_info) (peer, _) ->
              peer.Network_peer.Peer.host )
        ; field "peerId" ~typ:(non_null string) ~doc:"libp2p Peer ID"
            ~args:Arg.[]
            ~resolve:(fun _ (peer, __) -> peer.Network_peer.Peer.peer_id)
        ; field "trust" ~typ:(non_null float) ~doc:"Trust score"
            ~args:Arg.[]
            ~resolve:(fun _ (_, { trust; _ }) -> trust)
        ; field "bannedStatus"
            ~typ:(Graphql_basic_scalars.Time.typ ())
            ~doc:"Banned status"
            ~args:Arg.[]
            ~resolve:(fun _ (_, { banned; _ }) -> time_of_banned_status banned)
        ] )

  let send_payment =
    obj "SendPaymentPayload" ~fields:(fun _ ->
        [ field "payment"
            ~typ:(non_null User_command.user_command)
            ~doc:"Payment that was sent"
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let send_delegation =
    obj "SendDelegationPayload" ~fields:(fun _ ->
        [ field "delegation"
            ~typ:(non_null User_command.user_command)
            ~doc:"Delegation change that was sent"
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let send_zkapp =
    obj "SendZkappPayload" ~fields:(fun _ ->
        [ field "zkapp"
            ~typ:(non_null Zkapp_command.zkapp_command)
            ~doc:"zkApp transaction that was sent"
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let send_rosetta_transaction =
    obj "SendRosettaTransactionPayload" ~fields:(fun _ ->
        [ field "userCommand"
            ~typ:(non_null User_command.user_command_interface)
            ~doc:"Command that was sent"
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let export_logs =
    obj "ExportLogsPayload" ~fields:(fun _ ->
        [ field "exportLogs"
            ~typ:
              (non_null
                 (obj "TarFile" ~fields:(fun _ ->
                      [ field "tarfile" ~typ:(non_null string) ~args:[]
                          ~resolve:(fun _ basename -> basename)
                      ] ) ) )
            ~doc:"Tar archive containing logs"
            ~args:Arg.[]
            ~resolve:(fun (_ : Mina_lib.t resolve_info) -> Fn.id)
        ] )

  let set_coinbase_receiver =
    obj "SetCoinbaseReceiverPayload" ~fields:(fun _ ->
        [ field "lastCoinbaseReceiver"
            ~doc:
              "Returns the public key that was receiving coinbases previously, \
               or none if it was the block producer"
            ~typ:public_key
            ~args:Arg.[]
            ~resolve:(fun _ (last_receiver, _) -> last_receiver)
        ; field "currentCoinbaseReceiver"
            ~doc:
              "Returns the public key that will receive coinbase, or none if \
               it will be the block producer"
            ~typ:public_key
            ~args:Arg.[]
            ~resolve:(fun _ (_, current_receiver) -> current_receiver)
        ] )

  let set_snark_work_fee =
    obj "SetSnarkWorkFeePayload" ~fields:(fun _ ->
        [ field "lastFee" ~doc:"Returns the last fee set to do snark work"
            ~typ:(non_null fee)
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let set_snark_worker =
    obj "SetSnarkWorkerPayload" ~fields:(fun _ ->
        [ field "lastSnarkWorker"
            ~doc:
              "Returns the last public key that was designated for snark work"
            ~typ:public_key
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ] )

  let set_connection_gating_config =
    obj "SetConnectionGatingConfigPayload" ~fields:(fun _ ->
        [ field "trustedPeers"
            ~typ:(non_null (list (non_null peer)))
            ~doc:"Peers we will always allow connections from"
            ~args:Arg.[]
            ~resolve:(fun _ config -> config.Mina_net2.trusted_peers)
        ; field "bannedPeers"
            ~typ:(non_null (list (non_null peer)))
            ~doc:
              "Peers we will never allow connections from (unless they are \
               also trusted!)"
            ~args:Arg.[]
            ~resolve:(fun _ config -> config.Mina_net2.banned_peers)
        ; field "isolate" ~typ:(non_null bool)
            ~doc:
              "If true, no connections will be allowed unless they are from a \
               trusted peer"
            ~args:Arg.[]
            ~resolve:(fun _ config -> config.Mina_net2.isolate)
        ] )
end

module Arguments = struct
  let ip_address ~name ip_addr =
    Utils.result_of_exn Unix.Inet_addr.of_string ip_addr
      ~error:(sprintf !"%s is not valid." name)
end

module Input = struct
  open Schema.Arg

  module NetworkPeer = struct
    type input = Network_peer.Peer.t

    let arg_typ : ((Network_peer.Peer.t, string) result option, _) arg_typ =
      obj "NetworkPeer"
        ~doc:"Network identifiers for another protocol participant"
        ~coerce:(fun peer_id host libp2p_port ->
          try
            Ok
              Network_peer.Peer.
                { peer_id; host = Unix.Inet_addr.of_string host; libp2p_port }
          with _ -> Error "Invalid format for NetworkPeer.host" )
        ~fields:
          [ arg "peerId" ~doc:"base58-encoded peer ID" ~typ:(non_null string)
          ; arg "host" ~doc:"IP address of the remote host"
              ~typ:(non_null string)
          ; arg "libp2pPort" ~typ:(non_null int)
          ]
        ~split:(fun f (p : input) ->
          f p.peer_id (Unix.Inet_addr.to_string p.host) p.libp2p_port )
  end

  module PublicKey = struct
    type input = Public_key.Compressed.t

    let arg_typ =
      scalar "PublicKey" ~doc:"Public key in Base58Check format"
        ~coerce:(fun pk ->
          match pk with
          | `String s ->
              Result.map_error
                (Public_key.Compressed.of_base58_check s)
                ~f:Error.to_string_hum
          | _ ->
              Error "Expected public key as a string in Base58Check format" )
        ~to_json:(function
          | k -> `String (Public_key.Compressed.to_base58_check k) )
  end

  module PrivateKey = struct
    type input = Signature_lib.Private_key.t

    let arg_typ =
      scalar "PrivateKey" ~doc:"Base58Check-encoded private key"
        ~coerce:Signature_lib.Private_key.of_yojson
        ~to_json:Signature_lib.Private_key.to_yojson
  end

  module TokenId = struct
    type input = Token_id.t

    let arg_typ =
      scalar "TokenId" ~doc:"Base58Check representation of a token identifier"
        ~coerce:(fun token ->
          try
            match token with
            | `String token ->
                Ok (Token_id.of_string token)
            | _ ->
                Error "Invalid format for token."
          with _ -> Error "Invalid format for token." )
        ~to_json:(function (i : input) -> `String (Token_id.to_string i))
  end

  module Sign = struct
    type input = Sgn.t

    let arg_typ =
      enum "Sign"
        ~values:
          [ enum_value "PLUS" ~value:Sgn.Pos
          ; enum_value "MINUS" ~value:Sgn.Neg
          ]
  end

  module Field = struct
    type input = Snark_params.Tick0.Field.t

    let arg_typ =
      scalar "Field"
        ~coerce:(fun field ->
          match field with
          | `String s ->
              Ok (Snark_params.Tick.Field.of_string s)
          | _ ->
              Error "Expected a string representing a field element" )
        ~to_json:(function
          | (f : input) -> `String (Snark_params.Tick.Field.to_string f) )
  end

  module Nonce = struct
    type input = Mina_base.Account.Nonce.t

    let arg_typ =
      scalar "Nonce"
        ~coerce:(fun nonce ->
          (* of_string might raise *)
          try
            match nonce with
            | `String s ->
                (* a nonce is a uint32, GraphQL ints are signed int32, so use string *)
                Ok (Mina_base.Account.Nonce.of_string s)
            | _ ->
                Error "Expected string for nonce"
          with exn -> Error (Exn.to_string exn) )
        ~to_json:(function n -> `String (Mina_base.Account.Nonce.to_string n))
  end

  module SnarkedLedgerHash = struct
    type input = Frozen_ledger_hash.t

    let arg_typ =
      scalar "SnarkedLedgerHash"
        ~coerce:(fun hash ->
          match hash with
          | `String s ->
              Result.map_error
                (Frozen_ledger_hash.of_base58_check s)
                ~f:Error.to_string_hum
          | _ ->
              Error "Expected snarked ledger hash in Base58Check format" )
        ~to_json:(function
          | (h : input) -> `String (Frozen_ledger_hash.to_base58_check h) )
  end

  module BlockTime = struct
    type input = Block_time.t

    let arg_typ =
      scalar "BlockTime"
        ~coerce:(fun block_time ->
          match block_time with
          | `String s -> (
              try
                (* a block time is a uint64, GraphQL ints are signed int32, so use string *)
                (* of_string might raise *)
                Ok (Block_time.of_string_exn s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for block time" )
        ~to_json:(function (t : input) -> `String (Block_time.to_string_exn t))
  end

  module Length = struct
    type input = Mina_numbers.Length.t

    let arg_typ =
      scalar "Length"
        ~coerce:(fun length ->
          (* of_string might raise *)
          match length with
          | `String s -> (
              try
                (* a length is a uint32, GraphQL ints are signed int32, so use string *)
                Ok (Mina_numbers.Length.of_string s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for length" )
        ~to_json:(function
          | (l : input) -> `String (Mina_numbers.Length.to_string l) )
  end

  module CurrencyAmount = struct
    type input = Currency.Amount.t

    let arg_typ =
      scalar "CurrencyAmount"
        ~coerce:(fun amt ->
          match amt with
          | `String s -> (
              try Ok (Currency.Amount.of_string s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for currency amount" )
        ~to_json:(function
          | (c : input) -> `String (Currency.Amount.to_string c) )
        ~doc:
          "uint64 encoded as a json string representing an ammount of currency"
  end

  module Fee = struct
    type input = Currency.Fee.t

    let arg_typ =
      scalar "Fee"
        ~coerce:(fun fee ->
          match fee with
          | `String s -> (
              try Ok (Currency.Fee.of_string s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for fee" )
        ~to_json:(function (f : input) -> `String (Currency.Fee.to_string f))
        ~doc:"uint64 encoded as a json string representing a fee"
  end

  module SendTestZkappInput = struct
    type input = Mina_base.Zkapp_command.t

    let arg_typ =
      scalar "SendTestZkappInput" ~doc:"zkApp command for a test zkApp"
        ~coerce:(fun json ->
          let json = Utils.to_yojson json in
          Result.try_with (fun () -> Mina_base.Zkapp_command.of_json json)
          |> Result.map_error ~f:(fun ex -> Exn.to_string ex) )
        ~to_json:(fun (x : input) ->
          Yojson.Safe.to_basic @@ Mina_base.Zkapp_command.to_json x )
  end

  module PrecomputedBlock = struct
    type input = Mina_block.Precomputed.t

    let arg_typ =
      scalar "PrecomputedBlock" ~doc:"Block encoded in precomputed block format"
        ~coerce:(fun json ->
          let json = Utils.to_yojson json in
          Mina_block.Precomputed.of_yojson json )
        ~to_json:(fun (x : input) ->
          Yojson.Safe.to_basic (Mina_block.Precomputed.to_yojson x) )
  end

  module ExtensionalBlock = struct
    type input = Archive_lib.Extensional.Block.t

    let arg_typ =
      scalar "ExtensionalBlock" ~doc:"Block encoded in extensional block format"
        ~coerce:(fun json ->
          let json = Utils.to_yojson json in
          Archive_lib.Extensional.Block.of_yojson json )
        ~to_json:(fun (x : input) ->
          Yojson.Safe.to_basic @@ Archive_lib.Extensional.Block.to_yojson x )
  end

  module type Numeric_type = sig
    type t

    val to_string : t -> string

    val of_string : string -> t

    val of_int : int -> t

    val to_int : t -> int
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
           lower_name )
      ~to_json:(function n -> `String (Numeric.to_string n))
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
            Error (sprintf "Invalid format for %s type." lower_name) )

  module UInt64 = struct
    type input = Unsigned.UInt64.t

    let arg_typ = make_numeric_arg ~name:"UInt64" (module Unsigned.UInt64)
  end

  module UInt32 = struct
    type input = Unsigned.UInt32.t

    let arg_typ = make_numeric_arg ~name:"UInt32" (module Unsigned.UInt32)
  end

  module SignatureInput = struct
    open Snark_params.Tick

    type input =
      | Raw of Signature.t
      | Field_and_scalar of Field.t * Inner_curve.Scalar.t

    let arg_typ =
      obj "SignatureInput"
        ~coerce:(fun field scalar rawSignature ->
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
                  Error "Either field+scalar or rawSignature must by non-null" )
          )
        ~doc:
          "A cryptographic signature -- you must provide either field+scalar \
           or rawSignature"
        ~fields:
          [ arg "field" ~typ:string ~doc:"Field component of signature"
          ; arg "scalar" ~typ:string ~doc:"Scalar component of signature"
          ; arg "rawSignature" ~typ:string ~doc:"Raw encoded signature"
          ]
        ~split:(fun f (input : input) ->
          match input with
          | Raw (s : Signature.t) ->
              f None None (Some (Signature.Raw.encode s))
          | Field_and_scalar (field, scalar) ->
              f
                (Some (Field.to_string field))
                (Some (Inner_curve.Scalar.to_string scalar))
                None )
  end

  module VrfMessageInput = struct
    type input = Consensus_vrf.Layout.Message.t

    let arg_typ =
      obj "VrfMessageInput" ~doc:"The inputs to a vrf evaluation"
        ~coerce:(fun global_slot epoch_seed delegator_index ->
          { Consensus_vrf.Layout.Message.global_slot =
              Mina_numbers.Global_slot_since_hard_fork.of_uint32 global_slot
          ; epoch_seed = Mina_base.Epoch_seed.of_base58_check_exn epoch_seed
          ; delegator_index
          } )
        ~fields:
          [ arg "globalSlot" ~typ:(non_null UInt32.arg_typ)
          ; arg "epochSeed" ~doc:"Formatted with base58check"
              ~typ:(non_null string)
          ; arg "delegatorIndex"
              ~doc:"Position in the ledger of the delegator's account"
              ~typ:(non_null int)
          ]
        ~split:(fun f (t : input) ->
          f
            (Mina_numbers.Global_slot_since_hard_fork.to_uint32 t.global_slot)
            (Mina_base.Epoch_seed.to_base58_check t.epoch_seed)
            t.delegator_index )
  end

  module VrfThresholdInput = struct
    type input = Consensus_vrf.Layout.Threshold.t

    let arg_typ =
      obj "VrfThresholdInput"
        ~doc:
          "The amount of stake delegated, used to determine the threshold for \
           a vrf evaluation producing a block"
        ~coerce:(fun delegated_stake total_stake ->
          { Consensus_vrf.Layout.Threshold.delegated_stake =
              Currency.Balance.of_uint64 delegated_stake
          ; total_stake = Currency.Amount.of_uint64 total_stake
          } )
        ~fields:
          [ arg "delegatedStake"
              ~doc:
                "The amount of stake delegated to the vrf evaluator by the \
                 delegating account. This should match the amount in the \
                 epoch's staking ledger, which may be different to the amount \
                 in the current ledger."
              ~typ:(non_null UInt64.arg_typ)
          ; arg "totalStake"
              ~doc:
                "The total amount of stake across all accounts in the epoch's \
                 staking ledger."
              ~typ:(non_null UInt64.arg_typ)
          ]
        ~split:(fun f (t : input) ->
          f
            (Currency.Balance.to_uint64 t.delegated_stake)
            (Currency.Amount.to_uint64 t.total_stake) )
  end

  module VrfEvaluationInput = struct
    type input = Consensus_vrf.Layout.Evaluation.t

    let arg_typ =
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
          } )
        ~split:(fun f (x : input) ->
          f x.message
            (Public_key.compress x.public_key)
            (Snark_params.Tick.Inner_curve.Scalar.to_string x.c)
            (Snark_params.Tick.Inner_curve.Scalar.to_string x.s)
            (Consensus_vrf.Group.to_string_list_exn x.scaled_message_hash)
            x.vrf_threshold )
        ~fields:
          [ arg "message" ~typ:(non_null VrfMessageInput.arg_typ)
          ; arg "publicKey" ~typ:(non_null PublicKey.arg_typ)
          ; arg "c" ~typ:(non_null string)
          ; arg "s" ~typ:(non_null string)
          ; arg "scaledMessageHash" ~typ:(non_null (list (non_null string)))
          ; arg "vrfThreshold" ~typ:VrfThresholdInput.arg_typ
          ]
  end

  module Fields = struct
    let from ~doc = arg "from" ~typ:(non_null PublicKey.arg_typ) ~doc

    let to_ ~doc = arg "to" ~typ:(non_null PublicKey.arg_typ) ~doc

    let token ~doc = arg "token" ~typ:(non_null TokenId.arg_typ) ~doc

    let token_opt ~doc = arg "token" ~typ:TokenId.arg_typ ~doc

    let token_owner ~doc =
      arg "tokenOwner" ~typ:(non_null PublicKey.arg_typ) ~doc

    let receiver ~doc = arg "receiver" ~typ:(non_null PublicKey.arg_typ) ~doc

    let receiver_opt ~doc = arg "receiver" ~typ:PublicKey.arg_typ ~doc

    let fee_payer_opt ~doc = arg "feePayer" ~typ:PublicKey.arg_typ ~doc

    let fee ~doc = arg "fee" ~typ:(non_null UInt64.arg_typ) ~doc

    let amount ~doc = arg "amount" ~typ:(non_null UInt64.arg_typ) ~doc

    let memo =
      arg "memo" ~typ:string
        ~doc:"Short arbitrary message provided by the sender"

    let valid_until =
      arg "validUntil" ~typ:UInt32.arg_typ
        ~doc:
          "The global slot since genesis after which this transaction cannot \
           be applied"

    let nonce =
      arg "nonce" ~typ:UInt32.arg_typ
        ~doc:
          "Should only be set when cancelling transactions, otherwise a nonce \
           is determined automatically"

    let signature =
      arg "signature" ~typ:SignatureInput.arg_typ
        ~doc:
          "If a signature is provided, this transaction is considered signed \
           and will be broadcasted to the network without requiring a private \
           key"

    let senders =
      arg "senders"
        ~typ:(non_null (list (non_null PrivateKey.arg_typ)))
        ~doc:"The private keys from which to sign the payments"

    let repeat_count =
      arg "repeat_count" ~typ:(non_null UInt32.arg_typ)
        ~doc:"How many times shall transaction be repeated"

    let repeat_delay_ms =
      arg "repeat_delay_ms" ~typ:(non_null UInt32.arg_typ)
        ~doc:"Delay with which a transaction shall be repeated"
  end

  module SendPaymentInput = struct
    type input =
      { from : (Epoch_seed.t, bool) Public_key.Compressed.Poly.t
      ; to_ : Account.key
      ; amount : Currency.Amount.t
      ; fee : Currency.Fee.t
      ; valid_until : UInt32.input option
      ; memo : string option
      ; nonce : Mina_numbers.Account_nonce.t option
      }
    [@@deriving make]

    let arg_typ =
      let open Fields in
      obj "SendPaymentInput"
        ~coerce:(fun from to_ amount fee valid_until memo nonce ->
          (from, to_, amount, fee, valid_until, memo, nonce) )
        ~split:(fun f (x : input) ->
          f x.from x.to_
            (Currency.Amount.to_uint64 x.amount)
            (Currency.Fee.to_uint64 x.fee)
            x.valid_until x.memo x.nonce )
        ~fields:
          [ from ~doc:"Public key of sender of payment"
          ; to_ ~doc:"Public key of recipient of payment"
          ; amount ~doc:"Amount of MINA to send to receiver"
          ; fee ~doc:"Fee amount in order to send payment"
          ; valid_until
          ; memo
          ; nonce
          ]
  end

  module SendZkappInput = struct
    type input = SendTestZkappInput.input

    let arg_typ =
      let conv
          (x :
            Mina_base.Zkapp_command.t Fields_derivers_graphql.Schema.Arg.arg_typ
            ) : Mina_base.Zkapp_command.t Graphql_async.Schema.Arg.arg_typ =
        Obj.magic x
      in
      let arg_typ =
        { arg_typ = Mina_base.Zkapp_command.arg_typ () |> conv
        ; to_json =
            (function
            | x ->
                Yojson.Safe.to_basic
                  (Mina_base.Zkapp_command.zkapp_command_to_json x) )
        }
      in
      obj "SendZkappInput" ~coerce:Fn.id
        ~split:(fun f (x : input) -> f x)
        ~fields:
          [ arg "zkappCommand"
              ~doc:"zkApp command structure representing the transaction"
              ~typ:arg_typ
          ]
  end

  module SendDelegationInput = struct
    type input =
      { from : PublicKey.input
      ; to_ : PublicKey.input
      ; fee : Currency.Fee.t
      ; valid_until : UInt32.input option
      ; memo : string option
      ; nonce : UInt32.input option
      }
    [@@deriving make]

    let arg_typ =
      let open Fields in
      obj "SendDelegationInput"
        ~coerce:(fun from to_ fee valid_until memo nonce ->
          (from, to_, fee, valid_until, memo, nonce) )
        ~split:(fun f (x : input) ->
          f x.from x.to_
            (Currency.Fee.to_uint64 x.fee)
            x.valid_until x.memo x.nonce )
        ~fields:
          [ from ~doc:"Public key of sender of a stake delegation"
          ; to_ ~doc:"Public key of the account being delegated to"
          ; fee ~doc:"Fee amount in order to send a stake delegation"
          ; valid_until
          ; memo
          ; nonce
          ]
  end

  module RosettaTransaction = struct
    type input = Yojson.Basic.t

    let arg_typ =
      Schema.Arg.scalar "RosettaTransaction"
        ~doc:"A transaction encoded in the Rosetta format"
        ~coerce:(fun graphql_json ->
          Rosetta_lib.Transaction.to_mina_signed (Utils.to_yojson graphql_json)
          |> Result.map_error ~f:Error.to_string_hum )
        ~to_json:(Fn.id : input -> input)
  end

  module AddAccountInput = struct
    type input = string

    let arg_typ =
      obj "AddAccountInput" ~coerce:Fn.id
        ~fields:
          [ arg "password" ~doc:"Password used to encrypt the new account"
              ~typ:(non_null string)
          ]
        ~split:Fn.id
  end

  module UnlockInput = struct
    type input = Bytes.t * PublicKey.input

    let arg_typ =
      obj "UnlockInput"
        ~coerce:(fun password pk -> (password, pk))
        ~fields:
          [ arg "password" ~doc:"Password for the account to be unlocked"
              ~typ:(non_null string)
          ; arg "publicKey" ~doc:"Public key specifying which account to unlock"
              ~typ:(non_null PublicKey.arg_typ)
          ]
        ~split:(fun f ((password, pk) : input) ->
          f (Bytes.to_string password) pk )
  end

  module CreateHDAccountInput = struct
    type input = UInt32.input

    let arg_typ =
      obj "CreateHDAccountInput" ~coerce:Fn.id
        ~fields:
          [ arg "index" ~doc:"Index of the account in hardware wallet"
              ~typ:(non_null UInt32.arg_typ)
          ]
        ~split:Fn.id
  end

  module LockInput = struct
    type input = PublicKey.input

    let arg_typ =
      obj "LockInput" ~coerce:Fn.id
        ~fields:
          [ arg "publicKey" ~doc:"Public key specifying which account to lock"
              ~typ:(non_null PublicKey.arg_typ)
          ]
        ~split:Fn.id
  end

  module DeleteAccountInput = struct
    type input = PublicKey.input

    let arg_typ =
      obj "DeleteAccountInput" ~coerce:Fn.id
        ~fields:
          [ arg "publicKey" ~doc:"Public key of account to be deleted"
              ~typ:(non_null PublicKey.arg_typ)
          ]
        ~split:Fn.id
  end

  module ResetTrustStatusInput = struct
    type input = string

    let arg_typ =
      obj "ResetTrustStatusInput" ~coerce:Fn.id
        ~fields:[ arg "ipAddress" ~typ:(non_null string) ]
        ~split:Fn.id
  end

  module BlockFilterInput = struct
    type input = PublicKey.input

    (* TODO: Treat cases where filter_input has a null argument *)
    let arg_typ =
      obj "BlockFilterInput" ~coerce:Fn.id ~split:Fn.id
        ~fields:
          [ arg "relatedTo"
              ~doc:
                "A public key of a user who has their\n\
                \        transaction in the block, or produced the block"
              ~typ:(non_null PublicKey.arg_typ)
          ]
  end

  module UserCommandFilterType = struct
    type input = PublicKey.input

    let arg_typ =
      obj "UserCommandFilterType" ~coerce:Fn.id ~split:Fn.id
        ~fields:
          [ arg "toOrFrom"
              ~doc:
                "Public key of sender or receiver of transactions you are \
                 looking for"
              ~typ:(non_null PublicKey.arg_typ)
          ]
  end

  module SetCoinbaseReceiverInput = struct
    type input = PublicKey.input option

    let arg_typ =
      obj "SetCoinbaseReceiverInput" ~coerce:Fn.id ~split:Fn.id
        ~fields:
          [ arg "publicKey" ~typ:PublicKey.arg_typ
              ~doc:
                (sprintf
                   "Public key of the account to receive coinbases. Block \
                    production keys will receive the coinbases if omitted. %s"
                   Cli_lib.Default.receiver_key_warning )
          ]
  end

  module SetSnarkWorkFee = struct
    type input = UInt64.input

    let arg_typ =
      obj "SetSnarkWorkFee"
        ~fields:
          [ Fields.fee ~doc:"Fee to get rewarded for producing snark work" ]
        ~coerce:Fn.id ~split:Fn.id
  end

  module SetSnarkWorkerInput = struct
    type input = PublicKey.input option

    let arg_typ =
      obj "SetSnarkWorkerInput" ~coerce:Fn.id ~split:Fn.id
        ~fields:
          [ arg "publicKey" ~typ:PublicKey.arg_typ
              ~doc:
                (sprintf
                   "Public key you wish to start snark-working on; null to \
                    stop doing any snark work. %s"
                   Cli_lib.Default.receiver_key_warning )
          ]
  end

  module SetConnectionGatingConfigInput = struct
    type input =
      Mina_net2.connection_gating * [ `Clean_added_peers of bool option ]

    let arg_typ :
        ( ( Mina_net2.connection_gating * [ `Clean_added_peers of bool option ]
          , string )
          result
          option
        , input option )
        arg_typ =
      obj "SetConnectionGatingConfigInput"
        ~coerce:(fun trusted_peers banned_peers isolate clean_added_peers ->
          let open Result.Let_syntax in
          let%bind trusted_peers = Result.all trusted_peers in
          let%map banned_peers = Result.all banned_peers in
          ( Mina_net2.{ isolate; trusted_peers; banned_peers }
          , `Clean_added_peers clean_added_peers ) )
        ~split:(fun f ((t, `Clean_added_peers clean_added_peers) : input) ->
          f t.trusted_peers t.banned_peers t.isolate clean_added_peers )
        ~fields:
          Arg.
            [ arg "trustedPeers"
                ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
                ~doc:"Peers we will always allow connections from"
            ; arg "bannedPeers"
                ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
                ~doc:
                  "Peers we will never allow connections from (unless they are \
                   also trusted!)"
            ; arg "isolate" ~typ:(non_null bool)
                ~doc:
                  "If true, no connections will be allowed unless they are \
                   from a trusted peer"
            ; arg "cleanAddedPeers" ~typ:bool
                ~doc:
                  "If true, resets added peers to an empty list (including \
                   seeds)"
            ]
  end

  module Itn = struct
    module PaymentDetails = struct
      type input =
        { senders : Signature_lib.Private_key.t list
        ; receiver : Signature_lib.Public_key.Compressed.t
        ; amount : Currency.Amount.t
        ; min_fee : Currency.Fee.t
        ; max_fee : Currency.Fee.t
        ; memo_prefix : string
        ; tps : float
        ; duration_min : int
        }

      let arg_typ : ((input, string) result option, input option) arg_typ =
        obj "PaymentsDetails"
          ~doc:"Keys and other information for scheduling payments"
          ~coerce:(fun senders receiver amount min_fee max_fee memo_prefix tps
                       duration_min ->
            Result.return
              { senders
              ; receiver
              ; amount
              ; min_fee
              ; max_fee
              ; memo_prefix
              ; tps
              ; duration_min
              } )
          ~split:(fun f (t : input) ->
            f t.senders t.receiver t.amount t.min_fee t.max_fee t.memo_prefix
              t.tps t.duration_min )
          ~fields:
            Arg.
              [ arg "senders"
                  ~typ:(non_null (list (non_null PrivateKey.arg_typ)))
                  ~doc:"Private keys of accounts to send from"
              ; arg "receiver"
                  ~typ:(non_null PublicKey.arg_typ)
                  ~doc:"Public key of receiver of payments"
              ; arg "amount"
                  ~typ:(non_null CurrencyAmount.arg_typ)
                  ~doc:"Amount for payments"
              ; arg "minFee" ~typ:(non_null Fee.arg_typ) ~doc:"Minimum fee"
              ; arg "maxFee" ~typ:(non_null Fee.arg_typ) ~doc:"Maximum fee"
              ; arg "memoPrefix" ~doc:"Memo, up to 32 characters"
                  ~typ:(non_null string)
              ; arg "tps"
                  ~doc:"Frequency of transactions (transactions per second)"
                  ~typ:(non_null float)
              ; arg "durationMin" ~doc:"Length of scheduler run, in minutes"
                  ~typ:(non_null int)
              ]
    end

    module ZkappCommandsDetails = struct
      type input =
        { fee_payers : Signature_lib.Private_key.t list
        ; num_zkapps_to_deploy : int
        ; num_new_accounts : int
        ; tps : float
        ; duration_min : int
        ; memo_prefix : string
        ; no_precondition : bool
        ; init_balance : Currency.Amount.t
        ; min_fee : Currency.Fee.t
        ; max_fee : Currency.Fee.t
        ; deployment_fee : Currency.Fee.t
        ; account_queue_size : int
        ; max_cost : bool
        ; balance_change_range :
            Mina_generators.Zkapp_command_generators.balance_change_range_t
        ; max_account_updates : int option
        }

      let arg_typ : ((input, string) result option, input option) arg_typ =
        obj "ZkappCommandsDetails"
          ~doc:"Keys and other information for scheduling zkapp commands"
          ~coerce:(fun fee_payers num_zkapps_to_deploy num_new_accounts tps
                       duration_min memo_prefix no_precondition
                       min_balance_change max_balance_change
                       min_new_zkapp_balance max_new_zkapp_balance init_balance
                       min_fee max_fee deployment_fee account_queue_size
                       max_cost max_account_updates ->
            Result.return
              { fee_payers
              ; num_zkapps_to_deploy
              ; num_new_accounts
              ; tps
              ; duration_min
              ; memo_prefix
              ; no_precondition
              ; init_balance
              ; min_fee
              ; max_fee
              ; deployment_fee
              ; account_queue_size
              ; max_cost
              ; max_account_updates
              ; balance_change_range =
                  { min_balance_change
                  ; max_balance_change
                  ; min_new_zkapp_balance
                  ; max_new_zkapp_balance
                  }
              } )
          ~split:(fun f (t : input) ->
            f t.fee_payers t.num_zkapps_to_deploy t.num_new_accounts t.tps
              t.duration_min t.memo_prefix t.no_precondition
              t.balance_change_range.min_balance_change
              t.balance_change_range.max_balance_change
              t.balance_change_range.min_new_zkapp_balance
              t.balance_change_range.max_new_zkapp_balance t.init_balance
              t.min_fee t.max_fee t.deployment_fee t.account_queue_size
              t.max_cost t.max_account_updates )
          ~fields:
            Arg.
              [ arg "feePayers"
                  ~typ:(non_null (list (non_null PrivateKey.arg_typ)))
                  ~doc:
                    "Private keys of fee payers (fee payers also function as \
                     the account creators)"
              ; arg "numZkappsToDeploy" ~typ:(non_null int)
                  ~doc:
                    "Number of zkApp accounts that we initially deploy for the \
                     purpose of test"
              ; arg "numNewAccounts" ~typ:(non_null int)
                  ~doc:
                    "Number of zkapp accounts that the scheduler generates \
                     during the test"
              ; arg "tps" ~typ:(non_null float)
                  ~doc:"Frequency of transactions (transactions per seconds)"
              ; arg "durationMin" ~doc:"Length of scheduler run, in minutes"
                  ~typ:(non_null int)
              ; arg "memoPrefix" ~doc:"Prefix of memo" ~typ:(non_null string)
              ; arg "noPrecondition"
                  ~doc:"Disable the precondition in account updates"
                  ~typ:(non_null bool)
              ; arg "minBalanceChange" ~doc:"Minimum balance change"
                  ~typ:(non_null CurrencyAmount.arg_typ)
              ; arg "maxBalanceChange" ~doc:"Maximum balance change"
                  ~typ:(non_null CurrencyAmount.arg_typ)
              ; arg "minNewZkappBalance" ~doc:"Minimum new zkapp balance"
                  ~typ:(non_null CurrencyAmount.arg_typ)
              ; arg "maxNewZkappBalance" ~doc:"Maximum new zkapp balance"
                  ~typ:(non_null CurrencyAmount.arg_typ)
              ; arg "initBalance"
                  ~typ:(non_null CurrencyAmount.arg_typ)
                  ~doc:
                    "Initial balance for zkApp accounts that we initially \
                     deploy for the purpose of test"
              ; arg "minFee" ~doc:"Minimum fee" ~typ:(non_null Fee.arg_typ)
              ; arg "maxFee" ~doc:"Maximum fee" ~typ:(non_null Fee.arg_typ)
              ; arg "deploymentFee"
                  ~doc:"Fee for the initial deployment of zkApp accounts"
                  ~typ:(non_null Fee.arg_typ)
              ; arg "accountQueueSize"
                  ~doc:"The size of queue for recently used accounts"
                  ~typ:(non_null int)
              ; arg "maxCost" ~doc:"Generate max cost zkApp command"
                  ~typ:(non_null bool)
              ; arg "maxAccountUpdates"
                  ~doc:
                    "Parameter of zkapp generation, each generated zkapp tx \
                     will have (2*maxAccountUpdates+2) account updates \
                     (including balancing and fee payer)"
                  ~typ:int
              ]
    end

    module GatingUpdate = struct
      type input =
        { trusted_peers : Network_peer.Peer.t list
        ; banned_peers : Network_peer.Peer.t list
        ; isolate : bool
        ; clean_added_peers : bool
        ; added_peers : Network_peer.Peer.t list
        }

      let arg_typ =
        obj "GatingUpdate" ~doc:"Update to gating config and added peers"
          ~coerce:(fun trusted_peers banned_peers isolate clean_added_peers
                       added_peers ->
            let%bind.Result trusted_peers = Result.all trusted_peers in
            let%bind.Result banned_peers = Result.all banned_peers in
            let%map.Result added_peers = Result.all added_peers in
            { trusted_peers
            ; banned_peers
            ; isolate
            ; clean_added_peers
            ; added_peers
            } )
          ~split:(fun f (t : input) ->
            f t.trusted_peers t.banned_peers t.isolate t.clean_added_peers
              t.added_peers )
          ~fields:
            Arg.
              [ arg "trustedPeers"
                  ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
                  ~doc:"Peers we will always allow connections from"
              ; arg "bannedPeers"
                  ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
                  ~doc:
                    "Peers we will never allow connections from (unless they \
                     are also trusted!)"
              ; arg "isolate" ~typ:(non_null bool)
                  ~doc:
                    "If true, no connections will be allowed unless they are \
                     from a trusted peer"
              ; arg "cleanAddedPeers" ~typ:(non_null bool)
                  ~doc:
                    "If true, resets added peers to an empty list (including \
                     seeds)"
              ; arg "addedPeers"
                  ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
                  ~doc:"Peers to connect to"
              ]
    end
  end
end

let vrf_message : (Mina_lib.t, Consensus_vrf.Layout.Message.t option) typ =
  let open Consensus_vrf.Layout.Message in
  obj "VrfMessage" ~doc:"The inputs to a vrf evaluation" ~fields:(fun _ ->
      [ field "globalSlot"
          ~typ:(non_null global_slot_since_hard_fork)
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
      ] )

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
             current ledger." ~args:[] ~typ:(non_null balance)
          ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.delegated_stake; _ }
                   -> delegated_stake )
      ; field "totalStake"
          ~doc:
            "The total amount of stake across all accounts in the epoch's \
             staking ledger." ~args:[] ~typ:(non_null amount)
          ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.total_stake; _ } ->
            total_stake )
      ] )

let vrf_evaluation : (Mina_lib.t, Consensus_vrf.Layout.Evaluation.t option) typ
    =
  let open Consensus_vrf.Layout.Evaluation in
  let vrf_scalar = Graphql_lib.Scalars.VrfScalar.typ () in
  obj "VrfEvaluation"
    ~doc:"A witness to a vrf evaluation, which may be externally verified"
    ~fields:(fun _ ->
      [ field "message" ~typ:(non_null vrf_message)
          ~args:Arg.[]
          ~resolve:(fun _ { message; _ } -> message)
      ; field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ { public_key; _ } -> Public_key.compress public_key)
      ; field "c" ~typ:(non_null vrf_scalar)
          ~args:Arg.[]
          ~resolve:(fun _ { c; _ } -> c)
      ; field "s" ~typ:(non_null vrf_scalar)
          ~args:Arg.[]
          ~resolve:(fun _ { s; _ } -> s)
      ; field "scaledMessageHash"
          ~typ:(non_null (list (non_null string)))
          ~doc:"A group element represented as 2 field elements"
          ~args:Arg.[]
          ~resolve:(fun _ { scaled_message_hash; _ } ->
            Consensus_vrf.Group.to_string_list_exn scaled_message_hash )
      ; field "vrfThreshold" ~typ:vrf_threshold
          ~args:Arg.[]
          ~resolve:(fun _ { vrf_threshold; _ } -> vrf_threshold)
      ; field "vrfOutput"
          ~typ:(Graphql_lib.Scalars.VrfOutputTruncated.typ ())
          ~doc:
            "The vrf output derived from the evaluation witness. If null, the \
             vrf witness was invalid."
          ~args:Arg.[]
          ~resolve:(fun { ctx = mina; _ } t ->
            match t.vrf_output with
            | Some vrf ->
                Some vrf
            | None ->
                let constraint_constants =
                  (Mina_lib.config mina).precomputed_values.constraint_constants
                in
                to_vrf ~constraint_constants t
                |> Option.map ~f:Consensus_vrf.Output.truncate )
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
                    |> Bignum.to_float )
                  vrf_opt )
      ; field "thresholdMet" ~typ:bool
          ~doc:"Whether the threshold to produce a block was met, if specified"
          ~args:
            Arg.
              [ arg "input" ~doc:"Override for delegation threshold"
                  ~typ:Input.VrfThresholdInput.arg_typ
              ]
          ~resolve:(fun { ctx = mina; _ } t input ->
            match input with
            | Some { delegated_stake; total_stake } ->
                let constraint_constants =
                  (Mina_lib.config mina).precomputed_values.constraint_constants
                in
                (Consensus_vrf.Layout.Evaluation.compute_vrf
                   ~constraint_constants t ~delegated_stake ~total_stake )
                  .threshold_met
            | None ->
                t.threshold_met )
      ] )

let get_filtered_log_entries =
  obj "GetFilteredLogEntries" ~fields:(fun _ ->
      [ field "logMessages"
          ~typ:(non_null (list (non_null string)))
          ~doc:"Structured log messages since the given offset"
          ~args:Arg.[]
          ~resolve:(fun (_ : Mina_lib.t resolve_info) (logs, _) -> logs)
      ; field "isCapturing" ~typ:(non_null bool)
          ~doc:"Whether we are capturing structured log messages"
          ~args:Arg.[]
          ~resolve:(fun _ (_, is_started) -> is_started)
      ] )
