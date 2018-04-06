open Core_kernel
open Async_kernel
open Protocols

module type Ledger_fetcher_io_intf = sig
  type t
  type 'a hash
  type ledger

  val get_ledger_at_hash : t -> ledger hash -> ledger Deferred.Or_error.t
end

module type State_io_intf = sig
  type t
  type 'a state_with_witness

  val create : broadcast_state:'a state_with_witness Linear_pipe.Reader.t -> t

  val new_states : t -> 'a state_with_witness Linear_pipe.Reader.t
end

module type Network_intf = sig
  include State_io_intf
  include Ledger_fetcher_io_intf with type t := t
end

module type Ledger_fetcher_intf = sig
  type t
  type 'a hash
  type ledger
  type _ transaction

  val create : ledger_transitions:(ledger hash * [> `Valid_signature] transaction list) Linear_pipe.Reader.t -> t
  val get : t -> ledger hash -> ledger Deferred.t
end

module type Transaction_pool_intf = sig
  type t
  type _ transaction

  val add : t -> [> `Valid_signature] transaction -> t
  val remove : t -> [> `Valid_signature] transaction -> t
  val get : t -> k:int -> [> `Valid_signature] transaction list
end

module type Miner_intf = sig
  type t
  type 'a hash
  type _ transition_with_witness
  type state
  type transaction_pool

  type change =
    | Tip_change of state

  val create : change_feeder:change Linear_pipe.Reader.t -> t

  val transitions : t -> [> `Valid_signature] transition_with_witness Linear_pipe.Reader.t
end

module type Witness_change_intf = sig
  type 'a t_with_witness
  type 'a witness
  type t

  val forget_witness : 'a t_with_witness -> t
  val add_witness_exn : t -> 'a witness -> 'a t_with_witness
  val add_witness : t -> 'a witness -> 'a t_with_witness Or_error.t
end

module type Transition_with_witness_intf = sig
  type transition
  type 'a transaction

  type 'a t =
    { transactions : 'a transaction list
    ; transition : transition
    }

  include Witness_change_intf with type 'a t_with_witness = 'a t
                              and type 'a witness = 'a transaction list
                              and type t := transition
end

module type State_with_witness_intf = sig
  type state
  type 'a transaction

  type 'a t =
    { transactions : 'a transaction list
    ; state : state
    }

  include Witness_change_intf with type 'a t_with_witness = 'a t
                              and type 'a witness = 'a transaction list
                              and type t := state
end

module type Inputs_intf = sig
  include Minibit_pow.Inputs_intf

  module Ledger_fetcher_io : Ledger_fetcher_io_intf
  module Proof_carrying_state : sig
    type t = (State.t, State.Proof.t) Minibit_pow.Proof_carrying_data.t
  end
  module State_with_witness : State_with_witness_intf with type state := Proof_carrying_state.t
                                                       and type 'a transaction := 'a Transaction.t
  module Transition_with_witness : Transition_with_witness_intf with type 'a transaction := 'a Transaction.t
                                                                 and type transition := Transition.t
  module State_io : State_io_intf with type 'a state_with_witness := 'a State_with_witness.t
  module Ledger_fetcher : Ledger_fetcher_intf with type 'a hash := 'a Hash.t
                                               and type ledger := Ledger.t
                                               and type 'a transaction := 'a Transaction.t

  module Transaction_pool : Transaction_pool_intf with type 'a transaction := 'a Transaction.t
  module Miner : Miner_intf with type 'a hash := 'a Hash.t
                       and type state := State.t
                       and type 'a transition_with_witness := 'a Transition_with_witness.t
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

  type 'a t =
    { miner : Miner.t
    ; state_io : State_io.t
    ; miner_broadcast_writer : 'a State_with_witness.t Linear_pipe.Writer.t
    ; ledger_fetcher : Ledger_fetcher.t
    ; ledger_fetcher_transitions : (Ledger.t Hash.t * 'a Transaction.t list) Linear_pipe.Writer.t
    }
  constraint 'a = [> `Valid_signature]

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
            (State_io.new_states t.state_io)
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
              let%map p' = Protocol.step p (Protocol.Found (Transition_with_witness.forget_witness transition)) in
              (p', transition.transactions)
          | `Remote pcd ->
              let%map p' = Protocol.step p (Protocol.New_state (State_with_witness.forget_witness pcd)) in
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
      Linear_pipe.transfer updated_state_ledger t.ledger_fetcher_transitions
        ~f:(fun {state ; transactions} -> (state.data.ledger_hash, transactions))
    end;
end


