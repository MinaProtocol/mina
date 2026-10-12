(* The settle-pending-blocks command: which fork genesis it settles, and the
   errors for a bad --fork-genesis-hash. The settling itself is tested with
   Archive_lib.Settle_pending_blocks. Needs MINA_TEST_POSTGRES. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
module B = Synthetic_archive
module Settle = Archive_lib.Settle_pending_blocks

(* --fork-genesis-hash is parsed, so the blocks it names need real hashes *)
let state_hash n =
  Mina_base.State_hash.(
    to_base58_check (of_hash (Snark_params.Tick.Field.of_int n)))

(* Two hard forks: G1 on B, G2 on C. B' competes with B. *)
let two_forks s =
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b =
    B.block ~state_hash:(state_hash 1) ~parent:a s ~name:"B" ~height:2 Pending
  in
  let b' = B.block ~parent:a s ~name:"B'" ~height:2 Pending in
  let g1 =
    B.block ~state_hash:(state_hash 2) ~parent:b ~global_slot_since_hard_fork:0
      s ~name:"G1" ~height:3 Pending
  in
  let c = B.block ~parent:g1 s ~name:"C" ~height:4 Pending in
  let d = B.block ~parent:g1 s ~name:"D" ~height:4 Pending in
  let g2 =
    B.block ~state_hash:(state_hash 3) ~parent:c ~global_slot_since_hard_fork:0
      s ~name:"G2" ~height:5 Pending
  in
  [ ("A", a); ("B", b); ("B'", b'); ("G1", g1); ("C", c); ("D", d); ("G2", g2) ]

let with_two_forks ~server_uri ~name f =
  let s = B.create () in
  let blocks = two_forks s in
  B.Db.with_fresh ~server_uri ~name (fun db ->
      let%bind.Deferred.Or_error built = B.materialize s db in
      f db (fun name ->
          B.block_id built (List.Assoc.find_exn blocks name ~equal:String.equal) ) )

let settle ?fork_genesis_hash ~dry_run (db : B.Db.t) =
  Logic.settle_pending_blocks ~postgres_uri:db.uri ?fork_genesis_hash ~dry_run
    ()

let check expected (got : Settle.t) =
  Alcotest.(check string)
    "settled"
    (Sexp.to_string (Settle.sexp_of_t expected))
    (Sexp.to_string (Settle.sexp_of_t got))

let newest_by_default server_uri () =
  with_two_forks ~server_uri ~name:"test_toolbox_settle_newest" (fun db id ->
      let%map.Deferred.Or_error got = settle ~dry_run:true db in
      check
        { genesis_id = Some (id "G2")
        ; boundary = Some (Settled { canonicalized = 3; orphaned = 2 })
        ; orphaned_decided = 0
        }
        got )

let named_fork_genesis server_uri () =
  with_two_forks ~server_uri ~name:"test_toolbox_settle_named" (fun db id ->
      let open Deferred.Or_error.Let_syntax in
      let settle_g1 () =
        settle ~fork_genesis_hash:(state_hash 2) ~dry_run:false db
      in
      let%bind got = settle_g1 () in
      check
        { genesis_id = Some (id "G1")
        ; boundary = Some (Settled { canonicalized = 1; orphaned = 1 })
        ; orphaned_decided = 0
        }
        got ;
      let%map again = settle_g1 () in
      check
        { genesis_id = Some (id "G1")
        ; boundary = Some (Settled { canonicalized = 0; orphaned = 0 })
        ; orphaned_decided = 0
        }
        again )

let fails_with ~substring = function
  | Ok _ ->
      Alcotest.failf "expected an error containing %S" substring
  | Error e ->
      let msg = Error.to_string_hum e in
      if not (String.is_substring msg ~substring) then
        Alcotest.failf "expected %S in: %s" substring msg

let bad_fork_genesis_hash server_uri () =
  with_two_forks ~server_uri ~name:"test_toolbox_settle_bad_hash" (fun db _ ->
      let%bind not_fork_genesis =
        settle ~fork_genesis_hash:(state_hash 1) ~dry_run:true db
      in
      fails_with ~substring:"is not a fork genesis" not_fork_genesis ;
      let%map unknown =
        settle ~fork_genesis_hash:(state_hash 9) ~dry_run:true db
      in
      fails_with ~substring:"No block with state hash" unknown ;
      Ok () )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "archive_hardfork_toolbox"
    [ ( "settle-pending-blocks"
      , [ Alcotest.test_case "the newest fork genesis by default" `Quick
            (run newest_by_default)
        ; Alcotest.test_case "--fork-genesis-hash, then idempotent" `Quick
            (run named_fork_genesis)
        ; Alcotest.test_case "--fork-genesis-hash of a bad block" `Quick
            (run bad_fork_genesis_hash)
        ] )
    ]
