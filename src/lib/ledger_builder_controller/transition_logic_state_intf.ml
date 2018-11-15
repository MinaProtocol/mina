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

  val apply_all : t -> Change.t list -> logger:Logger.t -> t
  (** Invariant: Changes must be applied to atomically result in a consistent state *)

  val create :
       consensus_local_state:consensus_local_state
    -> (tip, state_hash) With_hash.t
    -> t
end
