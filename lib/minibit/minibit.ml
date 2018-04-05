open Core_kernel
open Async_kernel
open Protocols

module type Ledger_fetcher_remote_intf = sig
  type t
  type 'a hash
  type ledger

  val get_ledger_at_hash : t -> ledger hash -> ledger Deferred.t
end

module type Miner_remote_intf = sig
  type t
  type state
  type proof

  val create : broadcast_state:state Linear_pipe.Reader.t -> t

  val new_states : t -> (state * proof) Linear_pipe.Reader.t
end

module type Network_intf = sig
  include Miner_remote_intf
  include Ledger_fetcher_remote_intf with type t := t
end

module type Transaction_intf = sig
  type t
end

module type Ledger_fetcher_intf = sig
  type t
  type 'a hash
  type ledger
  type transaction

  val create : transition_feeder:(ledger hash * transaction list) Linear_pipe.Reader.t -> t
  val get : t -> ledger hash -> ledger Deferred.t
end

module type Transaction_pool_intf = sig
  type t
  type transaction

  val add : t -> transaction -> t
  val remove : t -> transaction -> t
  val get : t -> k:int -> transaction list
end

module type Miner_intf = sig
  type t
  type 'a hash
  type transition
  type state
  type transaction_pool

  type change =
    | Tip_change of state

  val create : change_feeder:change Linear_pipe.Reader.t -> t

  val transitions : t -> transition Linear_pipe.Reader.t
end

module type Inputs_intf = sig
  include Minibit_pow.Inputs_intf

  module Ledger_fetcher_remote : Ledger_fetcher_remote_intf
  module Miner_remote : Miner_remote_intf with type state := State.t
                                           and type proof := State.Proof.t
  module Ledger_fetcher : Ledger_fetcher_intf with type 'a hash := 'a Hash.t
                                               and type ledger := Ledger.t
                                               and type transaction := Transaction.t

  module Transaction_pool : Transaction_pool_intf with type transaction := Transaction.t
  module Miner : Miner_intf with type 'a hash := 'a Hash.t
                       and type state := State.t
                       and type transition := Transition.t
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
    ; miner_remote : Miner_remote.t
    ; miner_broadcast_writer : State.t Linear_pipe.Writer.t
    ; ledger_fetcher : Ledger_fetcher.t
    ; ledger_fetcher_transition_feeder : (Ledger.t Hash.t * Transaction.t list) Linear_pipe.Writer.t
    }

  let run t =
    let (mining_transitions_reader,mining_transitions_writer) = Linear_pipe.create () in
    don't_wait_for begin
      Linear_pipe.transfer (Miner.transitions t.miner) mining_transitions_writer ~f:(fun transition -> Protocol.Found transition)
    end;

    let p = Protocol.create ~initial:(Genesis.state, Genesis.proof) in

    let protocol_events =
      Linear_pipe.merge_unordered
        [ Linear_pipe.map
            (Miner.transitions t.miner)
            ~f:(fun transition -> Protocol.Found transition)
        ; Linear_pipe.map
            (Miner_remote.new_states t.miner_remote)
            ~f:(fun (s, p) -> Protocol.New_state (s, p))
        ]
    in
    let (updated_state_network, updated_state_ledger) =
      Linear_pipe.fork2 begin
        Linear_pipe.scan protocol_events ~f:Protocol.step ~init:p
        |> Linear_pipe.map ~f:(fun (p : Protocol.t) -> p.state |> fst)
      end
    in

    don't_wait_for begin
      Linear_pipe.transfer_id updated_state_network t.miner_broadcast_writer
    end;

    don't_wait_for begin
      Linear_pipe.transfer updated_state_ledger t.ledger_fetcher_transition_feeder
        ~f:(fun (state : State.t) -> (state.body.ledger_hash, state.body.transactions))
    end;
end


