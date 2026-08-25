open Core_kernel
open Async_kernel
open Mina_base
open Mina_transaction
module Ledger = Mina_ledger.Ledger

(** The stored shape: what the frontier writes to disk and passes around in its
    own diffs. Unversioned — a scan state reaches another node through the sync
    protocol, in verified fragments, so nothing untrusted parses this. *)
module Stored : sig
  type t

  include Binable.S with type t := t

  val hash : t -> Staged_ledger_hash.Aux_hash.t
end

type t

val hash : t -> Staged_ledger_hash.Aux_hash.t

module Transaction_with_witness : sig
  (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
  type t =
    { transaction_with_status : Mina_transaction.Transaction.t With_status.t
    ; state_hash : State_hash.t * State_body_hash.t
    ; statement : Transaction_snark.Statement.t
    ; init_stack : Pending_coinbase.Stack_versioned.t
    ; first_pass_ledger_witness : Mina_ledger.Sparse_ledger.t
    ; second_pass_ledger_witness : Mina_ledger.Sparse_ledger.t
    ; block_global_slot : Mina_numbers.Global_slot_since_genesis.t
    ; hash : Aux_hash.t
    }

  val create :
       transaction_with_status:Mina_transaction.Transaction.t With_status.t
    -> state_hash:State_hash.t * State_body_hash.t
    -> statement:Transaction_snark.Statement.t
    -> init_stack:Pending_coinbase.Stack_versioned.t
    -> first_pass_ledger_witness:Mina_ledger.Sparse_ledger.t
    -> second_pass_ledger_witness:Mina_ledger.Sparse_ledger.t
    -> block_global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> t
end

module Ledger_proof_with_hash : sig
  type t = (Ledger_proof.Cached.t, Aux_hash.t) With_hash.t

  val create : Ledger_proof.Cached.t -> t
end

module Available_job : sig
  type t
end

module Space_partition : sig
  type t = { first : int * int; second : (int * int) option } [@@deriving sexp]
end

module Job_view : sig
  type t [@@deriving sexp, to_yojson]
end

module Make_statement_scanner (Verifier : sig
  type t

  val verify :
       verifier:t
    -> Ledger_proof_with_hash.t list
    -> unit Or_error.t Deferred.Or_error.t
end) : sig
  val check_invariants :
       t
    -> verifier:Verifier.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> logger:Logger.t
    -> statement_check:
         [ `Full of State_hash.t -> Mina_state.Protocol_state.value Or_error.t
         | `Partial ]
    -> error_prefix:string
    -> last_proof_statement:Transaction_snark.Statement.t option
    -> registers_end:Mina_state.Registers.Value.t
    -> (unit, Error.t) Deferred.Result.t
end

val empty :
  constraint_constants:Genesis_constants.Constraint_constants.t -> unit -> t

val fill_work_and_enqueue_transactions :
     t
  -> logger:Logger.t
  -> Transaction_with_witness.t list
  -> Transaction_snark_work.t list
  -> (Ledger_proof.Cached.t option * t) Or_error.t

val latest_ledger_proof : t -> Ledger_proof.Cached.t option

(** Apply transactions coorresponding to the last emitted proof based on the
    two-pass system- first pass includes legacy transactions and zkapp payments
    and the second pass includes account updates. [ignore_incomplete] is to
    ignore the account updates that were not completed in a single scan state
    tree corresponding to a proof. Set this to true when applying transactions
    to get the snarked ledger corresponding to a proof.
    *)
val get_snarked_ledger_sync :
     ledger:Ledger.t
  -> get_protocol_state:
       (State_hash.t -> Mina_state.Protocol_state.Value.t Or_error.t)
  -> apply_first_pass:
       (   global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
        -> Ledger.t
        -> Transaction.t
        -> Ledger.Transaction_partially_applied.t Or_error.t )
  -> apply_second_pass:
       (   Ledger.t
        -> Ledger.Transaction_partially_applied.t
        -> Mina_transaction_logic.Transaction_applied.t Or_error.t )
  -> apply_first_pass_sparse_ledger:
       (   global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
        -> Mina_ledger.Sparse_ledger.t
        -> Mina_transaction.Transaction.t
        -> Mina_ledger.Sparse_ledger.T.Transaction_partially_applied.t
           Or_error.t )
  -> signature_kind:Mina_signature_kind.t
  -> t
  -> unit Or_error.t

val get_snarked_ledger_async :
     ?async_batch_size:int
  -> ledger:Ledger.t
  -> get_protocol_state:
       (State_hash.t -> Mina_state.Protocol_state.Value.t Or_error.t)
  -> apply_first_pass:
       (   global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
        -> Ledger.t
        -> Transaction.t
        -> Ledger.Transaction_partially_applied.t Or_error.t )
  -> apply_second_pass:
       (   Ledger.t
        -> Ledger.Transaction_partially_applied.t
        -> Mina_transaction_logic.Transaction_applied.t Or_error.t )
  -> apply_first_pass_sparse_ledger:
       (   global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
        -> Mina_ledger.Sparse_ledger.t
        -> Mina_transaction.Transaction.t
        -> Mina_ledger.Sparse_ledger.T.Transaction_partially_applied.t
           Or_error.t )
  -> signature_kind:Mina_signature_kind.t
  -> t
  -> unit Deferred.Or_error.t

(** Apply all the staged transactions to snarked ledger based on the
    two-pass system to obtain the staged ledger- first pass includes legacy
    transactions and zkapp payments and the second pass includes account
    updates.
    Returns the target first pass ledger hash after all the transactions have
    been applied
    *)
val get_staged_ledger_async :
     ?async_batch_size:int
  -> ledger:Ledger.t
  -> get_protocol_state:
       (State_hash.t -> Mina_state.Protocol_state.Value.t Or_error.t)
  -> apply_first_pass:
       (   global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
        -> Ledger.t
        -> Transaction.t
        -> Ledger.Transaction_partially_applied.t Or_error.t )
  -> apply_second_pass:
       (   Ledger.t
        -> Ledger.Transaction_partially_applied.t
        -> Mina_transaction_logic.Transaction_applied.t Or_error.t )
  -> apply_first_pass_sparse_ledger:
       (   global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
        -> Mina_ledger.Sparse_ledger.t
        -> Mina_transaction.Transaction.t
        -> Mina_ledger.Sparse_ledger.T.Transaction_partially_applied.t
           Or_error.t )
  -> signature_kind:Mina_signature_kind.t
  -> t
  -> [ `First_pass_ledger_hash of Ledger_hash.t ] Deferred.Or_error.t

val free_space : t -> int

(** Available space and the corresponding required work-count in one and/or two trees (if the slots to be occupied are in two different trees)*)
val partition_if_overflowing : t -> Space_partition.t

val statement_of_job : Available_job.t -> Transaction_snark.Statement.t option

val snark_job_list_json : t -> string

(** All the proof bundles *)
val all_work_statements_exn :
  t -> Transaction_snark.Statement.t One_or_two.t list

(** Required proof bundles for a certain number of slots *)
val required_work_pairs : t -> slots:int -> Available_job.t One_or_two.t list

(**K proof bundles*)
val k_work_pairs_for_new_diff : t -> k:int -> Available_job.t One_or_two.t list

(** All the proof bundles for 2**transaction_capacity_log2 slots that can be used up in one diff *)
val work_statements_for_new_diff :
  t -> Transaction_snark.Statement.t One_or_two.t list

(** True if the latest tree is full and transactions would be added on to a new tree *)
val next_on_new_tree : t -> bool

(**update scan state metrics*)
val update_metrics : t -> unit Or_error.t

(** Hashes of the protocol states required for proving transactions*)
val required_state_hashes : t -> State_hash.Set.t

(** Validate protocol states required for proving the transactions. Returns an association list of state_hash and the corresponding state*)
val check_required_protocol_states :
     t
  -> protocol_states:
       Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
  -> Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
     Or_error.t

(** All the proof bundles for snark workers*)
val all_work_pairs :
     t
  -> get_state:(State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
  -> ( Transaction_witness.t
     , Ledger_proof.Cached.t )
     Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list
     Or_error.t

val write_all_proofs_to_disk :
     signature_kind:Mina_signature_kind.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> Stored.t
  -> t

val read_all_proofs_from_disk : t -> Stored.t

(** Serving a scan state piece by piece, so that a bootstrapping node can fetch
    it in verifiable fragments rather than as one blob. The protocol itself is
    {!Parallel_scan_sync}; this wires it to the transaction scan state. *)
module Sync : sig
  (** The scan state being served, named before [Responder.t] shadows it. *)
  type nonrec scan_state = t

  module Address = Parallel_scan_sync.Address
  module Cursors = Parallel_scan_sync.Cursors
  module Band = Parallel_scan_sync.Band

  (** The digest that names a payload: [SHA256] of the bytes on the wire, which
      is how both payload types already hash themselves. A received payload is
      checked with this before anything tries to parse it.

      This is a payload digest, not the block's
      [Staged_ledger_hash.Aux_hash.t] — both are SHA256, but only the latter is
      what a manifest is checked against. *)
  val digest_of_bytes : string -> string

  (** What a syncing node fetches first: every payload named, the structure
      holding them committed to, and nothing trusted until it reproduces the
      block's staged ledger hash. *)
  module Manifest : sig
    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V1 : sig
        type t
      end
    end]

    type t = Stable.V1.t

    val aux_hash : t -> Staged_ledger_hash.Aux_hash.t

    (** The manifest also carries the ledger hash and pending coinbase, because
        the block commits to those together with the aux hash as one staged
        ledger hash — verifying only the aux hash would leave the other two for
        a peer to lie about. *)
    val staged_ledger_hash : t -> Staged_ledger_hash.t

    val ledger_hash : t -> Ledger_hash.t

    val pending_coinbase : t -> Pending_coinbase.t

    (** [verify t ~expected] recomputes the commitment from the manifest alone
        and compares it against the one in the block. *)
    val verify : t -> expected:Staged_ledger_hash.t -> unit Or_error.t
  end

  (** What one peer asks another for. *)
  module Query : sig
    type t =
      | Manifest of State_hash.t
      | Band of
          { scan_state : State_hash.t
          ; tree : string
          ; root : Address.t
          ; height : int
          }
      | Payloads of { scan_state : State_hash.t; digests : string array }
      | Protocol_states of State_hash.t
    [@@deriving sexp]

    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V1 : sig
        type nonrec t = t
      end
    end]

    (** The scan state a query is about. Every query names one, so any peer
        holding that root can answer it. *)
    val scan_state : t -> State_hash.t

    val max_payloads_per_query : int
  end

  module Answer : sig
    type t =
      | Manifest of Manifest.t
      | Band of Band.t
      | Payloads of (string * string) array
      | Protocol_states of Mina_state.Protocol_state.value array
    [@@deriving sexp]

    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V1 : sig
        type nonrec t = t
      end
    end]
  end

  (** A peer's side, built once per scan state and reused across requests. *)
  module Responder : sig
    type t

    val create :
         scan_state
      -> ledger_hash:Ledger_hash.t
      -> pending_coinbase:Pending_coinbase.t
      -> t

    val manifest : t -> Manifest.t

    (** The subtree rooted at [root] of the tree with digest [tree], truncated
        to [height] levels. Keyed by digest rather than position so that a peer
        whose forest has moved on can still serve a tree it holds. *)
    val band : t -> tree:string -> root:Address.t -> height:int -> Band.t option

    (** The [bin_prot] bytes of one payload, by digest. *)
    val payload_bytes : t -> digest:string -> string option

    (** Answer one query. *)
    val respond : t -> Query.t -> Answer.t option
  end

  (** Where a scan state sync has got to, for [mina client status]. A sync runs
      inside the bootstrap controller, which has no transition frontier to hang
      progress off the way catchup does, so the controller publishes here and
      the daemon's status reads it. *)
  module Progress : sig
    type t =
      { bands_outstanding : int; payloads_received : int; payloads_known : int }

    (** [None] clears it, and means no sync is running. *)
    val report : t option -> unit

    val get : unit -> t option

    (** As [(label, count)] pairs, the shape the daemon status renders. *)
    val to_entries : t -> (string * int) list
  end

  (** A syncing node's side: accumulates verified fragments and assembles a
      scan state once they are all in. *)
  module Builder : sig
    type t

    (** [create manifest ~expected ~band_height] checks [manifest] against the
        staged ledger hash in the block and opens a builder on it. This is the
        only point at which the chain is consulted; every later fragment is
        checked against something established here. *)
    val create :
         Manifest.t
      -> state_hash:State_hash.t
      -> expected:Staged_ledger_hash.t
      -> band_height:int
      -> t Or_error.t

    (** What to ask peers for next, in the form that goes on the wire. Bands
        come before payloads, because bands are what name payloads. *)
    val queries : t -> Query.t list

    (** Take an answer together with the query that asked for it; the pairing
        is what says which tree a band belongs to. *)
    val add_answer : t -> query:Query.t -> Answer.t -> unit Or_error.t

    val outstanding : t -> [ `Bands of int ] * [ `Payloads of int ]

    (** A snapshot for the daemon status. *)
    val progress : t -> Progress.t

    (** Assemble the serialised scan state, ready for
        {!write_all_proofs_to_disk}. Fails while anything is outstanding. *)
    val finish : t -> Stored.t Or_error.t
  end
end
