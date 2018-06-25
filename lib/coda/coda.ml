open Core_kernel
open Async_kernel
open Protocols

module type Ledger_builder_io_intf = sig
  type t

  type ledger_builder_hash

  type ledger_builder

  type state

  val get_ledger_builder_at_hash :
    t -> ledger_builder_hash -> (ledger_builder * state) Deferred.Or_error.t
end

module type State_io_intf = sig
  type net

  type t

  type state_with_witness

  val create :
    net -> broadcast_state:state_with_witness Linear_pipe.Reader.t -> t

  (* Over the wire we should be passing ledger_builder_hash, this function needs to preimage the hash also *)

  val new_states : net -> t -> state_with_witness Linear_pipe.Reader.t
end

module type Network_intf = sig
  type t

  type state_with_witness

  type ledger_builder

  type state

  type ledger_builder_hash

  module State_io :
    State_io_intf
    with type state_with_witness := state_with_witness
     and type net := t

  module Ledger_builder_io :
    Ledger_builder_io_intf
    with type t := t
     and type ledger_builder := ledger_builder
     and type ledger_builder_hash := ledger_builder_hash
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

  val get :
    t -> k:int -> ledger:ledger -> transaction_with_valid_signature list

  val load : disk_location:string -> t Deferred.t
end

module type Snark_pool_intf = sig
  type t

  type snark_pool_proof

  val add : t -> snark_pool_proof -> t

  val load : disk_location:string -> t Deferred.t
end

module type Ledger_builder_controller_intf = sig
  type ledger_builder

  type ledger_builder_hash

  type ledger_builder_transition

  type ledger

  type transaction_with_valid_signature

  type net

  type state

  type snark_pool

  type t

  module Config : sig
    type t =
      { keep_count: int [@default 50]
      ; parent_log: Logger.t
      ; net_deferred: net Deferred.t
      ; ledger_builder_transitions:
          ( transaction_with_valid_signature list
          * state
          * ledger_builder_transition )
          Linear_pipe.Reader.t
      ; disk_location: string
      ; snark_pool: snark_pool }
    [@@deriving make]
  end

  val create : Config.t -> t Deferred.t

  val local_get_ledger :
    t -> ledger_builder_hash -> (ledger_builder * state) Or_error.t

  val strongest_ledgers : t -> (ledger_builder * state) Linear_pipe.Reader.t
end

module type Miner_intf = sig
  type t

  type ledger

  type ledger_hash

  type ledger_builder

  type transaction

  type transition_with_witness

  type state

  module Tip : sig
    type t =
      { state: state
      ; ledger: ledger
      ; ledger_builder: ledger_builder
      ; transactions: transaction list }
  end

  type change = Tip_change of Tip.t

  val create :
    parent_log:Logger.t -> change_feeder:change Linear_pipe.Reader.t -> t

  val transitions : t -> transition_with_witness Linear_pipe.Reader.t
end

module type Witness_change_intf = sig
  type t_with_witness

  type witness

  type t

  val forget_witness : t_with_witness -> t

  val add_witness_exn : t -> witness -> t_with_witness

  val add_witness : t -> witness -> t_with_witness Or_error.t
end

module type Transition_with_witness_intf = sig
  type transition

  type transaction_with_valid_signature

  type ledger_hash

  type t =
    { transactions: transaction_with_valid_signature list
    ; previous_ledger_hash: ledger_hash
    ; transition: transition }
  [@@deriving sexp]

  include Witness_change_intf
          with type t_with_witness := t
           and type witness =
                      transaction_with_valid_signature list * ledger_hash
           and type t := transition
end

module type State_with_witness_intf = sig
  type state

  type transaction

  type transaction_with_valid_signature

  type ledger_hash

  type ledger_builder_transition

  type t =
    { transactions: transaction_with_valid_signature list
    ; ledger_builder_transition: ledger_builder_transition
    ; state: state }
  [@@deriving sexp]

  module Stripped : sig
    type t =
      { transactions: transaction list
      ; ledger_builder_transition: ledger_builder_transition
      ; state: state }
    [@@deriving bin_io]
  end

  val strip : t -> Stripped.t

  val check : Stripped.t -> t

  include Witness_change_intf
          with type t_with_witness := t
           and type witness =
                      transaction_with_valid_signature list
                      * ledger_builder_transition
           and type t := state
end

module type Inputs_intf = sig
  include Coda_pow.Inputs_intf

  module Ledger : sig
    type t
  end

  module Proof_carrying_state : sig
    type t = (State.t, State.Proof.t) Coda_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module State_with_witness :
    State_with_witness_intf
    with type state := Proof_carrying_state.t
     and type transaction := Transaction.t
     and type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type ledger_hash := Ledger_hash.t
     and type ledger_builder_transition := Ledger_builder_transition.t

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
    Snark_pool_intf with type snark_pool_proof := Snark_pool_proof.t

  module Ledger_builder_controller :
    Ledger_builder_controller_intf
    with type net := Net.t
     and type ledger := Ledger.t
     and type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type ledger_builder_transition := Ledger_builder_transition.t
     and type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type snark_pool := Snark_pool.t
     and type state := State.t

  module Transaction_pool :
    Transaction_pool_intf
    with type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type ledger := Ledger.t

  module Miner :
    Miner_intf
    with type transition_with_witness := Transition_with_witness.t
     and type ledger := Ledger.t
     and type ledger_hash := Ledger_hash.t
     and type ledger_builder := Ledger_builder.t
     and type transaction := Transaction.With_valid_signature.t
     and type state := State.t

  module Genesis : sig
    val state : State.t

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
    ; state_io: Net.State_io.t
    ; miner_changes_writer: Miner.change Linear_pipe.Writer.t
    ; miner_broadcast_writer: State_with_witness.t Linear_pipe.Writer.t
    ; ledger_builder_transitions:
        ( Transaction.With_valid_signature.t list
        * State.t
        * Ledger_builder_transition.t )
        Linear_pipe.Writer.t
        (* TODO: Is this the best spot for the transaction_pool ref? *)
    ; mutable transaction_pool: Transaction_pool.t
    ; mutable snark_pool: Snark_pool.t
    ; ledger_builder: Ledger_builder_controller.t
    ; log: Logger.t
    ; transactions_per_bundle: int
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
      ; transactions_per_bundle: int [@default 10]
      ; ledger_builder_transition_backup_capacity: int [@default 10] }
    [@@deriving make]
  end

  let create (config: Config.t) =
    let miner_changes_reader, miner_changes_writer = Linear_pipe.create () in
    let miner_broadcast_reader, miner_broadcast_writer =
      Linear_pipe.create ()
    in
    let ledger_builder_transitions_reader, ledger_builder_transitions_writer =
      Linear_pipe.create ()
    in
    let net_ivar = Ivar.create () in
    let%bind snark_pool =
      Snark_pool.load ~disk_location:config.snark_pool_disk_location
    in
    let%map ledger_builder =
      Ledger_builder_controller.create
        (Ledger_builder_controller.Config.make ~snark_pool
           ~parent_log:config.log ~net_deferred:(Ivar.read net_ivar)
           ~ledger_builder_transitions:ledger_builder_transitions_reader
           ~disk_location:config.ledger_builder_persistant_location ())
    in
    let miner =
      Miner.create ~parent_log:config.log ~change_feeder:miner_changes_reader
    in
    let%bind net =
      Net.create config.net_config
        (fun hash ->
          return
            (Or_error.is_ok
               (Ledger_builder_controller.local_get_ledger ledger_builder hash))
          )
        (fun hash ->
          return
            ( match
                Ledger_builder_controller.local_get_ledger ledger_builder hash
              with
            | Ok ledger_and_state -> Some ledger_and_state
            | _ -> None ) )
    in
    Ivar.fill net_ivar net ;
    let state_io =
      Net.State_io.create net ~broadcast_state:miner_broadcast_reader
    in
    let%map transaction_pool =
      Transaction_pool.load
        ~disk_location:config.transaction_pool_disk_location
    in
    { miner
    ; net
    ; state_io
    ; miner_broadcast_writer
    ; miner_changes_writer
    ; ledger_builder_transitions= ledger_builder_transitions_writer
    ; transaction_pool
    ; snark_pool
    ; ledger_builder
    ; log= config.log
    ; transactions_per_bundle= config.transactions_per_bundle
    ; ledger_builder_transition_backup_capacity=
        config.ledger_builder_transition_backup_capacity }

  let run t =
    Logger.info t.log "Starting to run Coda" ;
    let p : Protocol.t =
      Protocol.create ~initial:{data= Genesis.state; proof= Genesis.proof}
    in
    let miner_transitions_protocol = Miner.transitions t.miner in
    let protocol_events =
      Linear_pipe.merge_unordered
        [ Linear_pipe.map miner_transitions_protocol ~f:(fun transition ->
              `Local transition )
        ; Linear_pipe.map (Net.State_io.new_states t.net t.state_io) ~f:
            (fun s -> `Remote s ) ]
    in
    let updated_state_network, updated_state_ledger =
      Linear_pipe.fork2
        ( Linear_pipe.scan protocol_events ~init:(p, [], None) ~f:
            (fun (p, _, _) -> function
            | `Local transition ->
                Logger.info t.log
                  !"Stepping with local transition %{sexp: \
                    Transition_with_witness.t}"
                  transition ;
                let%map p' =
                  Protocol.step p
                    (Protocol.Event.Found
                       (Transition_with_witness.forget_witness transition))
                in
                ( p'
                , transition.transactions
                , Some transition.transition.ledger_builder_transition )
            | `Remote pcd ->
                Logger.info t.log
                  !"Stepping with remote pcd %{sexp: \
                    Inputs.State_with_witness.t}"
                  pcd ;
                let%map p' =
                  Protocol.step p
                    (Protocol.Event.New_state
                       ( State_with_witness.forget_witness pcd
                       , pcd.State_with_witness.ledger_builder_transition ))
                in
                (p', pcd.transactions, Some pcd.ledger_builder_transition) )
        |> Linear_pipe.map ~f:
             (fun (p, transactions, ledger_builder_transition) ->
               State_with_witness.add_witness_exn p.state
                 (transactions, Option.value_exn ledger_builder_transition) )
        )
    in
    don't_wait_for
      (Linear_pipe.transfer_id updated_state_network t.miner_broadcast_writer) ;
    don't_wait_for
      (Linear_pipe.iter updated_state_ledger ~f:
         (fun {state; transactions; ledger_builder_transition} ->
           Logger.info t.log
             !"Ledger has new %{sexp: Proof_carrying_state.t} and %{sexp: \
               Inputs.Transaction.With_valid_signature.t list}"
             state transactions ;
           (* TODO: Right now we're crashing on purpose if we even get a tiny bit
         *       backed up. We should fix this see issues #178 and #177 *)
           Linear_pipe.write_or_exn
             ~capacity:t.ledger_builder_transition_backup_capacity
             t.ledger_builder_transitions updated_state_ledger
             (transactions, state.data, ledger_builder_transition) ;
           return () )) ;
    don't_wait_for
      (Linear_pipe.transfer
         (Ledger_builder_controller.strongest_ledgers t.ledger_builder)
         t.miner_changes_writer ~f:(fun (ledger_builder, ledger, state) ->
           let transactions =
             Transaction_pool.get ~k:t.transactions_per_bundle ~ledger
               t.transaction_pool
           in
           Tip_change {Miner.Tip.transactions; ledger_builder; ledger; state}
       ))
end
