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

module type Chain_state_hash_intf = sig
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

module type Chain_state_intf = sig
  type chain_state_hash

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
    ; ancestor_hashes: chain_state_hash list
    ; previous_chain_state_hash: chain_state_hash }
  [@@deriving sexp, bin_io, fields]

  val hash : t -> chain_state_hash
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
  type chain_state

  type proof

  type transition

  module Witness : sig
    type t = {old_chain_state: chain_state; old_proof: proof; transition: transition}
  end

  val prove_zk_state_valid : Witness.t -> new_chain_state:chain_state -> proof Deferred.t
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

  module Chain_state_hash : Chain_state_hash_intf

  module Chain_state : sig
    include Chain_state_intf
            with type chain_state_hash := Chain_state_hash.t
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
    val validate : Chain_state.t -> Chain_state.Proof.t -> bool Deferred.t
    (** This includes the Chain_state.Proof.t validation *)
  end
end

module Make
    (Inputs : Inputs_intf)
    (Block_state_transition_proof : Block_state_transition_proof_intf
                                    with type chain_state := Inputs.Chain_state.t
                                     and type proof := Inputs.Chain_state.Proof.t
                                     and type transition := Inputs.Transition.t) =
struct
  open Inputs

  module Proof_carrying_state = struct
    type t = (Chain_state.t, Chain_state.Proof.t) Proof_carrying_data.t
  end

  module Event = struct
    type event =
      | Found of Transition.t
      | Candidate_state of Proof_carrying_state.t
  end

  type t = {chain_state: Proof_carrying_state.t} [@@deriving fields]

  let apply_chain_state_transition t (transition: Transition.t) : t Deferred.t =
    let get_next_epoch_seed prev =
      if 
        Slot.(transition.slot  >= Constants.forkable_slot)
        && Slot.(transition.slot < of_int 2 * Constants.forkable_slot)
      then Vrf.update_seed prev transition.vrf
      else prev
    in
    let epoch_seed, 
        next_epoch_seed, 
        next_epoch_ledger_hash,
        epoch_ledger_hash 
      =
      if Epoch.(transition.epoch > t.chain_state.data.epoch) 
      then t.chain_state.data.next_epoch_seed, 
           get_next_epoch_seed Epoch_seed.empty,
           t.chain_state.data.ledger_hash,
           t.chain_state.data.next_epoch_ledger_hash
      else t.chain_state.data.epoch_seed, 
           get_next_epoch_seed t.chain_state.data.next_epoch_seed,
           t.chain_state.data.next_epoch_ledger_hash,
           t.chain_state.data.epoch_ledger_hash
    in
    let () =
      Ledger.apply_transition transition.ledger transition.ledger_transition
      |> Or_error.ok_exn
    in
    let ancestor_hashes = t.chain_state.data.ancestor_hashes in
    let ancestor_hashes = (Chain_state.hash t.chain_state.data)::ancestor_hashes in
    let ancestor_hashes = 
      if List.length ancestor_hashes > (Slot.to_int Constants.forkable_slot)
      then List.tl_exn ancestor_hashes
      else ancestor_hashes
    in
    let new_chain_state =
      { Chain_state.epoch_seed
      ; timestamp= transition.timestamp
      ; next_epoch_seed
      ; next_epoch_ledger_hash
      ; epoch_ledger_hash
      ; ledger_hash= Ledger.merkle_root transition.ledger
      ; length= Length.increment t.chain_state.data.length
      ; slot= transition.slot
      ; epoch= transition.epoch
      ; ancestor_hashes= ancestor_hashes
      ; previous_chain_state_hash= Chain_state.hash t.chain_state.data }
    in
    let%map proof =
      Block_state_transition_proof.prove_zk_state_valid
        {old_chain_state= t.chain_state.data; old_proof= t.chain_state.proof; transition}
        ~new_chain_state
    in
    {chain_state= {data= new_chain_state; proof}}

  let create ~initial : t = {chain_state= initial}

  let select 
      (current: Proof_carrying_state.t)
      (candidate: Proof_carrying_state.t) 
    =
    let any ls = List.fold ~init:false ~f:(||) ls in
    let hash_in_current a = 
      any (List.map current.data.ancestor_hashes ~f:(fun b -> b = a))
    in
    let cand_fork_before_checkpoint = 
      any (List.map candidate.data.ancestor_hashes ~f:hash_in_current)
    in
    let%map validated = Validator.validate candidate.data candidate.proof in
    if not validated || not cand_fork_before_checkpoint
    then current
    else
      if Length.(candidate.data.length > current.data.length) 
      then candidate
      else current

  let step (t: t) = function
    | Event.Found transition -> apply_chain_state_transition t transition
    | Event.Candidate_state pcd ->
        let%map chain_state = select t.chain_state pcd in
        {chain_state}
end
