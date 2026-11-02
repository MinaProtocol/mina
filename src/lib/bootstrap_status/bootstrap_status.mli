(** What a node is doing to reach the network's chain: the step of
    initialisation or bootstrap it is in, and how far the ledger syncs it has
    run have got. The components doing that work record it here, and readers
    take a {!Snapshot.t}. *)

module Phase : sig
  type t =
    | Starting  (** Initialisation has not begun. *)
    | Waiting_for_genesis  (** The chain has not started yet. *)
    | Waiting_for_peers  (** Connecting to enough peers to begin. *)
    | Fetching_best_tip
        (** Asking peers for their best tip, while loading the transition
            frontier from disk. *)
    | Syncing_root_ledger  (** Bootstrap: syncing the root's snarked ledger. *)
    | Downloading_scan_state
        (** Bootstrap: downloading the root's scan state and pending
            coinbases. *)
    | Building_staged_ledger
        (** Bootstrap: building the root's staged ledger, which checks the scan
            state against the snarked ledger. *)
    | Syncing_epoch_ledgers  (** Syncing the staking and next epoch ledgers. *)
    | Loading_frontier
        (** Bootstrap: loading a transition frontier at the new root. *)
    | Participating  (** The transition frontier is running. *)
  [@@deriving equal, sexp, enumerate]
end

(** The ledgers a node syncs from its peers. *)
module Ledger : sig
  type t = Root_snarked | Staking_epoch | Next_epoch
  [@@deriving equal, sexp, enumerate]
end

module Snapshot : sig
  type ledger_sync =
    { ledger : Ledger.t
    ; target : Mina_base.Ledger_hash.t option
    ; active : bool  (** Whether the sync is still running. *)
    ; progress : Syncable_ledger.Progress.t
          (** For a sync that has ended, its progress when it ended. *)
    }

  type t =
    { phase : Phase.t
    ; phase_started_at : Core.Time.t
    ; bootstrap_started_at : Core.Time.t option
          (** When the current or most recent bootstrap started. *)
    ; bootstrap_attempts : int
          (** How many attempts the current or most recent bootstrap has
              started. *)
    ; last_attempt_failure : string option
          (** Why that bootstrap's last failed attempt failed. *)
    ; ledger_syncs : ledger_sync list
          (** The most recent sync of each ledger, in the order of
              {!Ledger.all}. *)
    }
end

type t

val create : unit -> t

val set_phase : t -> Phase.t -> unit

(** Record that a bootstrap has started, forgetting the attempts of any
    earlier one. *)
val start_bootstrap : t -> unit

val start_bootstrap_attempt : t -> unit

val fail_bootstrap_attempt : t -> reason:string -> unit

(** Run [f], reporting the sync of [ledger] read by [target] and [progress]
    while it runs, in place of any earlier sync of [ledger]. When [f]
    finishes, the sync's last progress is kept, and [target] and [progress]
    are no longer called. *)
val with_ledger_sync :
     t
  -> Ledger.t
  -> target:(unit -> Mina_base.Ledger_hash.t option)
  -> progress:(unit -> Syncable_ledger.Progress.t)
  -> f:(unit -> 'a Async_kernel.Deferred.t)
  -> 'a Async_kernel.Deferred.t

val snapshot : t -> Snapshot.t
