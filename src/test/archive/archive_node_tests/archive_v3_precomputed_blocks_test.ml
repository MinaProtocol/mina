open Async
open Core
open Mina_automation

(**
 * Test that blocks of version 3, written between the Berkeley and Mesa hard
 * forks, reach the archive over the RPC for older versions, and are archived
 * under their Berkeley hashes.
 *)

(* Mainnet blocks of version 3, from the public block bucket, kept with the
   [mina_block] tests, with the hashes of their commands in the mainnet
   archive dump `mainnet-archive-dump-2026-10-01_0000`, in sequence order. *)
let v3_blocks =
  [ ( "src/lib/mina_block/tests/mainnet-545000-3NKc1wHM45SweeqiCZyNwmNJQnT4vjzJmeCYkG83YqXNgDPY57ZD.json"
    , "3NKc1wHM45SweeqiCZyNwmNJQnT4vjzJmeCYkG83YqXNgDPY57ZD"
    , [ "5Jv6nCoABLcAsszC4kyFvEy3g6PXS5htvfM9JrGv2vPGERE11N8H"
      ; "5JvGVjyaCDWmyrgw6G9GWYhNaHftMAqUNe6PX2k8wfYYVpGDydDC"
      ; "5JusDQDoH4GfZpD19eRNJmW4vbFwToR7ja12FEMtAbL9Q9dpDk6D"
      ; "5JuNyBCfHpx8XkCMA7ox4i5mVdRudPGHSy7CmYW9SFqp5QJz9rUb"
      ; "5JuEnYjGNm9f4w2MQ3rjhGc7QubsonB7taTUxCsPzv5QVTiCGRCM"
      ] )
  ; ( "src/lib/mina_block/tests/mainnet-520000-3NKuyY4iqW7mXThknMwwNiKst67uo6txzhWFJj3S9fk1jot8M7Qn.json"
    , "3NKuyY4iqW7mXThknMwwNiKst67uo6txzhWFJj3S9fk1jot8M7Qn"
    , [ "5Ju7ubyPvv3tDvZtHRRUovWckgDQVmQtas8FF4GwUNeYJsJnHTmj" ] )
  ]

(* The hashes of the commands the archive holds for the block with
   [state_hash], in sequence order, separated by commas. *)
let archived_command_hashes ~archive_uri state_hash =
  Psql.run_command ~connection:(Psql.Conn_str archive_uri)
    (sprintf
       "SELECT string_agg(hash, ',' ORDER BY sequence_no) FROM (SELECT \
        buc.sequence_no, uc.hash FROM blocks b JOIN blocks_user_commands buc \
        ON buc.block_id = b.id JOIN user_commands uc ON uc.id = \
        buc.user_command_id WHERE b.state_hash = '%s' UNION ALL SELECT \
        bzc.sequence_no, zc.hash FROM blocks b JOIN blocks_zkapp_commands bzc \
        ON bzc.block_id = b.id JOIN zkapp_commands zc ON zc.id = \
        bzc.zkapp_command_id WHERE b.state_hash = '%s') AS commands"
       state_hash state_hash )

(* The archive writes blocks after acknowledging them, so this retries
   rather than reading the database straight after sending. *)
let assert_archived_command_hashes ~archive_uri ~state_hash ~expected =
  let expected = String.concat ~sep:"," expected in
  let rec check ~attempts_left =
    let%bind actual =
      archived_command_hashes ~archive_uri state_hash
      >>| Or_error.ok_exn
    in
    if String.equal actual expected then Deferred.unit
    else if attempts_left <= 1 then
      failwithf "Block %s has command hashes %s in the archive, rather than %s"
        state_hash actual expected ()
    else
      let%bind () = after (sec 3.0) in
      check ~attempts_left:(attempts_left - 1)
  in
  check ~attempts_left:10

type t = Mina_automation_fixture.Archive.after_bootstrap

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let daemon = Daemon.default () in
  let archive_uri = test_data.archive.config.postgres_uri in
  Archive.Process.start_logging test_data.archive
    ~log_file:(test_data.temp_dir ^/ "v3_precomputed_blocks_test.log") ;
  match%bind
    Archive_healthcheck.wait_db_and_server_ready ~postgres_uri:archive_uri
      ~server_port:test_data.archive.config.server_port ()
  with
  | Ok () ->
      let%bind () =
        Daemon.archive_blocks_from_files daemon.executor
          ~archive_address:test_data.archive.config.server_port
          ~format:`Precomputed
          (List.map v3_blocks ~f:(fun (file, _, _) -> file))
      in
      let%map () =
        Deferred.List.iter v3_blocks ~f:(fun (_, state_hash, expected) ->
            assert_archived_command_hashes ~archive_uri ~state_hash ~expected )
      in
      Mina_automation_fixture.Intf.Passed
  | Error e ->
      Deferred.return (Mina_automation_fixture.Intf.Failed e)
