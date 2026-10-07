(* Archive_lib.Processor.Genesis_accounts: the genesis ledger rows the archive
   writes at start-up, and the reader balance queries fall back to. Needs a
   PostgreSQL server: MINA_TEST_POSTGRES (any database path is ignored). *)

open Core
open Async
module B = Synthetic_archive
module G = Archive_lib.Processor.Genesis_accounts

let to_error e = Error.of_string (Caqti_error.show e)

let with_conn (db : B.Db.t) f =
  match%bind Mina_caqti.connect db.uri with
  | Error e ->
      return (Error (to_error e))
  | Ok (module Conn : Mina_caqti.CONNECTION) ->
      let%bind result = f (module Conn : Mina_caqti.CONNECTION) in
      let%map () = Conn.disconnect () in
      Result.map_error result ~f:to_error

let public_key name = B.public_key (B.account (B.create ()) name)

let account_id name =
  Mina_base.Account_id.create
    (Signature_lib.Public_key.Compressed.of_base58_check_exn (public_key name))
    Mina_base.Token_id.default

let untimed name ~balance =
  Mina_base.Account.create (account_id name)
    (Currency.Balance.of_nanomina_int_exn balance)

let timed name ~balance =
  Mina_base.Account.create_timed (account_id name)
    (Currency.Balance.of_nanomina_int_exn balance)
    ~initial_minimum_balance:(Currency.Balance.of_nanomina_int_exn 600)
    ~cliff_time:(Mina_numbers.Global_slot_since_genesis.of_int 10)
    ~cliff_amount:(Currency.Amount.of_nanomina_int_exn 100)
    ~vesting_period:(Mina_numbers.Global_slot_span.of_int 5)
    ~vesting_increment:(Currency.Amount.of_nanomina_int_exn 50)
  |> Or_error.ok_exn

let token = Mina_base.Token_id.(to_string default)

let latest db name ~height =
  with_conn db (fun conn ->
      G.latest conn ~public_key:(public_key name) ~token
        ~height:(Int64.of_int height) )

let add db ~genesis_height accounts =
  with_conn db (fun conn ->
      G.add conn ~genesis_height:(Int64.of_int genesis_height) accounts )

let outcome = function
  | `No_table ->
      "no table"
  | `Already_loaded ->
      "already loaded"
  | `Added n ->
      sprintf "added %d" n

let check_outcome what expected got =
  Alcotest.(check string) what expected (outcome got)

let check_row what expected (got : G.found option) =
  Alcotest.(check (option string))
    what
    (Option.map expected ~f:(fun (height, row) ->
         sprintf "%d %s" height (Sexp.to_string (G.sexp_of_row row)) ) )
    (Option.map got ~f:(fun g ->
         sprintf "%Ld %s" g.genesis_height
           (Sexp.to_string (G.sexp_of_row g.row)) ) )

let alice = untimed "alice" ~balance:1_000

let bob = timed "bob" ~balance:2_000

(* Both accounts read back as written, a second write of the same height
   changes nothing, and a later era is added beside the first: the reader
   answers from the newest era at or below the height asked about. *)
let write_and_read server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_rows" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind first = add db ~genesis_height:1 [ alice; bob ] in
      check_outcome "first write" "added 2" first ;
      let%bind again = add db ~genesis_height:1 [ alice ] in
      check_outcome "same height again" "already loaded" again ;
      let%bind a = latest db "alice" ~height:1 in
      check_row "alice" (Some (1, G.row_of_account alice)) a ;
      let%bind b = latest db "bob" ~height:7 in
      check_row "bob, timed" (Some (1, G.row_of_account bob)) b ;
      let alice' = untimed "alice" ~balance:5 in
      let%bind next = add db ~genesis_height:10 [ alice' ] in
      check_outcome "the next era" "added 1" next ;
      let%bind before = latest db "alice" ~height:9 in
      check_row "before the fork" (Some (1, G.row_of_account alice)) before ;
      let%bind after = latest db "alice" ~height:10 in
      check_row "after the fork" (Some (10, G.row_of_account alice')) after ;
      let%map nobody = latest db "carol" ~height:10 in
      check_row "not in any ledger" None nobody )

(* A database that never ran the schema upgrade: nothing is written and
   nothing is found, and neither is an error. *)
let without_table server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_no_table" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      (* upgrade.sql then downgrade.sql: the schema of an archive from before
         the table *)
      let%bind () = B.Db.run_script db `Upgrade in
      let%bind () = B.Db.run_script db `Rollback in
      let%bind written = add db ~genesis_height:1 [ alice ] in
      check_outcome "write" "no table" written ;
      let%map found = latest db "alice" ~height:1 in
      check_row "read" None found )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "genesis_accounts"
    [ ( "genesis_accounts"
      , [ Alcotest.test_case "write, read, and a later era" `Quick
            (run write_and_read)
        ; Alcotest.test_case "a database without the table" `Quick
            (run without_table)
        ] )
    ]
