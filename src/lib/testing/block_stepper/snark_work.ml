open Core
open Async
open Mina_base

let prove_dummy ~proof_cache_db:_ ~signature_kind:_ ~sok_digest:_ ~logger:_
    (module _ : Transaction_snark.S) spec =
  let statement = Snark_work_lib.Work.Single.Spec.statement spec in
  Deferred.Or_error.return
    (Ledger_proof.For_tests.Cached.mk_dummy_proof statement)

let prove_non_zkapp ~sok_digest (module T : Transaction_snark.S) input
    (w : Transaction_witness.Stable.V2.t) valid_transaction =
  Deferred.Or_error.try_with ~here:[%here] (fun () ->
      T.of_non_zkapp_command_transaction ~statement:{ input with sok_digest }
        { Transaction_protocol_state.Poly.transaction = valid_transaction
        ; block_data = w.protocol_state_body
        ; global_slot = w.block_global_slot
        }
        ~init_stack:w.init_stack
        (unstage (Mina_ledger.Sparse_ledger.handler w.first_pass_ledger)) )

let prove_zkapp ~proof_cache_db ~signature_kind ~sok_digest ~logger
    (module T : Transaction_snark.S) input (w : Transaction_witness.Stable.V2.t)
    zkapp_command =
  let open Deferred.Or_error.Let_syntax in
  let%bind witnesses_specs_stmts =
    Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works
      ~m:(module T)
      ~input ~witness:w
      ~zkapp_command:
        (Zkapp_command.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
           zkapp_command )
    |> Result.map_error
         ~f:
           Work_partitioner.Snark_worker_shared.Failed_to_generate_inputs
           .error_of_t
    |> Deferred.return
  in
  (* Prove all segments *)
  let num_segments = Mina_stdlib.Nonempty_list.length witnesses_specs_stmts in
  [%log internal] "Snark_work_zkapp_prove"
    ~metadata:[ ("zkapp_work_segments", `Int num_segments) ] ;
  let%bind segment_proofs =
    Deferred.Or_error.List.map ~how:`Sequential
      (Mina_stdlib.Nonempty_list.to_list witnesses_specs_stmts)
      ~f:(fun (witness, segment_spec, statement) ->
        [%log internal] "Snark_work_zkapp_segment" ;
        let%map.Deferred.Or_error proof =
          Deferred.Or_error.try_with ~here:[%here] (fun () ->
              T.of_zkapp_command_segment_exn
                ~statement:{ statement with sok_digest }
                ~witness ~spec:segment_spec )
        in
        [%log internal] "Snark_work_zkapp_segment_done" ;
        proof )
  in
  (* Binary tree merge: pairwise rounds until one proof remains.
     Odd elements carried forward, matching the partitioner's
     consecutive-range merge strategy. *)
  let rec merge_rounds = function
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
        let%bind merged =
          Deferred.Or_error.List.map ~how:`Sequential pairs ~f:(fun (a, b) ->
              [%log internal] "Snark_work_zkapp_merge" ;
              let%map.Deferred.Or_error proof = T.merge a b ~sok_digest in
              [%log internal] "Snark_work_zkapp_merge_done" ;
              proof )
        in
        merge_rounds (merged @ leftover)
  in
  let%bind proof = merge_rounds segment_proofs in
  [%log internal] "Snark_work_zkapp_prove_done" ;
  (* Statement mismatch check, same as perform_single_untimed *)
  if
    not (Transaction_snark.Statement.equal (Ledger_proof.statement proof) input)
  then
    Deferred.Or_error.error_string
      "Zkapp_command transaction final statement mismatch"
  else Deferred.Or_error.return proof

let prove_full ~proof_cache_db ~signature_kind ~sok_digest ~logger
    (module T : Transaction_snark.S)
    (spec :
      ( Transaction_witness.t
      , Ledger_proof.Cached.t )
      Snark_work_lib.Work.Single.Spec.t ) =
  let open Deferred.Or_error.Let_syntax in
  let single_spec = Snark_work_lib.Spec.Single.read_all_proofs_from_disk spec in
  let%map proof =
    match single_spec with
    | Transition (input, w) -> (
        match w.transaction with
        | Mina_transaction.Transaction.Command (Zkapp_command zkapp_command) ->
            [%log internal] "Snark_work_zkapp_proof" ;
            let%map.Deferred.Or_error proof =
              prove_zkapp ~proof_cache_db ~signature_kind ~sok_digest ~logger
                (module T)
                input w zkapp_command
            in
            [%log internal] "Snark_work_zkapp_proof_done" ;
            proof
        | Command (Signed_command cmd) ->
            [%log internal] "Snark_work_base_proof" ;
            let%bind cmd =
              Deferred.return
              @@ Result.of_option
                   (Signed_command.check ~signature_kind cmd)
                   ~error:(Error.of_string "Command has an invalid signature")
            in
            let%map.Deferred.Or_error proof =
              prove_non_zkapp ~sok_digest
                (module T)
                input w (Command (Signed_command cmd))
            in
            [%log internal] "Snark_work_base_proof_done" ;
            proof
        | Fee_transfer ft ->
            [%log internal] "Snark_work_base_proof" ;
            let%map.Deferred.Or_error proof =
              prove_non_zkapp ~sok_digest (module T) input w (Fee_transfer ft)
            in
            [%log internal] "Snark_work_base_proof_done" ;
            proof
        | Coinbase cb ->
            [%log internal] "Snark_work_base_proof" ;
            let%map.Deferred.Or_error proof =
              prove_non_zkapp ~sok_digest (module T) input w (Coinbase cb)
            in
            [%log internal] "Snark_work_base_proof_done" ;
            proof )
    | Merge (_, proof1, proof2) ->
        [%log internal] "Snark_work_merge" ;
        let%map.Deferred.Or_error proof = T.merge proof1 proof2 ~sok_digest in
        [%log internal] "Snark_work_merge_done" ;
        proof
  in
  Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof

let compute ~proof_level ~proof_cache_db ~signature_kind ~logger ~fee
    ~prover_key (module T : Transaction_snark.S) work_specs =
  let sok_digest = Sok_message.Digest.default in
  [%log info] "Computing %d snark work items"
    (List.sum (module Int) work_specs ~f:One_or_two.length) ;
  let prove_single =
    match (proof_level : Genesis_constants.Proof_level.t) with
    | Check | No_check ->
        prove_dummy
    | Full ->
        prove_full
  in
  [%log internal] "Snark_work_compute"
    ~metadata:
      [ ( "snark_work_items"
        , `Int (List.sum (module Int) work_specs ~f:One_or_two.length) )
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let%map proved_work =
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
    Deferred.Or_error.List.map work_specs ~how:`Sequential ~f:(fun one_or_two ->
        [%log internal] "Snark_work_bundle" ;
        let%map proofs =
          One_or_two.Deferred_result.map one_or_two
            ~f:
              (prove_single ~proof_cache_db ~signature_kind ~sok_digest ~logger
                 (module T) )
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
