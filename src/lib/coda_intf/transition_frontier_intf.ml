open Core_kernel
open Async_kernel
open Pipe_lib
open Coda_base
open Coda_state

(** An extension to the transition frontier that provides a view onto the data
    other components can use. These are exposed through the broadcast pipes
    accessible by calling extension_pipes on a Transition_frontier.t. *)
module type Transition_frontier_extension_intf = sig
  (** Internal state of the extension. *)
  type t

  type breadcrumb

  type transition_frontier

  type transition_frontier_diff

  (** The view type we're emitting. *)
  type view

  val create : breadcrumb -> t * view

  (** Handle a transition frontier diff, and return the new version of the
        computed view, if it's updated. *)
  val handle_diffs :
    t -> transition_frontier -> transition_frontier_diff list -> view option
end

module type Transition_frontier_diff_intf = sig
  type breadcrumb

  type external_transition_validated

  type scan_state

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
    | Full : breadcrumb -> full node_representation
    | Lite :
        (external_transition_validated, State_hash.t) With_hash.t
        -> lite node_representation

  module Minimal_root_data : sig
    module Stable : sig
      module V1 : sig
        type t =
          { hash: State_hash.Stable.V1.t
          ; scan_state: scan_state
          ; pending_coinbase: Pending_coinbase.Stable.V1.t }
        [@@deriving bin_io, version]
      end

      module Latest = V1
    end

    type t = Stable.Latest.t
  end

  (** A root transition is a representation of the
   *  change that occurs in a transition frontier when the
   *  root is transitioned. It contains a pointer to the new
   *  root, as well as pointers to all the nodes which are removed
   *  by transitioning the root.
   *)
  module Root_transition : sig
    module Stable : sig
      module V1 : sig
        type t =
          { new_root: Minimal_root_data.Stable.V1.t
          ; garbage: State_hash.Stable.V1.t list }
        [@@deriving bin_io, version]
      end

      module Latest = V1
    end

    type t = Stable.Latest.t
  end

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
    | Root_transitioned : Root_transition.t -> (_, State_hash.t) t
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

  val key_to_yojson : ('repr, 'mutant) t -> Yojson.Safe.json

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
end

module type Transition_frontier_incremental_hash_intf = sig
  type 'mutant lite_diff

  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, yojson, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving eq]

  type transition = {source: t; target: t}

  val empty : t

  val to_string : t -> string

  val merge_diff : t -> 'mutant lite_diff -> 'mutant -> t
end

module type Broadcast_extension_intf = sig
  type t

  type view

  type breadcrumb

  type base_transition_frontier

  type diff

  val create : breadcrumb -> t Deferred.t

  val peek : t -> view

  val update : t -> base_transition_frontier -> diff list -> unit Deferred.t
end

module type Transition_frontier_extensions_intf = sig
  type breadcrumb

  type transition_frontier

  type transition_frontier_diff

  (* [new] TODO: add this back?
  module Snark_pool_refcount : sig
    module Work : sig
      type t = Transaction_snark.Statement.t list [@@deriving sexp, yojson]

      module Stable :
        sig
          module V1 : sig
            type t [@@deriving sexp, bin_io]

            include Hashable.S_binable with type t := t
          end
        end
        with type V1.t = t

      include Hashable.S with type t := t

      val gen : t Quickcheck.Generator.t
    end

    include
      Extension
      with type view = int * int Work.Table.t
       and type breadcrumb := breadcrumb
       and type base_transition_frontier := base_transition_frontier
       and type diff := diff
  end

  module Best_tip_diff : sig
    type view =
      { new_user_commands: User_command.t list
      ; removed_user_commands: User_command.t list }

    include
      Extension
      with type view := view
       and type breadcrumb := breadcrumb
       and type base_transition_frontier := base_transition_frontier
       and type diff := diff
  end
  *)

  module Identity :
    Transition_frontier_extension_intf
    with type view = transition_frontier_diff list
     and type breadcrumb := breadcrumb
     and type transition_frontier := transition_frontier
     and type transition_frontier_diff := transition_frontier_diff
end

(** The type of the view onto the changes to the current best tip. This type
    needs to be here to avoid dependency cycles. *)
module type Transition_frontier_breadcrumb_intf = sig
  type t [@@deriving sexp, eq, compare, to_yojson]

  type display =
    { state_hash: string
    ; blockchain_state: Blockchain_state.display
    ; consensus_state: Consensus.Data.Consensus_state.display
    ; parent: string }
  [@@deriving yojson]

  type staged_ledger

  type mostly_validated_external_transition

  type external_transition_validated

  type verifier

  val create :
       (external_transition_validated, State_hash.t) With_hash.t
    -> staged_ledger
    -> t

  (** The copied breadcrumb delegates to [Staged_ledger.copy], the other fields are already immutable *)
  val copy : t -> t

  val build :
       logger:Logger.t
    -> verifier:verifier
    -> trust_system:Trust_system.t
    -> parent:t
    -> transition:mostly_validated_external_transition
    -> sender:Envelope.Sender.t option
    -> ( t
       , [ `Invalid_staged_ledger_diff of Error.t
         | `Invalid_staged_ledger_hash of Error.t
         | `Fatal_error of exn ] )
       Result.t
       Deferred.t

  val transition_with_hash :
    t -> (external_transition_validated, State_hash.t) With_hash.t

  val staged_ledger : t -> staged_ledger

  val just_emitted_a_proof : t -> bool

  val hash : t -> int

  val external_transition : t -> external_transition_validated

  val state_hash : t -> State_hash.t

  val parent_hash : t -> State_hash.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val display : t -> display

  val name : t -> string

  val to_user_commands : t -> User_command.t list
end

module type Transition_frontier_base_intf = sig
  type mostly_validated_external_transition

  type external_transition_validated

  type transaction_snark_scan_state

  type staged_ledger

  type staged_ledger_diff

  type verifier

  type t [@@deriving eq]

  module Breadcrumb :
    Transition_frontier_breadcrumb_intf
    with type mostly_validated_external_transition :=
                mostly_validated_external_transition
     and type external_transition_validated := external_transition_validated
     and type staged_ledger := staged_ledger
     and type verifier := verifier

  module Diff :
    Transition_frontier_diff_intf
    with type breadcrumb := Breadcrumb.t
     and type external_transition_validated := external_transition_validated
     and type scan_state := transaction_snark_scan_state

  module Hash :
    Transition_frontier_incremental_hash_intf
    with type 'mutant lite_diff := 'mutant Diff.Lite.t

  module Root_identifier : sig
    module Stable : sig
      module V1 : sig
        type t = {state_hash: State_hash.t; frontier_hash: Hash.t}
        [@@deriving bin_io, yojson]
      end

      module Latest = V1
    end

    type t = Stable.Latest.t = {state_hash: State_hash.t; frontier_hash: Hash.t}
  end

  module Root_data : sig
    type t =
      { transition: (external_transition_validated, State_hash.t) With_hash.t
      ; staged_ledger: staged_ledger }

    val minimize : t -> Diff.Minimal_root_data.t
  end

  val find_exn : t -> State_hash.t -> Breadcrumb.t

  val get_root : t -> Breadcrumb.t option

  val get_root_exn : t -> Breadcrumb.t

  val logger : t -> Logger.t

  val max_length : int

  val consensus_local_state : t -> Consensus.Data.Local_state.t

  val all_breadcrumbs : t -> Breadcrumb.t list

  val all_user_commands : t -> User_command.Set.t

  val root : t -> Breadcrumb.t

  val previous_root : t -> Breadcrumb.t option

  val oldest_breadcrumb_in_history : t -> Breadcrumb.t option

  val root_length : t -> int

  val best_tip : t -> Breadcrumb.t

  val best_tip_path : t -> Breadcrumb.t list

  val path_map : t -> Breadcrumb.t -> f:(Breadcrumb.t -> 'a) -> 'a list

  val hash_path : t -> Breadcrumb.t -> State_hash.t list

  val find : t -> State_hash.t -> Breadcrumb.t option

  val successor_hashes : t -> State_hash.t -> State_hash.t list

  val successor_hashes_rec : t -> State_hash.t -> State_hash.t list

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val successors_rec : t -> Breadcrumb.t -> Breadcrumb.t list

  val common_ancestor : t -> Breadcrumb.t -> Breadcrumb.t -> State_hash.t

  val iter : t -> f:(Breadcrumb.t -> unit) -> unit

  val best_tip_path_length_exn : t -> int

  val shallow_copy_root_snarked_ledger : t -> Ledger.Mask.Attached.t

  val visualize_to_string : t -> string

  val visualize : filename:string -> t -> unit
end

module type Transition_frontier_creatable_intf = sig
  include Transition_frontier_base_intf

  val create :
       logger:Logger.t
    -> root_data:Root_data.t
    -> root_ledger:Ledger.Db.t
    -> base_hash:Hash.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> t
end

module type Transition_frontier_intf = sig
  include Transition_frontier_base_intf

  type 'a transaction_snark_work_statement_table

  module Persistent_root : sig
    type t

    val create : logger:Logger.t -> directory:string -> t

    module Instance : sig
      type t

      val snarked_ledger : t -> Ledger.Db.t
    end
  end

  module Persistent_frontier : sig
    type t

    val create : logger:Logger.t -> verifier:verifier -> directory:string -> t

    module Instance : sig
      type t
    end

    val with_instance_exn : t -> f:(Instance.t -> 'a) -> 'a Deferred.t

    val reset_database_exn : t -> root_data:Root_data.t -> unit Deferred.t
  end

  type config =
    { logger: Logger.t
    ; verifier: verifier
    ; consensus_local_state: Consensus.Data.Local_state.t }

  val load :
       ?retry_with_fresh_db:bool
    -> config
    -> persistent_root:Persistent_root.t
    -> persistent_frontier:Persistent_frontier.t
    -> ( t
       , [> `Failure of string
         | `Bootstrap_required
         | `Persistent_frontier_malformed ] )
       Deferred.Result.t

  (** Adds a breadcrumb to the transition_frontier. It will first compute diffs
      corresponding to the add breadcrumb mutation. Then, these diffs will be
      fed into different extensions in the transition_frontier and the
      extensions will be updated accordingly. The updates that occur is based
      on the diff and the past version of the transition_frontier before the
      mutation occurs. Afterwards, the diffs are applied to the
      transition_frontier that will conduct the actual mutation on the
      transition_frontier. Finally, the updates on the extensions will be
      written into their respective broadcast pipes. It is important that all
      the updates on the transition_frontier are synchronous to prevent data
      races in the protocol. Thus, the writes must occur last on this function. *)
  val add_breadcrumb_exn : t -> Breadcrumb.t -> unit Deferred.t

  val wait_for_transition : t -> State_hash.t -> unit Deferred.t

  val persistent_root : t -> Persistent_root.t

  val persistent_frontier : t -> Persistent_frontier.t

  val root_snarked_ledger : t -> Ledger.Db.t

  module Extensions :
    Transition_frontier_extensions_intf
    with type breadcrumb := Breadcrumb.t
     and type transition_frontier := t
    (* [new] TODO: extensions should probably take in full diffs, not lite ones *)
     and type transition_frontier_diff := Diff.Lite.E.t

  val snark_pool_refcount_pipe :
       t
    -> (int * int transaction_snark_work_statement_table)
       Pipe_lib.Broadcast_pipe.Reader.t

  type best_tip_diff =
    { new_user_commands: User_command.t list
    ; removed_user_commands: User_command.t list }

  val best_tip_diff_pipe : t -> best_tip_diff Pipe_lib.Broadcast_pipe.Reader.t

  val root_history_path_map :
    t -> State_hash.t -> f:(Breadcrumb.t -> 'a) -> 'a Non_empty_list.t option

  val find_in_root_history : t -> State_hash.t -> Breadcrumb.t option

  val close : t -> unit Deferred.t

  module For_tests : sig
    val root_snarked_ledger : t -> Ledger.Db.t

    val root_history_mem : t -> State_hash.t -> bool

    val root_history_is_empty : t -> bool

    val apply_diff : t -> Diff.Lite.E.t -> unit

    val identity_pipe : t -> Extensions.Identity.view Broadcast_pipe.Reader.t
  end
end
