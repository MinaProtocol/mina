open Core_kernel
open Async_kernel
open Protocols
open Pipe_lib
open O1trace

module type Ledger_builder_io_intf = sig
  type t

  type net

  type ledger_builder_hash

  type ledger_hash

  type ledger_builder_aux

  type sync_ledger_query

  type sync_ledger_answer

  type protocol_state

  val create : net -> t

  val get_ledger_builder_aux_at_hash :
    t -> ledger_builder_hash -> ledger_builder_aux Deferred.Or_error.t

  val glue_sync_ledger :
       t
    -> (ledger_hash * sync_ledger_query) Linear_pipe.Reader.t
    -> (ledger_hash * sync_ledger_answer) Linear_pipe.Writer.t
    -> unit
end

module type Network_intf = sig
  type t

  type state_with_witness

  type ledger_builder

  type protocol_state

  type ledger_hash

  type ledger_builder_hash

  type parallel_scan_state

  type sync_ledger_query

  type sync_ledger_answer

  type snark_pool_diff

  type transaction_pool_diff

  val states :
    t -> (state_with_witness * Unix_timestamp.t) Linear_pipe.Reader.t

  val peers : t -> Kademlia.Peer.t list

  val snark_pool_diffs : t -> snark_pool_diff Linear_pipe.Reader.t

  val transaction_pool_diffs : t -> transaction_pool_diff Linear_pipe.Reader.t

  val broadcast_state : t -> state_with_witness -> unit

  val broadcast_snark_pool_diff : t -> snark_pool_diff -> unit

  val broadcast_transaction_pool_diff : t -> transaction_pool_diff -> unit

  module Ledger_builder_io :
    Ledger_builder_io_intf
    with type net := t
     and type ledger_builder_aux := parallel_scan_state
     and type ledger_builder_hash := ledger_builder_hash
     and type ledger_hash := ledger_hash
     and type protocol_state := protocol_state
     and type sync_ledger_query := sync_ledger_query
     and type sync_ledger_answer := sync_ledger_answer

  module Config : sig
    type t
  end

  val create :
       Config.t
    -> get_ledger_builder_aux_at_hash:(   ledger_builder_hash
                                       -> (parallel_scan_state * ledger_hash)
                                          option
                                          Deferred.t)
    -> answer_sync_ledger_query:(   ledger_hash * sync_ledger_query
                                 -> (ledger_hash * sync_ledger_answer)
                                    Deferred.Or_error.t)
    -> t Deferred.t
end

module type Transaction_pool_read_intf = sig
  type t

  type transaction_with_valid_signature

  val transactions : t -> transaction_with_valid_signature Sequence.t
end

module type Transaction_pool_intf = sig
  include Transaction_pool_read_intf

  type pool_diff

  type transaction

  val broadcasts : t -> pool_diff Linear_pipe.Reader.t

  val load :
       parent_log:Logger.t
    -> disk_location:string
    -> incoming_diffs:pool_diff Linear_pipe.Reader.t
    -> t Deferred.t

  val add : t -> transaction -> unit Deferred.t
end

module type Snark_pool_intf = sig
  type t

  type completed_work_statement

  type completed_work_checked

  type pool_diff

  val broadcasts : t -> pool_diff Linear_pipe.Reader.t

  val load :
       parent_log:Logger.t
    -> disk_location:string
    -> incoming_diffs:pool_diff Linear_pipe.Reader.t
    -> t Deferred.t

  val get_completed_work :
    t -> completed_work_statement -> completed_work_checked option
end

module type Ktree_intf = sig
  type elem

  type t [@@deriving sexp]

  val gen : elem Quickcheck.Generator.t -> t Quickcheck.Generator.t

  val find_map : t -> f:(elem -> 'a option) -> 'a option

  val path : t -> f:(elem -> bool) -> elem list option

  val singleton : elem -> t

  val longest_path : t -> elem list

  val add :
    t -> elem -> parent:(elem -> bool) -> [> `Added of t | `No_parent | `Repeat]

  val root : t -> elem
end

module type Ledger_builder_controller_intf = sig
  type public_key_compressed

  type ledger_builder

  type ledger_builder_hash

  type external_transition

  type ledger

  type maskable_ledger

  type tip

  type net

  type protocol_state

  type consensus_local_state

  type t

  type sync_query

  type sync_answer

  type ledger_proof

  type ledger_hash

  module Config : sig
    type t =
      { parent_log: Logger.t
      ; net_deferred: net Deferred.t
      ; external_transitions:
          (external_transition * Unix_timestamp.t) Linear_pipe.Reader.t
      ; genesis_tip: tip
      ; ledger: maskable_ledger
      ; consensus_local_state: consensus_local_state
      ; proposer_public_key: public_key_compressed option
      ; longest_tip_location: string }
    [@@deriving make]
  end

  val create : Config.t -> t Deferred.t

  module For_tests : sig
    val load_tip : t -> Config.t -> tip Deferred.t
  end

  val strongest_tip : t -> tip

  val local_get_ledger :
       t
    -> ledger_builder_hash
    -> (ledger_builder * protocol_state) Deferred.Or_error.t

  val strongest_ledgers :
    t -> (ledger_builder * external_transition) Linear_pipe.Reader.t

  val handle_sync_ledger_queries :
       t
    -> ledger_hash * sync_query
    -> (ledger_hash * sync_answer) Deferred.Or_error.t
end

module type Proposer_intf = sig
  type ledger_hash

  type ledger_builder

  type transaction

  type external_transition

  type completed_work_statement

  type completed_work_checked

  type protocol_state

  type protocol_state_proof

  type consensus_local_state

  type time_controller

  type keypair

  type transition_frontier

  type transaction_pool

  val create :
       parent_log:Logger.t
    -> get_completed_work:(   completed_work_statement
                           -> completed_work_checked option)
    -> transaction_pool:transaction_pool
    -> time_controller:time_controller
    -> keypair:keypair
    -> consensus_local_state:consensus_local_state
    -> transition_frontier:transition_frontier
    -> (external_transition * Unix_timestamp.t) Linear_pipe.Reader.t
end

module type Witness_change_intf = sig
  type t_with_witness

  type witness

  type t

  val forget_witness : t_with_witness -> t

  val add_witness_exn : t -> witness -> t_with_witness

  val add_witness : t -> witness -> t_with_witness Or_error.t
end

module type State_with_witness_intf = sig
  type state

  type ledger_hash

  type ledger_builder_transition

  type ledger_builder_transition_with_valid_signatures_and_proofs

  type t =
    { ledger_builder_transition:
        ledger_builder_transition_with_valid_signatures_and_proofs
    ; state: state }
  [@@deriving sexp]

  module Stripped : sig
    type t =
      {ledger_builder_transition: ledger_builder_transition; state: state}
  end

  val strip : t -> Stripped.t

  val forget_witness : t -> state
end

module type Inputs_intf = sig
  include Coda_pow.Inputs_intf

  module Proof_carrying_state : sig
    type t =
      ( Consensus_mechanism.Protocol_state.value
      , Protocol_state_proof.t )
      Coda_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module State_with_witness :
    State_with_witness_intf
    with type state := Proof_carrying_state.t
     and type ledger_hash := Ledger_hash.t
     and type ledger_builder_transition := Ledger_builder_transition.t
     and type ledger_builder_transition_with_valid_signatures_and_proofs :=
                Ledger_builder_transition.With_valid_signatures_and_proofs.t

  module Snark_pool :
    Snark_pool_intf
    with type completed_work_statement := Completed_work.Statement.t
     and type completed_work_checked := Completed_work.Checked.t

  module Work_selector :
    Coda_pow.Work_selector_intf
    with type ledger_builder := Ledger_builder.t
     and type work :=
                ( Ledger_proof_statement.t
                , Transaction.t
                , Sparse_ledger.t
                , Ledger_proof.t )
                Snark_work_lib.Work.Single.Spec.t
     and type snark_pool := Snark_pool.t
     and type fee := Currency.Fee.t

  module Transaction_pool :
    Transaction_pool_intf
    with type transaction_with_valid_signature :=
                User_command.With_valid_signature.t
     and type transaction := User_command.t

  module Sync_ledger : sig
    type query [@@deriving bin_io]

    type answer [@@deriving bin_io]
  end

  module Net :
    Network_intf
    with type state_with_witness := External_transition.t
     and type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type snark_pool_diff := Snark_pool.pool_diff
     and type transaction_pool_diff := Transaction_pool.pool_diff
     and type parallel_scan_state := Ledger_builder.Aux.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Sync_ledger.query
     and type sync_ledger_answer := Sync_ledger.answer

  module Ledger_builder_controller :
    Ledger_builder_controller_intf
    with type net := Net.t
     and type ledger := Ledger.t
     and type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type external_transition := External_transition.t
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type consensus_local_state := Consensus_mechanism.Local_state.t
     and type sync_query := Sync_ledger.query
     and type sync_answer := Sync_ledger.answer
     and type ledger_hash := Ledger_hash.t
     and type ledger_proof := Ledger_proof.t
     and type tip := Tip.t
     and type public_key_compressed := Public_key.Compressed.t
     and type maskable_ledger := Ledger.maskable_ledger

  module Ledger_db : Coda_pow.Ledger_creatable_intf

  module Masked_ledger : sig
    type t
  end

  module Transition_frontier :
    Protocols.Coda_transition_frontier.Transition_frontier_base_intf
    with type state_hash := Protocol_state_hash.t
     and type external_transition := External_transition.t
     and type ledger_database := Ledger_db.t
     and type masked_ledger := Masked_ledger.t

  module Transition_frontier_controller :
    Protocols.Coda_transition_frontier.Transition_frontier_controller_intf
    with type time_controller := Time.Controller.t
     and type external_transition := External_transition.t
     and type syncable_ledger_query := Sync_ledger.query
     and type syncable_ledger_answer := Sync_ledger.answer
     and type transition_frontier := Transition_frontier.t
     and type state_hash := Protocol_state_hash.t
     and type time := Time.t

  module Proposer :
    Proposer_intf
    with type ledger_hash := Ledger_hash.t
     and type ledger_builder := Ledger_builder.t
     and type transaction := User_command.With_valid_signature.t
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type protocol_state_proof := Protocol_state_proof.t
     and type consensus_local_state := Consensus_mechanism.Local_state.t
     and type completed_work_statement := Completed_work.Statement.t
     and type completed_work_checked := Completed_work.Checked.t
     and type external_transition := External_transition.t
     and type time_controller := Time.Controller.t
     and type keypair := Keypair.t
     and type transition_frontier := Transition_frontier.t
     and type transaction_pool := Transaction_pool.t

  module Ledger_transfer :
    Coda_pow.Ledger_transfer_intf
    with type src := Ledger.t
     and type dest := Ledger_db.t

  module Genesis : sig
    val state : Consensus_mechanism.Protocol_state.value

    val ledger : Ledger.maskable_ledger

    val proof : Protocol_state_proof.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type t =
    { propose_keypair: Keypair.t option
    ; run_snark_worker: bool
    ; net: Net.t
    ; external_transitions:
        (External_transition.t * Unix_timestamp.t) Linear_pipe.Writer.t
        (* TODO: Is this the best spot for the transaction_pool ref? *)
    ; transaction_pool: Transaction_pool.t
    ; snark_pool: Snark_pool.t
    ; transition_frontier: Transition_frontier.t
    ; strongest_ledgers:
        (Ledger_builder.t * External_transition.t) Linear_pipe.Reader.t
    ; log: Logger.t
    ; mutable seen_jobs: Work_selector.State.t
    ; receipt_chain_database: Coda_base.Receipt_chain_database.t
    ; ledger_builder_transition_backup_capacity: int
    ; snark_work_fee: Currency.Fee.t }

  let run_snark_worker t = t.run_snark_worker

  let propose_keypair t = t.propose_keypair

  let best_ledger_builder t =
    failwith
      "TODO: Use transition frontier to get best lb out; you'll need to \
       update the signature"

  let best_protocol_state t =
    failwith
      "TODO: Use transition frontier to get best lb out; you'll need to \
       update the signature"

  let best_tip t =
    failwith
      "TODO: Use transition frontier to get best lb out; you'll need to \
       update the signature"

  let get_ledger t lh =
    failwith
      "TODO: Use transition frontier to find an arbitrary ledger based on a \
       hash"

  let best_ledger t = Ledger_builder.ledger (best_ledger_builder t)

  let seen_jobs t = t.seen_jobs

  let set_seen_jobs t seen_jobs = t.seen_jobs <- seen_jobs

  let transaction_pool t = t.transaction_pool

  let snark_pool t = t.snark_pool

  let peers t = Net.peers t.net

  let snark_work_fee t = t.snark_work_fee

  let receipt_chain_database t = t.receipt_chain_database

  let ledger_builder_ledger_proof t =
    let lb = best_ledger_builder t in
    Ledger_builder.current_ledger_proof lb

  let strongest_ledgers t =
    Linear_pipe.map t.strongest_ledgers ~f:(fun (_, x) -> x)

  module Config = struct
    (** If ledger_db_location is None, will auto-generate a db based on a UUID *)
    type t =
      { log: Logger.t
      ; propose_keypair: Keypair.t option
      ; run_snark_worker: bool
      ; net_config: Net.Config.t
      ; ledger_builder_persistant_location: string
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; ledger_db_location: string option
      ; ledger_builder_transition_backup_capacity: int [@default 10]
      ; time_controller: Time.Controller.t
      ; banlist: Coda_base.Banlist.t
      ; receipt_chain_database: Coda_base.Receipt_chain_database.t
      ; snark_work_fee: Currency.Fee.t
      (* TODO: Pass banlist to modules discussed in Ban Reasons issue: https://github.com/CodaProtocol/coda/issues/852 *)
      }
    [@@deriving make]
  end

  let create (config : Config.t) =
    trace_task "coda" (fun () ->
        let _external_transitions_reader, external_transitions_writer =
          Linear_pipe.create ()
        in
        let net_ivar = Ivar.create () in
        let consensus_local_state =
          Consensus_mechanism.Local_state.create config.propose_keypair
        in
        let first_transition =
          External_transition.create
            ~protocol_state:Consensus_mechanism.genesis_protocol_state
            ~protocol_state_proof:Protocol_state_proof.dummy
            ~ledger_builder_diff:
              { Ledger_builder_diff.pre_diffs=
                  Either.First
                    { diff= {completed_works= []; user_commands= []}
                    ; coinbase_added= Ledger_builder_diff.At_most_one.Zero }
              ; prev_hash=
                  Ledger_builder_hash.of_aux_and_ledger_hash
                    (Ledger_builder_aux_hash.of_bytes "")
                    (Ledger.merkle_root Genesis_ledger.t)
              ; creator=
                  Account.public_key
                    (snd (List.hd_exn Genesis_ledger.accounts)) }
        in
        let transition_frontier =
          Transition_frontier.create ~logger:config.log
            ~root_transition:
              (With_hash.of_data first_transition
                 ~hash_data:
                   (Fn.compose Consensus_mechanism.Protocol_state.hash
                      External_transition.protocol_state))
            ~root_transaction_snark_scan_state:
              Transition_frontier.Transaction_snark_scan_state.empty
            ~root_staged_ledger_diff:None
            ~root_snarked_ledger:
              (Ledger_transfer.transfer_accounts ~src:Genesis.ledger
                 ~dest:
                   (Ledger_db.create ?directory_name:config.ledger_db_location
                      ()))
        in
        let () =
          Transition_frontier_controller.run ~logger:config.log
            ~time_controller:config.time_controller
            ~frontier:transition_frontier
            ~transition_reader:
              (failwith "Turn external_transitions_reader into a strict pipe")
            ~sync_query_reader:(failwith "TODO")
            ~sync_answer_writer:(failwith "TODO")
        in
        let%bind net =
          Net.create config.net_config
            ~get_ledger_builder_aux_at_hash:(fun _hash ->
              failwith "TODO: replace with new net" )
            ~answer_sync_ledger_query:(fun _query ->
              failwith "TODO: replace with new net" )
        in
        let%bind transaction_pool =
          Transaction_pool.load ~parent_log:config.log
            ~disk_location:config.transaction_pool_disk_location
            ~incoming_diffs:(Net.transaction_pool_diffs net)
        in
        don't_wait_for
          (Linear_pipe.iter (Transaction_pool.broadcasts transaction_pool)
             ~f:(fun x ->
               Net.broadcast_transaction_pool_diff net x ;
               Deferred.unit )) ;
        Ivar.fill net_ivar net ;
        don't_wait_for
          (Linear_pipe.transfer_id (Net.states net) external_transitions_writer) ;
        let%bind snark_pool =
          Snark_pool.load ~parent_log:config.log
            ~disk_location:config.snark_pool_disk_location
            ~incoming_diffs:(Net.snark_pool_diffs net)
        in
        don't_wait_for
          (Linear_pipe.iter (Snark_pool.broadcasts snark_pool) ~f:(fun x ->
               Net.broadcast_snark_pool_diff net x ;
               Deferred.unit )) ;
        let ( strongest_ledgers_for_miner
            , strongest_ledgers_for_network
            , strongest_ledgers_for_api ) =
          Linear_pipe.fork3
            (let _pipe =
               Transition_frontier.best_tip_reader transition_frontier
             in
             failwith
               "Handle impedence mismatch between linear_pipe and strict pipe")
        in
        Linear_pipe.iter strongest_ledgers_for_network ~f:(fun (_, t) ->
            Net.broadcast_state net t ; Deferred.unit )
        |> don't_wait_for ;
        ( match config.propose_keypair with
        | Some keypair ->
            Linear_pipe.iter strongest_ledgers_for_miner
              ~f:(fun (ledger_builder, transition) ->
                let protocol_state =
                  External_transition.protocol_state transition
                in
                Debug_assert.debug_assert (fun () ->
                    match Ledger_builder.statement_exn ledger_builder with
                    | `Empty -> ()
                    | `Non_empty
                        { source
                        ; target
                        ; fee_excess
                        ; proof_type= _
                        ; supply_increase= _ } ->
                        let bc_state =
                          Consensus_mechanism.Protocol_state.blockchain_state
                            protocol_state
                        in
                        [%test_eq: Currency.Fee.Signed.t]
                          Currency.Fee.Signed.zero fee_excess ;
                        [%test_eq: Frozen_ledger_hash.t]
                          (Consensus_mechanism.Blockchain_state.ledger_hash
                             bc_state)
                          source ;
                        [%test_eq: Frozen_ledger_hash.t]
                          ( Ledger_builder.ledger ledger_builder
                          |> Ledger.merkle_root
                          |> Frozen_ledger_hash.of_ledger_hash )
                          target ) ;
                return () )
            |> don't_wait_for ;
            let transitions =
              Proposer.create ~parent_log:config.log ~transaction_pool
                ~get_completed_work:(Snark_pool.get_completed_work snark_pool)
                ~time_controller:config.time_controller ~keypair
                ~consensus_local_state ~transition_frontier
            in
            don't_wait_for
              (Linear_pipe.transfer_id transitions external_transitions_writer)
        | None ->
            don't_wait_for (Linear_pipe.drain strongest_ledgers_for_miner) ) ;
        return
          { propose_keypair= config.propose_keypair
          ; run_snark_worker= config.run_snark_worker
          ; net
          ; external_transitions= external_transitions_writer
          ; transaction_pool
          ; snark_pool
          ; transition_frontier
          ; strongest_ledgers= strongest_ledgers_for_api
          ; log= config.log
          ; seen_jobs= Work_selector.State.init
          ; ledger_builder_transition_backup_capacity=
              config.ledger_builder_transition_backup_capacity
          ; receipt_chain_database= config.receipt_chain_database
          ; snark_work_fee= config.snark_work_fee } )
end
