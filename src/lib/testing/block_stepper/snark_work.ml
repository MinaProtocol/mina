open Core
open Async
open Mina_base

let prove_dummy ~proof_cache_db:_ ~signature_kind:_ ~sok_digest:_ ~logger:_
    (module _ : Transaction_snark.S) spec =
  let statement = Snark_work_lib.Work.Single.Spec.statement spec in
  Deferred.Or_error.return
    (Ledger_proof.For_tests.Cached.mk_dummy_proof statement)

let prove_full ~proof_cache_db ~signature_kind ~sok_digest ~logger
    (module T : Transaction_snark.S)
    (spec :
      ( Transaction_witness.t
      , Ledger_proof.Cached.t )
      Snark_work_lib.Work.Single.Spec.t ) =
  let single_spec = Snark_work_lib.Spec.Single.read_all_proofs_from_disk spec in
  let open Deferred.Or_error.Let_syntax in
  let%map proof =
    Snark_work_proving.prove_from_stable_spec ~proof_cache_db ~signature_kind
      ~sok_digest ~logger
      (module T)
      single_spec
  in
  Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof

type provider =
  { prove_single :
         ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
      -> Ledger_proof.Cached.t Deferred.Or_error.t
  ; logger : Logger.t
  ; how : Monad_sequence.how
  }

let create_direct ~proof_level ~proof_cache_db ~signature_kind ~logger
    (module T : Transaction_snark.S) =
  let sok_digest = Sok_message.Digest.default in
  let prove_single =
    match (proof_level : Genesis_constants.Proof_level.t) with
    | Check | No_check ->
        prove_dummy ~proof_cache_db ~signature_kind ~sok_digest ~logger
          (module T)
    | Full ->
        prove_full ~proof_cache_db ~signature_kind ~sok_digest ~logger (module T)
  in
  (* We'd really like to use Parallel here, obviously. Even with the global
     lock in ocaml 4 it would at least let us schedule a lot of rust kimchi
     proof generation in parallel. The issue is that snarky's Run.Make creates
     a stateful module with a single mutable state ref in it. Thus you would
     need to create/modify .Make variants of the transaction snark modules all
     the way down to snarky, so that they could reinstantiate everything down
     to snarky itself.

     Alternatively, we could ditch the "imperative" interface on top of the
     snarky's internal Internal_Basic (a.k.a. Snark) interface, and just use
     the internal pure interface. I would argue that this is much more honest
     about what these functions are doing. This would require
     zkapp_command_logic.ml to be parametrized by monad, however, if we wanted
     to keep the same structure where we instantiate it twice for checked and
     unchecked proving. *)
  { prove_single; logger; how = `Sequential }

let create_parallel ~num_workers ~proof_level ~proof_cache_db ~signature_kind
    ~constraint_constants ~logger =
  [%log info] "Spawning %d snark work worker processes" num_workers ;
  let%map workers =
    Deferred.List.map (List.init num_workers ~f:Fn.id) ~how:`Parallel
      ~f:(fun i ->
        [%log info] "Spawning snark work worker %d/%d" (i + 1) num_workers ;
        Snark_work_worker.create ~logger ~proof_level ~constraint_constants
          ~signature_kind )
  in
  let workers = Array.of_list workers in
  let num_workers = Array.length workers in
  (* A throttle with worker indices as resources. Each worker can only
     run one proof at a time (snarky mutable state), and the throttle
     dynamically assigns items to the first available worker — no
     pre-assignment, no idle workers while items are waiting. *)
  let worker_pool =
    Throttle.create_with ~continue_on_error:true
      (Array.to_list (Array.init num_workers ~f:Fn.id))
  in
  let prove_single spec =
    let stable_spec =
      Snark_work_lib.Spec.Single.read_all_proofs_from_disk spec
    in
    [%log internal] "Snark_work_parallel_enqueue" ;
    Throttle.enqueue worker_pool (fun worker_idx ->
        [%log internal] "Snark_work_parallel_enqueue_done"
          ~metadata:[ ("worker", `Int worker_idx) ] ;
        [%log internal] "Snark_work_parallel_rpc"
          ~metadata:[ ("worker", `Int worker_idx) ] ;
        let open Deferred.Or_error.Let_syntax in
        let%map proof =
          Snark_work_worker.prove_single workers.(worker_idx) stable_spec
        in
        [%log internal] "Snark_work_parallel_rpc_done"
          ~metadata:[ ("worker", `Int worker_idx) ] ;
        Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof )
  in
  { prove_single; logger; how = `Parallel }

let compute provider ~fee ~prover_key work_specs =
  let logger = provider.logger in
  [%log info] "Computing %d snark work items"
    (List.sum (module Int) work_specs ~f:One_or_two.length) ;
  [%log internal] "Snark_work_compute"
    ~metadata:
      [ ( "snark_work_items"
        , `Int (List.sum (module Int) work_specs ~f:One_or_two.length) )
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let%map proved_work =
    Deferred.Or_error.List.map work_specs ~how:provider.how
      ~f:(fun one_or_two ->
        [%log internal] "Snark_work_bundle" ;
        let%map proofs =
          match one_or_two with
          | `One a ->
              let%map a' = provider.prove_single a in
              `One a'
          | `Two (a, b) ->
              (* Dispatch both items concurrently — no dependency between
                 sibling work items in the scan state. *)
              let da = provider.prove_single a in
              let db = provider.prove_single b in
              let%bind a' = da in
              let%map b' = db in
              `Two (a', b')
        in
        [%log internal] "Snark_work_bundle_done" ;
        let statement =
          One_or_two.map one_or_two ~f:Snark_work_lib.Work.Single.Spec.statement
        in
        ( statement
        , Transaction_snark_work.Checked.create_unsafe
            { fee; proofs; prover = prover_key } ) )
  in
  [%log internal] "Snark_work_compute_done" ;
  let table = Transaction_snark_work.Statement.Table.create () in
  List.iter proved_work ~f:(fun (stmt, work) ->
      Transaction_snark_work.Statement.Table.set table ~key:stmt ~data:work ) ;
  Transaction_snark_work.Statement.Table.find table
