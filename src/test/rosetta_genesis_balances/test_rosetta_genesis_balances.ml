(* Rosetta's account balance against hand-built archives: an account seen
   only in a genesis ledger, only in blocks, in both, or in neither. Needs a
   PostgreSQL server: MINA_TEST_POSTGRES (any database path is ignored). *)

open Core
open Async
module B = Synthetic_archive

let token = Mina_base.Token_id.(to_string default)

(* liquid, total, nonce *)
type balance = int64 * int64 * int [@@deriving sexp, equal]

let balance_of db (account : B.account) ~height =
  match%bind Mina_caqti.connect db.B.Db.uri with
  | Error e ->
      return (Or_error.error_string (Caqti_error.show e))
  | Ok (module Conn : Mina_caqti.CONNECTION) ->
      let%bind result =
        Lib.Account.Sql.run
          (module Conn)
          ~block_query:(Some (`This (`Height (Int64.of_int height))))
          ~address:(B.public_key account) ~token_id:token
      in
      let%map () = Conn.disconnect () in
      Result.map_error result ~f:(fun e ->
          Error.of_string (Rosetta_lib.Errors.show e) )
      |> Result.map ~f:(fun (_, (b : Lib.Account.Balance_info.t), nonce) ->
             (b.liquid_balance, b.total_balance, Unsigned.UInt64.to_int nonce) )

let check what expected got =
  Alcotest.(check string)
    what
    (Sexp.to_string (sexp_of_balance expected))
    (Sexp.to_string (sexp_of_balance got))

let untimed n = (Int64.of_int n, Int64.of_int n)

(* A canonical chain 1..[n]; block 1 is the genesis block. *)
let chain s n =
  let rec go acc parent h =
    if h > n then List.rev acc
    else
      let b = B.block s ?parent ~name:(sprintf "c%d" h) ~height:h B.Canonical in
      go (b :: acc) (Some b) (h + 1)
  in
  go [] None 1

let scenario ~server_uri ~name build checks =
  let s = B.create () in
  let ctx = build s in
  B.Db.with_fresh ~server_uri ~name (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) = B.materialize s db in
      checks db ctx )

(* In the genesis ledger only: its genesis balance, not zero. *)
let genesis_only server_uri () =
  scenario ~server_uri ~name:"test_rosetta_genesis_only"
    (fun s ->
      let (_ : B.block list) = chain s 3 in
      let alice = B.account s "alice" in
      B.genesis_account s ~nonce:2 ~genesis_height:1 alice ~balance:1_000 ;
      alice )
    (fun db alice ->
      let%map.Deferred.Or_error got = balance_of db alice ~height:3 in
      let liquid, total = untimed 1_000 in
      check "genesis only" (liquid, total, 2) got )

(* In both, the block later: the block's state. *)
let block_later server_uri () =
  scenario ~server_uri ~name:"test_rosetta_block_later"
    (fun s ->
      let blocks = chain s 3 in
      let alice = B.account s "alice" in
      B.genesis_account s ~genesis_height:1 alice ~balance:1_000 ;
      B.account_state s ~nonce:1 (List.nth_exn blocks 1) alice ~balance:400 ;
      alice )
    (fun db alice ->
      let%map.Deferred.Or_error got = balance_of db alice ~height:3 in
      let liquid, total = untimed 400 in
      check "block later" (liquid, total, 1) got )

(* In both, a later fork's genesis later: the new era's state after the fork,
   the block's before it. *)
let genesis_later server_uri () =
  scenario ~server_uri ~name:"test_rosetta_genesis_later"
    (fun s ->
      let blocks = chain s 3 in
      let fork_block = List.nth_exn blocks 2 in
      let g =
        B.block s ~name:"g" ~height:4 ~parent:fork_block
          ~global_slot_since_hard_fork:0 B.Canonical
      in
      let (_ : B.block) =
        B.block s ~name:"n5" ~height:5 ~parent:g B.Canonical
      in
      let alice = B.account s "alice" in
      B.account_state s ~nonce:1 (List.nth_exn blocks 1) alice ~balance:400 ;
      B.genesis_account s ~nonce:1 ~genesis_height:4 alice ~balance:7_777 ;
      alice )
    (fun db alice ->
      let open Deferred.Or_error.Let_syntax in
      let%bind after = balance_of db alice ~height:5 in
      let liquid, total = untimed 7_777 in
      check "after the fork" (liquid, total, 1) after ;
      let%map before = balance_of db alice ~height:3 in
      let liquid, total = untimed 400 in
      check "before the fork" (liquid, total, 1) before )

(* In neither: it did not exist yet, zero. *)
let neither server_uri () =
  scenario ~server_uri ~name:"test_rosetta_neither"
    (fun s ->
      let (_ : B.block list) = chain s 2 in
      B.account s "carol" )
    (fun db carol ->
      let%map.Deferred.Or_error got = balance_of db carol ~height:2 in
      check "neither" (0L, 0L, 0) got )

(* A vesting account read from the genesis ledger and the same account read
   from the genesis block's accounts_accessed row: the same liquid and total
   balance at a later slot, so vesting counts from the genesis block. *)
let timed_parity server_uri () =
  let timing =
    { B.initial_minimum_balance = 600
    ; cliff_time = 5
    ; cliff_amount = 100
    ; vesting_period = 2
    ; vesting_increment = 50
    }
  in
  scenario ~server_uri ~name:"test_rosetta_timed_parity"
    (fun s ->
      let blocks = chain s 12 in
      let from_genesis = B.account s "alice" in
      let from_block = B.account s "bob" in
      B.genesis_account s ~timing ~genesis_height:1 from_genesis ~balance:1_000 ;
      B.account_state s ~timing (List.hd_exn blocks) from_block ~balance:1_000 ;
      (from_genesis, from_block) )
    (fun db (from_genesis, from_block) ->
      let open Deferred.Or_error.Let_syntax in
      let%bind g = balance_of db from_genesis ~height:12 in
      let%map b = balance_of db from_block ~height:12 in
      check "same balance as the genesis block's row" b g )

(* An archive without the table: Rosetta answers as it did before, from
   blocks only, and does not fail. *)
let without_table server_uri () =
  scenario ~server_uri ~name:"test_rosetta_no_genesis_table"
    (fun s ->
      let blocks = chain s 2 in
      let alice = B.account s "alice" in
      let bob = B.account s "bob" in
      B.account_state s (List.hd_exn blocks) bob ~balance:300 ;
      (alice, bob) )
    (fun db (alice, bob) ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () = B.Db.run_script db `Upgrade in
      let%bind () = B.Db.run_script db `Rollback in
      let%bind a = balance_of db alice ~height:2 in
      check "only in no block" (0L, 0L, 0) a ;
      let%map b = balance_of db bob ~height:2 in
      let liquid, total = untimed 300 in
      check "from blocks" (liquid, total, 0) b )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "rosetta_genesis_balances"
    [ ( "rosetta_genesis_balances"
      , [ Alcotest.test_case "in the genesis ledger only" `Quick
            (run genesis_only)
        ; Alcotest.test_case "in both, the block later" `Quick (run block_later)
        ; Alcotest.test_case "in both, a later fork's genesis later" `Quick
            (run genesis_later)
        ; Alcotest.test_case "in neither" `Quick (run neither)
        ; Alcotest.test_case "a vesting account: same as the genesis block"
            `Quick (run timed_parity)
        ; Alcotest.test_case "an archive without the table" `Quick
            (run without_table)
        ] )
    ]
