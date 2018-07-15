open Core_kernel
open Async_kernel
open Protocols

module type Ledger_builder_io_intf = sig
  type t

  type net

  type ledger_builder_hash

  type ledger_hash

  type ledger_builder_aux

  type sync_ledger_query

  type sync_ledger_answer

  type state

  val create : net -> t

  val get_ledger_builder_aux_at_hash :
       t
    -> ledger_builder_hash
    -> (ledger_builder_aux * state) Deferred.Or_error.t

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

  type state

  type ledger_hash

  type ledger_builder_hash

  type parallel_scan_state

  val new_states : t -> state_with_witness Linear_pipe.Reader.t

  module Ledger_builder_io :
    Ledger_builder_io_intf
    with type net := t
     and type ledger_builder_aux := parallel_scan_state
     and type ledger_builder_hash := ledger_builder_hash
     and type ledger_hash := ledger_hash
     and type state := state

  module Config : sig
    type t
  end

  val create :
       Config.t
    -> check_ledger_builder_at_hash:(ledger_builder_hash -> bool Deferred.t)
    -> get_ledger_builder_at_hash:(   ledger_builder_hash
                                   -> (ledger_builder * state) option
                                      Deferred.t)
    -> t Deferred.t
end

module type Transaction_pool_intf = sig
  type t

  type transaction_with_valid_signature

  type ledger

  val add : t -> transaction_with_valid_signature -> t

  val transactions : t -> transaction_with_valid_signature Sequence.t

  val load : disk_location:string -> t Deferred.t
end

module type Snark_pool_intf = sig
  type t

  type completed_work_statement

  type completed_work_checked

  type pool_diff

  val load :
       disk_location:string
    -> incoming_diffs:pool_diff Linear_pipe.Reader.t
    -> t Deferred.t

  val get_completed_work :
    t -> completed_work_statement -> completed_work_checked option
end

module type Ledger_builder_controller_intf = sig
  type ledger_builder

  type ledger_builder_hash

  type transition

  type ledger

  type net

  type state

  type t

  type sync_query

  type sync_answer

  type ledger_proof

  type ledger_hash

  module Config : sig
    type t =
      { parent_log: Logger.t
      ; net_deferred: net Deferred.t
      ; transitions:
          (state * transition) Linear_pipe.Reader.t
      ; genesis_ledger: ledger
      ; disk_location: string }
    [@@deriving make]
  end

  module Aux : sig
    type t = {root_and_proof: (ledger_hash * ledger_proof) option; state: state}
  end

  val create : Config.t -> t Deferred.t

  val local_get_ledger :
    t -> ledger_builder_hash -> (ledger_builder * state) Deferred.Or_error.t

  val strongest_ledgers : t -> (ledger_builder * state) Linear_pipe.Reader.t

  val handle_sync_ledger_queries : sync_query -> sync_answer
end

module type Miner_intf = sig
  type t

  type ledger_hash

  type ledger_builder

  type transaction

  type transition_with_witness

  type completed_work_statement

  type completed_work_checked

  type state

  module Tip : sig
    type t =
      { state: state
      ; ledger_builder: ledger_builder
      ; transactions: transaction Sequence.t }
  end

  type change = Tip_change of Tip.t

  val create :
       parent_log:Logger.t
    -> get_completed_work:(   completed_work_statement
                           -> completed_work_checked option)
    -> change_feeder:change Linear_pipe.Reader.t
    -> t

  val transitions : t -> (transition_with_witness * state) Linear_pipe.Reader.t
end

module type Witness_change_intf = sig
  type t_with_witness

  type witness

  type t

  val forget_witness : t_with_witness -> t

  val add_witness_exn : t -> witness -> t_with_witness

  val add_witness : t -> witness -> t_with_witness Or_error.t
end

(* TODO imeckler: Something funky going on with this module *)
module type Transition_with_witness_intf = sig
  type transition

  type transaction_with_valid_signature

  type ledger_hash

  type t = {previous_ledger_hash: ledger_hash; transition: transition}
  [@@deriving sexp]

  val forget_witness : t -> transition
  (*
  include Witness_change_intf
          with type t_with_witness := t
           and type witness =
                      transaction_with_valid_signature list * ledger_hash
           and type t := transition *)
end

(* TODO imeckler: talk with brandon about when transitions get checked and what this intf is
   also the above one. *)
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
    [@@deriving bin_io]
  end

  val strip : t -> Stripped.t

  val forget_witness : t -> state
  (*
  val check : Stripped.t -> t option

  include Witness_change_intf
          with type t_with_witness := t
           and type witness = ledger_builder_transition_with_valid_signatures_and_proofs
           and type t := state *)
end

module type Inputs_intf = sig
  include Coda_pow.Inputs_intf

  module Proof_carrying_state : sig
    type t = (State.t, State.Proof.t) Coda_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module State_with_witness :
    State_with_witness_intf
    with type state := Proof_carrying_state.t
     and type ledger_hash := Ledger_hash.t
     and type ledger_builder_transition := Ledger_builder_transition.t
     and type ledger_builder_transition_with_valid_signatures_and_proofs :=
                Ledger_builder_transition.With_valid_signatures_and_proofs.t

  (*      and type witness := Ledger_builder_transition.With_valid_signatures_and_proofs.t *)

  module Transition_with_witness :
    Transition_with_witness_intf
    with type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type transition := Transition.t
     and type ledger_hash := Ledger_hash.t

  module Net :
    Network_intf
    with type state_with_witness := State_with_witness.t
     and type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type state := State.t

  module Snark_pool :
    Snark_pool_intf
    with type completed_work_statement := Completed_work.Statement.t
     and type completed_work_checked := Completed_work.Checked.t

  module Ledger_builder_controller :
    Ledger_builder_controller_intf
    with type net := Net.t
     and type ledger := Ledger.t
     and type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type transition := Transition.t
     and type state := State.t

  module Transaction_pool :
    Transaction_pool_intf
    with type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type ledger := Ledger.t

  module Miner :
    Miner_intf
    with type transition_with_witness := Transition_with_witness.t
     and type ledger_hash := Ledger_hash.t
     and type ledger_builder := Ledger_builder.t
     and type transaction := Transaction.With_valid_signature.t
     and type state := State.t
     and type completed_work_statement := Completed_work.Statement.t
     and type completed_work_checked := Completed_work.Checked.t

  module Genesis : sig
    val state : State.t

    val ledger : Ledger.t

    val proof : State.Proof.t
  end
end

(* TODO: Lift Block_state_transition_proof out of the functor and inline it *)
module Make
    (Inputs : Inputs_intf)
    (Block_state_transition_proof : Coda_pow.Block_state_transition_proof_intf
                                    with type state := Inputs.State.t
                                     and type proof := Inputs.State.Proof.t
                                     and type transition := Inputs.Transition.t) =
struct
  module Protocol = Coda_pow.Make (Inputs) (Block_state_transition_proof)
  open Inputs

  type t =
    { miner: Miner.t
    ; net: Net.t
    ; miner_changes_writer: Miner.change Linear_pipe.Writer.t
    ; miner_broadcast_writer: State_with_witness.t Linear_pipe.Writer.t
    ; transitions:
        (State.t * Transition.t) Linear_pipe.Writer.t
        (* TODO: Is this the best spot for the transaction_pool ref? *)
    ; mutable transaction_pool: Transaction_pool.t
    ; mutable snark_pool: Snark_pool.t
    ; ledger_builder: Ledger_builder_controller.t
    ; log: Logger.t
    ; ledger_builder_transition_backup_capacity: int }

  let ledger_builder_controller t = t.ledger_builder

  let modify_transaction_pool t ~f = t.transaction_pool <- f t.transaction_pool

  let modify_snark_pool t ~f = t.snark_pool <- f t.snark_pool

  module Config = struct
    type t =
      { log: Logger.t
      ; net_config: Net.Config.t
      ; ledger_builder_persistant_location: string
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; ledger_builder_transition_backup_capacity: int [@default 10] }
    [@@deriving make]
  end

  let create (config: Config.t) =
    let miner_changes_reader, miner_changes_writer = Linear_pipe.create () in
    let miner_broadcast_reader, miner_broadcast_writer =
      Linear_pipe.create ()
    in
    let transitions_reader, transitions_writer =
      Linear_pipe.create ()
    in
    let net_ivar = Ivar.create () in
    let%bind snark_pool =
      Snark_pool.load ~disk_location:config.snark_pool_disk_location
        ~incoming_diffs:(failwith "TODO")
    in
    let%map ledger_builder =
      Ledger_builder_controller.create
        (Ledger_builder_controller.Config.make ~parent_log:config.log
           ~net_deferred:(Ivar.read net_ivar)
           ~genesis_ledger:Genesis.ledger
           ~disk_location:config.ledger_builder_persistant_location
           ~transitions:transitions_reader)
           (* TODO
           ~ledger_builder_diffs:
             (Linear_pipe.map ledger_builder_transitions_reader ~f:
                (fun (s, {Ledger_builder_transition.diff; _}) -> (s, diff) ))) *)
    in
    let miner =
      Miner.create ~parent_log:config.log ~change_feeder:miner_changes_reader
        ~get_completed_work:(Snark_pool.get_completed_work snark_pool)
    in
    let%bind net =
      Net.create config.net_config
        (fun hash ->
          Ledger_builder_controller.local_get_ledger ledger_builder hash
          >>| Or_error.is_ok )
        (fun hash ->
          match%map
            Ledger_builder_controller.local_get_ledger ledger_builder hash
          with
          | Ok ledger_and_state -> Some ledger_and_state
          | _ -> None )
    in
    Ivar.fill net_ivar net ;
    let%map transaction_pool =
      Transaction_pool.load
        ~disk_location:config.transaction_pool_disk_location
    in
    { miner
    ; net
    ; miner_broadcast_writer
    ; miner_changes_writer
    ; transitions= transitions_writer
    ; transaction_pool
    ; snark_pool
    ; ledger_builder
    ; log= config.log
    ; ledger_builder_transition_backup_capacity=
        config.ledger_builder_transition_backup_capacity }

  let forget_diff_validity
      { Ledger_builder_diff.With_valid_signatures_and_proofs.prev_hash
      ; completed_works
      ; transactions
      ; creator } =
    { Ledger_builder_diff.prev_hash
    ; completed_works= List.map completed_works ~f:Completed_work.forget
    ; transactions= (transactions :> Transaction.t list)
    ; creator }

  let forget_transition_validity
      {Ledger_builder_transition.With_valid_signatures_and_proofs.old; diff} =
    {Ledger_builder_transition.old; diff= forget_diff_validity diff}

  let run t =
    Logger.info t.log "Starting to run Coda" ;
    let p : Protocol.t =
      Protocol.create ~state:{data= Genesis.state; proof= Genesis.proof}
    in
    let miner_transitions_protocol = Miner.transitions t.miner in
    (* transaction_pool, snark_pool: self contained, and feed into network *)
    (* network states-> lbc
       mining states -> lbc
       lbc -> strongest_ledgers -> miner
       strongest_ledgers -> network
    *)

    (* Miner, ledger_builder, Net.State_io, snark_pool, transaction_pool *)
    (*
    let protocol_events =
      Linear_pipe.merge_unordered
        [ Linear_pipe.map miner_transitions_protocol ~f:(fun transition ->
              `Local transition )
        ; Linear_pipe.map (Net.State_io.new_states t.net t.state_io) ~f:
            (fun s -> `Remote s ) ]
    in
    let updated_state_network, updated_state_ledger =
      Linear_pipe.fork2
        ( Linear_pipe.scan protocol_events ~init:(p, None) ~f:(fun (p, _) ->
              function
            | `Local (transition, _) ->
                Logger.info t.log
                  !"Stepping with local transition %{sexp: \
                    Transition_with_witness.t}"
                  transition ;
                let%map p' =
                  Protocol.step p
                    (Protocol.Event.Found
                       (Transition_with_witness.forget_witness transition))
                in
                (p', Some transition.transition.ledger_builder_transition)
            | `Remote pcd ->
                Logger.info t.log
                  !"Stepping with remote pcd %{sexp: \
                    Inputs.State_with_witness.t}"
                  pcd ;
                let transition =
                  forget_transition_validity
                    pcd.State_with_witness.ledger_builder_transition
                in
                let%map p' =
                  Protocol.step p
                    (Protocol.Event.New_state
                       (State_with_witness.forget_witness pcd, transition))
                in
                (p', Some transition.diff) )
        |> Linear_pipe.map ~f:(fun (p, ledger_builder_transition) ->
               failwith "Ask brandon"
               (*
               State_with_witness.add_witness_exn p.state
                 (transactions, Option.value_exn ledger_builder_transition) *)
           ) )
       in
    don't_wait_for
      (Linear_pipe.transfer_id updated_state_network t.miner_broadcast_writer) ;
    don't_wait_for
      (Linear_pipe.iter updated_state_ledger ~f:
         (fun {state; ledger_builder_transition} ->
           Logger.info t.log
             !"Ledger has new %{sexp: Proof_carrying_state.t} and %{sexp: \
               Inputs.Ledger_builder_diff.t}"
             state
             (forget_diff_validity ledger_builder_transition.diff) ;
           (* TODO: Right now we're crashing on purpose if we even get a tiny bit
         *       backed up. We should fix this see issues #178 and #177 *)
           Linear_pipe.write_or_exn
             ~capacity:t.ledger_builder_transition_backup_capacity
             t.transitions updated_state_ledger
             (state.data, forget_transition_validity ledger_builder_transition) ;
           return () )) ;
    don't_wait_for
      (Linear_pipe.transfer
         (Ledger_builder_controller.strongest_ledgers t.ledger_builder)
         t.miner_changes_writer ~f:(fun (ledger_builder, state) ->
           let transactions =
             Transaction_pool.transactions t.transaction_pool
           in
           Tip_change {Miner.Tip.transactions; ledger_builder; state} ))
 *)
    failwith ""
end
