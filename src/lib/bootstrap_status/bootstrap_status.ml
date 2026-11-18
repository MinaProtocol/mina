open Core_kernel
open Async_kernel

module Phase = struct
  type t =
    | Starting
    | Waiting_for_genesis
    | Waiting_for_peers
    | Fetching_best_tip
    | Syncing_root_ledger
    | Downloading_scan_state
    | Building_staged_ledger
    | Syncing_epoch_ledgers
    | Loading_frontier
    | Participating
  [@@deriving equal, sexp, enumerate]
end

module Ledger = struct
  type t = Root_snarked | Staking_epoch | Next_epoch
  [@@deriving equal, sexp, enumerate]
end

module Snapshot = struct
  type ledger_sync =
    { ledger : Ledger.t
    ; target : Mina_base.Ledger_hash.t option
    ; active : bool
    ; progress : Syncable_ledger.Progress.t
    }

  type t =
    { phase : Phase.t
    ; phase_started_at : Core.Time.t
    ; bootstrap_started_at : Core.Time.t option
    ; bootstrap_attempts : int
    ; last_attempt_failure : string option
    ; ledger_syncs : ledger_sync list
    }
end

type ledger_sync =
  { mutable read :
      unit -> Mina_base.Ledger_hash.t option * Syncable_ledger.Progress.t
  ; mutable active : bool
  }

type t =
  { mutable phase : Phase.t
  ; mutable phase_started_at : Core.Time.t
  ; mutable bootstrap_started_at : Core.Time.t option
  ; mutable bootstrap_attempts : int
  ; mutable last_attempt_failure : string option
  ; mutable ledger_syncs : (Ledger.t * ledger_sync) list
  }

let create () =
  { phase = Starting
  ; phase_started_at = Core.Time.now ()
  ; bootstrap_started_at = None
  ; bootstrap_attempts = 0
  ; last_attempt_failure = None
  ; ledger_syncs = []
  }

let set_phase t phase =
  t.phase <- phase ;
  t.phase_started_at <- Core.Time.now ()

let start_bootstrap t =
  t.bootstrap_started_at <- Some (Core.Time.now ()) ;
  t.bootstrap_attempts <- 0 ;
  t.last_attempt_failure <- None

let start_bootstrap_attempt t = t.bootstrap_attempts <- t.bootstrap_attempts + 1

let fail_bootstrap_attempt t ~reason = t.last_attempt_failure <- Some reason

let with_ledger_sync t ledger ~target ~progress ~f =
  let sync = { read = (fun () -> (target (), progress ())); active = true } in
  t.ledger_syncs <-
    (ledger, sync)
    :: List.Assoc.remove t.ledger_syncs ledger ~equal:Ledger.equal ;
  Monitor.protect f ~finally:(fun () ->
      let last = sync.read () in
      sync.read <- (fun () -> last) ;
      sync.active <- false ;
      Deferred.unit )

let snapshot t : Snapshot.t =
  { phase = t.phase
  ; phase_started_at = t.phase_started_at
  ; bootstrap_started_at = t.bootstrap_started_at
  ; bootstrap_attempts = t.bootstrap_attempts
  ; last_attempt_failure = t.last_attempt_failure
  ; ledger_syncs =
      List.filter_map Ledger.all ~f:(fun ledger ->
          List.Assoc.find t.ledger_syncs ledger ~equal:Ledger.equal
          |> Option.map ~f:(fun sync ->
                 let target, progress = sync.read () in
                 { Snapshot.ledger; target; active = sync.active; progress } ) )
  }
