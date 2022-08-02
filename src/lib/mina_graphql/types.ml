open Core
open Async
open Graphql_async
open Mina_base
open Signature_lib
module Schema = Graphql_wrapper.Make (Schema)
open Schema
open Utils

include struct
  open Graphql_lib.Scalars

  let public_key = PublicKey.typ ()

  let uint64 = UInt64.typ ()

  let uint32 = UInt32.typ ()

  let json : (Mina_lib.t, Yojson.Basic.t option) typ = JSON.typ ()

  (* let epoch_seed = EpochSeed.typ () *)
end

(* let sync_status : ('context, Sync_status.t option) typ = *)
(*   enum "SyncStatus" ~doc:"Sync status of daemon" *)
(*     ~values: *)
(*     (List.map Sync_status.all ~f:(fun status -> *)
(*          enum_value *)
(*            (String.map ~f:Char.uppercase @@ Sync_status.to_string status) *)
(*            ~value:status ) ) *)

(* let transaction_status : *)
(*       (Mina_lib.t, Transaction_inclusion_status.State.t option) typ = *)
(*   enum "TransactionStatus" ~doc:"Status of a transaction" *)
(*     ~values: *)
(*     Transaction_inclusion_status.State. *)
(*   [ enum_value "INCLUDED" ~value:Included *)
(*       ~doc:"A transaction that is on the longest chain" *)
(*   ; enum_value "PENDING" ~value:Pending *)
(*       ~doc: *)
(*       "A transaction either in the transition frontier or in \ *)
(*        transaction pool but is not on the longest chain" *)
(*   ; enum_value "UNKNOWN" ~value:Unknown *)
(*       ~doc: *)
(*       "The transaction has either been snarked, reached finality \ *)
(*        through consensus or has been dropped" *)
(*   ] *)

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
            C.to_uint32 global_slot )
      ; field "startTime" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } global_slot ->
            let constants =
              (Mina_lib.config coda).precomputed_values.consensus_constants
            in
            Block_time.to_string @@ C.start_time ~constants global_slot )
      ; field "endTime" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } global_slot ->
            let constants =
              (Mina_lib.config coda).precomputed_values.consensus_constants
            in
            Block_time.to_string @@ C.end_time ~constants global_slot )
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
          ~typ:(non_null uint32)
          ~resolve:(fun _ (_, slot) -> slot)
    ] )

let block_producer_timing :
      (_, Daemon_rpcs.Types.Status.Next_producer_timing.t option) typ =
  obj "BlockProducerTimings" ~fields:(fun _ ->
      let of_time ~consensus_constants =
        Consensus.Data.Consensus_time.of_time_exn
          ~constants:consensus_constants
      in
      [ field "times"
          ~typ:(non_null @@ list @@ non_null consensus_time)
          ~doc:"Next block production time"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ }
                        { Daemon_rpcs.Types.Status.Next_producer_timing.timing
                        ; _
                        } ->
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
               [ of_time ~consensus_constants info.time ] )
      ; field "globalSlotSinceGenesis"
          ~typ:(non_null @@ list @@ non_null uint32)
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
          ~resolve:(fun { ctx = coda; _ }
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
            , global_slot_since_genesis ) )
    ] )

module DaemonStatus = struct
  type t = Daemon_rpcs.Types.Status.t

  (* let interval : (_, (Time.Span.t * Time.Span.t) option) typ = *)
  (*   obj "Interval" ~fields:(fun _ -> *)
  (*       [ field "start" ~typ:(non_null string) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ (start, _) -> *)
  (*             Time.Span.to_ms start |> Int64.of_float |> Int64.to_string ) *)
  (*       ; field "stop" ~typ:(non_null string) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ (_, end_) -> *)
  (*             Time.Span.to_ms end_ |> Int64.of_float |> Int64.to_string ) *)
  (*       ] ) *)

  (* let histogram : (_, Perf_histograms.Report.t option) typ = *)
  (*   obj "Histogram" ~fields:(fun _ -> *)
  (*       let open Reflection.Shorthand in *)
  (*       List.rev *)
  (*       @@ Perf_histograms.Report.Fields.fold ~init:[] *)
  (*            ~values:(id ~typ:Schema.(non_null (list (non_null int)))) *)
  (*            ~intervals:(id ~typ:(non_null (list (non_null interval)))) *)
  (*            ~underflow:nn_int ~overflow:nn_int ) *)

  let histograms = Daemon_rpcs.Graphql_objects.histograms ()

  module Rpc_timings = Daemon_rpcs.Types.Status.Rpc_timings
  module Rpc_pair = Rpc_timings.Rpc_pair

  (* let rpc_pair : (_, Perf_histograms.Report.t option Rpc_pair.t option) typ = *)
  (*   let h = Reflection.Shorthand.id ~typ:histogram in *)
  (*   obj "RpcPair" ~fields:(fun _ -> *)
  (*       List.rev @@ Rpc_pair.Fields.fold ~init:[] ~dispatch:h ~impl:h ) *)

  (* let rpc_timings : (_, Rpc_timings.t option) typ = *)
  (*   let fd = Reflection.Shorthand.id ~typ:(non_null rpc_pair) in *)
  (*   obj "RpcTimings" ~fields:(fun _ -> *)
  (*       List.rev *)
  (*       @@ Rpc_timings.Fields.fold ~init:[] ~get_staged_ledger_aux:fd *)
  (*            ~answer_sync_ledger_query:fd ~get_ancestry:fd *)
  (*            ~get_transition_chain_proof:fd ~get_transition_chain:fd ) *)

  (* module Histograms = Daemon_rpcs.Types.Status.Histograms *)

  (* let histograms : (_, Histograms.t option) typ = *)
  (*   let h = Reflection.Shorthand.id ~typ:histogram in *)
  (*   obj "Histograms" ~fields:(fun _ -> *)
  (*       let open Reflection.Shorthand in *)
  (*       List.rev *)
  (*       @@ Histograms.Fields.fold ~init:[] *)
  (*            ~rpc_timings:(id ~typ:(non_null rpc_timings)) *)
  (*            ~external_transition_latency:h *)
  (*            ~accepted_transition_local_latency:h *)
  (*            ~accepted_transition_remote_latency:h *)
  (*            ~snark_worker_transition_time:h ~snark_worker_merge_time:h ) *)

  (* let consensus_configuration : (_, Consensus.Configuration.t option) typ = *)
  (*   obj "ConsensusConfiguration" ~fields:(fun _ -> *)
  (*       let open Reflection.Shorthand in *)
  (*       List.rev *)
  (*       @@ Consensus.Configuration.Fields.fold ~init:[] ~delta:nn_int *)
  (*            ~k:nn_int ~slots_per_epoch:nn_int ~slot_duration:nn_int *)
  (*            ~epoch_duration:nn_int ~acceptable_network_delay:nn_int *)
  (*            ~genesis_state_timestamp:nn_time ) *)

  let consensus_configuration = Consensus.Graphql_objects.consensus_configuration ()
  let peer =  Network_peer_unix.Graphql_objects.peer ()
  let addrs_and_ports = Node_addrs_and_ports_unix.Graphql_objects.addrs_and_ports ()
  let metrics = Daemon_rpcs.Graphql_objects.metrics ()
  (* let addrs_and_ports : (_, Node_addrs_and_ports.Display.t option) typ = *)
 (*   obj "AddrsAndPorts" ~fields:(fun _ -> *)
  (*       let open Reflection.Shorthand in *)
  (*       List.rev *)
  (*       @@ Node_addrs_and_ports.Display.Fields.fold ~init:[] *)
  (*            ~external_ip:nn_string ~bind_ip:nn_string ~client_port:nn_int *)
  (*            ~libp2p_port:nn_int ~peer:(id ~typ:peer) ) *)

  (* let metrics : (_, Daemon_rpcs.Types.Status.Metrics.t option) typ = *)
  (*   obj "Metrics" ~fields:(fun _ -> *)
  (*       let open Reflection.Shorthand in *)
  (*       List.rev *)
  (*       @@ Daemon_rpcs.Types.Status.Metrics.Fields.fold ~init:[] *)
  (*            ~block_production_delay:nn_int_list *)
  (*            ~transaction_pool_diff_received:nn_int *)
  (*            ~transaction_pool_diff_broadcasted:nn_int *)
  (*            ~transactions_added_to_pool:nn_int ~transaction_pool_size:nn_int ) *)

  let t : (_, Daemon_rpcs.Types.Status.t option) typ =
    obj "DaemonStatus" ~fields:(fun _ ->
        let open Reflection.Shorthand in
        List.rev
        @@ Daemon_rpcs.Types.Status.Fields.fold ~init:[] ~num_accounts:int
             ~catchup_status:nn_catchup_status ~chain_id:nn_string
             ~next_block_production:(id ~typ:block_producer_timing)
             ~blockchain_length:int ~uptime_secs:nn_int
             ~ledger_merkle_root:string ~state_hash:string
             ~commit_id:nn_string ~conf_dir:nn_string
             ~peers:(id ~typ:(non_null (list (non_null peer))))
             ~user_commands_sent:nn_int ~snark_worker:string
             ~snark_work_fee:nn_int
             ~sync_status:(id ~typ:(non_null @@ Sync_status_unix.Graphql.sync_status ()))
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

let fee_transfer =
  obj "FeeTransfer" ~fields:(fun _ ->
      [ field "recipient"
          ~args:Arg.[]
          ~doc:"Public key of fee transfer recipient"
          ~typ:(non_null public_key)
          ~resolve:(fun _ ({ Fee_transfer.receiver_pk = pk; _ }, _) -> pk)
      ; field "fee" ~typ:(non_null uint64)
          ~args:Arg.[]
          ~doc:"Amount that the recipient is paid in this fee transfer"
          ~resolve:(fun _ ({ Fee_transfer.fee; _ }, _) ->
            Currency.Fee.to_uint64 fee )
      ; field "type" ~typ:(non_null string)
          ~args:Arg.[]
          ~doc:
          "Fee_transfer|Fee_transfer_via_coinbase Snark worker fees \
           deducted from the coinbase amount are of type \
           'Fee_transfer_via_coinbase', rest are deducted from transaction \
           fees"
          ~resolve:(fun _ (_, transfer_type) ->
            match transfer_type with
            | Filtered_external_transition.Fee_transfer_type
              .Fee_transfer_via_coinbase ->
               "Fee_transfer_via_coinbase"
            | Fee_transfer ->
               "Fee_transfer" )
    ] )


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
            Currency.Fee.to_uint64 fee )
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
      ; field "feeMagnitude" ~typ:(non_null uint64) ~doc:"Fee"
          ~args:Arg.[]
          ~resolve:(fun _ fee ->
            Currency.Amount.(to_uint64 (Signed.magnitude fee)) )
    ] )

let work_statement =
  obj "WorkDescription"
    ~doc:
    "Transition from a source ledger to a target ledger with some fee \
     excess and increase in supply " ~fields:(fun _ ->
      [ field "sourceLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the source ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.source; _ } ->
            Frozen_ledger_hash.to_base58_check source )
      ; field "targetLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the target ledger"
          ~args:Arg.[]
          ~resolve:(fun _ { Transaction_snark.Statement.target; _ } ->
            Frozen_ledger_hash.to_base58_check target )
      ; field "feeExcess" ~typ:(non_null signed_fee)
          ~doc:
          "Total transaction fee that is not accounted for in the \
           transition from source ledger to target ledger"
          ~args:Arg.[]
          ~resolve:(fun _
                        ({ fee_excess = { fee_excess_l; _ }; _ } :
                           Transaction_snark.Statement.t ) ->
            (* TODO: Expose full fee excess data. *)
            { fee_excess_l with
              magnitude = Currency.Amount.of_fee fee_excess_l.magnitude
          } )
      ; field "supplyIncrease" ~typ:(non_null uint64)
          ~doc:"Increase in total coinbase reward "
          ~args:Arg.[]
          ~resolve:(fun _
                        ({ supply_increase; _ } :
                           Transaction_snark.Statement.t ) ->
            Currency.Amount.to_uint64 supply_increase )
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
      ( 'context
      , (Mina_state.Blockchain_state.Value.t * State_hash.t) option )
        typ =
  obj "BlockchainState" ~fields:(fun _ ->
      [ field "date" ~typ:(non_null string) ~doc:(Doc.date "date")
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            let timestamp =
              Mina_state.Blockchain_state.timestamp blockchain_state
            in
            Block_time.to_string timestamp )
      ; field "utcDate" ~typ:(non_null string)
          ~doc:
          (Doc.date
             ~extra:
             ". Time offsets are adjusted to reflect true wall-clock \
              time instead of genesis time."
             "utcDate" )
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } t ->
            let blockchain_state, _ = t in
            let timestamp =
              Mina_state.Blockchain_state.timestamp blockchain_state
            in
            Block_time.to_string_system_time
              (Mina_lib.time_controller coda)
              timestamp )
      ; field "snarkedLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the snarked ledger"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            let snarked_ledger_hash =
              Mina_state.Blockchain_state.snarked_ledger_hash blockchain_state
            in
            Frozen_ledger_hash.to_base58_check snarked_ledger_hash )
      ; field "stagedLedgerHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the staged ledger"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let blockchain_state, _ = t in
            let staged_ledger_hash =
              Mina_state.Blockchain_state.staged_ledger_hash blockchain_state
            in
            Mina_base.Ledger_hash.to_base58_check
            @@ Staged_ledger_hash.ledger_hash staged_ledger_hash )
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
               Some (Transition_frontier.Breadcrumb.just_emitted_a_proof b)
          )
    ] )

let protocol_state :
      ( 'context
      , (Filtered_external_transition.Protocol_state.t * State_hash.t) option
      )
        typ =
  let open Filtered_external_transition.Protocol_state in
  obj "ProtocolState" ~fields:(fun _ ->
      [ field "previousStateHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the previous state"
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, _ = t in
            State_hash.to_base58_check protocol_state.previous_state_hash )
      ; field "blockchainState"
          ~doc:"State which is agnostic of a particular consensus algorithm"
          ~typ:(non_null blockchain_state)
          ~args:Arg.[]
          ~resolve:(fun _ t ->
            let protocol_state, state_hash = t in
            (protocol_state.blockchain_state, state_hash) )
      ; field "consensusState"
          ~doc:
          "State specific to the Codaboros Proof of Stake consensus \
           algorithm"
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
      [ field "accountCreationFee" ~typ:(non_null uint64)
          ~doc:"The fee charged to create a new account"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } () ->
            (Mina_lib.config coda).precomputed_values.constraint_constants
              .account_creation_fee |> Currency.Fee.to_uint64 )
      ; field "coinbase" ~typ:(non_null uint64)
          ~doc:
          "The amount received as a coinbase reward for producing a block"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } () ->
            (Mina_lib.config coda).precomputed_values.constraint_constants
              .coinbase_amount |> Currency.Amount.to_uint64 )
    ] )



let user_command = UserCommand.user_command_interface

let transactions =
  let open Filtered_external_transition.Transactions in
  obj "Transactions" ~doc:"Different types of transactions in a block"
    ~fields:(fun _ ->
      [ field "userCommands"
          ~doc:
          "List of user commands (payments and stake delegations) included \
           in this block"
          ~typ:(non_null @@ list @@ non_null user_command)
          ~args:Arg.[]
          ~resolve:(fun _ { commands; _ } ->
            List.filter_map commands ~f:(fun t ->
                match t.data.data with
                | Signed_command c ->
                   let status =
                     match t.status with
                     | Applied _ ->
                        UserCommand.Status.Applied
                     | Failed (e, _) ->
                        UserCommand.Status.Included_but_failed e
                   in
                   Some
                     (UserCommand.mk_user_command
                        { status; data = { t.data with data = c } } )
                | Snapp_command _ ->
                   (* TODO: This should be supported in some graph QL query *)
                   None ) )
      ; field "feeTransfer"
          ~doc:"List of fee transfers included in this block"
          ~typ:(non_null @@ list @@ non_null fee_transfer)
          ~args:Arg.[]
          ~resolve:(fun _ { fee_transfers; _ } -> fee_transfers)
      ; field "coinbase" ~typ:(non_null uint64)
          ~doc:"Amount of mina granted to the producer of this block"
          ~args:Arg.[]
          ~resolve:(fun _ { coinbase; _ } ->
            Currency.Amount.to_uint64 coinbase )
      ; field "coinbaseReceiverAccount" ~typ:AccountObj.account
          ~doc:"Account to which the coinbase for this block was granted"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } { coinbase_receiver; _ } ->
            Option.map
              ~f:(AccountObj.get_best_ledger_account_pk coda)
              coinbase_receiver )
    ] )

(* let protocol_state_proof : (Mina_lib.t, Proof.t option) typ = *)
(*   obj "protocolStateProof" ~fields:(fun _ -> *)
(*       [ field "base64" ~typ:string ~doc:"Base-64 encoded proof" *)
(*           ~args:Arg.[] *)
(*           ~resolve:(fun _ proof -> *)
(*             (\* Use the precomputed block proof encoding, for consistency. *\) *)
(*             Some (Mina_block.Precomputed.Proof.to_bin_string proof) ) *)
(*     ] ) *)

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
            AccountObj.get_best_ledger_account_pk coda data.creator )
      ; field "winnerAccount"
          ~typ:(non_null AccountObj.account)
          ~doc:"Account that won the slot (Delegator/Staker)"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } { With_hash.data; _ } ->
            AccountObj.get_best_ledger_account_pk coda data.winner )
      ; field "stateHash" ~typ:(non_null string)
          ~doc:"Base58Check-encoded hash of the state after this block"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.hash; _ } ->
            State_hash.to_base58_check hash )
      ; field "stateHashField" ~typ:(non_null string)
          ~doc:
          "Experimental: Bigint field-element representation of stateHash"
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.hash; _ } ->
            State_hash.to_decimal_string hash )
      ; field "protocolState" ~typ:(non_null protocol_state)
          ~args:Arg.[]
          ~resolve:(fun _ { With_hash.data; With_hash.hash; _ } ->
            (data.protocol_state, hash) )
      ; field "protocolStateProof"
          ~typ:(non_null @@ Mina_block_unix.Graphql_objects.protocol_state_proof ())
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
          ~resolve:(fun { ctx = coda; _ } (key, _) ->
            AccountObj.get_best_ledger_account_pk coda key )
      ; field "fee" ~typ:(non_null uint64)
          ~doc:"Fee that snark worker is charging to generate a snark proof"
          ~args:Arg.[]
          ~resolve:(fun (_ : Mina_lib.t resolve_info) (_, fee) ->
            Currency.Fee.to_uint64 fee )
    ] )


module Arguments = struct
  let ip_address ~name ip_addr =
    result_of_exn Unix.Inet_addr.of_string ip_addr
      ~error:(sprintf !"%s is not valid." name)
end


(* let vrf_message : ('context, Consensus_vrf.Layout.Message.t option) typ = *)
(*   let open Consensus_vrf.Layout.Message in *)
(*   obj "VrfMessage" ~doc:"The inputs to a vrf evaluation" ~fields:(fun _ -> *)
(*       [ field "globalSlot" ~typ:(non_null uint32) *)
(*           ~args:Arg.[] *)
(*           ~resolve:(fun _ { global_slot; _ } -> global_slot) *)
(*       ; field "epochSeed" ~typ:(non_null epoch_seed) *)
(*           ~args:Arg.[] *)
(*           ~resolve:(fun _ { epoch_seed; _ } -> epoch_seed) *)
(*       ; field "delegatorIndex" *)
(*           ~doc:"Position in the ledger of the delegator's account" *)
(*           ~typ:(non_null int) *)
(*           ~args:Arg.[] *)
(*           ~resolve:(fun _ { delegator_index; _ } -> delegator_index) *)
(*     ] ) *)

(* let vrf_threshold = *)
(*   obj "VrfThreshold" *)
(*     ~doc: *)
(*     "The amount of stake delegated, used to determine the threshold for a \ *)
(*      vrf evaluation winning a slot" ~fields:(fun _ -> *)
(*       [ field "delegatedStake" *)
(*           ~doc: *)
(*           "The amount of stake delegated to the vrf evaluator by the \ *)
(*            delegating account. This should match the amount in the epoch's \ *)
(*            staking ledger, which may be different to the amount in the \ *)
(*            current ledger." ~args:[] ~typ:(non_null uint64) *)
(*           ~resolve:(fun *)
(*               _ *)
(*               { Consensus_vrf.Layout.Threshold.delegated_stake; _ } *)
(*             -> Currency.Balance.to_uint64 delegated_stake ) *)
(*       ; field "totalStake" *)
(*           ~doc: *)
(*           "The total amount of stake across all accounts in the epoch's \ *)
(*            staking ledger." ~args:[] ~typ:(non_null uint64) *)
(*           ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.total_stake; _ } -> *)
(*             Currency.Amount.to_uint64 total_stake ) *)
(*     ] ) *)

let vrf_evaluation : ('context, Consensus_vrf.Layout.Evaluation.t option) typ
  =
  let open Consensus_vrf.Layout.Evaluation in
  obj "VrfEvaluation"
    ~doc:"A witness to a vrf evaluation, which may be externally verified"
    ~fields:(fun _ ->
      [ field "message" ~typ:(non_null @@ Consensus.Graphql_objects.vrf_message ())
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
            Consensus_vrf.Group.to_string_list_exn scaled_message_hash )
      ; field "vrfThreshold" ~typ:(Consensus.Graphql_objects.vrf_threshold ())
          ~args:Arg.[]
          ~resolve:(fun _ { vrf_threshold; _ } -> vrf_threshold)
      ; field "vrfOutput" ~typ:string
          ~doc:
          "The vrf output derived from the evaluation witness. If null, \
           the vrf witness was invalid."
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
            Option.map ~f:Consensus_vrf.Output.Truncated.to_base58_check
              vrf_opt )
      ; field "vrfOutputFractional" ~typ:float
          ~doc:
          "The vrf output derived from the evaluation witness, as a \
           fraction. This represents a won slot if vrfOutputFractional <= \
           (1 - (1 / 4)^(delegated_balance / total_stake)). If null, the \
           vrf witness was invalid."
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
          ~doc:
          "Whether the threshold to produce a block was met, if specified"
          ~args:
          Arg.
        [ arg "input" ~doc:"Override for delegation threshold"
            ~typ:Input.VrfThresholdInput.arg_typ
        ]
          ~resolve:(fun { ctx = mina; _ } t input ->
            match input with
            | Some { delegated_stake; total_stake } ->
               let constraint_constants =
                 (Mina_lib.config mina).precomputed_values
                   .constraint_constants
               in
               (Consensus_vrf.Layout.Evaluation.compute_vrf
                  ~constraint_constants t ~delegated_stake ~total_stake )
                 .threshold_met
            | None ->
               t.threshold_met )
    ] )
