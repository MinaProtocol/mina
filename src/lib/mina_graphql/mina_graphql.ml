open Core
open Async
open Graphql_async
open Mina_base
module Ledger = Mina_ledger.Ledger
open Signature_lib
open Currency

module Option = struct
  include Option

  module Result = struct
    let sequence (type a b) (o : (a, b) result option) =
      match o with
      | None ->
          Ok None
      | Some r ->
          Result.map r ~f:(fun a -> Some a)
  end
end

(** Convert a GraphQL constant to the equivalent json representation.
    We can't coerce this directly because of the presence of the [`Enum]
    constructor, so we have to recurse over the structure replacing all of the
    [`Enum]s with [`String]s.
*)
let rec to_yojson (json : Graphql_parser.const_value) : Yojson.Safe.t =
  match json with
  | `Assoc fields ->
      `Assoc (List.map fields ~f:(fun (name, json) -> (name, to_yojson json)))
  | `Bool b ->
      `Bool b
  | `Enum s ->
      `String s
  | `Float f ->
      `Float f
  | `Int i ->
      `Int i
  | `List l ->
      `List (List.map ~f:to_yojson l)
  | `Null ->
      `Null
  | `String s ->
      `String s

let result_of_exn f v ~error = try Ok (f v) with _ -> Error error

let result_of_or_error ?error v =
  Result.map_error v ~f:(fun internal_error ->
      let str_error = Error.to_string_hum internal_error in
      match error with
      | None ->
          str_error
      | Some error ->
          sprintf "%s (%s)" error str_error)

let result_field_no_inputs ~resolve =
  Schema.io_field ~resolve:(fun resolve_info src ->
      Deferred.return @@ resolve resolve_info src)

(* one input *)
let result_field ~resolve =
  Schema.io_field ~resolve:(fun resolve_info src inputs ->
      Deferred.return @@ resolve resolve_info src inputs)

(* two inputs *)
let result_field2 ~resolve =
  Schema.io_field ~resolve:(fun resolve_info src input1 input2 ->
      Deferred.return @@ resolve resolve_info src input1 input2)

module Doc = struct
  let date ?(extra = "") s =
    sprintf
      !"%s (stringified Unix time - number of milliseconds since January 1, \
        1970)%s"
      s extra

  let bin_prot =
    sprintf !"%s (base58-encoded janestreet/bin_prot serialization)"
end

module Reflection = struct
  let regex = lazy (Re2.create_exn {regex|\_(\w)|regex})

  let underToCamel s =
    Re2.replace_exn (Lazy.force regex) s ~f:(fun m ->
        let s = Re2.Match.get_exn ~sub:(`Index 1) m in
        String.capitalize s)

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

    let nn_time a x =
      reflect
        (fun t -> Block_time.to_time t |> Time.to_string)
        ~typ:(non_null string) a x

    let nn_catchup_status a x =
      reflect
        (fun o ->
          Option.map o
            ~f:
              (List.map ~f:(function
                | ( Transition_frontier.Full_catchup_tree.Node.State.Enum
                    .Finished
                  , _ ) ->
                    "finished"
                | Failed, _ ->
                    "failed"
                | To_download, _ ->
                    "to_download"
                | To_initial_validate, _ ->
                    "to_initial_validate"
                | To_verify, _ ->
                    "to_verify"
                | Wait_for_parent, _ ->
                    "wait_for_parent"
                | To_build_breadcrumb, _ ->
                    "to_build_breadcrumb"
                | Root, _ ->
                    "root")))
        ~typ:(list (non_null string))
        a x

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
  open Graphql_lib.Base_types

  let public_key = public_key ()

  let uint64 = uint64 ()

  let uint32 = uint32 ()

  let token_id = token_id ()

  let json : ('context, Yojson.Basic.t option) typ =
    scalar "JSON" ~doc:"Arbitrary JSON" ~coerce:Fn.id

  let epoch_seed = epoch_seed ()

  let sync_status : ('context, Sync_status.t option) typ =
    enum "SyncStatus" ~doc:"Sync status of daemon"
      ~values:
        (List.map Sync_status.all ~f:(fun status ->
             enum_value
               (String.map ~f:Char.uppercase @@ Sync_status.to_string status)
               ~value:status))

  let transaction_status :
      ('context, Transaction_inclusion_status.State.t option) typ =
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
          Consensus.Data.Consensus_time.of_time_exn
            ~constants:consensus_constants
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

  module DaemonStatus = struct
    type t = Daemon_rpcs.Types.Status.t

    let interval : (_, (Time.Span.t * Time.Span.t) option) typ =
      obj "Interval" ~fields:(fun _ ->
          [ field "start" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (start, _) ->
                Time.Span.to_ms start |> Int64.of_float |> Int64.to_string)
          ; field "stop" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (_, end_) ->
                Time.Span.to_ms end_ |> Int64.of_float |> Int64.to_string)
          ])

    let histogram : (_, Perf_histograms.Report.t option) typ =
      obj "Histogram" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Perf_histograms.Report.Fields.fold ~init:[]
               ~values:(id ~typ:Schema.(non_null (list (non_null int))))
               ~intervals:(id ~typ:(non_null (list (non_null interval))))
               ~underflow:nn_int ~overflow:nn_int)

    module Rpc_timings = Daemon_rpcs.Types.Status.Rpc_timings
    module Rpc_pair = Rpc_timings.Rpc_pair

    let rpc_pair : (_, Perf_histograms.Report.t option Rpc_pair.t option) typ =
      let h = Reflection.Shorthand.id ~typ:histogram in
      obj "RpcPair" ~fields:(fun _ ->
          List.rev @@ Rpc_pair.Fields.fold ~init:[] ~dispatch:h ~impl:h)

    let rpc_timings : (_, Rpc_timings.t option) typ =
      let fd = Reflection.Shorthand.id ~typ:(non_null rpc_pair) in
      obj "RpcTimings" ~fields:(fun _ ->
          List.rev
          @@ Rpc_timings.Fields.fold ~init:[] ~get_staged_ledger_aux:fd
               ~answer_sync_ledger_query:fd ~get_ancestry:fd
               ~get_transition_chain_proof:fd ~get_transition_chain:fd)

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
               ~snark_worker_transition_time:h ~snark_worker_merge_time:h)

    let consensus_configuration : (_, Consensus.Configuration.t option) typ =
      obj "ConsensusConfiguration" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Consensus.Configuration.Fields.fold ~init:[] ~delta:nn_int
               ~k:nn_int ~slots_per_epoch:nn_int ~slot_duration:nn_int
               ~epoch_duration:nn_int ~acceptable_network_delay:nn_int
               ~genesis_state_timestamp:nn_time)

    let peer : (_, Network_peer.Peer.Display.t option) typ =
      obj "Peer" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Network_peer.Peer.Display.Fields.fold ~init:[] ~host:nn_string
               ~libp2p_port:nn_int ~peer_id:nn_string)

    let addrs_and_ports : (_, Node_addrs_and_ports.Display.t option) typ =
      obj "AddrsAndPorts" ~fields:(fun _ ->
          let open Reflection.Shorthand in
          List.rev
          @@ Node_addrs_and_ports.Display.Fields.fold ~init:[]
               ~external_ip:nn_string ~bind_ip:nn_string ~client_port:nn_int
               ~libp2p_port:nn_int ~peer:(id ~typ:peer))

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
               ~highest_unvalidated_block_length_received:nn_int)
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
              Currency.Fee.to_uint64 fee)
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
    let `Needs_some_work_for_snapps_on_mainnet = Mina_base.Util.todo_snapps in
    obj "WorkDescription"
      ~doc:
        "Transition from a source ledger to a target ledger with some fee \
         excess and increase in supply " ~fields:(fun _ ->
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
              "Total transaction fee that is not accounted for in the \
               transition from source ledger to target ledger"
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
              Block_time.to_string timestamp)
        ; field "utcDate" ~typ:(non_null string)
            ~doc:
              (Doc.date
                 ~extra:
                   ". Time offsets are adjusted to reflect true wall-clock \
                    time instead of genesis time."
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
              "State specific to the Codaboros Proof of Stake consensus \
               algorithm"
            ~typ:(non_null @@ Consensus.Data.Consensus_state.graphql_type ())
            ~args:Arg.[]
            ~resolve:(fun _ t ->
              let protocol_state, _ = t in
              protocol_state.consensus_state)
        ])

  let chain_reorganization_status : ('contxt, [ `Changed ] option) typ =
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
            ~doc:
              "The amount received as a coinbase reward for producing a block"
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
            "A total balance annotated with the amount that is currently \
             unknown with the invariant unknown <= total, as well as the \
             currently liquid and locked balances." ~fields:(fun _ ->
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
                      Transition_frontier.Breadcrumb.blockchain_length crumb)
              (* TODO: Mutually recurse with "block" instead -- #5396 *)
            ; field "stateHash" ~typ:string
                ~doc:
                  "Hash of block at which balance was measured. Can be null if \
                   bootstrapping. Guaranteed to be non-null for direct account \
                   lookup queries when not bootstrapping. Can also be null \
                   when accessed as nested properties (eg. via delegators). "
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
          ; snapp
          ; snapp_uri
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
        let%bind snapp = snapp in
        let%map snapp_uri = snapp_uri in
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
        ; snapp
        ; snapp_uri
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
          ; snapp
          ; snapp_uri
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
        ; snapp
        ; snapp_uri = Some snapp_uri
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
              ; snapp = None
              ; snapp_uri = None
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
          , Snapp_account.t option
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
          [ field "stake" ~typ:(non_null bool) ~doc:"Permission to stake"
              ~args:Arg.[]
              ~resolve:(fun _ permission -> permission.Permissions.Poly.stake)
          ; field "editState" ~typ:(non_null auth_required)
              ~doc:"Authorization required to edit snapp state"
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
                "Authorization required to set the verification key of the \
                 snapp associated with the account"
              ~args:Arg.[]
              ~resolve:(fun _ permission ->
                permission.Permissions.Poly.set_verification_key)
          ; field "setSnappUri" ~typ:(non_null auth_required)
              ~doc:
                "Authorization required to change the URI of the snapp \
                 associated with the account "
              ~args:Arg.[]
              ~resolve:(fun _ permission ->
                permission.Permissions.Poly.set_snapp_uri)
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
          [ field "verificationKey"
              ~doc:"Verification key in Base58Check format"
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
                 ~resolve:(fun _ { account; _ } ->
                   account.Account.Poly.token_id)
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
                     Mina_lib
                     .get_inferred_nonce_from_transaction_pool_and_ledger coda
                       account_id
                   with
                   | `Active (Some nonce) ->
                       Some (Account.Nonce.to_string nonce)
                   | `Active None | `Bootstrapping ->
                       None)
             ; field "epochDelegateAccount" ~typ:(Lazy.force account)
                 ~doc:
                   "The account that you delegated on the staking ledger of \
                    the current block's epoch"
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
                              genesis ledger. The account was not present in \
                              the ledger." ;
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
                            ledger. The account may not be in the ledger: \
                            $error" ;
                         None ))
             ; field "receiptChainHash" ~typ:string
                 ~doc:"Top hash of the receipt chain merkle-list"
                 ~args:Arg.[]
                 ~resolve:(fun _ { account; _ } ->
                   Option.map ~f:Receipt.Chain_hash.to_base58_check
                     account.Account.Poly.receipt_chain_hash)
             ; field "delegate" ~typ:public_key
                 ~doc:
                   "The public key to which you are delegating - if you are \
                    not delegating to anybody, this would return your public \
                    key"
                 ~args:Arg.[]
                 ~deprecated:(Deprecated (Some "use delegateAccount instead"))
                 ~resolve:(fun _ { account; _ } ->
                   account.Account.Poly.delegate)
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
                   "The list of accounts which are delegating to you (note \
                    that the info is recorded in the last epoch so it might \
                    not be up to date with the current account status)"
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
                   "The list of accounts which are delegating to you in the \
                    last epoch (note that the info is recorded in the one \
                    before last epoch epoch so it might not be up to date with \
                    the current account status)"
                 ~args:Arg.[]
                 ~resolve:(fun { ctx = coda; _ } { account; _ } ->
                   let open Option.Let_syntax in
                   let pk = account.Account.Poly.public_key in
                   let%map delegators =
                     Mina_lib.last_epoch_delegators coda ~pk
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
                   "True if locked, false if unlocked, null if the account \
                    isn't tracked by the queried daemon"
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
             ; field "snappUri" ~typ:string
                 ~doc:
                   "The URI associated with this account, usually pointing to \
                    the snapp source code"
                 ~args:Arg.[]
                 ~resolve:(fun _ { account; _ } ->
                   account.Account.Poly.snapp_uri)
             ; field "snappState"
                 ~typ:(list @@ non_null string)
                 ~doc:
                   "The 8 field elements comprising the snapp state associated \
                    with this account encoded as bignum strings"
                 ~args:Arg.[]
                 ~resolve:(fun _ { account; _ } ->
                   account.Account.Poly.snapp
                   |> Option.map ~f:(fun snapp_account ->
                          snapp_account.app_state |> Snapp_state.V.to_list
                          |> List.map ~f:Snapp_basic.F.to_string))
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
                   Option.value_map account.Account.Poly.snapp ~default:None
                     ~f:(fun snapp_account -> snapp_account.verification_key))
             ; field "sequenceEvents"
                 ~doc:"Sequence events associated with this account"
                 ~typ:(list (non_null string))
                 ~args:Arg.[]
                 ~resolve:(fun _ { account; _ } ->
                   Option.map account.Account.Poly.snapp
                     ~f:(fun snapp_account ->
                       List.map ~f:Snark_params.Tick.Field.to_string
                         (Pickles_types.Vector.to_list
                            snapp_account.sequence_state)))
             ]))

    let account = Lazy.force account
  end

  module Command_status = struct
    type t =
      | Applied
      | Enqueued
      | Included_but_failed of Transaction_status.Failure.t
  end

  module User_command = struct
    let kind :
        ( 'context
        , [< `Payment
          | `Stake_delegation
          | `Create_new_token
          | `Create_token_account
          | `Mint_tokens ]
          option )
        typ =
      scalar "UserCommandKind" ~doc:"The kind of user command" ~coerce:(function
        | `Payment ->
            `String "PAYMENT"
        | `Stake_delegation ->
            `String "STAKE_DELEGATION"
        | `Create_new_token ->
            `String "CREATE_NEW_TOKEN"
        | `Create_token_account ->
            `String "CREATE_TOKEN_ACCOUNT"
        | `Mint_tokens ->
            `String "MINT_TOKENS")

    let to_kind (t : Signed_command.t) =
      match Signed_command.payload t |> Signed_command_payload.body with
      | Payment _ ->
          `Payment
      | Stake_delegation _ ->
          `Stake_delegation
      | Create_new_token _ ->
          `Create_new_token
      | Create_token_account _ ->
          `Create_token_account
      | Mint_tokens _ ->
          `Mint_tokens

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
                "Amount that the source is sending to receiver - 0 for \
                 commands that are not associated with an amount"
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
                "If true, this represents a delegation of stake, otherwise it \
                 is a payment"
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
        ( Mina_lib.t
        , (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t )
        field
        list =
      [ field_no_status "id" ~typ:(non_null guid) ~args:[]
          ~resolve:(fun _ user_command ->
            Signed_command.to_base58_check user_command.With_hash.data)
      ; field_no_status "hash" ~typ:(non_null string) ~args:[]
          ~resolve:(fun _ user_command ->
            Transaction_hash.to_base58_check user_command.With_hash.hash)
      ; field_no_status "kind" ~typ:(non_null kind) ~args:[]
          ~doc:"String describing the kind of user command"
          ~resolve:(fun _ cmd -> to_kind cmd.With_hash.data)
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
              (Signed_command.source ~next_available_token:Token_id.invalid
                 cmd.With_hash.data))
      ; field_no_status "receiver" ~typ:(non_null AccountObj.account)
          ~args:[] ~doc:"Account that the command applies to"
          ~resolve:(fun { ctx = coda; _ } cmd ->
            AccountObj.get_best_ledger_account coda
              (Signed_command.receiver ~next_available_token:Token_id.invalid
                 cmd.With_hash.data))
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
            "Fee that the fee-payer is willing to pay for making the \
             transaction" ~resolve:(fun _ cmd ->
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
            @@ Signed_command.receiver ~next_available_token:Token_id.invalid
                 cmd.With_hash.data)
      ; field "failureReason" ~typ:string ~args:[]
          ~doc:
            "null is no failure or status unknown, reason for failure \
             otherwise." ~resolve:(fun _ uc ->
            match uc.With_status.status with
            | Applied | Enqueued ->
                None
            | Included_but_failed failure ->
                Some (Transaction_status.Failure.to_string failure))
      ]

    let payment =
      obj "UserCommandPayment" ~fields:(fun _ -> user_command_shared_fields)

    let mk_payment = add_type user_command_interface payment

    let stake_delegation =
      obj "UserCommandDelegation" ~fields:(fun _ ->
          field_no_status "delegator" ~typ:(non_null AccountObj.account)
            ~args:[] ~resolve:(fun { ctx = coda; _ } cmd ->
              AccountObj.get_best_ledger_account coda
                (Signed_command.source ~next_available_token:Token_id.invalid
                   cmd.With_hash.data))
          :: field_no_status "delegatee" ~typ:(non_null AccountObj.account)
               ~args:[] ~resolve:(fun { ctx = coda; _ } cmd ->
                 AccountObj.get_best_ledger_account coda
                   (Signed_command.receiver
                      ~next_available_token:Token_id.invalid cmd.With_hash.data))
          :: user_command_shared_fields)

    let mk_stake_delegation = add_type user_command_interface stake_delegation

    let create_new_token =
      obj "UserCommandNewToken" ~fields:(fun _ ->
          field_no_status "tokenOwner" ~typ:(non_null public_key) ~args:[]
            ~doc:"Public key to set as the owner of the new token"
            ~resolve:(fun _ cmd -> Signed_command.source_pk cmd.With_hash.data)
          :: field_no_status "newAccountsDisabled" ~typ:(non_null bool) ~args:[]
               ~doc:"Whether new accounts created in this token are disabled"
               ~resolve:(fun _ cmd ->
                 match
                   Signed_command_payload.body
                   @@ Signed_command.payload cmd.With_hash.data
                 with
                 | Create_new_token { disable_new_accounts; _ } ->
                     disable_new_accounts
                 | _ ->
                     (* We cannot exclude this at the type level. *)
                     failwith
                       "Type error: Expected a Create_new_token user command")
          :: user_command_shared_fields)

    let mk_create_new_token = add_type user_command_interface create_new_token

    let create_token_account =
      obj "UserCommandNewAccount" ~fields:(fun _ ->
          field_no_status "tokenOwner" ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"The account that owns the token for the new account"
            ~resolve:(fun { ctx = coda; _ } cmd ->
              AccountObj.get_best_ledger_account coda
                (Signed_command.source ~next_available_token:Token_id.invalid
                   cmd.With_hash.data))
          :: field_no_status "disabled" ~typ:(non_null bool) ~args:[]
               ~doc:
                 "Whether this account should be disabled upon creation. If \
                  this command was not issued by the token owner, it should \
                  match the 'newAccountsDisabled' property set in the token \
                  owner's account." ~resolve:(fun _ cmd ->
                 match
                   Signed_command_payload.body
                   @@ Signed_command.payload cmd.With_hash.data
                 with
                 | Create_token_account { account_disabled; _ } ->
                     account_disabled
                 | _ ->
                     (* We cannot exclude this at the type level. *)
                     failwith
                       "Type error: Expected a Create_token_account user \
                        command")
          :: user_command_shared_fields)

    let mk_create_token_account =
      add_type user_command_interface create_token_account

    let mint_tokens =
      obj "UserCommandMintTokens" ~fields:(fun _ ->
          field_no_status "tokenOwner" ~typ:(non_null AccountObj.account)
            ~args:[] ~doc:"The account that owns the token to mint"
            ~resolve:(fun { ctx = coda; _ } cmd ->
              AccountObj.get_best_ledger_account coda
                (Signed_command.source ~next_available_token:Token_id.invalid
                   cmd.With_hash.data))
          :: user_command_shared_fields)

    let mk_mint_tokens = add_type user_command_interface mint_tokens

    let mk_user_command
        (cmd : (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t)
        =
      match
        Signed_command_payload.body @@ Signed_command.payload cmd.data.data
      with
      | Payment _ ->
          mk_payment cmd
      | Stake_delegation _ ->
          mk_stake_delegation cmd
      | Create_new_token _ ->
          mk_create_new_token cmd
      | Create_token_account _ ->
          mk_create_token_account cmd
      | Mint_tokens _ ->
          mk_mint_tokens cmd

    let user_command = user_command_interface
  end

  module Snapp_command = struct
    module With_status = struct
      type 'a t = { data : 'a; status : Command_status.t }

      let map t ~f = { t with data = f t.data }
    end

    let field_no_status ?doc ?deprecated lab ~typ ~args ~resolve =
      field ?doc ?deprecated lab ~typ ~args ~resolve:(fun c cmd ->
          resolve c cmd.With_status.data)

    let mk_field_lists evs =
      List.map evs ~f:(fun fields ->
          Array.map fields ~f:Snark_params.Tick.Field.to_string |> Array.to_list)

    let party_display =
      obj "Party" ~doc:"Party in a snapp transaction" ~fields:(fun _ ->
          [ field "publicKey"
              ~doc:"Public key of the party as a Base58Check string"
              ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (party : Party.t) ->
                Public_key.Compressed.to_base58_check party.data.body.public_key)
          ; field "events"
              ~doc:"Events associated with the party (fields in Base58Check)"
              ~typ:(non_null (list (non_null (list (non_null string)))))
              ~args:Arg.[]
              ~resolve:(fun _ (party : Party.t) ->
                mk_field_lists party.data.body.events)
          ; field "sequenceEvents"
              ~doc:
                "Sequence events associated with the party (fields in \
                 Base58Check)"
              ~typ:(non_null (list (non_null (list (non_null string)))))
              ~args:Arg.[]
              ~resolve:(fun _ (party : Party.t) ->
                mk_field_lists party.data.body.sequence_events)
          ])

    let snapp_command =
      obj "SnappCommand" ~fields:(fun _ ->
          [ field_no_status "id"
              ~doc:"A Base58Check string representing the command"
              ~typ:(non_null guid) ~args:[] ~resolve:(fun _ parties ->
                Parties.to_base58_check parties.With_hash.data)
          ; field_no_status "hash"
              ~doc:"A cryptographic hash of the snapp command"
              ~typ:(non_null string) ~args:[] ~resolve:(fun _ parties ->
                Transaction_hash.to_base58_check parties.With_hash.hash)
          ; field_no_status "nonce" ~typ:(non_null int) ~args:[]
              ~doc:
                "Sequence number of the snapp transaction for the fee-payer's \
                 account" ~resolve:(fun _ parties ->
                Parties.nonce parties.With_hash.data |> Unsigned.UInt32.to_int)
          ; field_no_status "feePayer" ~typ:(non_null AccountObj.account)
              ~args:[]
              ~doc:"Account that pays the fees for the snapp transaction"
              ~resolve:(fun { ctx = coda; _ } cmd ->
                AccountObj.get_best_ledger_account coda
                  (Parties.fee_payer cmd.With_hash.data))
          ; field_no_status "accountsAccessed"
              ~typ:(non_null (list (non_null AccountObj.account)))
              ~args:[]
              ~doc:"List of accounts accessed to complete the snapp transaction"
              ~resolve:(fun { ctx = coda; _ } parties ->
                let account_ids =
                  Parties.accounts_accessed parties.With_hash.data
                in
                List.map account_ids ~f:(fun acct_id ->
                    AccountObj.get_best_ledger_account coda acct_id))
          ; field_no_status "fee" ~typ:(non_null uint64) ~args:[]
              ~doc:
                "Transaction fee paid by the fee-payer for the snapp \
                 transaction" ~resolve:(fun _ parties ->
                Parties.fee parties.With_hash.data |> Currency.Fee.to_uint64)
          ; field_no_status "feeToken" ~typ:(non_null token_id) ~args:[]
              ~doc:"Token used to pay the fee" ~resolve:(fun _ parties ->
                Parties.fee_token parties.With_hash.data)
          ; field "failureReason" ~typ:string ~args:[]
              ~doc:
                "The reason for the snapp transaction failure; null means \
                 success or the status is unknown" ~resolve:(fun _ cmd ->
                match cmd.With_status.status with
                | Applied | Enqueued ->
                    None
                | Included_but_failed failure ->
                    Some (Transaction_status.Failure.to_string failure))
          ; field_no_status "parties"
              ~typ:(non_null (list (non_null party_display)))
              ~args:[] ~doc:"Parties involved in the snapp transaction"
              ~resolve:(fun _ cmd -> Parties.parties cmd.With_hash.data)
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
                        | Applied _ ->
                            Command_status.Applied
                        | Failed (e, _) ->
                            Command_status.Included_but_failed e
                      in
                      Some
                        (User_command.mk_user_command
                           { status; data = { t.data with data = c } })
                  | Parties _ ->
                      None))
        ; field "snappCommands"
            ~doc:"List of snapp commands included in this block"
            ~typ:(non_null @@ list @@ non_null Snapp_command.snapp_command)
            ~args:Arg.[]
            ~resolve:(fun _ { commands; _ } ->
              List.filter_map commands ~f:(fun t ->
                  match t.data.data with
                  | Signed_command _ ->
                      None
                  | Parties parties ->
                      let status =
                        match t.status with
                        | Applied _ ->
                            Command_status.Applied
                        | Failed (e, _) ->
                            Command_status.Included_but_failed e
                      in
                      Some
                        { Snapp_command.With_status.status
                        ; data = { t.data with data = parties }
                        }))
        ; field "feeTransfer"
            ~doc:"List of fee transfers included in this block"
            ~typ:(non_null @@ list @@ non_null fee_transfer)
            ~args:Arg.[]
            ~resolve:(fun _ { fee_transfers; _ } -> fee_transfers)
        ; field "coinbase" ~typ:(non_null uint64)
            ~doc:"Amount of MINA granted to the producer of this block"
            ~args:Arg.[]
            ~resolve:(fun _ { coinbase; _ } ->
              Currency.Amount.to_uint64 coinbase)
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
              Some
                (Mina_transition.External_transition.Precomputed_block.Proof
                 .to_bin_string proof))
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
            ~doc:
              "Experimental: Bigint field-element representation of stateHash"
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

  module Payload = struct
    let peer : ('context, Network_peer.Peer.t option) typ =
      obj "NetworkPeerPayload" ~fields:(fun _ ->
          [ field "peerId" ~doc:"base58-encoded peer ID" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ peer -> peer.Network_peer.Peer.peer_id)
          ; field "host" ~doc:"IP address of the remote host"
              ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ peer ->
                Unix.Inet_addr.to_string peer.Network_peer.Peer.host)
          ; field "libp2pPort" ~typ:(non_null int)
              ~args:Arg.[]
              ~resolve:(fun _ peer -> peer.Network_peer.Peer.libp2p_port)
          ])

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
              ~resolve:(fun { ctx = coda; _ } key ->
                AccountObj.get_best_ledger_account_pk coda key)
          ])

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
              ~resolve:(fun { ctx = coda; _ } key ->
                AccountObj.get_best_ledger_account_pk coda key)
          ])

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
              ~resolve:(fun { ctx = coda; _ } key ->
                AccountObj.get_best_ledger_account_pk coda key)
          ])

    let delete_account =
      obj "DeleteAccountPayload" ~fields:(fun _ ->
          [ field "publicKey" ~typ:(non_null public_key)
              ~doc:"Public key of the deleted account"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let reload_accounts =
      obj "ReloadAccountsPayload" ~fields:(fun _ ->
          [ field "success" ~typ:(non_null bool)
              ~doc:"True when the reload was successful"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

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
          ])

    let string_of_banned_status = function
      | Trust_system.Banned_status.Unbanned ->
          None
      | Banned_until tm ->
          Some (Time.to_string tm)

    let trust_status =
      obj "TrustStatusPayload" ~fields:(fun _ ->
          let open Trust_system.Peer_status in
          [ field "ipAddr" ~typ:(non_null string) ~doc:"IP address"
              ~args:Arg.[]
              ~resolve:(fun _ (peer, _) ->
                Unix.Inet_addr.to_string peer.Network_peer.Peer.host)
          ; field "peerId" ~typ:(non_null string) ~doc:"libp2p Peer ID"
              ~args:Arg.[]
              ~resolve:(fun _ (peer, __) -> peer.Network_peer.Peer.peer_id)
          ; field "trust" ~typ:(non_null float) ~doc:"Trust score"
              ~args:Arg.[]
              ~resolve:(fun _ (_, { trust; _ }) -> trust)
          ; field "bannedStatus" ~typ:string ~doc:"Banned status"
              ~args:Arg.[]
              ~resolve:(fun _ (_, { banned; _ }) ->
                string_of_banned_status banned)
          ])

    let send_payment =
      obj "SendPaymentPayload" ~fields:(fun _ ->
          [ field "payment"
              ~typ:(non_null User_command.user_command)
              ~doc:"Payment that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let send_delegation =
      obj "SendDelegationPayload" ~fields:(fun _ ->
          [ field "delegation"
              ~typ:(non_null User_command.user_command)
              ~doc:"Delegation change that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let create_token =
      obj "SendCreateTokenPayload" ~fields:(fun _ ->
          [ field "createNewToken"
              ~typ:(non_null User_command.create_new_token)
              ~doc:"Token creation command that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let create_token_account =
      obj "SendCreateTokenAccountPayload" ~fields:(fun _ ->
          [ field "createNewTokenAccount"
              ~typ:(non_null User_command.create_token_account)
              ~doc:"Token account creation command that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let mint_tokens =
      obj "SendMintTokensPayload" ~fields:(fun _ ->
          [ field "mintTokens"
              ~typ:(non_null User_command.mint_tokens)
              ~doc:"Token minting command that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let send_snapp =
      obj "SendSnappPayload" ~fields:(fun _ ->
          [ field "snapp"
              ~typ:(non_null Snapp_command.snapp_command)
              ~doc:"snapp transaction that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let send_rosetta_transaction =
      obj "SendRosettaTransactionPayload" ~fields:(fun _ ->
          [ field "userCommand"
              ~typ:(non_null User_command.user_command_interface)
              ~doc:"Command that was sent"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let export_logs =
      obj "ExportLogsPayload" ~fields:(fun _ ->
          [ field "exportLogs"
              ~typ:
                (non_null
                   (obj "TarFile" ~fields:(fun _ ->
                        [ field "tarfile" ~typ:(non_null string) ~args:[]
                            ~resolve:(fun _ basename -> basename)
                        ])))
              ~doc:"Tar archive containing logs"
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let add_payment_receipt =
      obj "AddPaymentReceiptPayload" ~fields:(fun _ ->
          [ field "payment"
              ~typ:(non_null User_command.user_command)
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let set_coinbase_receiver =
      obj "SetCoinbaseReceiverPayload" ~fields:(fun _ ->
          [ field "lastCoinbaseReceiver"
              ~doc:
                "Returns the public key that was receiving coinbases \
                 previously, or none if it was the block producer"
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
          ])

    let set_snark_work_fee =
      obj "SetSnarkWorkFeePayload" ~fields:(fun _ ->
          [ field "lastFee" ~doc:"Returns the last fee set to do snark work"
              ~typ:(non_null uint64)
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

    let set_snark_worker =
      obj "SetSnarkWorkerPayload" ~fields:(fun _ ->
          [ field "lastSnarkWorker"
              ~doc:
                "Returns the last public key that was designated for snark work"
              ~typ:public_key
              ~args:Arg.[]
              ~resolve:(fun _ -> Fn.id)
          ])

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
                "If true, no connections will be allowed unless they are from \
                 a trusted peer"
              ~args:Arg.[]
              ~resolve:(fun _ config -> config.Mina_net2.isolate)
          ])
  end

  module Arguments = struct
    let ip_address ~name ip_addr =
      result_of_exn Unix.Inet_addr.of_string ip_addr
        ~error:(sprintf !"%s is not valid." name)
  end

  module Input = struct
    open Schema.Arg

    let peer : (Network_peer.Peer.t, string) result option arg_typ =
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
          ; arg "host" ~doc:"IP address of the remote host"
              ~typ:(non_null string)
          ; arg "libp2pPort" ~typ:(non_null int)
          ]

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

    let token_id_arg =
      scalar "TokenId"
        ~doc:"String representation of a token's UInt64 identifier"
        ~coerce:(fun token ->
          try
            match token with
            | `String token ->
                Ok (Token_id.of_string token)
            | _ ->
                Error "Invalid format for token."
          with _ -> Error "Invalid format for token.")

    let sign =
      enum "Sign"
        ~values:
          [ enum_value "PLUS" ~value:Sgn.Pos
          ; enum_value "MINUS" ~value:Sgn.Neg
          ]

    let field =
      scalar "Field" ~coerce:(fun field ->
          match field with
          | `String s ->
              Ok (Snark_params.Tick.Field.of_string s)
          | _ ->
              Error "Expected a string representing a field element")

    let nonce =
      scalar "Nonce" ~coerce:(fun nonce ->
          (* of_string might raise *)
          try
            match nonce with
            | `String s ->
                (* a nonce is a uint32, GraphQL ints are signed int32, so use string *)
                Ok (Mina_base.Account.Nonce.of_string s)
            | _ ->
                Error "Expected string for nonce"
          with exn -> Error (Exn.to_string exn))

    let snarked_ledger_hash =
      scalar "SnarkedLedgerHash" ~coerce:(fun hash ->
          match hash with
          | `String s ->
              Result.map_error
                (Frozen_ledger_hash.of_base58_check s)
                ~f:Error.to_string_hum
          | _ ->
              Error "Expected snarked ledger hash in Base58Check format")

    let block_time =
      scalar "BlockTime" ~coerce:(fun block_time ->
          match block_time with
          | `String s -> (
              try
                (* a block time is a uint64, GraphQL ints are signed int32, so use string *)
                (* of_string might raise *)
                Ok (Block_time.of_string_exn s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for block time")

    let length =
      scalar "Length" ~coerce:(fun length ->
          (* of_string might raise *)
          match length with
          | `String s -> (
              try
                (* a length is a uint32, GraphQL ints are signed int32, so use string *)
                Ok (Mina_numbers.Length.of_string s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for length")

    let currency_amount =
      scalar "CurrencyAmount" ~coerce:(fun amt ->
          match amt with
          | `String s -> (
              try Ok (Currency.Amount.of_string s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for currency amount")

    let fee =
      scalar "Fee" ~coerce:(fun fee ->
          match fee with
          | `String s -> (
              try Ok (Currency.Fee.of_string s)
              with exn -> Error (Exn.to_string exn) )
          | _ ->
              Error "Expected string for fee")

    module Snapp_inputs = struct
      (* inputs particular to snapps *)

      let snapp_balance_change :
          ((Amount.t, Sgn.t) Signed_poly.t, string) Result.t option arg_typ =
        obj "BalanceChange" ~doc:"A signed amount"
          ~coerce:(fun magnitude sgn ->
            try Ok Currency.Signed_poly.{ magnitude; sgn }
            with exn -> Error (Exn.to_string exn))
          ~fields:
            [ arg "magnitude" ~doc:"An amount of MINA"
                ~typ:(non_null currency_amount)
            ; arg "sign" ~doc:"The sign of the amount" ~typ:(non_null sign)
            ]

      let snapp_vk_with_hash =
        obj "VerificationKeyWithHash" ~doc:"Verification key with hash"
          ~coerce:(fun vk hash ->
            let open Result.Let_syntax in
            let%bind data =
              let vk_or_err =
                Pickles.Side_loaded.Verification_key.of_base58_check vk
              in
              Result.map_error vk_or_err ~f:Error.to_string_hum
            in
            let%map hash =
              Pickles.Backend.Tick.Field.of_yojson (`String hash)
            in
            { With_hash.data; hash })
          ~fields:
            [ arg "verificationKey"
                ~doc:"Verification key in Base58Check format"
                ~typ:(non_null string)
            ; arg "hash" ~doc:"Hash of verification key" ~typ:(non_null string)
            ]

      let snapp_token =
        scalar "AccountToken" ~coerce:(fun tok ->
            Account.Token_symbol.of_yojson (to_yojson tok))

      let snapp_auth_required =
        let open Permissions.Auth_required in
        enum "AuthRequired" ~doc:"Kind of authorization required"
          ~values:
            [ enum_value "None" ~value:None
            ; enum_value "Either" ~value:Either
            ; enum_value "Proof" ~value:Proof
            ; enum_value "Signature" ~value:Signature
            ; enum_value "Impossible" ~value:Impossible
            ]

      let snapp_permissions =
        obj "Permissions"
          ~coerce:
            (fun stake edit_state send receive set_delegate set_permissions
                 set_verification_key set_snapp_uri edit_sequence_state
                 set_token_symbol increment_nonce set_voting_for ->
            Ok
              { Permissions.Poly.stake
              ; edit_state
              ; send
              ; receive
              ; set_delegate
              ; set_permissions
              ; set_verification_key
              ; set_snapp_uri
              ; edit_sequence_state
              ; set_token_symbol
              ; increment_nonce
              ; set_voting_for
              })
          ~fields:
            [ arg "stake" ~typ:(non_null bool)
            ; arg "editState" ~typ:(non_null snapp_auth_required)
            ; arg "send" ~typ:(non_null snapp_auth_required)
            ; arg "receive" ~typ:(non_null snapp_auth_required)
            ; arg "setDelegate" ~typ:(non_null snapp_auth_required)
            ; arg "setPermissions" ~typ:(non_null snapp_auth_required)
            ; arg "setVerificationKey" ~typ:(non_null snapp_auth_required)
            ; arg "setSnappUri" ~typ:(non_null snapp_auth_required)
            ; arg "editSequenceState" ~typ:(non_null snapp_auth_required)
            ; arg "setTokenSymbol" ~typ:(non_null snapp_auth_required)
            ; arg "incrementNonce" ~typ:(non_null snapp_auth_required)
            ; arg "setVotingFor" ~typ:(non_null snapp_auth_required)
            ]

      let snapp_timing =
        obj "Timing"
          ~coerce:
            (fun initial_minimum_balance cliff_time cliff_amount vesting_period
                 vesting_increment ->
            (* the conversion functions here can raise *)
            try
              let initial_minimum_balance =
                Currency.Balance.of_string initial_minimum_balance
              in
              let cliff_time = Mina_numbers.Global_slot.of_string cliff_time in
              let cliff_amount = Currency.Amount.of_string cliff_amount in
              let vesting_period =
                Mina_numbers.Global_slot.of_string vesting_period
              in
              let vesting_increment =
                Currency.Amount.of_string vesting_increment
              in
              Ok
                { Party.Update.Timing_info.initial_minimum_balance
                ; cliff_time
                ; cliff_amount
                ; vesting_period
                ; vesting_increment
                }
            with exn -> Error (Exn.to_string exn))
            (* TODO: These all should be their precise scalar types rather than strings *)
          ~fields:
            [ arg "initialMinimumBalance"
                ~doc:"Initial minimum balance as a string"
                ~typ:(non_null string)
            ; arg "cliffTime" ~doc:"Cliff time, a global slot, as a string"
                ~typ:(non_null string)
            ; arg "cliffAmount" ~doc:"Cliff amoount, as a string"
                ~typ:(non_null string)
            ; arg "vestingPeriod"
                ~doc:"Vesting period, a number of slots, as a string"
                ~typ:(non_null string)
            ; arg "vestingIncrement" ~doc:"Vesting amount, as a string"
                ~typ:(non_null string)
            ]

      let snapp_update : (Party.Update.t, string) Result.t option arg_typ =
        obj "PartyUpdate" ~doc:"Update component of a snapp Party"
          ~coerce:
            (fun app_state_elts delegate vk perms snapp_uri tok_sym timing
                 voting_for ->
            let open Result.Let_syntax in
            let v o = Snapp_basic.Set_or_keep.of_option o in
            let app_state_elts = List.map app_state_elts ~f:v in
            let%bind app_state =
              let expected_len = 8 in
              let len = List.length app_state_elts in
              if len = expected_len then
                (* length check prevents raising *)
                Ok (Snapp_state.V.of_list_exn app_state_elts)
              else
                Error
                  (sprintf "Expected %d field elements in app state, got %d"
                     expected_len len)
            in
            let s = Option.Result.sequence in
            let%bind voting_for =
              s (Option.map ~f:State_hash.of_base58_check voting_for)
              |> Result.map_error ~f:Error.to_string_hum
            in
            let%bind vk' = s vk in
            let%bind perms' = s perms in
            let%map timing' = s timing in
            Party.Update.Poly.
              { app_state
              ; delegate = v delegate
              ; verification_key = v vk'
              ; permissions = v perms'
              ; snapp_uri = v snapp_uri
              ; token_symbol = v tok_sym
              ; timing = v timing'
              ; voting_for = v voting_for
              })
          ~fields:
            [ arg "appState"
                ~doc:"List of _exactly_ 8 field elements (null if keep)"
                ~typ:(non_null (list field))
            ; arg "delegate" ~doc:"TODO: What is this?" ~typ:public_key_arg
            ; arg "verificationKey"
                ~doc:"A verification key and hash, or null if Keep"
                ~typ:snapp_vk_with_hash
            ; arg "permissions" ~doc:"Permissions, or null if Keep"
                ~typ:snapp_permissions
            ; arg "snappUri" ~doc:"A URI string, or null if Keep" ~typ:string
            ; arg "tokenSymbol" ~doc:"Token symbol" ~typ:snapp_token
            ; arg "timing" ~doc:"Timing info, or null if Keep" ~typ:snapp_timing
            ; arg "votingFor" ~doc:"State hash to vote for, or null if Keep"
                ~typ:string
            ]

      let snapp_balance =
        scalar "Balance" ~coerce:(fun s ->
            try
              match s with
              | `String balance ->
                  Ok (Currency.Balance.of_string balance)
              | _ ->
                  Error "Expected balance as a string"
            with exn -> Error (Exn.to_string exn))

      let snapp_global_slot =
        scalar "GlobalSlot" ~coerce:(fun amt ->
            match amt with
            | `String s -> (
                try Ok (Mina_numbers.Global_slot.of_string s)
                with exn -> Error (Exn.to_string exn) )
            | _ ->
                Error "Expected string for global slot")

      module Interval = struct
        let i name typ =
          obj (name ^ "Interval")
            ~coerce:(fun lower upper ->
              Snapp_predicate.Closed_interval.{ lower; upper })
            ~fields:
              [ arg "lower" ~typ:(non_null typ)
              ; arg "upper" ~typ:(non_null typ)
              ]

        let nonce = i "Nonce" nonce

        let balance = i "Balance" snapp_balance

        let length = i "Length" length

        let block_time = i "BlockTime" block_time

        let global_slot = i "GlobalSlot" snapp_global_slot

        let currency_amount = i "CurrencyAmount" currency_amount

        let token_id = i "TokenId" token_id_arg
      end

      let snapp_vrf_output =
        scalar "VrfOutput" ~coerce:(fun vrf_output ->
            match vrf_output with
            | `Null ->
                Ok ()
            | _ ->
                Error "VRF output, expected null")

      let snapp_state_hash =
        scalar "StateHash" ~coerce:(fun state_hash ->
            match state_hash with
            | `String s ->
                Result.map_error
                  (State_hash.of_base58_check s)
                  ~f:Error.to_string_hum
            | _ ->
                Error "Expected state hash in Base58Check format")

      let snapp_epoch_seed =
        scalar "EpochSeed" ~coerce:(fun field ->
            match field with
            | `String s ->
                Ok (Snark_params.Tick.Field.of_string s)
            | _ ->
                Error "Expected a string representing a field element")

      let snapp_epoch_ledger =
        obj "EpochLedger"
          ~coerce:(fun hash total_currency ->
            let v o = Snapp_basic.Or_ignore.of_option o in
            Ok
              { Epoch_ledger.Poly.hash = v hash
              ; total_currency = v total_currency
              })
          ~fields:
            [ arg "hash" ~typ:snarked_ledger_hash
            ; arg "totalCurrency" ~typ:Interval.currency_amount
            ]

      let snapp_epoch_data =
        obj "EpochData"
          ~coerce:
            (fun ledger_result seed start_checkpoint lock_checkpoint
                 epoch_length ->
            let open Result.Let_syntax in
            let v o = Snapp_basic.Or_ignore.of_option o in
            let%map ledger = ledger_result in
            { Snapp_predicate.Protocol_state.Epoch_data.Poly.ledger
            ; seed = v seed
            ; start_checkpoint = v start_checkpoint
            ; lock_checkpoint = v lock_checkpoint
            ; epoch_length = v epoch_length
            })
          ~fields:
            [ arg "ledger" ~typ:(non_null snapp_epoch_ledger)
            ; arg "seed" ~typ:snapp_epoch_seed
            ; arg "startCheckpoint" ~typ:snapp_state_hash
            ; arg "lockCheckpoint" ~typ:snapp_state_hash
            ; arg "epochLength" ~typ:Interval.length
            ]

      let check_or_null_doc s = s ^ " Checked if present. Ignored if null."

      let snapp_protocol_state_arg :
          (Snapp_predicate.Protocol_state.t, string) result option arg_typ =
        obj "SnappProtocolState" ~doc:"Protocol state for a snapp transaction"
          ~coerce:
            (fun snarked_ledger_hash snarked_next_available_token timestamp
                 blockchain_length min_window_density last_vrf_output_opt
                 total_currency global_slot_since_hard_fork
                 global_slot_since_genesis staking_epoch_data_result
                 next_epoch_data_result ->
            let open Result.Let_syntax in
            let v o = Snapp_basic.Or_ignore.of_option o in
            let last_vrf_output =
              (* if the value is given, it's null
                 if it's not given, provide the null
              *)
              match last_vrf_output_opt with Some () -> () | None -> ()
            in
            let%bind staking_epoch_data = staking_epoch_data_result in
            let%bind next_epoch_data = next_epoch_data_result in
            Ok
              { Snapp_predicate.Protocol_state.Poly.snarked_ledger_hash =
                  v snarked_ledger_hash
              ; snarked_next_available_token = v snarked_next_available_token
              ; timestamp = v timestamp
              ; blockchain_length = v blockchain_length
              ; min_window_density = v min_window_density
              ; last_vrf_output
              ; total_currency = v total_currency
              ; global_slot_since_hard_fork = v global_slot_since_hard_fork
              ; global_slot_since_genesis = v global_slot_since_genesis
              ; staking_epoch_data
              ; next_epoch_data
              })
          ~fields:
            [ arg "snarkedLedgerHash"
                ~doc:
                  (check_or_null_doc
                     "Snarked ledger hash in Base58Check format.")
                ~typ:snarked_ledger_hash
            ; arg "snarkedNextAvailableToken"
                ~doc:
                  (check_or_null_doc
                     "Next available tokenId according to the snarked ledger.")
                ~typ:Interval.token_id
            ; arg "timestamp"
                ~doc:
                  (check_or_null_doc
                     "Timestamp of the start of the slot where this protocol \
                      state was created")
                ~typ:Interval.block_time
            ; arg "blockchainLength"
                ~doc:(check_or_null_doc "Length of the blockchain.")
                ~typ:Interval.length
            ; arg "minWindowDensity"
                ~doc:(check_or_null_doc "Minimum window density")
                ~typ:Interval.length
            ; arg "lastVrfOutput" ~typ:snapp_vrf_output (* nullable! *)
            ; arg "totalCurrency" ~typ:Interval.currency_amount
            ; arg "globalSlotSinceHardFork" ~typ:Interval.global_slot
            ; arg "globalSlotSinceGenesis" ~typ:Interval.global_slot
            ; arg "stakingEpochData" ~typ:(non_null snapp_epoch_data)
            ; arg "nextEpochData" ~typ:(non_null snapp_epoch_data)
            ]

      let snapp_party_body : (Party.Body.t, string) Result.t option arg_typ =
        obj "PartyBody" ~doc:"Body component of a snapp Party"
          ~coerce:
            (fun pk update_result token_id balance_change increment_nonce events
                 sequence_events call_data call_depth protocol_state
                 use_full_commitment ->
            try
              let open Result.Let_syntax in
              let%bind public_key =
                Result.map_error
                  (Public_key.Compressed.of_base58_check pk)
                  ~f:Error.to_string_hum
              in
              let token_id = Token_id.of_string token_id in
              let mk_field_arrays evs =
                List.map evs ~f:(fun fields ->
                    List.map fields ~f:Snark_params.Tick.Field.of_string
                    |> Array.of_list)
              in
              let%bind update = update_result in
              let%bind balance_change = balance_change in
              let%map protocol_state = protocol_state in
              let events = mk_field_arrays events in
              let sequence_events = mk_field_arrays sequence_events in
              let call_data = Snark_params.Tick.Field.of_string call_data in
              Party.Body.Poly.
                { public_key
                ; update
                ; token_id
                ; increment_nonce
                ; balance_change
                ; events
                ; sequence_events
                ; call_data
                ; call_depth
                ; protocol_state
                ; use_full_commitment
                }
            with exn -> Error (Exn.to_string exn))
          ~fields:
            [ arg "publicKey" ~doc:"Public key as a Base58Check string"
                ~typ:(non_null string)
            ; arg "update" ~doc:"Update part of the body"
                ~typ:(non_null snapp_update)
            ; arg "tokenId" ~doc:"Token id" ~typ:(non_null string)
            ; arg "balanceChange"
                ~doc:
                  "Signed amount representing the amount to change for this \
                   particular relevant party."
                ~typ:(non_null snapp_balance_change)
            ; arg "incrementNonce" ~doc:"Whether to increment the nonce"
                ~typ:(non_null bool)
              (* TODO: Do we want fields in base58 in graphQL? Should we use a string of the base10 number like in other parts? Should we use a hex 32bytes -- that seems most natural to me? *)
            ; arg "events"
                ~doc:
                  "A list of events emitted by the snapp. Each event is a list \
                   of field elements, the particular meaning of each event is \
                   determined by the snapp's internal logic."
                ~typ:(non_null (list (non_null (list (non_null string)))))
            ; arg "sequenceEvents"
                ~doc:
                  "A list of sequence events emitted by the snapp. Each event \
                   is a list of field elements, the particular meaning of each \
                   event is determined by the snapp's internal logic. A \
                   commitment to these events is added to the sequenceState of \
                   the snapp account for later use"
                ~typ:(non_null (list (non_null (list (non_null string)))))
            ; arg "callData"
                ~doc:
                  "A commitment to the arguments passed to the snapp and the \
                   returned value, for internal use by the calling snapp. This \
                   commitment is opaque to ensure that private data can be \
                   passed between snapps without revealing it on chain."
                ~typ:(non_null string)
            ; arg "callDepth"
                ~doc:
                  "The number of nested snapp calls in the transaction before \
                   reaching this party."
                ~typ:(non_null int)
            ; arg "protocolState"
                ~typ:(non_null snapp_protocol_state_arg)
                ~doc:"The protocol state in a snapp transaction"
            ; arg "useFullCommitment"
                ~doc:
                  "Use the full or partial commitment when checking the party \
                   predicate."
                ~typ:(non_null bool)
            ]

      let snapp_fee_payer_party_body =
        obj "FeePayerPartyBody" ~doc:"Body component of a snapp Fee Payer Party"
          ~coerce:
            (fun pk update_result fee events sequence_events call_data
                 call_depth protocol_state ->
            try
              let open Result.Let_syntax in
              let%bind public_key =
                Result.map_error
                  (Public_key.Compressed.of_base58_check pk)
                  ~f:Error.to_string_hum
              in
              let token_id = () in
              let increment_nonce = () in
              let mk_field_arrays evs =
                List.map evs ~f:(fun fields ->
                    List.map fields ~f:Snark_params.Tick.Field.of_string
                    |> Array.of_list)
              in
              let%bind update = update_result in
              let balance_change = fee in
              let events = mk_field_arrays events in
              let sequence_events = mk_field_arrays sequence_events in
              let call_data = Snark_params.Tick.Field.of_string call_data in
              let%map protocol_state = protocol_state in
              { Party.Body.Poly.public_key
              ; update
              ; token_id
              ; balance_change
              ; increment_nonce
              ; events
              ; sequence_events
              ; call_data
              ; call_depth
              ; protocol_state
              ; use_full_commitment = ()
              }
            with exn -> Error (Exn.to_string exn))
          ~fields:
            [ arg "publicKey" ~doc:"Public key as a Base58Check string"
                ~typ:(non_null string)
            ; arg "update" ~doc:"Update part of the body"
                ~typ:(non_null snapp_update)
            ; arg "fee" ~doc:"Transaction fee" ~typ:(non_null fee)
            ; arg "events" ~doc:"A list of list of fields in Base58Check"
                ~typ:(non_null (list (non_null (list (non_null string)))))
            ; arg "sequenceEvents"
                ~doc:"A list of list of fields in Base58Check"
                ~typ:(non_null (list (non_null (list (non_null string)))))
            ; arg "callData" ~doc:"A field in Base58Check"
                ~typ:(non_null string)
            ; arg "callDepth"
                ~doc:
                  "The number of nested snapp calls in the transaction before \
                   reaching the fee payer."
                ~typ:(non_null int)
            ; arg "protocolState"
                ~typ:(non_null snapp_protocol_state_arg)
                ~doc:"The protocol state in a snapp transaction"
            ]

      let snapp_party_predicated_fee_payer :
          (Party.Predicated.Fee_payer.t, string) Result.t option arg_typ =
        obj "SnappPartyPredicatedFeePayer"
          ~doc:"A party to a snapp transaction with a nonce predicate"
          ~coerce:(fun body nonce ->
            let open Result.Let_syntax in
            let%map body = body in
            let predicate = nonce in
            Party.Predicated.Poly.{ body; predicate })
          ~fields:
            [ arg "body" ~doc:"fee payer party"
                ~typ:(non_null snapp_fee_payer_party_body)
            ; arg "predicate" ~doc:"nonce" ~typ:(non_null nonce)
            ]

      let snapp_signature =
        scalar "Signature" ~coerce:(fun signature ->
            match signature with
            | `String s ->
                Result.map_error
                  (Signature.of_base58_check s)
                  ~f:Error.to_string_hum
            | _ ->
                Error "Expected signature as a string in Base58Check format")

      (* TODO: define a type otherwise identical to Party.Fee_party.t, but
         which makes the nonce optional
      *)
      let snapp_party_fee_payer =
        obj "SnappPartyFeePayer"
          ~doc:"A party to a snapp transaction with a signature authorization"
          ~coerce:(fun data authorization ->
            let open Result.Let_syntax in
            let%bind data = data in
            Ok Party.Fee_payer.{ data; authorization })
          ~fields:
            [ arg "data" ~doc:"party with a signature and nonce predicate"
                ~typ:(non_null snapp_party_predicated_fee_payer)
            ; arg "authorization" ~doc:"signature"
                ~typ:(non_null snapp_signature)
            ]

      let snapp_receipt_chain_hash =
        scalar "ReceiptChainHash" ~coerce:(fun s ->
            try
              match s with
              | `String chain_hash ->
                  Receipt.Chain_hash.of_base58_check chain_hash
                  |> Result.map_error ~f:Error.to_string_hum
              | _ ->
                  Error "Expected balance as a string"
            with exn -> Error (Exn.to_string exn))

      let snapp_state =
        obj "SnappState" ~doc:"snapp state, a list of 8 field elements"
          ~coerce:(fun element_results ->
            let elements =
              List.map ~f:Snapp_basic.Or_ignore.of_option element_results
            in
            if List.length elements = 8 then
              (* length check means this won't raise *)
              Ok (Snapp_state.V.of_list_exn elements)
            else Error "Expected 8 elements for snapp state")
          ~fields:[ arg "elements" ~typ:(non_null (list field)) ]

      let snapp_predicate_account =
        obj "SnappPredicateAccount"
          ~coerce:
            (fun balance nonce receipt_chain_hash public_key delegate
                 state_result sequence_state proved_state ->
            let open Result.Let_syntax in
            let v o = Snapp_basic.Or_ignore.of_option o in
            let%map state = state_result in
            ( Snapp_predicate.Account.Poly.
                { balance = v balance
                ; nonce = v nonce
                ; receipt_chain_hash = v receipt_chain_hash
                ; public_key = v public_key
                ; delegate = v delegate
                ; state
                ; sequence_state = v sequence_state
                ; proved_state = v proved_state
                }
              : Snapp_predicate.Account.t ))
          ~fields:
            [ arg "balance" ~typ:Interval.balance
            ; arg "nonce" ~typ:Interval.nonce
            ; arg "receiptChainHash"
                ~doc:"receipt chain hash, or null if Ignore"
                ~typ:snapp_receipt_chain_hash
            ; arg "publicKey" ~typ:public_key_arg
            ; arg "delegate" ~typ:public_key_arg
            ; arg "state" ~typ:(non_null snapp_state)
            ; arg "sequenceState" ~typ:field
            ; arg "provedState" ~typ:bool
            ]

      let snapp_predicate =
        obj "SnappPredicate"
          ~coerce:(fun account_opt nonce_opt ->
            match (account_opt, nonce_opt) with
            | None, None ->
                Ok Party.Predicate.Accept
            | Some account_result, None -> (
                match account_result with
                | Ok account ->
                    Ok (Party.Predicate.Full account)
                | Error err ->
                    Error err )
            | None, Some nonce ->
                Ok (Party.Predicate.Nonce nonce)
            | Some _, Some _ ->
                Error
                  "Ill-defined predicate. Account and nonce cannot both be \
                   provided.")
          ~fields:
            [ arg "account"
                ~doc:
                  "The constraints that the account must satisfy in order for \
                   this update to succeed. Snapps can use this field to assert \
                   properties about the account."
                ~typ:snapp_predicate_account
            ; arg "nonce"
                ~doc:
                  "The constraints that the nonce must satisfy in order for \
                   this update to succeed."
                ~typ:nonce
            ]

      let snapp_party_predicated =
        obj "SnappPartyPredicated"
          ~coerce:(fun body_result predicate_result ->
            let open Result.Let_syntax in
            let%bind body = body_result in
            let%bind predicate = predicate_result in
            Ok Party.Predicated.Poly.{ body; predicate })
          ~fields:
            [ arg "body" ~doc:"Body of the party predicated"
                ~typ:(non_null snapp_party_body)
            ; arg "predicate" ~doc:"Predicate of the party predicated"
                ~typ:(non_null snapp_predicate)
            ]

      let snapp_proof =
        scalar "SnappProof" ~coerce:(fun proof ->
            match proof with
            | `String s ->
                Pickles.Side_loaded.Proof.of_base64 s
            | _ ->
                Error "Expected snapp proof as base64-encoded string")

      let snapp_control =
        obj "Control"
          ~coerce:(fun proof_opt signature_opt ->
            match (proof_opt, signature_opt) with
            | Some proof, None ->
                Ok (Control.Proof proof)
            | None, Some signature ->
                Ok (Control.Signature signature)
            | Some _, Some _ ->
                Error "Expected a proof or a signature, but not both"
            | None, None ->
                Ok Control.None_given)
          ~fields:
            [ arg "proof" ~typ:snapp_proof
            ; arg "signature" ~typ:snapp_signature
            ]

      let snapp_party_arg =
        obj "SnappParty" ~doc:"A party to a snapp transaction"
          ~coerce:(fun predicated_result authorization_result ->
            let open Result.Let_syntax in
            let%bind data = predicated_result in
            let%bind authorization = authorization_result in
            Ok Party.{ data; authorization })
          ~fields:
            [ arg "data" ~doc:"Predicated party"
                ~typ:(non_null snapp_party_predicated)
            ; arg "authorization" ~doc:"Authorization for this party"
                ~typ:(non_null snapp_control)
            ]
    end

    let send_test_snapp =
      scalar "SendTestSnappInput" ~doc:"Parties for a test snapp"
        ~coerce:(fun json ->
          let json = to_yojson json in
          Mina_base.Parties.of_yojson json)

    let precomputed_block =
      scalar "PrecomputedBlock" ~doc:"Block encoded in precomputed block format"
        ~coerce:(fun json ->
          let json = to_yojson json in
          Mina_transition.External_transition.Precomputed_block.of_yojson json)

    let extensional_block =
      scalar "ExtensionalBlock" ~doc:"Block encoded in extensional block format"
        ~coerce:(fun json ->
          let json = to_yojson json in
          Archive_lib.Extensional.Block.of_yojson json)

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
             "String or Integer representation of a %s number. If the input is \
              a string, it must represent the number in base 10"
             lower_name) ~coerce:(fun key ->
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
                  (sprintf "Could not convert negative number to %s."
                     lower_name)
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
          "A cryptographic signature -- you must provide either field+scalar \
           or rawSignature"
        ~fields:
          [ arg "field" ~typ:string ~doc:"Field component of signature"
          ; arg "scalar" ~typ:string ~doc:"Scalar component of signature"
          ; arg "rawSignature" ~typ:string ~doc:"Raw encoded signature"
          ]

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

    let vrf_threshold =
      obj "VrfThresholdInput"
        ~doc:
          "The amount of stake delegated, used to determine the threshold for \
           a vrf evaluation producing a block"
        ~coerce:(fun delegated_stake total_stake ->
          { Consensus_vrf.Layout.Threshold.delegated_stake =
              Currency.Balance.of_uint64 delegated_stake
          ; total_stake = Currency.Amount.of_uint64 total_stake
          })
        ~fields:
          [ arg "delegatedStake"
              ~doc:
                "The amount of stake delegated to the vrf evaluator by the \
                 delegating account. This should match the amount in the \
                 epoch's staking ledger, which may be different to the amount \
                 in the current ledger."
              ~typ:(non_null uint64_arg)
          ; arg "totalStake"
              ~doc:
                "The total amount of stake across all accounts in the epoch's \
                 staking ledger."
              ~typ:(non_null uint64_arg)
          ]

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

    module Fields = struct
      let from ~doc = arg "from" ~typ:(non_null public_key_arg) ~doc

      let to_ ~doc = arg "to" ~typ:(non_null public_key_arg) ~doc

      let token ~doc = arg "token" ~typ:(non_null token_id_arg) ~doc

      let token_opt ~doc = arg "token" ~typ:token_id_arg ~doc

      let token_owner ~doc =
        arg "tokenOwner" ~typ:(non_null public_key_arg) ~doc

      let receiver ~doc = arg "receiver" ~typ:(non_null public_key_arg) ~doc

      let receiver_opt ~doc = arg "receiver" ~typ:public_key_arg ~doc

      let fee_payer_opt ~doc = arg "feePayer" ~typ:public_key_arg ~doc

      let fee ~doc = arg "fee" ~typ:(non_null uint64_arg) ~doc

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
            "Should only be set when cancelling transactions, otherwise a \
             nonce is determined automatically"

      let signature =
        arg "signature" ~typ:signature_arg
          ~doc:
            "If a signature is provided, this transaction is considered signed \
             and will be broadcasted to the network without requiring a \
             private key"

      let snapp_fee_payer =
        arg "feePayer"
          ~typ:(non_null Snapp_inputs.snapp_party_fee_payer)
          ~doc:"The fee payer party to a snapp transaction"

      let snapp_other_parties =
        arg "otherParties"
          ~typ:(non_null (list (non_null Snapp_inputs.snapp_party_arg)))
          ~doc:"The parties other than the fee payer in a snapp transaction"

      let snapp_protocol_state =
        arg "protocolState"
          ~typ:(non_null Snapp_inputs.snapp_protocol_state_arg)
          ~doc:"The protocol state in a snapp transaction"
    end

    let send_payment =
      let open Fields in
      obj "SendPaymentInput"
        ~coerce:(fun from to_ token amount fee valid_until memo nonce ->
          (from, to_, token, amount, fee, valid_until, memo, nonce))
        ~fields:
          [ from ~doc:"Public key of sender of payment"
          ; to_ ~doc:"Public key of recipient of payment"
          ; token_opt ~doc:"Token to send"
          ; arg "amount" ~doc:"Amount of MINA to send to receiver"
              ~typ:(non_null uint64_arg)
          ; fee ~doc:"Fee amount in order to send payment"
          ; valid_until
          ; memo
          ; nonce
          ]

    let send_snapp =
      let open Fields in
      obj "SendSnappInput"
        ~coerce:(fun fee_payer other_parties memo ->
          (fee_payer, other_parties, memo))
        ~fields:[ snapp_fee_payer; snapp_other_parties; memo ]

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

    let create_token =
      let open Fields in
      obj "SendCreateTokenInput"
        ~coerce:(fun fee_payer token_owner fee valid_until memo nonce ->
          (fee_payer, token_owner, fee, valid_until, memo, nonce))
        ~fields:
          [ fee_payer_opt
              ~doc:"Public key to pay the fee from (defaults to the tokenOwner)"
          ; token_owner ~doc:"Public key to create the token for"
          ; fee ~doc:"Fee amount in order to create a token"
          ; valid_until
          ; memo
          ; nonce
          ]

    let create_token_account =
      let open Fields in
      obj "SendCreateTokenAccountInput"
        ~coerce:
          (fun token_owner token receiver fee fee_payer valid_until memo nonce ->
          ( token_owner
          , token
          , receiver
          , fee
          , fee_payer
          , valid_until
          , memo
          , nonce ))
        ~fields:
          [ token_owner ~doc:"Public key of the token's owner"
          ; token ~doc:"Token to create an account for"
          ; receiver ~doc:"Public key to create the account for"
          ; fee ~doc:"Fee amount in order to create a token account"
          ; fee_payer_opt
              ~doc:
                "Public key to pay the fees from and sign the transaction with \
                 (defaults to the receiver)"
          ; valid_until
          ; memo
          ; nonce
          ]

    let mint_tokens =
      let open Fields in
      obj "SendMintTokensInput"
        ~coerce:
          (fun token_owner token receiver amount fee valid_until memo nonce ->
          (token_owner, token, receiver, amount, fee, valid_until, memo, nonce))
        ~fields:
          [ token_owner ~doc:"Public key of the token's owner"
          ; token ~doc:"Token to mint more of"
          ; receiver_opt
              ~doc:
                "Public key to mint the new tokens for (defaults to token \
                 owner's account)"
          ; arg "amount"
              ~doc:"Amount of token to create in the receiver's account"
              ~typ:(non_null uint64_arg)
          ; fee ~doc:"Fee amount in order to mint tokens"
          ; valid_until
          ; memo
          ; nonce
          ]

    let rosetta_transaction =
      Schema.Arg.scalar "RosettaTransaction"
        ~doc:"A transaction encoded in the Rosetta format"
        ~coerce:(fun graphql_json ->
          Rosetta_lib.Transaction.to_mina_signed (to_yojson graphql_json)
          |> Result.map_error ~f:Error.to_string_hum)

    let create_account =
      obj "AddAccountInput" ~coerce:Fn.id
        ~fields:
          [ arg "password" ~doc:"Password used to encrypt the new account"
              ~typ:(non_null string)
          ]

    let unlock_account =
      obj "UnlockInput"
        ~coerce:(fun password pk -> (password, pk))
        ~fields:
          [ arg "password" ~doc:"Password for the account to be unlocked"
              ~typ:(non_null string)
          ; arg "publicKey" ~doc:"Public key specifying which account to unlock"
              ~typ:(non_null public_key_arg)
          ]

    let create_hd_account =
      obj "CreateHDAccountInput" ~coerce:Fn.id
        ~fields:
          [ arg "index" ~doc:"Index of the account in hardware wallet"
              ~typ:(non_null uint32_arg)
          ]

    let lock_account =
      obj "LockInput" ~coerce:Fn.id
        ~fields:
          [ arg "publicKey" ~doc:"Public key specifying which account to lock"
              ~typ:(non_null public_key_arg)
          ]

    let delete_account =
      obj "DeleteAccountInput" ~coerce:Fn.id
        ~fields:
          [ arg "publicKey" ~doc:"Public key of account to be deleted"
              ~typ:(non_null public_key_arg)
          ]

    let reset_trust_status =
      obj "ResetTrustStatusInput" ~coerce:Fn.id
        ~fields:[ arg "ipAddress" ~typ:(non_null string) ]

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

    let user_command_filter_input =
      obj "UserCommandFilterType" ~coerce:Fn.id
        ~fields:
          [ arg "toOrFrom"
              ~doc:
                "Public key of sender or receiver of transactions you are \
                 looking for"
              ~typ:(non_null public_key_arg)
          ]

    let set_coinbase_receiver =
      obj "SetCoinbaseReceiverInput" ~coerce:Fn.id
        ~fields:
          [ arg "publicKey" ~typ:public_key_arg
              ~doc:
                "Public key of the account to receive coinbases. Block \
                 production keys will receive the coinbases if none is given"
          ]

    let set_snark_work_fee =
      obj "SetSnarkWorkFee"
        ~fields:
          [ Fields.fee ~doc:"Fee to get rewarded for producing snark work" ]
        ~coerce:Fn.id

    let set_snark_worker =
      obj "SetSnarkWorkerInput" ~coerce:Fn.id
        ~fields:
          [ arg "publicKey" ~typ:public_key_arg
              ~doc:
                "Public key you wish to start snark-working on; null to stop \
                 doing any snark work"
          ]

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
                  "If true, no connections will be allowed unless they are \
                   from a trusted peer"
            ]
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
            ~resolve:(fun
                       _
                       { Consensus_vrf.Layout.Threshold.delegated_stake; _ }
                     -> Currency.Balance.to_uint64 delegated_stake)
        ; field "totalStake"
            ~doc:
              "The total amount of stake across all accounts in the epoch's \
               staking ledger." ~args:[] ~typ:(non_null uint64)
            ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.total_stake; _ } ->
              Currency.Amount.to_uint64 total_stake)
        ])

  let vrf_evaluation : ('context, Consensus_vrf.Layout.Evaluation.t option) typ
      =
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
                vrf_opt)
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
                      |> Bignum.to_float)
                    vrf_opt)
        ; field "thresholdMet" ~typ:bool
            ~doc:
              "Whether the threshold to produce a block was met, if specified"
            ~args:
              Arg.
                [ arg "input" ~doc:"Override for delegation threshold"
                    ~typ:Input.vrf_threshold
                ]
            ~resolve:(fun { ctx = mina; _ } t input ->
              match input with
              | Some { delegated_stake; total_stake } ->
                  let constraint_constants =
                    (Mina_lib.config mina).precomputed_values
                      .constraint_constants
                  in
                  (Consensus_vrf.Layout.Evaluation.compute_vrf
                     ~constraint_constants t ~delegated_stake ~total_stake)
                    .threshold_met
              | None ->
                  t.threshold_met)
        ])
end

module Subscriptions = struct
  open Schema

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

  let commands = [ new_sync_update; new_block; chain_reorganization ]
end

module Mutations = struct
  open Schema

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
      ~typ:(non_null Types.Payload.create_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.create_account) ]
      ~resolve:create_account_resolver

  let create_account =
    io_field "createAccount"
      ~doc:
        "Create a new account - this will create a new keypair and store it in \
         the daemon"
      ~typ:(non_null Types.Payload.create_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.create_account) ]
      ~resolve:create_account_resolver

  let create_hd_account : (Mina_lib.t, unit) field =
    io_field "createHDAccount"
      ~doc:Secrets.Hardware_wallets.create_hd_account_summary
      ~typ:(non_null Types.Payload.create_account)
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
      ~typ:(non_null Types.Payload.unlock_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.unlock_account) ]
      ~resolve:unlock_account_resolver

  let unlock_account =
    io_field "unlockAccount"
      ~doc:"Allow transactions to be sent from the unlocked account"
      ~typ:(non_null Types.Payload.unlock_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.unlock_account) ]
      ~resolve:unlock_account_resolver

  let lock_account_resolver { ctx = t; _ } () pk =
    Mina_lib.wallets t |> Secrets.Wallets.lock ~needle:pk ;
    pk

  let lock_wallet =
    field "lockWallet"
      ~doc:"Lock an unlocked account to prevent transaction being sent from it"
      ~deprecated:(Deprecated (Some "use lockAccount instead"))
      ~typ:(non_null Types.Payload.lock_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.lock_account) ]
      ~resolve:lock_account_resolver

  let lock_account =
    field "lockAccount"
      ~doc:"Lock an unlocked account to prevent transaction being sent from it"
      ~typ:(non_null Types.Payload.lock_account)
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
      ~typ:(non_null Types.Payload.delete_account)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.delete_account) ]
      ~resolve:delete_account_resolver

  let delete_account =
    io_field "deleteAccount"
      ~doc:"Delete the private key for an account that you track"
      ~typ:(non_null Types.Payload.delete_account)
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
      ~typ:(non_null Types.Payload.reload_accounts)
      ~args:Arg.[]
      ~resolve:reload_account_resolver

  let reload_accounts =
    io_field "reloadAccounts"
      ~doc:"Reload tracked account information from disk"
      ~typ:(non_null Types.Payload.reload_accounts)
      ~args:Arg.[]
      ~resolve:reload_account_resolver

  let import_account =
    io_field "importAccount" ~doc:"Reload tracked account information from disk"
      ~typ:(non_null Types.Payload.import_account)
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
      ~typ:(list (non_null Types.Payload.trust_status))
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

  let send_snapp_command mina parties =
    match Mina_commands.setup_and_submit_snapp_command mina parties with
    | `Active f -> (
        match%map f with
        | Ok parties ->
            let cmd =
              { Types.Snapp_command.With_status.data = parties
              ; status = Enqueued
              }
            in
            let cmd_with_hash =
              Types.Snapp_command.With_status.map cmd ~f:(fun cmd ->
                  { With_hash.data = cmd
                  ; hash = Transaction_hash.hash_command (Parties cmd)
                  })
            in
            Ok cmd_with_hash
        | Error e ->
            Error
              (sprintf "Couldn't send snapp command: %s"
                 (Error.to_string_hum e)) )
    | `Bootstrapping ->
        return (Error "Daemon is bootstrapping")

  let mock_snapp_command mina parties :
      ( (Parties.t, Transaction_hash.t) With_hash.t
        Types.Snapp_command.With_status.t
      , string )
      result
      Io.t =
    (* instead of adding the parties to the transaction pool, as we would for an actual snapp,
       apply the snapp using an ephemeral ledger
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
                  "When creating ledger for mock snapp, account with public \
                   key %s and token %s already existed"
                  (Signature_lib.Public_key.Compressed.to_string pk)
                  (Token_id.to_string token) ()
            | Error err ->
                (* should be unreachable *)
                Error.tag_arg err
                  "When creating ledger for mock snapp, error when adding \
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
                (* rearrange data to match result type of `send_snapp_command` *)
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
                        | Applied _ ->
                            Applied
                        | Failed (failure, _balance_data) ->
                            Included_but_failed failure
                      in
                      ( { data = with_hash; status }
                        : _ Types.Snapp_command.With_status.t ))
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

  let create_user_command_input ~fee ~fee_token ~fee_payer_pk ~nonce_opt
      ~valid_until ~memo ~signer ~body ~sign_choice :
      (User_command_input.t, string) result =
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
    User_command_input.create ~signer ~fee ~fee_token ~fee_payer_pk
      ?nonce:nonce_opt ~valid_until ~memo ~body ~sign_choice ()

  let make_signed_user_command ~signature ~nonce_opt ~signer ~memo ~fee
      ~fee_token ~fee_payer_pk ~valid_until ~body =
    let open Deferred.Result.Let_syntax in
    let%bind signature = signature |> Deferred.return in
    let%map user_command_input =
      create_user_command_input ~nonce_opt ~signer ~memo ~fee ~fee_token
        ~fee_payer_pk ~valid_until ~body
        ~sign_choice:(User_command_input.Sign_choice.Signature signature)
      |> Deferred.return
    in
    user_command_input

  let send_signed_user_command ~signature ~coda ~nonce_opt ~signer ~memo ~fee
      ~fee_token ~fee_payer_pk ~valid_until ~body =
    let open Deferred.Result.Let_syntax in
    let%bind user_command_input =
      make_signed_user_command ~signature ~nonce_opt ~signer ~memo ~fee
        ~fee_token ~fee_payer_pk ~valid_until ~body
    in
    let%map cmd = send_user_command coda user_command_input in
    Types.User_command.With_status.map cmd ~f:(fun cmd ->
        { With_hash.data = cmd
        ; hash = Transaction_hash.hash_command (Signed_command cmd)
        })

  let send_unsigned_user_command ~coda ~nonce_opt ~signer ~memo ~fee ~fee_token
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
      create_user_command_input ~nonce_opt ~signer ~memo ~fee ~fee_token
        ~fee_payer_pk ~valid_until ~body ~sign_choice)
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
      ~typ:(non_null Types.Payload.send_delegation)
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
        let fee_token = Token_id.default in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_token ~fee_payer_pk:from ~valid_until ~body
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command
        | Some signature ->
            let%bind signature = signature |> Deferred.return in
            send_signed_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_token ~fee_payer_pk:from ~valid_until ~body ~signature
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command)

  let send_payment =
    io_field "sendPayment" ~doc:"Send a payment"
      ~typ:(non_null Types.Payload.send_payment)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.send_payment)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = coda; _ } ()
             (from, to_, token_id, amount, fee, valid_until, memo, nonce_opt)
             signature ->
        let body =
          Signed_command_payload.Body.Payment
            { source_pk = from
            ; receiver_pk = to_
            ; token_id = Option.value ~default:Token_id.default token_id
            ; amount = Amount.of_uint64 amount
            }
        in
        let fee_token = Token_id.default in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_token ~fee_payer_pk:from ~valid_until ~body
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command
        | Some signature ->
            send_signed_user_command ~coda ~nonce_opt ~signer:from ~memo ~fee
              ~fee_token ~fee_payer_pk:from ~valid_until ~body ~signature
            |> Deferred.Result.map ~f:Types.User_command.mk_user_command)

  let make_snapp_endpoint ~name ~doc ~f =
    io_field name ~doc
      ~typ:(non_null Types.Payload.send_snapp)
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.send_snapp) ]
      ~resolve:
        (fun { ctx = coda; _ } ()
             (fee_payer_result, other_parties_results, memo) ->
        let parties_result =
          let open Result.Let_syntax in
          let other_parties_result = Result.all other_parties_results in
          let%bind fee_payer = fee_payer_result in
          let%bind other_parties = other_parties_result in
          let%map memo =
            Option.value_map memo ~default:(Ok Signed_command_memo.empty)
              ~f:(fun memo ->
                result_of_exn Signed_command_memo.create_from_string_exn memo
                  ~error:"Invalid `memo` provided.")
          in
          { Parties.fee_payer; other_parties; memo }
        in
        match parties_result with
        | Ok parties ->
            f coda parties
        | Error err ->
            return (Error err))

  let send_snapp =
    make_snapp_endpoint ~name:"sendSnapp" ~doc:"Send a snapp transaction"
      ~f:send_snapp_command

  let mock_snapp =
    make_snapp_endpoint ~name:"mockSnapp"
      ~doc:"Mock a snapp transaction, no effect on blockchain"
      ~f:mock_snapp_command

  let send_test_snapp =
    io_field "sendTestSnapp" ~doc:"Send a test snapp"
      ~args:Arg.[ arg "parties" ~typ:(non_null Types.Input.send_test_snapp) ]
      ~typ:(non_null Types.Payload.send_snapp)
      ~resolve:(fun { ctx = mina; _ } () parties ->
        send_snapp_command mina parties)

  let create_token =
    io_field "createToken" ~doc:"Create a new token"
      ~typ:(non_null Types.Payload.create_token)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.create_token)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = coda; _ } ()
             (fee_payer_pk, token_owner, fee, valid_until, memo, nonce_opt)
             signature ->
        let fee_payer_pk = Option.value ~default:token_owner fee_payer_pk in
        let body =
          Signed_command_payload.Body.Create_new_token
            { token_owner_pk = token_owner
            ; disable_new_accounts =
                (* TODO(5274): Expose when permissions commands are merged. *)
                false
            }
        in
        let fee_token = Token_id.default in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:token_owner
              ~memo ~fee ~fee_token ~fee_payer_pk ~valid_until ~body
        | Some signature ->
            send_signed_user_command ~coda ~nonce_opt ~signer:token_owner ~memo
              ~fee ~fee_token ~fee_payer_pk ~valid_until ~body ~signature)

  let create_token_account =
    io_field "createTokenAccount" ~doc:"Create a new account for a token"
      ~typ:(non_null Types.Payload.create_token_account)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.create_token_account)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = coda; _ } ()
             ( token_owner
             , token
             , receiver
             , fee
             , fee_payer
             , valid_until
             , memo
             , nonce_opt ) signature ->
        let body =
          Signed_command_payload.Body.Create_token_account
            { token_id = token
            ; token_owner_pk = token_owner
            ; receiver_pk = receiver
            ; account_disabled =
                (* TODO(5274): Expose when permissions commands are merged. *)
                false
            }
        in
        let fee_token = Token_id.default in
        let fee_payer_pk = Option.value ~default:receiver fee_payer in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:fee_payer_pk
              ~memo ~fee ~fee_token ~fee_payer_pk ~valid_until ~body
        | Some signature ->
            send_signed_user_command ~coda ~nonce_opt ~signer:fee_payer_pk ~memo
              ~fee ~fee_token ~fee_payer_pk ~valid_until ~body ~signature)

  let mint_tokens =
    io_field "mintTokens" ~doc:"Mint more of a token"
      ~typ:(non_null Types.Payload.mint_tokens)
      ~args:
        Arg.
          [ arg "input" ~typ:(non_null Types.Input.mint_tokens)
          ; Types.Input.Fields.signature
          ]
      ~resolve:
        (fun { ctx = coda; _ } ()
             ( token_owner
             , token
             , receiver
             , amount
             , fee
             , valid_until
             , memo
             , nonce_opt ) signature ->
        let body =
          Signed_command_payload.Body.Mint_tokens
            { token_id = token
            ; token_owner_pk = token_owner
            ; receiver_pk = Option.value ~default:token_owner receiver
            ; amount = Amount.of_uint64 amount
            }
        in
        let fee_token = Token_id.default in
        match signature with
        | None ->
            send_unsigned_user_command ~coda ~nonce_opt ~signer:token_owner
              ~memo ~fee ~fee_token ~fee_payer_pk:token_owner ~valid_until ~body
        | Some signature ->
            send_signed_user_command ~coda ~nonce_opt ~signer:token_owner ~memo
              ~fee ~fee_token ~fee_payer_pk:token_owner ~valid_until ~body
              ~signature)

  let send_rosetta_transaction =
    io_field "sendRosettaTransaction"
      ~doc:"Send a transaction in Rosetta format"
      ~typ:(non_null Types.Payload.send_rosetta_transaction)
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
      ~typ:(non_null Types.Payload.export_logs)
      ~resolve:(fun { ctx = coda; _ } () basename_opt ->
        let%map result = export_logs ~coda basename_opt in
        Result.map_error result
          ~f:(Fn.compose Yojson.Safe.to_string Error_json.error_to_yojson))

  let set_coinbase_receiver =
    field "setCoinbaseReceiver" ~doc:"Set the key to receive coinbases"
      ~args:
        Arg.[ arg "input" ~typ:(non_null Types.Input.set_coinbase_receiver) ]
      ~typ:(non_null Types.Payload.set_coinbase_receiver)
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
      ~typ:(non_null Types.Payload.set_snark_worker)
      ~resolve:(fun { ctx = coda; _ } () pk ->
        let old_snark_worker_key = Mina_lib.snark_worker_key coda in
        let%map () = Mina_lib.replace_snark_worker_key coda pk in
        Ok old_snark_worker_key)

  let set_snark_work_fee =
    result_field "setSnarkWorkFee"
      ~doc:"Set fee that you will like to receive for doing snark work"
      ~args:Arg.[ arg "input" ~typ:(non_null Types.Input.set_snark_work_fee) ]
      ~typ:(non_null Types.Payload.set_snark_work_fee)
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
      ~typ:(non_null Types.Payload.set_connection_gating_config)
      ~resolve:(fun { ctx = coda; _ } () config ->
        let open Deferred.Result.Let_syntax in
        let%bind config = Deferred.return config in
        let open Deferred.Let_syntax in
        Mina_networking.set_connection_gating_config (Mina_lib.net coda) config
        >>| Result.return)

  let add_peer =
    io_field "addPeers"
      ~args:
        Arg.
          [ arg "peers" ~typ:(non_null @@ list @@ non_null @@ Types.Input.peer)
          ; arg "seed" ~typ:bool
          ]
      ~doc:"Connect to the given peers"
      ~typ:(non_null @@ list @@ non_null Types.DaemonStatus.peer)
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
    [ add_wallet
    ; create_account
    ; create_hd_account
    ; unlock_account
    ; unlock_wallet
    ; lock_account
    ; lock_wallet
    ; delete_account
    ; delete_wallet
    ; reload_accounts
    ; import_account
    ; reload_wallets
    ; send_payment
    ; send_delegation
    ; create_token
    ; create_token_account
    ; mint_tokens
    ; send_snapp
    ; mock_snapp
    ; send_test_snapp
    ; export_logs
    ; set_coinbase_receiver
    ; set_snark_worker
    ; set_snark_work_fee
    ; set_connection_gating_config
    ; add_peer
    ; archive_precomputed_block
    ; archive_extensional_block
    ; send_rosetta_transaction
    ]
end

module Queries = struct
  open Schema

  (* helper for pooledUserCommands, pooledSnappCommands *)
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

  let pooled_snapp_commands =
    field "pooledSnappCommands"
      ~doc:
        "Retrieve all the scheduled snapp commands for a specified sender that \
         the current daemon sees in its transaction pool. All scheduled \
         commands are queried if no sender is specified"
      ~typ:(non_null @@ list @@ non_null Types.Snapp_command.snapp_command)
      ~args:
        Arg.
          [ arg "publicKey" ~doc:"Public key of sender of pooled snapp commands"
              ~typ:Types.Input.public_key_arg
          ; arg "hashes" ~doc:"Hashes of the snapp commands to find in the pool"
              ~typ:(list (non_null string))
          ; arg "ids" ~typ:(list (non_null guid)) ~doc:"Ids of snapp commands"
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
            | Parties snapp_cmd ->
                Some
                  { Types.Snapp_command.With_status.status = Enqueued
                  ; data = { cmd_with_hash with data = snapp_cmd }
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
      ~typ:(non_null Types.DaemonStatus.t) ~resolve:(fun { ctx = coda; _ } () ->
        Mina_commands.get_status ~flag:`Performance coda >>| Result.return)

  let trust_status =
    field "trustStatus"
      ~typ:(list (non_null Types.Payload.trust_status))
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
      ~typ:(non_null @@ list @@ non_null Types.Payload.trust_status)
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
    field "tokenOwner" ~doc:"Find the public key that owns a given token"
      ~typ:Types.public_key
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
          ; arg "snappTransaction" ~typ:guid ~doc:"Id of a snapp transaction"
          ]
      ~resolve:
        (fun { ctx = coda; _ } () (serialized_payment : string option)
             (serialized_snapp : string option) ->
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
          match (serialized_payment, serialized_snapp) with
          | None, None | Some _, Some _ ->
              Error
                "Invalid query: Specify either a payment ID or a snapp \
                 transaction ID"
          | Some payment, None ->
              deserialize_txn (`Signed_command payment)
          | None, Some snapp_txn ->
              deserialize_txn (`Parties snapp_txn)
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
    let transition =
      Transition_frontier.Breadcrumb.validated_transition breadcrumb
    in
    let transactions =
      Mina_transition.External_transition.Validated.transactions
        ~constraint_constants:
          (Mina_lib.config coda).precomputed_values.constraint_constants
        transition
    in
    With_hash.Stable.Latest.
      { data =
          Filtered_external_transition.of_transition transition `All
            transactions
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
                  Mina_transition.External_transition.Validated
                  .blockchain_length validated_transition
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
      ~typ:(non_null @@ list @@ non_null Types.DaemonStatus.peer)
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

  let next_available_token =
    field "nextAvailableToken"
      ~doc:
        "The next token ID that has not been allocated. Token IDs are \
         allocated sequentially, so all lower token IDs have been allocated"
      ~args:Arg.[]
      ~typ:(non_null Types.token_id)
      ~resolve:(fun { ctx = coda; _ } () ->
        coda |> Mina_lib.best_tip |> Participating_state.active
        |> Option.map ~f:(fun tip ->
               Transition_frontier.Breadcrumb.staged_ledger tip
               |> Staged_ledger.ledger |> Ledger.next_available_token)
        |> Option.value ~default:Token_id.(next default))

  let connection_gating_config =
    io_field "connectionGatingConfig"
      ~doc:
        "The rules that the libp2p helper will use to determine which \
         connections to permit"
      ~args:Arg.[]
      ~typ:(non_null Types.Payload.set_connection_gating_config)
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
             (from, to_, token_id, amount, fee, valid_until, memo, nonce_opt)
             signature ->
        let open Deferred.Result.Let_syntax in
        let body =
          Signed_command_payload.Body.Payment
            { source_pk = from
            ; receiver_pk = to_
            ; token_id = Option.value ~default:Token_id.default token_id
            ; amount = Amount.of_uint64 amount
            }
        in
        let fee_token = Token_id.default in
        let%bind signature =
          match signature with
          | Some signature ->
              return signature
          | None ->
              Deferred.Result.fail "Signature field is missing"
        in
        let%bind user_command_input =
          Mutations.make_signed_user_command ~nonce_opt ~signer:from ~memo ~fee
            ~fee_token ~fee_payer_pk:from ~valid_until ~body ~signature
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

  let commands =
    [ sync_status
    ; daemon_status
    ; version
    ; owned_wallets (* deprecated *)
    ; tracked_accounts
    ; wallet (* deprecated *)
    ; connection_gating_config
    ; account
    ; accounts_for_pk
    ; token_owner
    ; current_snark_worker
    ; best_chain
    ; block
    ; genesis_block
    ; initial_peers
    ; get_peers
    ; pooled_user_commands
    ; pooled_snapp_commands
    ; transaction_status
    ; trust_status
    ; trust_status_all
    ; snark_pool
    ; pending_snark_work
    ; genesis_constants
    ; time_offset
    ; next_available_token
    ; validate_payment
    ; evaluate_vrf
    ; check_vrf
    ; runtime_config
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
      [ Queries.daemon_status; Queries.block; Queries.version ]
      ~mutations:[] ~subscriptions:[])
