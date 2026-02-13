open Core
open Async
open Mina_base

let prove_single ~proof_level ~proof_cache_db ~signature_kind ~sok_digest
    ~logger (module T : Transaction_snark.S)
    (spec :
      ( Transaction_witness.t
      , Ledger_proof.Cached.t )
      Snark_work_lib.Work.Single.Spec.t ) =
  match (proof_level : Genesis_constants.Proof_level.t) with
  | Check | No_check ->
      let statement = Snark_work_lib.Work.Single.Spec.statement spec in
      Deferred.return (Ledger_proof.For_tests.Cached.mk_dummy_proof statement)
  | Full -> (
      let single_spec =
        Snark_work_lib.Spec.Single.read_all_proofs_from_disk spec
      in
      match single_spec with
      | Transition (input, w) -> (
          match w.transaction with
          | Mina_transaction.Transaction.Command (Zkapp_command zkapp_command)
            ->
              let witnesses_specs_stmts =
                Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works
                  ~m:(module T)
                  ~input ~witness:w
                  ~zkapp_command:
                    (Zkapp_command.write_all_proofs_to_disk ~signature_kind
                       ~proof_cache_db zkapp_command )
                |> Result.map_error
                     ~f:
                       Work_partitioner.Snark_worker_shared
                       .Failed_to_generate_inputs
                       .error_of_t
                |> Or_error.ok_exn
              in
              (* Prove all segments *)
              let%bind segment_proofs =
                Deferred.List.map ~how:`Sequential
                  (Mina_stdlib.Nonempty_list.to_list witnesses_specs_stmts)
                  ~f:(fun (witness, segment_spec, statement) ->
                    T.of_zkapp_command_segment_exn
                      ~statement:{ statement with sok_digest }
                      ~witness ~spec:segment_spec )
              in
              (* Binary tree merge: pairwise rounds until one proof remains.
                 Odd elements carried forward, matching the partitioner's
                 consecutive-range merge strategy. *)
              let rec merge_rounds = function
                | [] ->
                    failwith "empty segment proofs"
                | [ single ] ->
                    Deferred.return single
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
                      Deferred.List.map ~how:`Sequential pairs ~f:(fun (a, b) ->
                          T.merge a b ~sok_digest >>| Or_error.ok_exn )
                    in
                    merge_rounds (merged @ leftover)
              in
              let%map proof = merge_rounds segment_proofs in
              (* Statement mismatch check, same as perform_single_untimed *)
              if
                not
                  (Transaction_snark.Statement.equal
                     (Ledger_proof.statement proof)
                     input )
              then failwith "Zkapp_command transaction final statement mismatch" ;
              Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof
          | _ ->
              (* Non-zkapp transitions: delegate to worker *)
              let%map proof =
                Snark_worker.Impl.perform_single_untimed
                  ~m:(module T)
                  ~logger ~proof_cache_db ~single_spec ~signature_kind
                  ~sok_digest ()
                >>| Or_error.ok_exn
              in
              Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof )
      | Merge _ ->
          let%map proof =
            Snark_worker.Impl.perform_single_untimed
              ~m:(module T)
              ~logger ~proof_cache_db ~single_spec ~signature_kind ~sok_digest
              ()
            >>| Or_error.ok_exn
          in
          Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof )

let compute ~proof_level ~proof_cache_db ~signature_kind ~logger ~fee
    ~prover_key (module T : Transaction_snark.S) work_specs =
  let sok_digest = Sok_message.Digest.default in
  let%map proved_work =
    Deferred.List.map work_specs ~how:`Sequential ~f:(fun one_or_two ->
        let%map proofs =
          One_or_two.Deferred.map one_or_two ~f:(fun spec ->
              prove_single ~proof_level ~proof_cache_db ~signature_kind
                ~sok_digest ~logger
                (module T)
                spec )
        in
        let statement =
          One_or_two.map one_or_two ~f:Snark_work_lib.Work.Single.Spec.statement
        in
        ( statement
        , Transaction_snark_work.Checked.create_unsafe
            { fee; proofs; prover = prover_key } ) )
  in
  let table = Transaction_snark_work.Statement.Table.create () in
  List.iter proved_work ~f:(fun (stmt, work) ->
      Transaction_snark_work.Statement.Table.set table ~key:stmt ~data:work ) ;
  Transaction_snark_work.Statement.Table.find table
