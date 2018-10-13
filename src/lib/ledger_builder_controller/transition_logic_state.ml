open Core_kernel

module type S = sig
  type consensus_local_state

  type external_transition

  type tip

  type state_hash

  module Transition_tree :
    Coda_lib.Ktree_intf
    with type elem := (external_transition, state_hash) With_hash.t

  type t

  val locked_tip : t -> (tip, state_hash) With_hash.t

  val longest_branch_tip : t -> (tip, state_hash) With_hash.t

  val ktree : t -> Transition_tree.t option

  val assert_state_valid : t -> unit

  module Change : sig
    type t =
      | Locked_tip of (tip, state_hash) With_hash.t
      | Longest_branch_tip of (tip, state_hash) With_hash.t
      | Ktree of Transition_tree.t
    [@@deriving sexp]
  end

  val apply_all : t -> Change.t list -> t
  (** Invariant: Changes must be applied to atomically result in a consistent state *)

  val create :
       consensus_local_state:consensus_local_state
    -> (tip, state_hash) With_hash.t
    -> t
end

module type Inputs_intf = sig
  module Frozen_ledger_hash : sig
    type t
  end

  module Security : sig
    val max_depth : [`Infinity | `Finite of int]
  end

  module Ledger : sig
    type t
  end

  module Ledger_builder : sig
    type t

    val ledger : t -> Ledger.t

    val snarked_ledger :
      t -> snarked_ledger_hash:Frozen_ledger_hash.t -> Ledger.t Or_error.t
  end

  module Blockchain_state : sig
    type value [@@deriving eq]

    val ledger_hash : value -> Frozen_ledger_hash.t
  end

  module Consensus_mechanism : sig
    module Local_state : sig
      type t
    end

    module Consensus_state : sig
      type value
    end

    module Protocol_state : sig
      type value

      val consensus_state : value -> Consensus_state.value

      val blockchain_state : value -> Blockchain_state.value
    end

    module External_transition : sig
      type t [@@deriving compare, sexp, bin_io]
    end

    val lock_transition :
         Consensus_state.value
      -> Consensus_state.value
      -> snarked_ledger:(unit -> Ledger.t Or_error.t)
      -> local_state:Local_state.t
      -> unit
  end

  module Tip : sig
    type t [@@deriving sexp]

    val protocol_state : t -> Consensus_mechanism.Protocol_state.value

    val ledger_builder : t -> Ledger_builder.t
  end

  module State_hash : sig
    type t [@@deriving compare, sexp, bin_io]
  end

  module Tip_ops : sig
    val assert_materialization_of :
         (Tip.t, State_hash.t) With_hash.t
      -> (Consensus_mechanism.External_transition.t, State_hash.t) With_hash.t
      -> unit
  end
end

module Make (Inputs : Inputs_intf) :
  S
  with type tip := Inputs.Tip.t
   and type consensus_local_state := Inputs.Consensus_mechanism.Local_state.t
   and type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type state_hash := Inputs.State_hash.t =
struct
  open Inputs
  open Consensus_mechanism

  module Transition_tree =
    Ktree.Make (struct
        type t = (External_transition.t, State_hash.t) With_hash.t
        [@@deriving compare, bin_io, sexp]
      end)
      (Security)

  module Change = struct
    type t =
      | Locked_tip of (Tip.t, State_hash.t) With_hash.t
      | Longest_branch_tip of (Tip.t, State_hash.t) With_hash.t
      | Ktree of Transition_tree.t
    [@@deriving sexp]
  end

  open Change

  (**
   *       /-----
   *      *
   *      ^\-------
   *      |      \----
   *      O          ^
   *                 |
   *                 O
   *
   *    The ktree represents the fork tree. We annotate
   *    the root and longest_branch with Tip.t's.
   *)
  type t =
    { locked_tip: (Tip.t, State_hash.t) With_hash.t
    ; longest_branch_tip: (Tip.t, State_hash.t) With_hash.t
    ; ktree: Transition_tree.t option
    ; consensus_local_state: Local_state.t
    (* TODO: This impl assumes we have the original Ouroboros assumption. In
       order to work with the Praos assumption we'll need to keep a linked
       list as well at the prefix of size (#blocks possible out of order)
     *)
    }
  [@@deriving fields]

  let apply t = function
    | Locked_tip locked_tip ->
        let consensus_state_of_tip tip =
          Tip.protocol_state tip |> Protocol_state.consensus_state
        in
        let old_tip = t.locked_tip.data in
        let new_tip = locked_tip.data in
        let snarked_ledger_hash =
          Tip.protocol_state old_tip |> Protocol_state.blockchain_state
          |> Blockchain_state.ledger_hash
        in
        lock_transition
          (consensus_state_of_tip old_tip)
          (consensus_state_of_tip new_tip)
          ~snarked_ledger:(fun () ->
            Ledger_builder.snarked_ledger
              (Tip.ledger_builder new_tip)
              ~snarked_ledger_hash )
          ~local_state:t.consensus_local_state ;
        {t with locked_tip}
    | Longest_branch_tip h -> {t with longest_branch_tip= h}
    | Ktree k -> {t with ktree= Some k}

  (* Invariant: state is consistent after change applications *)
  let assert_state_valid t =
    Debug_assert.debug_assert (fun () ->
        match t.ktree with
        | None -> ()
        | Some ktree ->
          match Transition_tree.longest_path ktree with
          | [] -> failwith "Impossible, paths are non-empty"
          | [x] ->
              Tip_ops.assert_materialization_of t.locked_tip x ;
              Tip_ops.assert_materialization_of t.longest_branch_tip x
          | x :: y :: rest ->
              let last = List.last_exn (y :: rest) in
              Tip_ops.assert_materialization_of t.locked_tip x ;
              Tip_ops.assert_materialization_of t.longest_branch_tip last )

  let apply_all t changes =
    assert_state_valid t ;
    let t' = List.fold changes ~init:t ~f:apply in
    assert_state_valid t' ; t'

  let create ~consensus_local_state genesis_heavy =
    { locked_tip= genesis_heavy
    ; longest_branch_tip= genesis_heavy
    ; ktree= None
    ; consensus_local_state }
end
