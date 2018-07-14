open Core_kernel
open Async_kernel
open Protocols

module type State_io_intf = sig
  type net

  type t

  type state_with_witness

  val create :
    net -> broadcast_state:state_with_witness Linear_pipe.Reader.t -> t

  val new_states : net -> t -> state_with_witness Linear_pipe.Reader.t
end

module type Ledger_builder_io_intf = sig
  type net

  type t

  type hash

  type aux

  type sync_ledger_query

  type sync_ledger_answer

  val create : net -> t

  val get_ledger_builder_aux_at_hash : t -> hash -> aux Deferred.t

  val glue_sync_ledger :
       t
    -> sync_ledger_query Linear_pipe.Reader.t
    -> sync_ledger_answer Linear_pipe.Writer.t
    -> unit
end

module type Network_intf = sig
  type t

  type state_with_witness

  type state

  type ledger_builder_hash

  type ledger_builder_aux

  type sync_ledger_query

  type sync_ledger_answer

  module State_io :
    State_io_intf
    with type state_with_witness := state_with_witness
     and type net := t

  module Ledger_builder_io :
    Ledger_builder_io_intf
    with type net := t
     and type hash := ledger_builder_hash
     and type aux := ledger_builder_aux
     and type sync_ledger_query := sync_ledger_query
     and type sync_ledger_answer := sync_ledger_answer

  module Config : sig
    type t
  end

  val create :
       Config.t
    -> get_ledger_builder_aux_at_hash:(   ledger_builder_hash
                                       -> ledger_builder_aux option Deferred.t)
    -> answer_sync_ledger_query:(   sync_ledger_query
                                 -> sync_ledger_answer Deferred.t)
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

module type Miner_intf = sig
  type t

  type ledger_hash

  type ledger

  type transaction

  type transition_with_witness

  type state

  module Tip : sig
    type t = {state: state; ledger: ledger; transactions: transaction list}
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

  type t =
    { transactions: transaction_with_valid_signature list
    ; previous_ledger_hash: ledger_hash
    ; state: state }
  [@@deriving sexp]

  module Stripped : sig
    type t =
      { transactions: transaction list
      ; previous_ledger_hash: ledger_hash
      ; state: state }
    [@@deriving bin_io]
  end

  val strip : t -> Stripped.t

  val check : Stripped.t -> t

  include Witness_change_intf
          with type t_with_witness := t
           and type witness =
                      transaction_with_valid_signature list * ledger_hash
           and type t := state
end

module type Inputs_intf = sig
  include Minibit_pow.Inputs_intf

  type ledger_builder_hash

  type ledger_builder_aux

  module Proof_carrying_state : sig
    type t = (State.t, State.Proof.t) Minibit_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module Sync_ledger : sig
    type query [@@deriving bin_io]

    type answer [@@deriving bin_io]
  end

  module State_with_witness :
    State_with_witness_intf
    with type state := Proof_carrying_state.t
     and type transaction := Transaction.t
     and type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type ledger_hash := Ledger_hash.t

  module Transition_with_witness :
    Transition_with_witness_intf
    with type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type transition := Transition.t
     and type ledger_hash := Ledger_hash.t

  module Net :
    Network_intf
    with type state_with_witness := State_with_witness.t
     and type ledger_builder_hash := ledger_builder_hash
     and type ledger_builder_aux := ledger_builder_aux
     and type state := State.t
     and type sync_ledger_query := Sync_ledger.query
     and type sync_ledger_answer := Sync_ledger.answer

  module Transaction_pool :
    Transaction_pool_intf
    with type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type ledger := Ledger.t

  module Miner :
    Miner_intf
    with type transition_with_witness := Transition_with_witness.t
     and type ledger_hash := Ledger_hash.t
     and type ledger := Ledger.t
     and type transaction := Transaction.With_valid_signature.t
     and type state := State.t

  module Genesis : sig
    val state : State.t

    val proof : State.Proof.t
  end
end

(* TODO: Lift block_state_transition_proof out of the functor and inline it *)
module Make
    (Inputs : Inputs_intf)
    (Block_state_transition_proof : Minibit_pow.
                                    Block_state_transition_proof_intf
                                    with type state := Inputs.State.t
                                     and type proof := Inputs.State.Proof.t
                                     and type transition := Inputs.Transition.t) =
struct
  module Protocol = Minibit_pow.Make (Inputs) (Block_state_transition_proof)
  open Inputs

  type t =
    { miner: Miner.t
    ; net: Net.t
    ; state_io: Net.State_io.t
    ; miner_changes_writer: Miner.change Linear_pipe.Writer.t
    ; miner_broadcast_writer:
        State_with_witness.t Linear_pipe.Writer.t
        (* TODO: Is this the best spot for the transaction_pool ref? *)
    ; mutable transaction_pool: Transaction_pool.t
    ; log: Logger.t }

  let modify_transaction_pool t ~f = t.transaction_pool <- f t.transaction_pool

  module Config = struct
    type t =
      { log: Logger.t
      ; net_config: Net.Config.t
      ; ledger_disk_location: string
      ; pool_disk_location: string }
  end

  let create (config: Config.t) =
    let miner_changes_reader, miner_changes_writer = Linear_pipe.create () in
    let miner_broadcast_reader, miner_broadcast_writer =
      Linear_pipe.create ()
    in
    let miner =
      Miner.create ~parent_log:config.log ~change_feeder:miner_changes_reader
    in
    let%bind net =
      Net.create config.net_config
        (fun hash -> failwith "get_ledger_builder_aux_at_hash unimplemented")
        (fun hash -> failwith "answer_sync_ledger_query unimplemented")
    in
    let state_io =
      Net.State_io.create net ~broadcast_state:miner_broadcast_reader
    in
    let%map transaction_pool =
      Transaction_pool.load ~disk_location:config.pool_disk_location
    in
    { miner
    ; net
    ; state_io
    ; miner_broadcast_writer
    ; miner_changes_writer
    ; transaction_pool
    ; log= config.log }

  let run t =
    Logger.info t.log "Starting to run minibit" ;
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
                , Some transition.previous_ledger_hash )
            | `Remote pcd ->
                Logger.info t.log
                  !"Stepping with remote pcd %{sexp: \
                    Inputs.State_with_witness.t}"
                  pcd ;
                let%map p' =
                  Protocol.step p
                    (Protocol.Event.New_state
                       (State_with_witness.forget_witness pcd))
                in
                (p', pcd.transactions, Some pcd.previous_ledger_hash) )
        |> Linear_pipe.map ~f:(fun (p, transactions, previous_ledger_hash) ->
               State_with_witness.add_witness_exn p.state
                 (transactions, Option.value_exn previous_ledger_hash) ) )
    in
    don't_wait_for
      (Linear_pipe.transfer_id updated_state_network t.miner_broadcast_writer)
end
