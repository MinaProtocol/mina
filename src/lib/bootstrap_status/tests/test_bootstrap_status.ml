open Core
open Async
module Phase = Bootstrap_status.Phase
module Ledger = Bootstrap_status.Ledger
module Snapshot = Bootstrap_status.Snapshot

let phase =
  Alcotest.testable
    (Fmt.of_to_string (Fn.compose Sexp.to_string Phase.sexp_of_t))
    Phase.equal

let ledger =
  Alcotest.testable
    (Fmt.of_to_string (Fn.compose Sexp.to_string Ledger.sexp_of_t))
    Ledger.equal

let ledger_hash =
  Alcotest.testable
    (Fmt.of_to_string Mina_base.Ledger_hash.to_base58_check)
    Mina_base.Ledger_hash.equal

let hash_a = Mina_base.Ledger_hash.empty_hash

let hash_b = Mina_base.Ledger_hash.merge ~height:0 hash_a hash_a

let progress ~targets : Syncable_ledger.Progress.t =
  { targets
  ; target_set_at = None
  ; pending_child_hashes = 0
  ; pending_contents = 0
  ; synced = false
  ; answers_accepted = 0
  ; answers_ignored = 0
  ; answers_rejected = 0
  ; last_accepted_answer_at = None
  ; num_accounts = None
  ; accounts_settled = 0
  ; accounts_received = 0
  }

let ledger_sync_exn (snapshot : Snapshot.t) l =
  List.find_exn snapshot.ledger_syncs ~f:(fun (s : Snapshot.ledger_sync) ->
      Ledger.equal s.ledger l )

let run f = Thread_safe.block_on_async_exn f

let test_initial () =
  let ({ phase = p
       ; bootstrap_started_at
       ; bootstrap_attempts
       ; last_attempt_failure
       ; ledger_syncs
       ; _
       }
        : Snapshot.t ) =
    Bootstrap_status.snapshot (Bootstrap_status.create ())
  in
  Alcotest.check phase "phase" Starting p ;
  Alcotest.(check bool)
    "no bootstrap" true
    (Option.is_none bootstrap_started_at) ;
  Alcotest.(check int) "attempts" 0 bootstrap_attempts ;
  Alcotest.(check (option string)) "failure" None last_attempt_failure ;
  Alcotest.(check int) "ledger syncs" 0 (List.length ledger_syncs)

let test_set_phase () =
  let t = Bootstrap_status.create () in
  let before = (Bootstrap_status.snapshot t).phase_started_at in
  Bootstrap_status.set_phase t Syncing_root_ledger ;
  let snapshot = Bootstrap_status.snapshot t in
  Alcotest.check phase "phase" Syncing_root_ledger snapshot.phase ;
  Alcotest.(check bool)
    "started no earlier than before" true
    Time.(snapshot.phase_started_at >= before)

let test_bootstrap_attempts () =
  let t = Bootstrap_status.create () in
  Bootstrap_status.start_bootstrap t ;
  Bootstrap_status.start_bootstrap_attempt t ;
  Bootstrap_status.fail_bootstrap_attempt t ~reason:"no scan state" ;
  Bootstrap_status.start_bootstrap_attempt t ;
  let snapshot = Bootstrap_status.snapshot t in
  Alcotest.(check bool)
    "bootstrap started" true
    (Option.is_some snapshot.bootstrap_started_at) ;
  Alcotest.(check int) "attempts" 2 snapshot.bootstrap_attempts ;
  Alcotest.(check (option string))
    "failure" (Some "no scan state") snapshot.last_attempt_failure ;
  Bootstrap_status.start_bootstrap t ;
  let snapshot = Bootstrap_status.snapshot t in
  Alcotest.(check int) "attempts reset" 0 snapshot.bootstrap_attempts ;
  Alcotest.(check (option string))
    "failure reset" None snapshot.last_attempt_failure

let test_live_then_kept () =
  let t = Bootstrap_status.create () in
  let target = ref (Some hash_a) in
  let targets = ref 1 in
  let read () = ledger_sync_exn (Bootstrap_status.snapshot t) Root_snarked in
  run (fun () ->
      Bootstrap_status.with_ledger_sync t Root_snarked
        ~target:(fun () -> !target)
        ~progress:(fun () -> progress ~targets:!targets)
        ~f:(fun () ->
          Alcotest.(check bool) "active" true (read ()).active ;
          target := Some hash_b ;
          targets := 2 ;
          let sync = read () in
          Alcotest.(check (option ledger_hash))
            "live target" (Some hash_b) sync.target ;
          Alcotest.(check int) "live progress" 2 sync.progress.targets ;
          Deferred.unit ) ) ;
  target := None ;
  targets := 3 ;
  let sync = read () in
  Alcotest.(check bool) "inactive" false sync.active ;
  Alcotest.(check (option ledger_hash)) "kept target" (Some hash_b) sync.target ;
  Alcotest.(check int) "kept progress" 2 sync.progress.targets

let test_kept_when_f_raises () =
  let t = Bootstrap_status.create () in
  let result =
    run (fun () ->
        Monitor.try_with (fun () ->
            Bootstrap_status.with_ledger_sync t Staking_epoch
              ~target:(fun () -> Some hash_a)
              ~progress:(fun () -> progress ~targets:1)
              ~f:(fun () -> failwith "sync failed") ) )
  in
  Alcotest.(check bool) "raised" true (Result.is_error result) ;
  let sync = ledger_sync_exn (Bootstrap_status.snapshot t) Staking_epoch in
  Alcotest.(check bool) "inactive" false sync.active ;
  Alcotest.(check int) "kept progress" 1 sync.progress.targets

let test_replaced_and_ordered () =
  let t = Bootstrap_status.create () in
  let sync l ~targets =
    run (fun () ->
        Bootstrap_status.with_ledger_sync t l
          ~target:(fun () -> None)
          ~progress:(fun () -> progress ~targets)
          ~f:(fun () -> Deferred.unit) )
  in
  sync Next_epoch ~targets:1 ;
  sync Root_snarked ~targets:1 ;
  sync Next_epoch ~targets:2 ;
  let snapshot = Bootstrap_status.snapshot t in
  Alcotest.(check (list ledger))
    "one sync per ledger, in order"
    [ Root_snarked; Next_epoch ]
    (List.map snapshot.ledger_syncs ~f:(fun (s : Snapshot.ledger_sync) ->
         s.ledger ) ) ;
  Alcotest.(check int)
    "latest sync" 2 (ledger_sync_exn snapshot Next_epoch).progress.targets

let () =
  Alcotest.run "Bootstrap_status"
    [ ( "phases"
      , [ Alcotest.test_case "a new status has nothing to report" `Quick
            test_initial
        ; Alcotest.test_case "the phase and when it started are recorded" `Quick
            test_set_phase
        ; Alcotest.test_case
            "a new bootstrap forgets the previous one's attempts" `Quick
            test_bootstrap_attempts
        ] )
    ; ( "ledger syncs"
      , [ Alcotest.test_case "a sync is read live while it runs, and kept after"
            `Quick test_live_then_kept
        ; Alcotest.test_case "a sync is kept when it raises" `Quick
            test_kept_when_f_raises
        ; Alcotest.test_case "a ledger's latest sync replaces its earlier one"
            `Quick test_replaced_and_ordered
        ] )
    ]
