open Core_kernel
open Async_kernel
open Protocols

module type Ledger_fetcher_io_intf = sig
  type t
  type 'a hash
  type ledger
  type state

  val get_ledger_at_hash : t -> ledger hash -> (ledger * state) Deferred.Or_error.t
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
  type 'a hash
  type state
  module State_io : State_io_intf with type stripped_state_with_witness := stripped_state_with_witness 
                                   and type net := t
  module Ledger_fetcher_io : Ledger_fetcher_io_intf with type t := t
                                                     and type ledger := ledger 
                                                     and type 'a hash := 'a hash
                                                     and type state := state

  module Config : sig
    type t
  end

  val create
    : Config.t
    -> (ledger hash -> bool Deferred.t)
    -> (ledger hash -> (ledger * state) option Deferred.t)
    -> t Deferred.t

end

module type Ledger_fetcher_intf = sig
  type t
  type 'a hash
  type ledger
  type transaction_with_valid_signature
  type state
  type net

  module Config : sig
    type t =
      { keep_count : int [@default 50]
      ; parent_log : Logger.t
      ; net_deferred : net Deferred.t
      ; ledger_transitions : (ledger hash * transaction_with_valid_signature list * state) Linear_pipe.Reader.t
      }
    [@@deriving make]
  end

  val create : Config.t -> t
  val get : t -> ledger hash -> ledger Deferred.Or_error.t

  val local_get : t -> ledger hash -> (ledger * state) Or_error.t
end

module type Transaction_pool_intf = sig
  type t
  type transaction_with_valid_signature

  val add : t -> transaction_with_valid_signature -> t
  val remove : t -> transaction_with_valid_signature -> t
  val get : t -> k:int -> transaction_with_valid_signature list
end

module type Miner_intf = sig
  type t
  type 'a hash
  type ledger
  type transition_with_witness
  type state
  type transaction_pool

  type change =
    | Tip_change of { state : state; transaction_pool : transaction_pool }

  val create
    : logger:Logger.t
    -> ledger:ledger
    -> initial_state:state
    -> initial_transaction_pool:transaction_pool
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
    [@@deriving bin_io]
  end
  module State_with_witness : State_with_witness_intf with type state := Proof_carrying_state.t
                                                       and type transaction := Transaction.t
                                                       and type transaction_with_valid_signature := Transaction.With_valid_signature.t
  module Transition_with_witness : Transition_with_witness_intf with type transaction_with_valid_signature := Transaction.With_valid_signature.t
                                                                 and type transition := Transition.t

  module Net : Network_intf
    with type stripped_state_with_witness := State_with_witness.Stripped.t 
     and type ledger := Ledger.t
     and type 'a hash := 'a Hash.t
     and type state := State.t

  module Ledger_fetcher : Ledger_fetcher_intf with type 'a hash := 'a Hash.t
                                               and type ledger := Ledger.t
                                               and type transaction_with_valid_signature := Transaction.With_valid_signature.t
                                               and type state := State.t
                                               and type net := Net.t

  module Transaction_pool : Transaction_pool_intf with type transaction_with_valid_signature := Transaction.With_valid_signature.t
  module Miner : Miner_intf with type 'a hash := 'a Hash.t
                             and type ledger := Ledger.t
                             and type state := State.t
                             and type transition_with_witness := Transition_with_witness.t
                             and type transaction_pool := Transaction_pool.t
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
    ; miner_broadcast_writer : State_with_witness.t Linear_pipe.Writer.t
    ; ledger_fetcher_transitions : (Ledger.t Hash.t * Transaction.With_valid_signature.t list * State.t) Linear_pipe.Writer.t
    }

  module Config = struct
    type t =
      { log : Logger.t
      ; net_config : Net.Config.t
      }
  end

  let create (config : Config.t) =
    let (miner_broadcast_reader,miner_broadcast_writer) = Linear_pipe.create () in
    let (ledger_fetcher_transitions_reader, ledger_fetcher_transitions_writer) = Linear_pipe.create () in
    let (change_feeder_reader, change_feeder_writer) = Linear_pipe.create () in
    let ledger_fetcher_net_ivar = Ivar.create () in
    let ledger_fetcher = Ledger_fetcher.create (Ledger_fetcher.Config.make ~parent_log:config.log ~net_deferred:(Ivar.read ledger_fetcher_net_ivar) ~ledger_transitions:ledger_fetcher_transitions_reader ()) in
    let miner =
      Miner.create
        ~ledger:(failwith "TODO")
        ~logger:config.log
        ~initial_state:(failwith "TODO")
        ~initial_transaction_pool:(failwith "TODO")
        ~change_feeder:change_feeder_reader
    in
    let%map net = 
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
    { miner
    ; net
    ; state_io
    ; miner_broadcast_writer
    ; ledger_fetcher_transitions = ledger_fetcher_transitions_writer
    }

  let run t =
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
              let%map p' = Protocol.step p (Protocol.Event.Found (Transition_with_witness.forget_witness transition)) in
              (p', transition.transactions)
          | `Remote pcd ->
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
        (* TODO: Right now we're crashing on purpose if we even get a tiny bit
         *       backed up. We should fix this see issues #178 and #177 *)
        Linear_pipe.write_or_exn ~capacity:10 t.ledger_fetcher_transitions updated_state_ledger (state.data.ledger_hash, transactions, state.data);
        return ()
      )
    end;

    printf "Pipes hooked in\n%!"
end


