open Core_kernel
open Async_kernel

module type Hash_intf = sig
  type 'a t [@@deriving compare, hash, sexp]

  val hash : 'a -> 'a t
end

module type Proof_intf = sig
  type input
  type t

  val verify : t -> input -> bool Deferred.t
end

module type Ledger_intf = sig
  type t
end

module type Body_intf  = sig
  type ledger
  type transaction
  type 'a hash
  type t =
    { ledger_hash : ledger hash
    ; transactions : transaction list
    }
end

module type Nonce_intf = sig
  type t
end

module type Transaction_intf = sig
  type t
end

module type Strength_intf = sig
  type t
  type difficulty

  val increase : t -> by:difficulty -> t
end

module type Difficulty_intf = sig
  type t

  val next : t -> last:Time.t -> this:Time.t -> t
end

module type Header_intf  = sig
  type 'a hash
  type nonce
  type strength
  type difficulty
  type body
  type t =
    { prev_timestamp : Time.t
    ; timestamp : Time.t
    ; length : int
    ; strength : strength
    ; difficulty : difficulty
    ; nonce : nonce
    ; prev_header_hash : t hash
    ; body_hash : body hash
    }
  [@@deriving fields]
end

module type Chain_state_intf  = sig
  type 'a hash
  type body
  type header
  type t =
    { body : body
    ; header : header
    ; header_hash : header hash
    }
  [@@deriving fields]
end

module type Chain_transition_intf  = sig
  type 'a hash
  type ledger
  type proof
  type nonce
  type transaction
  type t =
    { new_ledger_hash : ledger hash
    ; transactions : transaction list
    ; ledger_proof : proof
    ; new_timestamp : Time.t
    ; nonce : nonce
    }
end

module type Machine_intf = sig
  type t
  type state
  type transition
  type event =
    | Found of transition
    | New_state of state

  val current_state : t -> state

  val create : initial:state -> t
  val step : t -> transition -> t
  val drive : t ->
    scan:(init:t -> f:(t -> event -> t Deferred.t) -> t Linear_pipe.Reader.t) ->
    t Linear_pipe.Reader.t
end

module type Block_state_transition_proof_intf = sig
  type state
  type proof
  type transition

  type witness =
    { old_state : state
    ; old_proof : proof
    ; new_state : state
    ; transition : transition
    }
  (* SNARK "zk_state_valid" proving that, for new_state:
    - all old values came from a chain_state with valid proof
    - transition.ledger_proof proves a valid sequence of transactions moved the ledger from state.body.ledger_hash to new_ledger_hash 
    - prev_timestamp is the old state.header.timestamp
    - timestamp is a newer timestamp than the prev timestamp
    - length is one greater than the old length
    - a "current difficulty" is computed correctly from (most_recent_difficulty, timestamp, new_timestamp)
    - the most recent strength is computed correctly from the most_recent_strength and the "current difficulty"
    - most_recent_difficulty is current difficulty
    - body hash is a hash of the new body
    - prev_header_hash is the old state.header_hash
    - header_hash is a hash of the new header
    - header_hash meets current difficulty
    *)
  val prove_zk_state_valid : witness -> proof Deferred.t
end

module type Inputs_intf = sig
  module Hash : Hash_intf
  module Transaction : Transaction_intf
  module Nonce : Nonce_intf
  module Difficulty : Difficulty_intf
  module Strength : Strength_intf with type difficulty := Difficulty.t

  module Ledger : Ledger_intf
  module Ledger_proof : Proof_intf with type input = Ledger.t Hash.t

  module State : sig
    module Body : Body_intf with type ledger := Ledger.t
                             and type transaction := Transaction.t
                             and type 'a hash := 'a Hash.t
    module Header : Header_intf with type 'a hash := 'a Hash.t
                                 and type nonce := Nonce.t
                                 and type strength := Strength.t
                                 and type difficulty := Difficulty.t
                                 and type body := Body.t

    include Chain_state_intf with type 'a hash := 'a Hash.t
                              and type body := Body.t
                              and type header := Header.t

    module Proof : Proof_intf with type input = t
  end

  module Transition : Chain_transition_intf with type 'a hash := 'a Hash.t
                                       and type ledger := Ledger.t
                                       and type proof := Ledger_proof.t
                                       and type transaction := Transaction.t
                                       and type nonce := Nonce.t
end

module Make
  (Inputs : Inputs_intf)
  (* TODO: Lift this out of the functor and inline it *)
  (Block_state_transition_proof : Block_state_transition_proof_intf with type state := Inputs.State.t
                                                                     and type proof := Inputs.State.Proof.t
                                                                     and type transition := Inputs.Transition.t)
  = struct
    open Inputs

    type event =
      | Found of Transition.t
      | New_state of State.t * State.Proof.t
    type t =
      { state : State.t * State.Proof.t
      }
    [@@deriving fields]

    let step' t (transition : Transition.t) : t Deferred.t =
      let header =
        t.state |> fst |> State.header
      in
      let new_difficulty =
        Difficulty.next
          header.difficulty
          ~last:header.timestamp
          ~this:transition.new_timestamp
      in
      let new_body : State.Body.t =
        { ledger_hash = transition.new_ledger_hash
        ; transactions = transition.transactions
        }
      in
      let new_header : State.Header.t =
        { prev_timestamp = header.timestamp
        ; timestamp = transition.new_timestamp
        ; length = header.length + 1
        ; strength = Strength.increase header.strength ~by:new_difficulty
        ; difficulty = new_difficulty
        ; nonce = transition.nonce
        ; prev_header_hash = t.state |> fst |> State.header_hash
        ; body_hash = Hash.hash new_body
        }
      in
      let new_state : State.t =
        { body = new_body
        ; header = new_header
        ; header_hash = Hash.hash new_header
        }
      in
      let%map proof = Block_state_transition_proof.prove_zk_state_valid
        { old_state = t.state |> fst
        ; old_proof = t.state |> snd
        ; new_state
        ; transition
        }
      in
      { state = (new_state, proof) }

    let create ~initial : t =
      { state = initial
      }

    let check_state (old_state, old_proof) (new_state, new_proof) =
      let new_strength = new_state.State.header.strength in
      let old_strength = old_state.State.header.strength in
      if Strength.(new_strength > old_strength) then
        State.Proof.verify new_proof new_state
      else
        return false

    let step (t : t) = function
      | Found transition ->
          step' t transition
      | New_state (state, proof) ->
          match%map check_state t.state (state, proof) with
          | true -> { state = (state, proof) }
          | false -> t
  end
