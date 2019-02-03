open Core_kernel
open Async_kernel
open Protocols
open Pipe_lib
open Strict_pipe
open O1trace

module type Staged_ledger_io_intf = sig
  type t

  type net

  type staged_ledger_hash

  type ledger_hash

  type staged_ledger_aux

  type sync_ledger_query

  type sync_ledger_answer

  type protocol_state

  val create : net -> t

  val get_staged_ledger_aux_at_hash :
       t
    -> staged_ledger_hash
    -> staged_ledger_aux Envelope.Incoming.t Deferred.Or_error.t
end

module type Network_intf = sig
  type t

  type state_with_witness

  type staged_ledger

  type protocol_state

  type ledger_hash

  type staged_ledger_hash

  type parallel_scan_state

  type sync_ledger_query

  type sync_ledger_answer

  type snark_pool_diff

  type transaction_pool_diff

  type time

  type state_hash

  type state_body_hash

  val states :
    t -> (state_with_witness Envelope.Incoming.t * time) Strict_pipe.Reader.t

  val peers : t -> Network_peer.Peer.t list

  val random_peers : t -> int -> Network_peer.Peer.t list

  val catchup_transition :
       t
    -> Network_peer.Peer.t
    -> state_hash
    -> state_with_witness list option Or_error.t Deferred.t

  val snark_pool_diffs :
    t -> snark_pool_diff Envelope.Incoming.t Linear_pipe.Reader.t

  val transaction_pool_diffs :
    t -> transaction_pool_diff Envelope.Incoming.t Linear_pipe.Reader.t

  val broadcast_state : t -> state_with_witness -> unit

  val broadcast_snark_pool_diff : t -> snark_pool_diff -> unit

  val broadcast_transaction_pool_diff : t -> transaction_pool_diff -> unit

  val glue_sync_ledger :
       t
    -> (ledger_hash * sync_ledger_query) Linear_pipe.Reader.t
    -> (ledger_hash * sync_ledger_answer) Envelope.Incoming.t
       Linear_pipe.Writer.t
    -> unit

  module Config : sig
    type t
  end

  val create :
       Config.t
    -> get_staged_ledger_aux_at_hash:(   staged_ledger_hash Envelope.Incoming.t
                                      -> (parallel_scan_state * ledger_hash)
                                         option
                                         Deferred.t)
    -> answer_sync_ledger_query:(   (ledger_hash * sync_ledger_query)
                                    Envelope.Incoming.t
                                 -> (ledger_hash * sync_ledger_answer)
                                    Deferred.Or_error.t)
    -> transition_catchup:(   state_hash Envelope.Incoming.t
                           -> state_with_witness list Deferred.Option.t)
    -> get_ancestry:(   (state_hash * int) Envelope.Incoming.t
                     -> (state_with_witness * state_body_hash list)
                        Deferred.Option.t)
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
    -> incoming_diffs:pool_diff Envelope.Incoming.t Linear_pipe.Reader.t
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
    -> incoming_diffs:pool_diff Envelope.Incoming.t Linear_pipe.Reader.t
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

  type staged_ledger

  type staged_ledger_hash

  type external_transition_verified

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
          (external_transition_verified * Unix_timestamp.t)
          Linear_pipe.Reader.t
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
    -> staged_ledger_hash
    -> (staged_ledger * protocol_state) Deferred.Or_error.t

  val strongest_ledgers :
    t -> (staged_ledger * external_transition_verified) Linear_pipe.Reader.t

  val handle_sync_ledger_queries :
       t
    -> ledger_hash * sync_query
    -> (ledger_hash * sync_answer) Deferred.Or_error.t
end

module type Proposer_intf = sig
  type state_hash

  type ledger_hash

  type staged_ledger

  type transaction

  type external_transition

  type external_transition_verified

  type completed_work_statement

  type completed_work_checked

  type protocol_state

  type protocol_state_proof

  type consensus_local_state

  type time_controller

  type keypair

  type transition_frontier

  type transaction_pool

  type time

  val run :
       parent_log:Logger.t
    -> get_completed_work:(   completed_work_statement
                           -> completed_work_checked option)
    -> transaction_pool:transaction_pool
    -> time_controller:time_controller
    -> keypair:keypair
    -> consensus_local_state:consensus_local_state
    -> frontier_reader:transition_frontier Mvar.Read_only.t
    -> transition_writer:( ( external_transition_verified
                           , state_hash )
                           With_hash.t
                         , synchronous
                         , unit Deferred.t )
                         Strict_pipe.Writer.t
    -> unit
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

  type staged_ledger_transition

  type staged_ledger_transition_with_valid_signatures_and_proofs

  type t =
    { staged_ledger_transition:
        staged_ledger_transition_with_valid_signatures_and_proofs
    ; state: state }
  [@@deriving sexp]

  module Stripped : sig
    type t = {staged_ledger_transition: staged_ledger_transition; state: state}
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
     and type staged_ledger_transition := Staged_ledger_transition.t
     and type staged_ledger_transition_with_valid_signatures_and_proofs :=
                Staged_ledger_transition.With_valid_signatures_and_proofs.t

  module Snark_pool :
    Snark_pool_intf
    with type completed_work_statement := Transaction_snark_work.Statement.t
     and type completed_work_checked := Transaction_snark_work.Checked.t

  module Work_selector :
    Coda_pow.Work_selector_intf
    with type staged_ledger := Staged_ledger.t
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

  module State_body_hash : sig
    type t
  end

  module Net :
    Network_intf
    with type state_with_witness := External_transition.t
     and type staged_ledger := Staged_ledger.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type snark_pool_diff := Snark_pool.pool_diff
     and type transaction_pool_diff := Transaction_pool.pool_diff
     and type parallel_scan_state := Staged_ledger.Scan_state.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Coda_base.Sync_ledger.query
     and type sync_ledger_answer := Coda_base.Sync_ledger.answer
     and type time := Time.t
     and type state_hash := Protocol_state_hash.t
     and type state_body_hash := State_body_hash.t

  module Ledger_db : Coda_pow.Ledger_creatable_intf

  module Masked_ledger : sig
    type t
  end

  module Transition_frontier :
    Protocols.Coda_transition_frontier.Transition_frontier_intf
    with type state_hash := Protocol_state_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger_db.t
     and type masked_ledger := Masked_ledger.t
     and type transaction := Transaction.t
     and type staged_ledger := Staged_ledger.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t

  module Transition_router :
    Protocols.Coda_transition_frontier.Transition_router_intf
    with type time_controller := Time.Controller.t
     and type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Verified.t
     and type transition_frontier := Transition_frontier.t
     and type state_hash := Protocol_state_hash.t
     and type time := Time.t
     and type network := Net.t
     and type ledger_db := Ledger_db.t

  module Proposer :
    Proposer_intf
    with type state_hash := Protocol_state_hash.t
     and type ledger_hash := Ledger_hash.t
     and type staged_ledger := Staged_ledger.t
     and type transaction := User_command.With_valid_signature.t
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type protocol_state_proof := Protocol_state_proof.t
     and type consensus_local_state := Consensus_mechanism.Local_state.t
     and type completed_work_statement := Transaction_snark_work.Statement.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Verified.t
     and type time_controller := Time.Controller.t
     and type keypair := Keypair.t
     and type transition_frontier := Transition_frontier.t
     and type transaction_pool := Transaction_pool.t
     and type time := Time.t

  module Ledger_transfer :
    Coda_pow.Ledger_transfer_intf
    with type src := Ledger.t
     and type dest := Ledger_db.t

  module Genesis : sig
    val state :
      ( Consensus_mechanism.Protocol_state.value
      , Protocol_state_hash.t )
      With_hash.t

    val ledger : Ledger.maskable_ledger

    val proof : Protocol_state_proof.t
  end

  module Sync_handler :
    Protocols.Coda_transition_frontier.Sync_handler_intf
    with type state_hash := Protocol_state_hash.t
     and type ledger_hash := Ledger_hash.t
     and type transition_frontier := Transition_frontier.t
     and type ancestor_proof := State_body_hash.t list
     and type external_transition := External_transition.t
     and type syncable_ledger_query := Coda_base.Sync_ledger.query
     and type syncable_ledger_answer := Coda_base.Sync_ledger.answer
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type t =
    { propose_keypair: Keypair.t option
    ; run_snark_worker: bool
    ; net:
        Net.t (* TODO: Is this the best spot for the transaction_pool ref? *)
    ; transaction_pool: Transaction_pool.t
    ; snark_pool: Snark_pool.t
    ; transition_frontier: Transition_frontier.t Mvar.Read_only.t
    ; strongest_ledgers:
        (External_transition.Verified.t, Protocol_state_hash.t) With_hash.t
        Strict_pipe.Reader.t
    ; proposer_transition_writer:
        ( (External_transition.Verified.t, Protocol_state_hash.t) With_hash.t
        , synchronous
        , unit Deferred.t )
        Writer.t
    ; log: Logger.t
    ; mutable seen_jobs: Work_selector.State.t
    ; receipt_chain_database: Coda_base.Receipt_chain_database.t
    ; staged_ledger_transition_backup_capacity: int
    ; external_transitions_writer:
        (External_transition.t Envelope.Incoming.t * Inputs.Time.t)
        Pipe.Writer.t
    ; time_controller: Time.Controller.t
    ; snark_work_fee: Currency.Fee.t }

  let peek_frontier frontier_mvar =
    Mvar.peek frontier_mvar
    |> Result.of_option
         ~error:
           (Error.of_string
              "Cannot retrieve transition frontier now. Bootstrapping right \
               now.")

  let run_snark_worker t = t.run_snark_worker

  let propose_keypair t = t.propose_keypair

  let best_tip_opt t =
    let open Option.Let_syntax in
    let%map frontier = Mvar.peek t.transition_frontier in
    Transition_frontier.best_tip frontier

  let best_staged_ledger_opt t =
    let open Option.Let_syntax in
    let%map tip = best_tip_opt t in
    Transition_frontier.Breadcrumb.staged_ledger tip

  let best_protocol_state_opt t =
    let open Option.Let_syntax in
    let%map tip = best_tip_opt t in
    Transition_frontier.Breadcrumb.transition_with_hash tip
    |> With_hash.data |> External_transition.Verified.protocol_state

  let best_ledger_opt t =
    let open Option.Let_syntax in
    let%map staged_ledger = best_staged_ledger_opt t in
    Staged_ledger.ledger staged_ledger

  let compose_of_option f =
    Fn.compose
      (Option.value_map ~default:`Bootstrapping ~f:(fun x -> `Active x))
      f

  let best_tip = compose_of_option best_tip_opt

  let best_staged_ledger = compose_of_option best_staged_ledger_opt

  let best_protocol_state = compose_of_option best_protocol_state_opt

  let best_ledger = compose_of_option best_ledger_opt

  let get_ledger t staged_ledger_hash =
    let open Deferred.Or_error.Let_syntax in
    let%bind frontier =
      Deferred.return (t.transition_frontier |> peek_frontier)
    in
    match
      List.find_map (Transition_frontier.all_breadcrumbs frontier) ~f:(fun b ->
          let staged_ledger = Transition_frontier.Breadcrumb.staged_ledger b in
          if
            Staged_ledger_hash.equal
              (Staged_ledger.hash staged_ledger)
              staged_ledger_hash
          then Some (Ledger.to_list (Staged_ledger.ledger staged_ledger))
          else None )
    with
    | Some x -> Deferred.return (Ok x)
    | None ->
        Deferred.Or_error.error_string
          "staged ledger hash not found in transition frontier"

  let seen_jobs t = t.seen_jobs

  let set_seen_jobs t seen_jobs = t.seen_jobs <- seen_jobs

  let transaction_pool t = t.transaction_pool

  let snark_pool t = t.snark_pool

  let peers t = Net.peers t.net

  let snark_work_fee t = t.snark_work_fee

  let receipt_chain_database t = t.receipt_chain_database

  let staged_ledger_ledger_proof t =
    let open Option.Let_syntax in
    let%bind sl = best_staged_ledger_opt t in
    Staged_ledger.current_ledger_proof sl

  let strongest_ledgers t = t.strongest_ledgers

  module Config = struct
    (** If ledger_db_location is None, will auto-generate a db based on a UUID *)
    type t =
      { log: Logger.t
      ; propose_keypair: Keypair.t option
      ; run_snark_worker: bool
      ; net_config: Net.Config.t
      ; staged_ledger_persistant_location: string
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; ledger_db_location: string option
      ; staged_ledger_transition_backup_capacity: int [@default 10]
      ; time_controller: Time.Controller.t
      ; banlist: Coda_base.Banlist.t
      ; receipt_chain_database: Coda_base.Receipt_chain_database.t
      ; snark_work_fee: Currency.Fee.t
      (* TODO: Pass banlist to modules discussed in Ban Reasons issue: https://github.com/CodaProtocol/coda/issues/852 *)
      }
    [@@deriving make]
  end

  let start t =
    let consensus_local_state =
      Consensus_mechanism.Local_state.create t.propose_keypair
    in
    Option.iter t.propose_keypair ~f:(fun keypair ->
        Proposer.run ~parent_log:t.log ~transaction_pool:t.transaction_pool
          ~get_completed_work:(Snark_pool.get_completed_work t.snark_pool)
          ~time_controller:t.time_controller ~keypair ~consensus_local_state
          ~frontier_reader:t.transition_frontier
          ~transition_writer:t.proposer_transition_writer )

  let create (config : Config.t) =
    trace_task "coda" (fun () ->
        let external_transitions_reader, external_transitions_writer =
          Strict_pipe.create Synchronous
        in
        let proposer_transition_reader, proposer_transition_writer =
          Strict_pipe.create Synchronous
        in
        let net_ivar = Ivar.create () in
        let empty_diff =
          { Staged_ledger_diff.diff=
              ( { completed_works= []
                ; user_commands= []
                ; coinbase= Staged_ledger_diff.At_most_two.Zero }
              , None )
          ; prev_hash=
              Staged_ledger_hash.of_aux_and_ledger_hash
                (Staged_ledger_aux_hash.of_bytes "")
                (Ledger.merkle_root Genesis_ledger.t)
          ; creator=
              Account.public_key (snd (List.hd_exn Genesis_ledger.accounts)) }
        in
        let genesis_protocol_state =
          With_hash.data Consensus_mechanism.genesis_protocol_state
        in
        (* the genesis transition is assumed to be valid *)
        let (`I_swear_this_is_safe_see_my_comment first_transition) =
          External_transition.to_verified
            (External_transition.create ~protocol_state:genesis_protocol_state
               ~protocol_state_proof:Genesis.proof
               ~staged_ledger_diff:empty_diff)
        in
        let ledger_db =
          Ledger_db.create ?directory_name:config.ledger_db_location ()
        in
        let%bind transition_frontier =
          Transition_frontier.create ~logger:config.log
            ~max_length:Consensus.Constants.k
            ~root_transition:
              (With_hash.of_data first_transition
                 ~hash_data:
                   (Fn.compose Consensus_mechanism.Protocol_state.hash
                      External_transition.Verified.protocol_state))
            ~root_transaction_snark_scan_state:
              (Staged_ledger.Scan_state.empty ())
            ~root_staged_ledger_diff:None
            ~root_snarked_ledger:
              (Ledger_transfer.transfer_accounts ~src:Genesis.ledger
                 ~dest:ledger_db)
        in
        let frontier_mvar = Mvar.create () in
        Mvar.set frontier_mvar transition_frontier ;
        let frontier_read_ref = Mvar.read_only frontier_mvar in
        let%bind net =
          Net.create config.net_config
            ~get_staged_ledger_aux_at_hash:(fun _hash ->
              failwith "shouldn't be necessary right now?" )
            ~answer_sync_ledger_query:(fun query_env ->
              let open Or_error.Let_syntax in
              let result =
                let ledger_hash, query = Envelope.Incoming.data query_env in
                let%bind frontier = peek_frontier frontier_read_ref in
                Sync_handler.answer_query ~frontier ledger_hash query
                |> Result.of_option
                     ~error:
                       (Error.createf
                          !"Could not answer query for ledger_hash: \
                            %{sexp:Ledger_hash.t}"
                          ledger_hash)
              in
              result |> Deferred.return )
            ~transition_catchup:(fun enveloped_hash ->
              let open Deferred.Option.Let_syntax in
              let hash = Envelope.Incoming.data enveloped_hash in
              let%bind frontier =
                Deferred.return @@ Mvar.peek frontier_read_ref
              in
              let%map breadcrumb =
                Deferred.return @@ Transition_frontier.find frontier hash
              in
              Transition_frontier.path_map
                ~f:(fun b ->
                  Transition_frontier.Breadcrumb.transition_with_hash b
                  |> With_hash.data |> External_transition.of_verified )
                frontier breadcrumb )
            ~get_ancestry:(fun query_env ->
              let descendent, count = Envelope.Incoming.data query_env in
              let result =
                let open Option.Let_syntax in
                let%bind frontier = Mvar.peek frontier_read_ref in
                Sync_handler.prove_ancestry ~frontier count descendent
              in
              Deferred.return result )
        in
        let valid_transitions =
          Transition_router.run ~logger:config.log ~network:net
            ~time_controller:config.time_controller ~frontier_mvar ~ledger_db
            ~network_transition_reader:
              (Strict_pipe.Reader.map external_transitions_reader
                 ~f:(fun (tn, tm) -> (`Transition tn, `Time_received tm) ))
            ~proposer_transition_reader
        in
        let valid_transitions_for_network, valid_transitions_for_api =
          Strict_pipe.Reader.Fork.two valid_transitions
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
          (Strict_pipe.Reader.iter_without_pushback
             valid_transitions_for_network ~f:(fun transition_with_hash ->
               (* remove verified status for network broadcast *)
               Net.broadcast_state net
                 (External_transition.of_verified
                    (With_hash.data transition_with_hash)) )) ;
        don't_wait_for
          (Strict_pipe.transfer (Net.states net) external_transitions_writer
             ~f:ident) ;
        let%bind snark_pool =
          Snark_pool.load ~parent_log:config.log
            ~disk_location:config.snark_pool_disk_location
            ~incoming_diffs:(Net.snark_pool_diffs net)
        in
        don't_wait_for
          (Linear_pipe.iter (Snark_pool.broadcasts snark_pool) ~f:(fun x ->
               Net.broadcast_snark_pool_diff net x ;
               Deferred.unit )) ;
        return
          { propose_keypair= config.propose_keypair
          ; run_snark_worker= config.run_snark_worker
          ; net
          ; transaction_pool
          ; snark_pool
          ; transition_frontier= frontier_read_ref
          ; time_controller= config.time_controller
          ; external_transitions_writer=
              Strict_pipe.Writer.to_linear_pipe external_transitions_writer
          ; strongest_ledgers= valid_transitions_for_api
          ; log= config.log
          ; seen_jobs= Work_selector.State.init
          ; staged_ledger_transition_backup_capacity=
              config.staged_ledger_transition_backup_capacity
          ; receipt_chain_database= config.receipt_chain_database
          ; snark_work_fee= config.snark_work_fee
          ; proposer_transition_writer } )
end
