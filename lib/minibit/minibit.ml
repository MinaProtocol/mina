open Core_kernel
open Async_kernel
open Protocols

module type Ledger_fetcher_io_intf = sig
  type t
  type ledger_hash
  type ledger
  type state

  val get_ledger_at_hash : t -> ledger_hash -> (ledger * state) Deferred.Or_error.t
end

module type State_io_intf = sig
  type net
  type t
  type stripped_state_with_witness

  val create : net -> broadcast_state:stripped_state_with_witness Linear_pipe.Reader.t -> t

  val new_states : net -> t -> stripped_state_with_witness Linear_pipe.Reader.t
end

module type Network_intf = sig
  type t
  type stripped_state_with_witness
  type ledger
  type state
  type ledger_hash
  module State_io : State_io_intf with type stripped_state_with_witness := stripped_state_with_witness 
                                   and type net := t
  module Ledger_fetcher_io : Ledger_fetcher_io_intf with type t := t
                                                     and type ledger := ledger 
                                                     and type ledger_hash := ledger_hash
                                                     and type state := state

  module Config : sig
    type t
  end

  val create
    : Config.t
    -> (ledger_hash -> bool Deferred.t)
    -> (ledger_hash -> (ledger * state) option Deferred.t)
    -> t Deferred.t

end

module type Transaction_pool_intf = sig
  type t
  type transaction_with_valid_signature

  val add : t -> transaction_with_valid_signature -> t
  val remove : t -> transaction_with_valid_signature -> t
  val get : t -> k:int -> transaction_with_valid_signature list
  val load : disk_location:string -> t Deferred.t
end

module type Ledger_fetcher_intf = sig
  type t
  type ledger_hash
  type ledger
  type transaction_with_valid_signature
  type state
  type net

  module Config : sig
    type t =
      { keep_count : int [@default 50]
      ; parent_log : Logger.t
      ; net_deferred : net Deferred.t
      ; ledger_transitions : (ledger_hash * transaction_with_valid_signature list * state) Linear_pipe.Reader.t
      ; disk_location : string
      }
    [@@deriving make]
  end

  val create : Config.t -> t Deferred.t
  val best_ledger : t -> ledger
  val get : t -> ledger_hash -> ledger Deferred.Or_error.t

  val local_get : t -> ledger_hash -> (ledger * state) Or_error.t
  val strongest_ledgers : t -> (ledger * state) Linear_pipe.Reader.t
end

module type Miner_intf = sig
  type t
  type ledger_hash
  type ledger
  type transaction
  type transition_with_witness
  type state

  module Tip : sig
    type t =
      { state : state
      ; ledger : ledger
      ; transactions : transaction list
      }
  end

  type change =
    | Tip_change of Tip.t

  val create
    : parent_log:Logger.t
    -> change_feeder:change Linear_pipe.Reader.t
    -> t

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

  type t =
    { transactions : transaction_with_valid_signature list
    ; transition : transition
    }
  [@@deriving sexp]

  include Witness_change_intf with type t_with_witness := t
                              and type witness = transaction_with_valid_signature list
                              and type t := transition
end

module type State_with_witness_intf = sig
  type state
  type transaction
  type transaction_with_valid_signature

  type t =
    { transactions : transaction_with_valid_signature list
    ; state : state
    }
  [@@deriving sexp]

  module Stripped : sig
    type t =
      { transactions : transaction list
      ; state : state
      }
    [@@deriving bin_io]
  end


  val strip : t -> Stripped.t

  include Witness_change_intf with type t_with_witness := t
                              and type witness = transaction_with_valid_signature list
                              and type t := state
end

module type Inputs_intf = sig
  include Minibit_pow.Inputs_intf

  module Proof_carrying_state : sig
    type t = (State.t, State.Proof.t) Minibit_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end
  module State_with_witness : State_with_witness_intf with type state := Proof_carrying_state.t
                                                       and type transaction := Transaction.t
                                                       and type transaction_with_valid_signature := Transaction.With_valid_signature.t
  module Transition_with_witness : Transition_with_witness_intf with type transaction_with_valid_signature := Transaction.With_valid_signature.t
                                                                 and type transition := Transition.t

  module Net : Network_intf
    with type stripped_state_with_witness := State_with_witness.Stripped.t 
     and type ledger := Ledger.t
     and type ledger_hash := Ledger_hash.t
     and type state := State.t

  module Transaction_pool : Transaction_pool_intf with type transaction_with_valid_signature := Transaction.With_valid_signature.t
  module Ledger_fetcher : Ledger_fetcher_intf with type ledger_hash := Ledger_hash.t
                                               and type ledger := Ledger.t
                                               and type transaction_with_valid_signature := Transaction.With_valid_signature.t
                                               and type state := State.t
                                               and type net := Net.t

  module Miner : Miner_intf with type transition_with_witness := Transition_with_witness.t
                             and type ledger_hash := Ledger_hash.t
                             and type ledger := Ledger.t
                             and type transaction := Transaction.With_valid_signature.t
                             and type state := State.t


  module Genesis : sig
    val state : State.t
    val proof : State.Proof.t
  end
end

module Make
  (Inputs : Inputs_intf)
  (* TODO: Lift this out of the functor and inline it *)
  (Block_state_transition_proof : Minibit_pow.Block_state_transition_proof_intf with type state := Inputs.State.t
                                                                     and type proof := Inputs.State.Proof.t
                                                                     and type transition := Inputs.Transition.t)
= struct

  module Protocol = Minibit_pow.Make(Inputs)(Block_state_transition_proof)
  open Inputs

  type t =
    { miner : Miner.t
    ; net : Net.t
    ; state_io : Net.State_io.t
    ; miner_changes_writer : Miner.change Linear_pipe.Writer.t
    ; miner_broadcast_writer : State_with_witness.t Linear_pipe.Writer.t
    ; ledger_fetcher_transitions : (Ledger_hash.t * Transaction.With_valid_signature.t list * State.t) Linear_pipe.Writer.t
    (* TODO: Is this the best spot for the transaction_pool ref? *)
    ; mutable transaction_pool : Transaction_pool.t
    ; ledger_fetcher : Ledger_fetcher.t
    ; log : Logger.t
    }

  let ledger_fetcher t = t.ledger_fetcher
  let modify_transaction_pool t ~f =
    t.transaction_pool <- f t.transaction_pool

  module Config = struct
    type t =
      { log : Logger.t
      ; net_config : Net.Config.t
      ; ledger_disk_location : string
      ; pool_disk_location : string
      }
  end

  let create (config : Config.t) =
    let (miner_changes_reader, miner_changes_writer) = Linear_pipe.create () in
    let (miner_broadcast_reader,miner_broadcast_writer) = Linear_pipe.create () in
    let (ledger_fetcher_transitions_reader, ledger_fetcher_transitions_writer) = Linear_pipe.create () in
    let ledger_fetcher_net_ivar = Ivar.create () in
    let%bind ledger_fetcher =
      Ledger_fetcher.create
        (Ledger_fetcher.Config.make
          ~parent_log:config.log
          ~net_deferred:(Ivar.read ledger_fetcher_net_ivar)
          ~ledger_transitions:ledger_fetcher_transitions_reader
          ~disk_location:config.ledger_disk_location ())
    in
    let miner =
      Miner.create
        ~parent_log:config.log
        ~change_feeder:miner_changes_reader
    in
    let%bind net = 
      Net.create 
        config.net_config
        (fun hash -> return (Or_error.is_ok (Ledger_fetcher.local_get ledger_fetcher hash)))
        (fun hash -> 
           return (
             match Ledger_fetcher.local_get ledger_fetcher hash with
             | Ok ledger_and_state -> Some ledger_and_state
             | _ -> None))
    in
    Ivar.fill ledger_fetcher_net_ivar net;
    let state_io = 
      Net.State_io.create 
        net 
        ~broadcast_state:(Linear_pipe.map miner_broadcast_reader ~f:State_with_witness.strip) in
    let%map transaction_pool =
      Transaction_pool.load ~disk_location:config.pool_disk_location
    in
    { miner
    ; net
    ; state_io
    ; miner_broadcast_writer
    ; miner_changes_writer
    ; ledger_fetcher_transitions = ledger_fetcher_transitions_writer
    ; transaction_pool
    ; ledger_fetcher
    ; log = config.log
    }

  let run t =
    Logger.info t.log "Starting to run minibit";
    let p : Protocol.t = Protocol.create ~initial:{ data = Genesis.state ; proof = Genesis.proof } in

    let (miner_transitions_protocol, miner_transitions_ledger_fetcher) =
      Linear_pipe.fork2 (Miner.transitions t.miner)
    in
    let protocol_events =
      Linear_pipe.merge_unordered
        [ Linear_pipe.map
            miner_transitions_protocol
            ~f:(fun transition -> `Local transition)
        ; Linear_pipe.filter_map
            (Net.State_io.new_states t.net t.state_io)
            ~f:(fun {state ; transactions} ->
              let open Option.Let_syntax in
              let%map valid_transactions = Option.all (List.map ~f:Transaction.check transactions) in
              `Remote {State_with_witness.state ; transactions = valid_transactions})
        ]
    in
    let (updated_state_network, updated_state_ledger) =
      Linear_pipe.fork2 begin
        Linear_pipe.scan protocol_events ~init:(p, []) ~f:(fun (p, _) -> function
          | `Local transition ->
              Logger.info t.log !"Stepping with local transition %{sexp: Transition_with_witness.t}" transition;
              let%map p' = Protocol.step p (Protocol.Event.Found (Transition_with_witness.forget_witness transition)) in
              (p', transition.transactions)
          | `Remote pcd ->
              Logger.info t.log !"Stepping with remote pcd %{sexp: Inputs.State_with_witness.t}" pcd;
              let%map p' = Protocol.step p (Protocol.Event.New_state (State_with_witness.forget_witness pcd)) in
              (p', pcd.transactions)
        )
        |> Linear_pipe.map
          ~f:(fun (p, transactions) -> State_with_witness.add_witness_exn p.state transactions)
      end
    in

    don't_wait_for begin
      Linear_pipe.transfer_id updated_state_network t.miner_broadcast_writer
    end;

    don't_wait_for begin
      Linear_pipe.iter updated_state_ledger ~f:(fun {state ; transactions} ->
        Logger.info t.log !"Ledger has new %{sexp: Proof_carrying_state.t} and %{sexp: Inputs.Transaction.With_valid_signature.t list}" state transactions;
        (* TODO: Right now we're crashing on purpose if we even get a tiny bit
         *       backed up. We should fix this see issues #178 and #177 *)
        Linear_pipe.write_or_exn ~capacity:10 t.ledger_fetcher_transitions updated_state_ledger (state.data.ledger_hash, transactions, state.data);
        return ()
      )
    end;

    don't_wait_for begin
      Linear_pipe.transfer (Ledger_fetcher.strongest_ledgers t.ledger_fetcher) t.miner_changes_writer ~f:(fun (ledger, state) ->
        let transaction_per_bundle = 10 in
        let transactions = Transaction_pool.get ~k:transaction_per_bundle t.transaction_pool in
        Tip_change { Miner.Tip.transactions ; ledger ; state }
      )
    end;

    printf "Pipes hooked in\n%!"
end


