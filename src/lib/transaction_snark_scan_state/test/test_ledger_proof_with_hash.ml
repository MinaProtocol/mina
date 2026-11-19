open Core
open Async
open Transaction_snark_scan_state

let check_hash_matches_decoded ~proof_cache_db =
  Quickcheck.test ~trials:5 Mina_state.Snarked_ledger_state.gen
    ~f:(fun statement ->
      let proof =
        Ledger_proof.create ~statement
          ~sok_digest:Mina_base.Sok_message.Digest.default
          ~proof:(Lazy.force Mina_base.Proof.transaction_dummy)
      in
      let cached =
        Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof
      in
      [%test_eq: Mina_base.Aux_hash.t]
        (Ledger_proof_with_hash.create cached).hash
        (Ledger_proof_with_hash.hash
           (Ledger_proof.Cached.read_proof_from_disk cached) ) )

let%test_unit "Ledger_proof_with_hash.create matches hashing the decoded proof \
               (identity cache)" =
  check_hash_matches_decoded
    ~proof_cache_db:(Proof_cache_tag.create_identity_db ())

let%test_unit "Ledger_proof_with_hash.create matches hashing the decoded proof \
               (LMDB cache)" =
  Thread_safe.block_on_async_exn (fun () ->
      Mina_stdlib_unix.File_system.with_temp_dir "ledger_proof_with_hash"
        ~f:(fun tmp_dir ->
          Proof_cache_tag.create_db ~logger:(Logger.null ()) tmp_dir
          >>| function
          | Ok proof_cache_db ->
              check_hash_matches_decoded ~proof_cache_db
          | Error _ ->
              failwith "failed to create proof cache db" ) )
