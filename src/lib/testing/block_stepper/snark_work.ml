open Core
open Async
open Mina_base

let prove_dummy ~proof_cache_db:_ ~signature_kind:_ ~sok_digest ~logger:_
    (module _ : Transaction_snark.S) spec =
  let statement = Snark_work_lib.Work.Single.Spec.statement spec in
  Deferred.Or_error.return
    (Ledger_proof.Cached.create ~statement ~sok_digest
       ~proof:(Lazy.force Proof.For_tests.transaction_dummy_tag) )

type provider =
  { prove_single :
         sok_digest:Sok_message.Digest.t
      -> ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
      -> Ledger_proof.Cached.t Deferred.Or_error.t
  ; logger : Logger.t
  ; how : Monad_sequence.how
  }

(* Local copy of segment extraction — avoids needing (module T : S) on the
   host. Identical logic to
   Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works but
   taking scalar parameters instead of a first-class module. *)
let extract_zkapp_segment_works ~signature_kind ~constraint_constants
    ~(input : Mina_state.Snarked_ledger_state.t)
    ~(witness : Transaction_witness.Stable.Latest.t)
    ~(zkapp_command : Zkapp_command.t) =
  let inputs =
    Or_error.try_with (fun () ->
        Transaction_snark.zkapp_command_witnesses_exn ~signature_kind
          ~constraint_constants ~global_slot:witness.block_global_slot
          ~state_body:witness.protocol_state_body
          ~fee_excess:Currency.Amount.Signed.zero
          [ ( `Pending_coinbase_init_stack witness.init_stack
            , `Pending_coinbase_of_statement
                { Transaction_snark.Pending_coinbase_stack_state.source =
                    input.source.pending_coinbase_stack
                ; target = input.target.pending_coinbase_stack
                }
            , `Sparse_ledger witness.first_pass_ledger
            , `Sparse_ledger witness.second_pass_ledger
            , `Connecting_ledger_hash input.connecting_ledger_left
            , zkapp_command )
          ]
        |> List.rev )
  in
  match inputs with
  | Error e ->
      Or_error.error_string (Error.to_string_mach e)
  | Ok [] ->
      Or_error.error_string "No witness generated"
  | Ok (first :: rest) ->
      Ok (Mina_stdlib.Nonempty_list.init first rest)

(* Binary tree merge: pairwise rounds until one proof remains.
   Odd elements are carried forward. Each round's merges are dispatched
   via ~how. *)
let rec merge_rounds proofs ~how ~dispatch_merge =
  match proofs with
  | [] ->
      Deferred.Or_error.error_string "empty segment proofs"
  | [ single ] ->
      Deferred.Or_error.return single
  | proofs ->
      let pairs, leftover =
        let rec go = function
          | a :: b :: rest ->
              let ps, lo = go rest in
              ((a, b) :: ps, lo)
          | rest ->
              ([], rest)
        in
        go proofs
      in
      let open Deferred.Or_error.Let_syntax in
      let%bind merged =
        Deferred.Or_error.List.map ~how pairs ~f:(fun (a, b) ->
            dispatch_merge a b )
      in
      merge_rounds (merged @ leftover) ~how ~dispatch_merge

let prove_single_with_prover ~prover ~sok_digest ~proof_cache_db ~signature_kind
    ~constraint_constants ~logger spec =
  let stable_spec = Snark_work_lib.Spec.Single.read_all_proofs_from_disk spec in
  let open Deferred.Or_error.Let_syntax in
  let%map proof =
    match stable_spec with
    | Transition (input, w) -> (
        let stmt_with_sok = { input with sok_digest } in
        match w.transaction with
        | Command (Zkapp_command zkapp_command) ->
            [%log internal] "Snark_work_zkapp_proof" ;
            let zkapp_cmd =
              Zkapp_command.write_all_proofs_to_disk ~signature_kind
                ~proof_cache_db zkapp_command
            in
            let%bind segments =
              extract_zkapp_segment_works ~signature_kind ~constraint_constants
                ~input ~witness:w ~zkapp_command:zkapp_cmd
              |> Deferred.return
            in
            let segment_list = Mina_stdlib.Nonempty_list.to_list segments in
            [%log internal] "Snark_work_zkapp_prove"
              ~metadata:
                [ ("zkapp_work_segments", `Int (List.length segment_list)) ] ;
            let%bind segment_proofs =
              Deferred.Or_error.List.map ~how:(Snark_work_prover.how prover)
                segment_list ~f:(fun (witness, seg_spec, stmt) ->
                  [%log internal] "Snark_work_zkapp_segment" ;
                  Snark_work_prover.prove_zkapp_segment prover
                    { statement = { stmt with sok_digest }
                    ; witness
                    ; spec = seg_spec
                    } )
            in
            let%bind proof =
              merge_rounds segment_proofs ~how:(Snark_work_prover.how prover)
                ~dispatch_merge:(fun p1 p2 ->
                  [%log internal] "Snark_work_zkapp_merge" ;
                  Snark_work_prover.prove_merge prover
                    { proof1 = p1; proof2 = p2; sok_digest } )
            in
            [%log internal] "Snark_work_zkapp_proof_done" ;
            if
              not
                (Transaction_snark.Statement.equal
                   (Ledger_proof.statement proof)
                   input )
            then
              Deferred.Or_error.error_string
                "Zkapp_command transaction final statement mismatch"
            else Deferred.Or_error.return proof
        | _ ->
            Snark_work_prover.prove_base prover
              { statement = stmt_with_sok; witness = w } )
    | Merge (_, p1, p2) ->
        Snark_work_prover.prove_merge prover
          { proof1 = p1; proof2 = p2; sok_digest }
  in
  Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof

let create_direct ~proof_level ~proof_cache_db ~signature_kind ~logger
    (module T : Transaction_snark.S) =
  let prove_single =
    match (proof_level : Genesis_constants.Proof_level.t) with
    | Check | No_check ->
        fun ~sok_digest ->
          prove_dummy ~proof_cache_db ~signature_kind ~sok_digest ~logger
            (module T)
    | Full ->
        let constraint_constants = T.constraint_constants in
        let prover = Snark_work_prover.make ~signature_kind (module T) in
        fun ~sok_digest ->
          prove_single_with_prover ~prover ~sok_digest ~proof_cache_db
            ~signature_kind ~constraint_constants ~logger
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
  (* Dispatch a single operation to the pool, return proof *)
  let dispatch_to_pool rpc_fn =
    Throttle.enqueue worker_pool (fun worker_idx ->
        [%log internal] "Snark_work_parallel_rpc"
          ~metadata:[ ("worker", `Int worker_idx) ] ;
        let open Deferred.Or_error.Let_syntax in
        let%map result = rpc_fn workers.(worker_idx) in
        [%log internal] "Snark_work_parallel_rpc_done"
          ~metadata:[ ("worker", `Int worker_idx) ] ;
        result )
  in
  let prover : Snark_work_prover.t =
    { prove_base =
        (fun { statement; witness } ->
          dispatch_to_pool (fun worker ->
              Snark_work_worker.prove_base worker statement witness ) )
    ; prove_zkapp_segment =
        (fun { statement; witness; spec } ->
          let witness_stable =
            Transaction_snark.Zkapp_command_segment.Witness
            .read_all_proofs_from_disk witness
          in
          dispatch_to_pool (fun worker ->
              Snark_work_worker.prove_zkapp_segment worker statement
                witness_stable spec ) )
    ; prove_merge =
        (fun { proof1; proof2; sok_digest } ->
          dispatch_to_pool (fun worker ->
              Snark_work_worker.prove_merge worker proof1 proof2 sok_digest ) )
    ; how = `Parallel
    }
  in
  let prove_single ~sok_digest =
    prove_single_with_prover ~prover ~sok_digest ~proof_cache_db ~signature_kind
      ~constraint_constants ~logger
  in
  { prove_single; logger; how = `Parallel }

let compute provider ~fee ~prover_key work_specs =
  let sok_digest = Sok_message.(digest (create ~fee ~prover:prover_key)) in
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
              let%map a' = provider.prove_single ~sok_digest a in
              `One a'
          | `Two (a, b) -> (
              match provider.how with
              | `Parallel | `Max_concurrent_jobs _ ->
                  (* Dispatch both items concurrently — no dependency between
                     sibling work items in the scan state. Safe because each
                     item goes to a separate worker process. *)
                  let da = provider.prove_single ~sok_digest a in
                  let db = provider.prove_single ~sok_digest b in
                  let%bind a' = da in
                  let%map b' = db in
                  `Two (a', b')
              | `Sequential ->
                  (* Must be sequential in-process: snarky has mutable state,
                     so two concurrent proofs would corrupt it. *)
                  let%bind a' = provider.prove_single ~sok_digest a in
                  let%map b' = provider.prove_single ~sok_digest b in
                  `Two (a', b') )
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
