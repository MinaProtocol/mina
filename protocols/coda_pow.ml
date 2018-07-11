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
  type t [@@deriving bin_io, eq, sexp]

  include Hashable.S_binable with type t := t
end

module type State_hash_intf = sig
  type t [@@deriving bin_io, sexp]

  include Hashable.S_binable with type t := t
end

module type Ledger_builder_hash_intf = sig
  type t [@@deriving bin_io, sexp, eq]

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

  type super_transaction

  type ledger_hash

  val create : unit -> t

  val copy : t -> t

  val merkle_root : t -> ledger_hash

  val apply_transaction : t -> valid_transaction -> unit Or_error.t

  val apply_super_transaction : t -> super_transaction -> unit Or_error.t

  val undo_super_transaction : t -> super_transaction -> unit Or_error.t
end

module type Snark_pool_proof_intf = sig
  module Statement : sig
    type t [@@deriving sexp, bin_io]
  end

  type t [@@deriving sexp, bin_io]
end

module type Transaction_intf = sig
  type t [@@deriving sexp, compare, eq]

  type fee

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp, compare, eq, bin_io]
  end

  val check : t -> With_valid_signature.t option

  val fee : t -> fee
  (*Fee excess*)
end

module type Public_key_intf = sig
  type t

  module Compressed : sig
    type t
  end
end

module type Fee_transfer_intf = sig
  type t [@@deriving sexp, compare, eq]

  type public_key

  type fee

  type single = public_key * fee

  val of_single_list : (public_key * fee) list -> t list
end

module type Fee_intf = sig
  module Signed : sig
    type t [@@deriving bin_io]
  end

  module Unsigned : sig
    type t [@@deriving bin_io]
  end
end

module type Super_transaction_intf = sig
  type valid_transaction

  type fee_transfer

  type unsigned_fee

  type t = Transaction of valid_transaction | Fee_transfer of fee_transfer
  [@@deriving sexp, compare, eq]

  val fee_excess : t -> unsigned_fee Or_error.t
end

module type Transaction_snark_intf = sig
  type ledger_hash

  type fee_excess

  type message

  type t [@@deriving sexp, bin_io]

  module Statement : sig
    type t =
      { source: ledger_hash
      ; target: ledger_hash
      ; fee_excess: fee_excess
      ; proof_type: [`Merge | `Base] }
    [@@deriving sexp, bin_io]
  end

  val verify : t -> Statement.t -> message:message -> bool Deferred.t
end

module type Completed_work_intf = sig
  type proof

  type statement

  type fee

  type public_key

  module Statement : sig
    type t = statement list
  end

  type t = {fee: fee; proofs: proof list; prover: public_key}
  [@@deriving sexp, bin_io]

  val proofs_length : int
end

module type Ledger_builder_diff_intf = sig
  type transaction

  type ledger_builder_hash

  type public_key

  type completed_work

  type t =
    { prev_hash: ledger_builder_hash
    ; completed_works: completed_work list
    ; transactions: transaction list
    ; creator: public_key }
  [@@deriving sexp, bin_io]
end

module type Ledger_builder_transition_intf = sig
  type ledger_builder

  type diff

  type t = {old: ledger_builder; diff: diff}
end

module type Ledger_builder_intf = sig
  type t [@@deriving sexp, bin_io]

  type diff

  type ledger_builder_hash

  type public_key

  type ledger

  type ledger_proof

  type transaction_with_valid_signature

  type statement

  type completed_work

  val ledger : t -> ledger

  val copy : t -> t

  val max_margin : int

  val hash : t -> ledger_builder_hash

  val margin : t -> int

  val create : ledger:ledger -> self:public_key -> t

  val apply : t -> diff -> ledger_proof option Deferred.Or_error.t

  (* This should memoize the snark verifications *)

  val create_diff :
       t
    -> transactions_by_fee:transaction_with_valid_signature Sequence.t
    -> get_completed_work:(statement -> completed_work option)
    -> diff
end

module type Nonce_intf = sig
  type t

  val succ : t -> t

  val random : unit -> t
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

  type ledger_builder_hash

  type nonce

  type pow

  type difficulty

  type strength

  type time

  type t =
    { next_difficulty: difficulty
    ; previous_state_hash: state_hash
    ; ledger_builder_hash: ledger_builder_hash
    ; ledger_hash: ledger_hash
    ; strength: strength
    ; timestamp: time }
  [@@deriving sexp, bin_io, fields]

  val hash : t -> state_hash

  val create_pow : t -> nonce -> pow Or_error.t
end

module type Transition_intf = sig
  type ledger_hash

  type proof

  type nonce

  type time

  type ledger_builder_transition

  type t =
    { ledger_hash: ledger_hash (* TODO: I believe this is unused. *)
    ; ledger_proof: proof
    ; ledger_builder_transition: ledger_builder_transition
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

  type ledger_builder_transition

  module Event : sig
    type e = Found of transition | New_state of state

    type t = e * ledger_builder_transition
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

  (*
Blockchain_snark ~old ~nonce ~ledger_snark ~ledger_hash ~timestamp ~new_hash
  Input:
    old : Blockchain.t
    old_snark : proof
    nonce : int
    work_snark : proof
    ledger_hash : Ledger_hash.t
    timestamp : Time.t
    new_hash : State_hash.t
  Witness:
    transition : Transition.t
  such that
    the old_snark verifies against old
    new = update_with_asserts(old, nonce, timestamp, ledger_hash)
    hash(new) = new_hash
    the work_snark verifies against the old.ledger_hash and new_ledger_hash
    new.timestamp > old.timestamp
    hash(new_hash||nonce) < target(old.next_difficulty)
  *)

  val prove_zk_state_valid : Witness.t -> new_state:state -> proof Deferred.t
end

module Proof_carrying_data = struct
  type ('a, 'b) t = {data: 'a; proof: 'b} [@@deriving sexp, fields, bin_io]
end

module type Inputs_intf = sig
  module Time : Time_intf

  module Public_key : Public_key_intf

  module Fee : Fee_intf

  module Transaction : Transaction_intf with type fee := Fee.Unsigned.t

  module Fee_transfer : Fee_transfer_intf

  module Super_transaction : Super_transaction_intf

  module Block_nonce : Nonce_intf

  module Ledger_hash : Ledger_hash_intf

  module Ledger :
    Ledger_intf
    with type valid_transaction := Transaction.With_valid_signature.t
     and type super_transaction := Super_transaction.t
     and type ledger_hash := Ledger_hash.t

  module Pow : Pow_intf

  module Difficulty :
    Difficulty_intf with type time := Time.t and type pow := Pow.t

  module Strength : Strength_intf with type difficulty := Difficulty.t

  module State_hash : State_hash_intf

  module Ledger_builder_hash : Ledger_builder_hash_intf

  (*
Bundle Snark:
   Input:
      l1 : Ledger_hash.t,
      l2 : Ledger_hash.t,
      fee_excess : Amount.Signed.t,
   Witness:
      t : Tagged_transaction.t
   such that
     applying [t] to ledger with merkle hash [l1] results in ledger with merkle hash [l2].

Merge Snark:
    Input:
      s1 : state
      s3 : state
      fee_excess_total : Amount.Signed.t
    Witness:
      s2 : state
      p12 : proof
      p23 : proof
      fee_excess12 : Amount.Signed.t
      fee_excess23 : Amount.Signed.t
    s.t.
      p12 verifies s1 -> s2 is a valid transition with fee_excess12
      p23 verifies s2 -> s3 is a valid transition with fee_excess23
      fee_excess_total = fee_excess12 + fee_excess23
  *)

  module Ledger_builder_diff :
    Ledger_builder_diff_intf with type transaction := Transaction.t

  module Time_close_validator :
    Time_close_validator_intf with type time := Time.t

  module Ledger_proof : Proof_intf

  module Completed_work :
    Completed_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof.input
     and type fee := Fee.Unsigned.t
     and type public_key := Public_key.Compressed.t

  module Ledger_builder :
    Ledger_builder_intf
    with type diff := Ledger_builder_diff.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type public_key := Public_key.Compressed.t
     and type ledger := Ledger.t
     and type ledger_proof := Ledger_proof.t
     and type transaction_with_valid_signature :=
                Transaction.With_valid_signature.t
     and type statement := Completed_work.Statement.t

  module Ledger_builder_transition :
    Ledger_builder_transition_intf
    with type diff := Ledger_builder_diff.t
     and type ledger_builder := Ledger_builder.t

  module Transition :
    Transition_intf
    with type ledger_hash := Ledger_hash.t
     and type proof := Ledger_proof.t
     and type nonce := Block_nonce.t
     and type time := Time.t
     and type ledger_builder_transition := Ledger_builder_transition.t

  module State : sig
    include State_intf
            with type ledger_hash := Ledger_hash.t
             and type state_hash := State_hash.t
             and type difficulty := Difficulty.t
             and type strength := Strength.t
             and type time := Time.t
             and type nonce := Block_nonce.t
             and type ledger_builder_hash := Ledger_builder_hash.t
             and type pow := Pow.t

    module Proof : Proof_intf with type input = t
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
    type t =
      | Found of Transition.t
      | New_state of Proof_carrying_state.t * Ledger_builder_transition.t
  end

  type t = {state: Proof_carrying_state.t}
  [@@deriving fields]

  let step' t (transition: Transition.t) : t Deferred.t =
    let state = t.state.data in
    let proof = t.state.proof in
    let {Ledger_builder_transition.old;diff} = transition.ledger_builder_transition in
    match%bind Ledger_builder.apply old diff with
    | Error e -> return t
    (* TODO: This proof should go somewhere! Also we mutated [old] so not clear
       if that's ok *)
    | Ok maybe_new_ledger ->
        let next_difficulty =
          Difficulty.next state.next_difficulty ~last:state.timestamp
            ~this:transition.timestamp
        in
        let new_state : State.t =
          { next_difficulty
          ; previous_state_hash= State.hash state
          ; ledger_builder_hash= Ledger_builder.hash old
          ; ledger_hash= Ledger.merkle_root (Ledger_builder.ledger old)
          ; strength=
              Strength.increase state.strength ~by:state.next_difficulty
          ; timestamp= transition.timestamp }
        in
        let%map proof =
          Block_state_transition_proof.prove_zk_state_valid
            {old_state= state; old_proof= proof; transition}
            ~new_state
        in
        {state= {data= new_state; proof}}

  let create ~state : t = {state}

  let check_state (old_pcd: Proof_carrying_state.t)
      (new_pcd: Proof_carrying_state.t)
      (ledger_builder_transition: Ledger_builder_transition.t) =
    let ledger_builder_valid () =
      let ledger_builder = ledger_builder_transition.old in
      match%map
        Ledger_builder.apply ledger_builder ledger_builder_transition.diff
      with
      | Error _ -> false
      | Ok maybe_new_ledger ->
          let new_ledger_hash =
            Option.value_map maybe_new_ledger ~default:old_pcd.data.ledger_hash
              ~f:(fun _proof ->
                Ledger.merkle_root (Ledger_builder.ledger ledger_builder) )
          in
          (* TODO soon: these checks are irrelevant and should be handled inside of
             Ledger_builder.apply.
          *)
          let margin = Ledger_builder.margin ledger_builder in
          Ledger_builder_hash.equal
            (Ledger_builder.hash ledger_builder)
            new_pcd.data.ledger_builder_hash
          && Int.( >= ) margin Ledger_builder.max_margin
          && Ledger_hash.equal new_ledger_hash new_pcd.data.ledger_hash
    in
    let new_strength = new_pcd.data.strength in
    let old_strength = old_pcd.data.strength in
    if
      Strength.(new_strength > old_strength)
      && Time_close_validator.validate new_pcd.data.timestamp
    then
      let%bind b = ledger_builder_valid () in
      if b then State.Proof.verify new_pcd.proof new_pcd.data else return false
    else return false

  let step (t: t) = function
    | Event.Found transition -> step' t transition
    | Event.New_state (pcd, ledger_builder_transition) ->
        match%map check_state t.state pcd ledger_builder_transition with
        | true -> {state= pcd}
        | false -> t
end
