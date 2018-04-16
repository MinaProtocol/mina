open Core_kernel
open Async_kernel

module type Time_intf = sig
  type t

  val now : unit -> t
end

module type Hash_intf = sig
  type 'a t [@@deriving compare, hash, sexp, bin_io]
  val digest : 'a -> 'a t
end

module type Proof_intf = sig
  type input
  type t

  val verify : t -> input -> bool Deferred.t
end

module type Ledger_intf = sig
  type t [@@deriving sexp, compare, hash, bin_io]
  type valid_transaction

  val copy : t -> t
  val apply_transaction : t -> valid_transaction -> unit Or_error.t
end

module type Nonce_intf = sig
  type t

  val succ : t -> t
  val random : unit -> t
end

module type Transaction_intf = sig
  type t


  module With_valid_signature : sig
    type t
  end

  val check : t -> With_valid_signature.t option
  val forget : With_valid_signature.t -> t
end

module type Strength_intf = sig
  type t [@@deriving compare]
  type difficulty

  val ( < ) : t -> t -> bool
  val ( > ) : t -> t -> bool
  val ( = ) : t -> t -> bool
  val increase : t -> by:difficulty -> t
end

module type Difficulty_intf = sig
  type t
  type time
  type _ hash
  type nonce
  type state

  val next : t -> last:time -> this:time -> t

  val meets : t -> (state * nonce) hash -> bool
end

module type State_intf  = sig
  type 'a hash
  type transition
  type difficulty
  type strength
  type ledger
  type time

  type t =
    { next_difficulty      : difficulty
    ; previous_state_hash  : t hash
    ; ledger_hash          : ledger hash
    ; strength             : strength
    ; timestamp            : time
    }
  [@@deriving bin_io, fields]
end

module type Transition_intf  = sig
  type 'a hash
  type ledger
  type proof
  type nonce
  type time

  type t =
    { ledger_hash : ledger hash
    ; ledger_proof : proof
    ; timestamp : time
    ; nonce : nonce
    }
  [@@deriving fields]
end

module type Time_close_validator_intf = sig
  type time

  val validate : time -> bool
end

module type Machine_intf = sig
  type t
  type state
  type transition
  module Event : sig
    type t =
      | Found of transition
      | New_state of state
  end
  val current_state : t -> state

  val create : initial:state -> t
  val step : t -> transition -> t
  val drive : t ->
    scan:(init:t -> f:(t -> Event.t -> t Deferred.t) -> t Linear_pipe.Reader.t) ->
    t Linear_pipe.Reader.t
end

module type Block_state_transition_proof_intf = sig
  type state
  type proof
  type transition

  module Witness : sig
    type t =
      { old_state : state
      ; old_proof : proof
      ; transition : transition
      }
  end

  val prove_zk_state_valid : Witness.t -> new_state:state -> proof Deferred.t
end

module Proof_carrying_data = struct
  type ('a, 'b) t =
    { data : 'a
    ; proof : 'b
    }
  [@@deriving fields, bin_io]
end

module type Inputs_intf = sig
  module Time : Time_intf
  module Hash : Hash_intf
  module Transaction : Transaction_intf
  module Nonce : Nonce_intf

  module Ledger : Ledger_intf with type valid_transaction := Transaction.With_valid_signature.t
  module Ledger_proof : Proof_intf with type input = Ledger.t Hash.t * Ledger.t Hash.t

  module Transition : Transition_intf with type 'a hash := 'a Hash.t
                                       and type ledger := Ledger.t
                                       and type proof := Ledger_proof.t
                                       and type nonce := Nonce.t
                                       and type time := Time.t

  module Time_close_validator : Time_close_validator_intf with type time := Time.t

  module rec State : sig
    include State_intf with type 'a hash := 'a Hash.t
                        and type difficulty := Difficulty.t
                        and type strength := Strength.t
                        and type transition := Transition.t
                        and type ledger := Ledger.t
                        and type time := Time.t

    module Proof : Proof_intf with type input = t
  end and Difficulty : (Difficulty_intf
    with type time := Time.t
     and type 'a hash := 'a Hash.t
     and type nonce := Nonce.t
     and type state := State.t)
  and Strength : Strength_intf with type difficulty := Difficulty.t
end

module Make
  (Inputs : Inputs_intf)
  (* SNARK "zk_state_valid" proving that, for new_state:
    - old_proof verifies old_state (Induction hypothesis)
    - transition.ledger_proof verifies a valid sequence of transactions moved the ledger from old_state.ledger_hash to new_state.ledger_hash
    - new_state.timestamp is transition.timestamp
    - new_state.ledger_hash is transition.ledger_hash
    - new_state.timestamp is newer than old_state.timestamp
    - the "next difficulty" is computed correctly from (old_state.next_difficulty, old_state.timestamp, new_state.timestamp)
    - the strength is computed correctly from the old_state.next_difficulty and the old_state.strength
    - new_state.next_difficulty is "next difficulty"
    - new_state.previous_state_hash is a hash of old_state
    - hash(new_state||transition.nonce) meets old_state.next_difficulty
    as) meets old_state.next_difficulty
    *)
  (* TODO: Lift this out of the functor and inline it *)
  (Block_state_transition_proof : Block_state_transition_proof_intf with type state := Inputs.State.t
                                                                     and type proof := Inputs.State.Proof.t
                                                                     and type transition := Inputs.Transition.t)
  = struct
    open Inputs

    module Proof_carrying_state = struct
      type t = (State.t, State.Proof.t) Proof_carrying_data.t
    end

    module Event = struct
      type event =
        | Found of Transition.t
        | New_state of Proof_carrying_state.t
    end

    type t =
      { state : Proof_carrying_state.t }
    [@@deriving fields]

    let step' t (transition : Transition.t) : t Deferred.t =
      let state = t.state.data in
      let proof = t.state.proof in

      let next_difficulty =
        Difficulty.next
          state.next_difficulty
          ~last:state.timestamp
          ~this:transition.timestamp
      in
      let new_state : State.t =
        { next_difficulty
        ; previous_state_hash  = Hash.digest state
        ; ledger_hash          = transition.ledger_hash
        ; strength             = Strength.increase state.strength ~by:state.next_difficulty
        ; timestamp            = transition.timestamp
        }
      in

      let%map proof = Block_state_transition_proof.prove_zk_state_valid
        { old_state = state
        ; old_proof = proof
        ; transition
        }
        ~new_state
      in
      { state = { data = new_state ; proof} }

    let create ~initial : t =
      { state = initial
      }

    let check_state (old_pcd : Proof_carrying_state.t) (new_pcd : Proof_carrying_state.t)  =
      let new_strength = new_pcd.data.strength in
      let old_strength = old_pcd.data.strength in
      if Strength.(new_strength > old_strength) &&
          Time_close_validator.validate(new_pcd.data.timestamp) then
        State.Proof.verify new_pcd.proof new_pcd.data
      else
        return false

    let step (t : t) = function
      | Event.Found transition ->
          step' t transition
      | Event.New_state pcd ->
          match%map check_state t.state pcd with
          | true -> { state = pcd }
          | false -> t
  end
