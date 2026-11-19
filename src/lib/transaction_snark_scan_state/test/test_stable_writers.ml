open Core
open Async

(** Run [f] once with an identity proof cache and once with an LMDB one. *)
let with_each_proof_cache ~f =
  f (Proof_cache_tag.create_identity_db ()) ;
  Thread_safe.block_on_async_exn (fun () ->
      Mina_stdlib_unix.File_system.with_temp_dir "stable_writers"
        ~f:(fun tmp_dir ->
          Proof_cache_tag.create_db ~logger:(Logger.null ()) tmp_dir
          >>| function
          | Ok proof_cache_db ->
              f proof_cache_db
          | Error _ ->
              failwith "failed to create proof cache db" ) )

let cached_ledger_proofs ~proof_cache_db =
  Quickcheck.random_value ~seed:(`Deterministic "stable_writers")
    (Quickcheck.Generator.list_with_length 3 Mina_state.Snarked_ledger_state.gen)
  |> List.map ~f:(fun statement ->
         Ledger_proof.create ~statement
           ~sok_digest:Mina_base.Sok_message.Digest.default
           ~proof:(Lazy.force Mina_base.Proof.transaction_dummy)
         |> Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db )

let%test_unit "Proof_cache_tag.bin_writer_stored writes the decoded proof's \
               serialization" =
  with_each_proof_cache ~f:(fun proof_cache_db ->
      List.iter (cached_ledger_proofs ~proof_cache_db) ~f:(fun cached ->
          let tag = Ledger_proof.Cached.underlying_proof cached in
          [%test_eq: string]
            (Bin_prot.Writer.to_string Proof_cache_tag.bin_writer_stored tag)
            (Binable.to_string
               (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
               (Proof_cache_tag.read_proof_from_disk tag) ) ) )

let%test_unit "Ledger_proof.Cached.bin_writer_stable writes the decoded \
               proof's serialization" =
  with_each_proof_cache ~f:(fun proof_cache_db ->
      List.iter (cached_ledger_proofs ~proof_cache_db) ~f:(fun cached ->
          [%test_eq: string]
            (Bin_prot.Writer.to_string Ledger_proof.Cached.bin_writer_stable
               cached )
            (Binable.to_string
               (module Ledger_proof.Stable.Latest)
               (Ledger_proof.Cached.read_proof_from_disk cached) ) ) )
