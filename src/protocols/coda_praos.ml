open Core_kernel
open Async_kernel

let coinbase_amount = Currency.Amount.of_int 10

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
  type t [@@deriving eq, bin_io, sexp]

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

module type Ledger_transition_intf = sig
  type t [@@deriving sexp]
end

module type Ledger_intf = sig
  type t [@@deriving sexp, compare, hash, bin_io]

  type ledger_hash

  type transition

  type key

  type amount

  val apply_transition : t -> transition -> unit Or_error.t

  val merkle_root : t -> ledger_hash

  val lookup : t -> key -> amount
end

module type Transaction_intf = sig
  type t [@@deriving sexp, compare, eq]

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp, compare, eq]
  end

  val check : t -> With_valid_signature.t option
end

module type Length_intf = sig
  type t [@@deriving sexp, compare, bin_io]

  val zero : t

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val increment : t -> t
end

module type Epoch_intf = sig
  type t [@@deriving sexp, compare, bin_io]

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val increment : t -> t
end

module type Slot_intf = sig
  type t [@@deriving sexp, compare, bin_io]

  type epoch

  val zero : t

  val of_int : int -> t

  val to_int : t -> int

  val ( < ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( >= ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( * ) : t -> t -> t

  val true_slot_position :
    slot:t -> inside_epoch:epoch -> epoch_slots:int -> Int64.t
  (** slot + (epoch_slots * inside_epoch) *)

  val increment : t -> t
end

module type Epoch_seed_intf = sig
  type t [@@deriving sexp, bin_io]

  val empty : t
end

module type State_intf = sig
  type state_hash

  type ledger_hash

  type seed

  type length

  type time

  type slot

  type epoch

  type t =
    { ledger_hash: ledger_hash
    ; epoch_seed: seed
    ; next_epoch_seed: seed
    ; next_epoch_ledger_hash: ledger_hash
    ; epoch_ledger_hash: ledger_hash
    ; length: length
    ; timestamp: time
    ; slot: slot
    ; epoch: epoch
    ; locked_hash: state_hash
    ; previous_state_hash: state_hash }
  [@@deriving sexp, bin_io, fields]

  val hash : t -> state_hash
end

module type Vrf_intf = sig
  type slot

  type epoch

  type amount

  type seed

  module Key : sig
    type t [@@deriving sexp, bin_io]
  end

  type t [@@deriving sexp, bin_io]

  val update_seed : seed -> t -> seed

  val verify :
       t
    -> slot:slot
    -> epoch:epoch
    -> key:Key.t
    -> amount:amount
    -> seed:seed
    -> bool Deferred.t
end

module type Transition_intf = sig
  type slot

  type epoch

  type vrf

  type key

  type ledger_transition

  type ledger

  type time

  type t =
    { slot: slot
    ; epoch: epoch
    ; vrf: vrf
    ; key: key
    ; timestamp: time
    ; ledger: ledger
    ; epoch_ledger: ledger
    ; ledger_transition: ledger_transition }
  [@@deriving fields]
end

module type Time_close_validator_intf = sig
  type time

  val validate : time -> bool
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

  module Transaction : Transaction_intf

  module Ledger_hash : Ledger_hash_intf

  module Ledger_proof : Proof_intf

  module Length : Length_intf

  module Epoch : Epoch_intf

  module Slot : Slot_intf with type epoch := Epoch.t

  module Epoch_seed : Epoch_seed_intf

  module Amount : sig
    type t
  end

  module Vrf :
    Vrf_intf
    with type seed := Epoch_seed.t
     and type slot := Slot.t
     and type epoch := Epoch.t
     and type amount := Amount.t

  module Ledger_transition : Ledger_transition_intf

  module Ledger :
    Ledger_intf
    with type ledger_hash := Ledger_hash.t
     and type amount := Amount.t
     and type key := Vrf.Key.t
     and type transition := Ledger_transition.t

  module Transition :
    Transition_intf
    with type slot := Slot.t
     and type epoch := Epoch.t
     and type vrf := Vrf.t
     and type key := Vrf.Key.t
     and type ledger_transition := Ledger_transition.t
     and type ledger := Ledger.t
     and type time := Time.t

  module Time_close_validator :
    Time_close_validator_intf with type time := Time.t

  module State_hash : State_hash_intf

  module State : sig
    include
      State_intf
      with type state_hash := State_hash.t
       and type ledger_hash := Ledger_hash.t
       and type seed := Epoch_seed.t
       and type length := Length.t
       and type time := Time.t
       and type slot := Slot.t
       and type epoch := Epoch.t

    module Proof : Proof_intf with type input = t
  end

  module Constants : sig
    val forkable_slot : Slot.t

    val epoch_slots : int
  end

  module Validator : sig
    val validate : State.t -> State.Proof.t -> bool Deferred.t
    (** This includes the State.Proof.t validation *)

    val prefix_of :
         candidate_locked:State_hash.t
      -> curr_locked:State_hash.t
      -> bool Deferred.t
    (** This invariant is only checked during tests, in production we just believe this happens *)
  end

  module State_history : sig
    val ancestors : State.t -> State.t Sequence.t
    (** Lazy sequence sorted by slot number descending *)
  end
end

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
    type event =
      | Found of Transition.t
      | Candidate_state of Proof_carrying_state.t
  end

  type t = {state: Proof_carrying_state.t} [@@deriving fields]

  let step' t (transition : Transition.t) : t Deferred.t =
    assert (
      Ledger_hash.equal
        (Ledger.merkle_root transition.ledger)
        t.state.data.ledger_hash ) ;
    let is_epoch_transition =
      Epoch.( > ) transition.epoch t.state.data.epoch
    in
    let epoch_seed =
      if is_epoch_transition then t.state.data.next_epoch_seed
      else t.state.data.epoch_seed
    in
    let next_epoch_seed =
      if is_epoch_transition then Epoch_seed.empty
      else if
        Slot.( >= ) transition.slot Constants.forkable_slot
        && Slot.(transition.slot < of_int 2 * Constants.forkable_slot)
      then Vrf.update_seed t.state.data.next_epoch_seed transition.vrf
      else t.state.data.next_epoch_seed
    in
    let next_epoch_ledger_hash =
      if is_epoch_transition then t.state.data.ledger_hash
      else t.state.data.next_epoch_ledger_hash
    in
    let epoch_ledger_hash =
      if is_epoch_transition then t.state.data.next_epoch_ledger_hash
      else t.state.data.epoch_ledger_hash
    in
    assert (
      Ledger_hash.equal
        (Ledger.merkle_root transition.epoch_ledger)
        epoch_ledger_hash ) ;
    let%bind b =
      Vrf.verify transition.vrf ~slot:transition.slot ~epoch:transition.epoch
        ~key:transition.key
        ~amount:(Ledger.lookup transition.epoch_ledger transition.key)
        ~seed:epoch_seed
    in
    if not b then failwith "VRF verification failed, but we created the VRF!" ;
    (* TODO: make sure we verify that ledger transitions are valid before this point *)
    let () =
      Ledger.apply_transition transition.ledger transition.ledger_transition
      |> Or_error.ok_exn
    in
    let ancestors : State.t Sequence.t =
      State_history.ancestors t.state.data
    in
    let newest_locked_ancestor =
      Sequence.find ancestors ~f:(fun a ->
          let open Int64 in
          let open Constants in
          Slot.true_slot_position ~slot:a.slot ~inside_epoch:a.epoch
            ~epoch_slots
          <= Slot.true_slot_position ~slot:transition.slot
               ~inside_epoch:transition.epoch ~epoch_slots
             - of_int (Slot.to_int forkable_slot) )
    in
    let locked_hash =
      newest_locked_ancestor
      |> Option.map ~f:(fun a -> State.hash a)
      |> Option.value ~default:t.state.data.locked_hash
    in
    let new_state =
      { State.epoch_seed
      ; timestamp= transition.timestamp
      ; next_epoch_seed
      ; next_epoch_ledger_hash
      ; epoch_ledger_hash
      ; ledger_hash= Ledger.merkle_root transition.ledger
      ; length= Length.increment t.state.data.length
      ; slot= transition.slot
      ; epoch= transition.epoch
      ; locked_hash
      ; previous_state_hash= State.hash t.state.data }
    in
    let%map proof =
      Block_state_transition_proof.prove_zk_state_valid
        {old_state= t.state.data; old_proof= t.state.proof; transition}
        ~new_state
    in
    {state= {data= new_state; proof}}

  let create ~initial : t = {state= initial}

  let select (current : Proof_carrying_state.t)
      (candidate : Proof_carrying_state.t) =
    let%bind validated = Validator.validate candidate.data candidate.proof in
    if not validated then return current
    else
      let%map prefixed =
        Validator.prefix_of ~candidate_locked:candidate.data.locked_hash
          ~curr_locked:current.data.locked_hash
      in
      if not prefixed then current
      else if Length.( > ) candidate.data.length current.data.length then
        candidate
      else current

  let step (t : t) = function
    | Event.Found transition -> step' t transition
    | Event.Candidate_state pcd ->
        let%map state = select t.state pcd in
        {state}
end
