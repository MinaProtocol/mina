(** A parallel scan state: a forest of full binary trees over which work is
    folded incrementally.

    Data enters at the leaves and results are merged upwards, so that a block's
    worth of transactions can be added while the proofs for earlier ones are
    still outstanding. See [scan_state.md] for the shape of the forest and the
    constants that govern it.

    The state itself is abstract. Its trees are held flat, its nodes carry
    digests maintained as the forest fills, and both of those are invariants
    rather than API: a caller that could reach a tree's arrays could put the
    forest out of step with the commitment {!hash} computes over it. What a
    caller may do is add to it, take work from it, fold over it, and turn it
    into a form that can be stored or synced. *)

open Core

module Job_status : sig
  type t = Todo | Done [@@deriving equal, sexp]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving equal, sexp, bin_io, version]
    end

    module Latest = V1
  end

  val to_string : t -> string
end

(** A leaf. [Full] carries the datum a worker turns into a proof. *)
module Base_node : sig
  type 'base t = Empty | Full of { job : 'base; status : Job_status.t }
  [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type nonrec 'base t = 'base t [@@deriving sexp, bin_io, version]
    end

    module Latest = V1
  end
end

(** An interior node. [Part] holds the left result while the right is still
    outstanding; [Full] is ready to be merged. *)
module Merge_node : sig
  type 'merge t =
    | Empty
    | Part of 'merge
    | Full of { left : 'merge; right : 'merge }
  [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type nonrec 'merge t = 'merge t [@@deriving sexp, bin_io, version]
    end

    module Latest = V1
  end
end

(** A job offered to a worker: a datum to prove, or a pair of results to merge. *)
module Available_job : sig
  type ('merge, 'base) t = Base of 'base | Merge of 'merge * 'merge
  [@@deriving sexp]
end

(** A node paired with its position, for callers that report on the forest
    rather than work it. *)
module Job_view : sig
  module Node : sig
    type 'a t =
      | Base_empty
      | Base_full of { job : 'a; status : Job_status.t }
      | Merge_empty
      | Merge_part of 'a
      | Merge_full of { left : 'a; right : 'a }
    [@@deriving sexp]
  end

  type 'a t = { position : int; value : 'a Node.t } [@@deriving sexp]
end

(** Counts for one tree. Setting any gauge from these is the caller's business;
    the scan state reports numbers and knows nothing of Prometheus. *)
module Tree_metrics : sig
  type t =
    { available_space : int; base_jobs_todo : int; merge_jobs_todo : int }
  [@@deriving compare, equal, sexp]
end

(** How a block's worth of data divides between the head tree and the next,
    when the head cannot hold all of it. *)
module Space_partition : sig
  type t = { first : int * int; second : (int * int) option } [@@deriving sexp]
end

module Hash : sig
  (** Transparent: a digest is a digest, and the sync protocol works in raw
      strings on the wire. Nothing is protected by hiding it. *)
  type t = Digestif.SHA256.t

  val equal : t -> t -> bool

  val to_raw_string : t -> string

  val of_raw_string : string -> t
end

(** How to digest the payloads a caller stores in the forest.

    The scan state commits to its contents without knowing what they are, so
    the caller supplies this once and every digest the structure maintains is
    derived through it. *)
module Payload_digest : sig
  type ('merge, 'base) t = { merge : 'merge -> string; base : 'base -> string }
end

(** One tree of the forest. Abstract for the same reason the forest is. *)
module Tree : sig
  type ('merge, 'base) t

  (** The tree's digest: the root of the Merkle tree over its nodes. *)
  val digest : ('merge, 'base) t -> Hash.t

  (** The index a node at [level] and [index] within that level occupies, in
      the heap order the digests are laid out in. *)
  val slot : level:int -> index:int -> int
end

type ('merge, 'base) t [@@deriving sexp]

(** An empty forest. [max_base_jobs] is [2^transaction_capacity_log_2]. *)
val empty : max_base_jobs:int -> delay:int -> ('merge, 'base) t

(** Add a block's [data] and the [completed_jobs] paying for it.

    Fails rather than truncating: the caller is expected to have asked
    {!free_space} and {!jobs_for_next_update} what would be accepted. *)
val update :
     ('merge, 'base) t
  -> payload_digest:('merge, 'base) Payload_digest.t
  -> data:'base list
  -> completed_jobs:'merge list
  -> (('merge * 'base list) option * ('merge, 'base) t) Or_error.t

(** A commitment to the whole forest: the Merkle root over its trees.

    Maintained as the forest changes rather than recomputed, so this is cheap
    and does not walk anything. *)
val hash : ('merge, 'base) t -> Hash.t

(** Every job the forest is currently offering, oldest tree first. *)
val all_jobs : ('merge, 'base) t -> ('merge, 'base) Available_job.t list list

(** The jobs a caller must complete to add a full block. *)
val jobs_for_next_update :
  ('merge, 'base) t -> ('merge, 'base) Available_job.t list list

(** As {!jobs_for_next_update}, for a block filling only [slots] of them. *)
val jobs_for_slots :
  ('merge, 'base) t -> slots:int -> ('merge, 'base) Available_job.t list list

(** How many data a block may add. *)
val free_space : ('merge, 'base) t -> int

(** The most recent emitted result and the data it covers, if the forest has
    emitted one. *)
val last_emitted_value : ('merge, 'base) t -> ('merge * 'base list) option

(** Whether the next datum starts a new tree. *)
val next_on_new_tree : ('merge, 'base) t -> bool

(** Every datum still awaiting a proof, oldest tree first. *)
val pending_data : ('merge, 'base) t -> 'base list list

(** The forest's trees, newest first. A tree is opaque: what a caller can do
    with one is ask for its {!Tree.digest}. *)
val trees : ('merge, 'base) t -> ('merge, 'base) Tree.t list

(** Per-tree counts, oldest first. *)
val metrics : ('merge, 'base) t -> Tree_metrics.t list

(** Every node of the forest with its position, for reporting. *)
val job_views :
     ('merge, 'base) t
  -> f_merge:('merge -> 'a)
  -> f_base:('base -> 'a)
  -> 'a Job_view.t list list

(** How the next block's data divides across trees. *)
val partition_if_overflowing : ('merge, 'base) t -> Space_partition.t

(** Change the representation of the payloads, leaving the structure alone.

    [f_merge] and [f_base] must preserve payload digests: the digests cached
    throughout the forest are carried over untouched, so a function that
    changed one would leave the state committing to something it no longer
    holds. *)
val map :
     ('merge, 'base) t
  -> f_merge:('merge -> 'merge_2)
  -> f_base:('base -> 'base_2)
  -> ('merge_2, 'base_2) t

(** The forest with every payload replaced by its digest.

    This is what a syncing node needs before it can fetch anything: it names
    every payload and commits to the structure holding them, and it is
    {!map} at a different payload type. *)
val skeleton :
     ('merge, 'base) t
  -> payload_digest:('merge, 'base) Payload_digest.t
  -> (string, string) t

(** The payload digest of a skeleton, whose payloads {e are} digests. *)
val identity_digest : (string, string) Payload_digest.t

(** Recompute every digest from the payloads, rather than trusting those
    carried in. Used to check a forest that arrived from elsewhere. *)
val rebuilt :
     ('merge, 'base) t
  -> payload_digest:('merge, 'base) Payload_digest.t
  -> ('merge, 'base) t

(** Fold over every node, oldest tree first and, within a tree, root downwards
    then left to right. *)
val fold_chronological :
     ('merge, 'base) t
  -> init:'acc
  -> f_merge:('acc -> 'merge Merge_node.t -> 'acc)
  -> f_base:('acc -> 'base Base_node.t -> 'acc)
  -> 'acc

(** {!fold_chronological} in a monad, stopping early.

    Exists because verifying a forest of statements cannot hold the runtime for
    the duration. *)
module Make_foldable (M : Monad.S) : sig
  val fold_chronological_until :
       ('merge, 'base) t
    -> init:'acc
    -> f_merge:
         ('acc -> 'merge Merge_node.t -> ('acc, 'stop) Continue_or_stop.t M.t)
    -> f_base:('acc -> 'base Base_node.t -> ('acc, 'stop) Continue_or_stop.t M.t)
    -> finish:('acc -> 'stop M.t)
    -> 'stop M.t
end

(** The stored shape of a forest: what it looks like written down.

    Carries the digests rather than recomputing them on load, so {!of_wire}
    trusts what it is given — which is why this is the frontier's own
    persistence and not what crosses the network. A forest reaching a node from
    a peer arrives through the sync protocol, in fragments checked against a
    root the block already commits to. *)
module Wire : sig
  type ('merge, 'base) t [@@deriving sexp, bin_io]
end

val to_wire : ('merge, 'base) t -> ('merge, 'base) Wire.t

val of_wire :
     ('merge, 'base) Wire.t
  -> payload_digest:('merge, 'base) Payload_digest.t
  -> ('merge, 'base) t

(** The representation itself, for the synchronisation protocol.

    The sync protocol cuts fragments out of a forest and checks them against a
    root, which it cannot do without seeing how the forest is laid out. It is
    part of this structure's implementation that happens to live in another
    library, because a library takes its own name as its main module and this
    one cannot re-export something that depends on it.

    Nothing else should use this. Reaching a tree's arrays is enough to put the
    forest out of step with the commitment {!hash} computes over it. *)
module Private : sig
  (** Digest a list of fields, length-prefixed so that the encoding is
      unambiguous. Every digest the structure maintains goes through this. *)
  val digest_fields : string list -> Hash.t

  (** The digest of the last emitted result, as {!hash} commits to it. *)
  val digest_of_acc :
       payload_digest:('merge, 'base) Payload_digest.t
    -> ('merge * 'base list) option
    -> Hash.t

  val trees : ('merge, 'base) t -> ('merge, 'base) Tree.t list

  (** Assemble a forest from trees fetched elsewhere. The digest of [acc] is
      computed here; the tree digests are the caller's, and are checked against
      the root the block commits to rather than here. *)
  val create :
       trees:('merge, 'base) Tree.t list
    -> acc:('merge * 'base list) option
    -> payload_digest:('merge, 'base) Payload_digest.t
    -> max_base_jobs:int
    -> delay:int
    -> ('merge, 'base) t

  val acc : ('merge, 'base) t -> ('merge * 'base list) option

  val max_base_jobs : ('merge, 'base) t -> int

  val delay : ('merge, 'base) t -> int

  module Tree : sig
    type ('merge, 'base) t = ('merge, 'base) Tree.t

    val digest : ('merge, 'base) t -> Hash.t

    val slot : level:int -> index:int -> int

    val depth : ('merge, 'base) t -> int

    val filled : ('merge, 'base) t -> int

    val level : ('merge, 'base) t -> int

    val proved : ('merge, 'base) t -> int

    val bases : ('merge, 'base) t -> 'base Base_node.t array

    val merges : ('merge, 'base) t -> 'merge Merge_node.t array

    val digests : ('merge, 'base) t -> Hash.t array

    (** Assemble a tree from nodes fetched elsewhere. The digests are not
        checked here: {!rebuilt} recomputes them, and the caller checks the
        result against the root the block commits to. *)
    val create :
         merges:'merge Merge_node.t array
      -> bases:'base Base_node.t array
      -> digests:Hash.t array
      -> filled:int
      -> level:int
      -> proved:int
      -> ('merge, 'base) t

    val empty_digests : depth:int -> Hash.t array

    val digest_of_base :
      payload_digest:(_, 'base) Payload_digest.t -> 'base Base_node.t -> Hash.t

    val digest_of_merge :
         payload_digest:('merge, _) Payload_digest.t
      -> left:Hash.t
      -> right:Hash.t
      -> 'merge Merge_node.t
      -> Hash.t

    val rebuilt :
         ('merge, 'base) t
      -> payload_digest:('merge, 'base) Payload_digest.t
      -> ('merge, 'base) t
  end
end
