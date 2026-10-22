open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive

(**
 * Mainnet block 565083 sets the token symbol of an account to the single byte
 * 0xff, which is not UTF-8; block 565084 touches that account again. A running
 * archive must store both blocks, sent unchanged by a mock daemon, with the
 * symbol byte for byte.
 *)

let blocks =
  List.map
    [ "mainnet-565083-3NLSAECx1Z9wsk7EWNjtf8LZp4fyHq2ruffw1f8SBU9MTwYAHV6T.json"
    ; "mainnet-565084-3NK4rMyPyvhanvYUCp2WRtGRTPEozxC2LMCBzhnXGm4sJJtj6cRx.json"
    ] ~f:(fun file -> "src/test/archive/archive_node_tests/test_data" ^/ file)

let account = "B62qjoWP2dCbr8z1Zt9XRhYsKJaDr66kNTJKGh9KKUbQz4hfphMduEZ"

(* an editor or a re-encode that turns the raw byte into valid UTF-8 would make
   this test pass on a broken archive *)
let assert_raw_byte file =
  let%map raw = Reader.file_contents file in
  if not (String.is_substring raw ~substring:"\"token_symbol\":\"\xff\"") then
    failwithf "%s does not hold the raw 0xff token symbol" file ()

type t = Mina_automation_fixture.Archive.after_bootstrap

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let daemon = Daemon.default () in
  let archive_uri = test_data.archive.config.postgres_uri in
  let%bind () = Deferred.List.iter blocks ~f:assert_raw_byte in
  let log_file = test_data.temp_dir ^/ "non_utf8_token_symbol_test.log" in
  Archive.Process.start_logging test_data.archive ~log_file ;
  match%bind
    Archive_healthcheck.wait_db_and_server_ready ~postgres_uri:archive_uri
      ~server_port:test_data.archive.config.server_port ()
  with
  | Ok () ->
      let%bind () =
        Daemon.archive_blocks_from_files daemon.executor
          ~archive_address:test_data.archive.config.server_port
          ~format:`Precomputed blocks
      in
      let%bind () =
        Archive_precomputed_blocks_test.assert_archived_blocks ~archive_uri
          ~expected:(List.length blocks)
      in
      let%map stored =
        Psql.run_command ~connection:(Psql.Conn_str archive_uri)
          (sprintf
             {sql| SELECT count(*)
                   FROM accounts_accessed aa
                   JOIN account_identifiers ai ON ai.id = aa.account_identifier_id
                   JOIN public_keys pk ON pk.id = ai.public_key_id
                   JOIN token_symbols ts ON ts.id = aa.token_symbol_id
                   WHERE pk.value = '%s' AND ts.value = '\xff'::bytea |sql}
             account )
      in
      if String.equal "2" (String.strip (Or_error.ok_exn stored)) then
        Mina_automation_fixture.Intf.Passed
      else
        Mina_automation_fixture.Intf.Failed
          (Error.createf
             "expected the 0xff token symbol in both blocks, got %s rows"
             (Or_error.ok_exn stored) )
  | Error e ->
      Deferred.return (Mina_automation_fixture.Intf.Failed e)
