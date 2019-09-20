open Coda_base
open Coda_transition

type full

type lite

(** A node can be represented in two different formats.
 *  A full node representation is a breadcrumb, which
 *  contains both an external transition and a computed
 *  staged ledger (masked off of the node parent's
 *  staged ledger). A lite node representation is merely
 *  the external transition itself. The staged ledger
 *  can be recomputed if needed, though not cheaply.
 *  The purpose of the separation of these two formats
 *  is required due to the fact that a breadcrumb cannot
 *  be serialized with bin_io. Only the external transition
 *  can be serialized and persisted to disk. This node
 *  representation type is used to parameterize the diff
 *  type over which representation is being used so that
 *  the diff format can be shared between both the in memory
 *  transition frontier and the persistent transition frontier.
 *)
type 'repr node_representation =
  | Full : Breadcrumb.t -> full node_representation
  | Lite : External_transition.Validated.t -> lite node_representation

(** A transition frontier diff represents a single item
 *  of mutation that can be or has been performed on
 *  a transition frontier. Each diff is associated with
 *  a type parameter that reprsents a "diff mutant".
 *  A "diff mutant" is any information related to the
 *  correct application of a diff which is not encapsulated
 *  directly within the itself. This is used for computing
 *  the transition frontier incremental hash. For example,
 *  if some diff adds some new information, the diff itself
 *  would contain the information it's adding, but if the
 *  act of adding that information correctly to the transition
 *  frontier depends on some other state at the time the
 *  diff is applied, that state should be represented in mutant
 *  parameter for that diff.
 *)
type ('repr, 'mutant) t =
  | New_node : 'repr node_representation -> ('repr, unit) t
      (** A diff representing new nodes which are added to
   *  the transition frontier. This has no mutant as adding
   *  a node merely depends on its parent being in the
   *  transition frontier already. If the parent wasn't
   *  already in the transition frontier, attempting to
   *  process this diff would generate an error instead. *)
  | Root_transitioned : Root_data.Transition.t -> (_, State_hash.t) t
      (** A diff representing that the transition frontier root
   *  has been moved forward. The diff contains the state hash
   *  of the new root, as well as state hashes of all nodes that
   *  were garbage collected by this root change. Garbage is
   *  topologically sorted from oldest to youngest. The old root
   *  should not be included in the garbage since it is implicitly
   *  removed. The mutant for this diff is the state hash of the
   *  old root. This ensures that all transition frontiers agreed
   *  on the old roots value at the time of processing this diff.
   *)
  | Best_tip_changed : State_hash.t -> (_, State_hash.t) t
      (** A diff representing that there is a new best tip in
   *  the transition frontier. The mutant for this diff is
   *  the state hash of the old best tip. This ensures that
   *  all transition frontiers agreed on the old best tip
   *  pointer at the time of processing this diff.
   *)

type ('repr, 'mutant) diff = ('repr, 'mutant) t

val to_yojson : ('repr, 'mutant) t -> Yojson.Safe.json

val to_lite : (full, 'mutant) t -> (lite, 'mutant) t

module Lite : sig
  type 'mutant t = (lite, 'mutant) diff

  module E : sig
    type t = E : (lite, 'mutant) diff -> t [@@deriving bin_io]
  end
end

module Full : sig
  type 'mutant t = (full, 'mutant) diff

  module E : sig
    type t = E : (full, 'mutant) diff -> t

    val to_lite : t -> Lite.E.t
  end
end
