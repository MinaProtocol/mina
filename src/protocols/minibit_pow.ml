open Core_kernel
open Async_kernel

module type Time_intf = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, bin_io]
    end
  end

  type t [@@deriving sexp]

  module Span : sig
    type t

    val of_time_span : Core_kernel.Time.Span.t -> t

    val ( < ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val ( <= ) : t -> t -> bool

    val ( = ) : t -> t -> bool
  end

  val diff : t -> t -> Span.t

  val now : unit -> t
end

module type Ledger_hash_intf = sig
  type t [@@deriving bin_io, sexp]

  include Hashable.S_binable with type t := t
end

module type State_hash_intf = sig
  type t [@@deriving bin_io, sexp]

  include Hashable.S_binable with type t := t
end

module type Proof_intf = sig
  type input

  type t

  val verify : t -> input -> bool Deferred.t
end

module type Ledger_intf = sig
  type t [@@deriving sexp, compare, hash, bin_io]

  type valid_transaction

  type ledger_hash

  val create : unit -> t

  val copy : t -> t

  val merkle_root : t -> ledger_hash

  val apply_transaction : t -> valid_transaction -> unit Or_error.t
end

module type Nonce_intf = sig
  type t

  val succ : t -> t

  val random : unit -> t
end

module type Public_key_intf = sig
  module Compressed : sig
    type t [@@deriving bin_io]
  end

  type t [@@deriving sexp, eq]
end

module type Transaction_intf = sig
  type t [@@deriving sexp, eq]

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp, eq]

    val compare : seed:string -> t -> t -> int
  end

  val check : t -> With_valid_signature.t option
end

module type Strength_intf = sig
  type t [@@deriving compare, bin_io]

  type difficulty

  val zero : t

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val increase : t -> by:difficulty -> t
end

module type Pow_intf = sig
  type t
end

module type Difficulty_intf = sig
  type t

  type time

  type pow

  val next : t -> last:time -> this:time -> t

  val meets : t -> pow -> bool
end

module type State_intf = sig
  type state_hash

  type ledger_hash

  type nonce

  type pow

  type difficulty

  type strength

  type time

  type t =
    { next_difficulty: difficulty
    ; previous_state_hash: state_hash
    ; ledger_hash: ledger_hash
    ; strength: strength
    ; timestamp: time }
  [@@deriving sexp, bin_io, fields]

  val hash : t -> state_hash

  val create_pow : t -> nonce -> pow Or_error.t
end

module type Transition_intf = sig
  type ledger_hash

  type ledger

  type proof

  type nonce

  type time

  type t =
    { ledger_hash: ledger_hash
    ; ledger_proof: proof
    ; timestamp: time
    ; nonce: nonce }
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
    type t = Found of transition | New_state of state
  end

  val current_state : t -> state

  val create : initial:state -> t

  val step : t -> transition -> t

  val drive :
       t
    -> scan:(   init:t
             -> f:(t -> Event.t -> t Deferred.t)
             -> t Linear_pipe.Reader.t)
    -> t Linear_pipe.Reader.t
end

module type Block_state_transition_proof_intf = sig
  type state

  type proof

  type transition

  module Witness : sig
    type t = {old_state: state; old_proof: proof; transition: transition}
  end

  val prove_zk_state_valid : Witness.t -> new_state:state -> proof Deferred.t
end

module Proof_carrying_data = struct
  type ('a, 'b) t = {data: 'a; proof: 'b} [@@deriving sexp, fields, bin_io]
end

module type Inputs_intf = sig
  module Time : Time_intf

  module Public_key : Public_key_intf

  module Transaction : Transaction_intf

  module Block_nonce : Nonce_intf

  module Ledger_hash : Ledger_hash_intf

  module Ledger_proof : Proof_intf

  module Ledger :
    Ledger_intf
    with type valid_transaction := Transaction.With_valid_signature.t
     and type ledger_hash := Ledger_hash.t

  module Transition :
    Transition_intf
    with type ledger_hash := Ledger_hash.t
     and type ledger := Ledger.t
     and type proof := Ledger_proof.t
     and type nonce := Block_nonce.t
     and type time := Time.t

  module Time_close_validator :
    Time_close_validator_intf with type time := Time.t

  module Pow : Pow_intf

  module Difficulty :
    Difficulty_intf with type time := Time.t and type pow := Pow.t

  module Strength : Strength_intf with type difficulty := Difficulty.t

  module State_hash : State_hash_intf

  module State : sig
    include
      State_intf
      with type ledger_hash := Ledger_hash.t
       and type state_hash := State_hash.t
       and type difficulty := Difficulty.t
       and type strength := Strength.t
       and type time := Time.t
       and type nonce := Block_nonce.t
       and type pow := Pow.t

    module Proof : Proof_intf with type input = t
  end
end

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
(* TODO: Lift block_state_transition_proof out of the functor and inline it *)
module Make
    (Inputs : Inputs_intf)
    (Block_state_transition_proof : Block_state_transition_proof_intf
                                    with type state := Inputs.State.t
                                     and type proof := Inputs.State.Proof.t
                                     and type transition := Inputs.Transition.t) =
struct
  open Inputs

  module Proof_carrying_state = struct
    type t = (State.t, State.Proof.t) Proof_carrying_data.t
  end

  module Event = struct
    type event = Found of Transition.t | New_state of Proof_carrying_state.t
  end

  type t = {state: Proof_carrying_state.t} [@@deriving fields]

  let step' t (transition : Transition.t) : t Deferred.t =
    let state = t.state.data in
    let proof = t.state.proof in
    let next_difficulty =
      Difficulty.next state.next_difficulty ~last:state.timestamp
        ~this:transition.timestamp
    in
    let new_state : State.t =
      { next_difficulty
      ; previous_state_hash= State.hash state
      ; ledger_hash= transition.ledger_hash
      ; strength= Strength.increase state.strength ~by:state.next_difficulty
      ; timestamp= transition.timestamp }
    in
    let%map proof =
      Block_state_transition_proof.prove_zk_state_valid
        {old_state= state; old_proof= proof; transition}
        ~new_state
    in
    {state= {data= new_state; proof}}

  let create ~initial : t = {state= initial}

  let check_state (old_pcd : Proof_carrying_state.t)
      (new_pcd : Proof_carrying_state.t) =
    let new_strength = new_pcd.data.strength in
    let old_strength = old_pcd.data.strength in
    if
      Strength.(new_strength > old_strength)
      && Time_close_validator.validate new_pcd.data.timestamp
    then State.Proof.verify new_pcd.proof new_pcd.data
    else return false

  let step (t : t) = function
    | Event.Found transition -> step' t transition
    | Event.New_state pcd -> (
        match%map check_state t.state pcd with
        | true -> {state= pcd}
        | false -> t )
end
