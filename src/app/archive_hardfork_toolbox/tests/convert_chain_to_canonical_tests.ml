(* convert-chain-to-canonical: settles the boundary of the newest fork genesis
   with Archive_lib.Settle_pending_blocks; --dry-run reports the same change
   and writes nothing. The settle logic itself is tested in
   src/app/archive/tests/settle_pending_blocks. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
module B = Synthetic_archive
module Settle = Archive_lib.Settle_pending_blocks

(* A watermark behind the fork block C: B and C are pending, D competes with
   C. *)
let scenario s =
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
  let c = B.block ~parent:b s ~name:"C" ~height:3 Pending in
  let d = B.block ~parent:b s ~name:"D" ~height:3 Pending in
  let g =
    B.block ~parent:c ~protocol_version:(5, 0, 0) ~global_slot_since_hard_fork:0
      s ~name:"genesis" ~height:4 Canonical
  in
  (g, [ ("A", a); ("B", b); ("C", c); ("D", d); ("genesis", g) ])

let statuses (db : B.Db.t) built blocks =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      let%map results =
        Deferred.List.map blocks ~how:`Sequential ~f:(fun (name, block) ->
            Conn.find
              (Mina_caqti.find_req Caqti_type.int Caqti_type.string
                 "SELECT chain_status::text FROM blocks WHERE id = ?" )
              (B.block_id built block)
            |> Deferred.Result.map ~f:(fun status -> (name, status)) )
      in
      Result.all results
      |> Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e)) )

let check_statuses db built blocks want =
  let%map.Deferred.Or_error got = statuses db built blocks in
  Alcotest.(check (list (pair string string))) "chain statuses" want got

let dry_run_then_run server_uri () =
  let s = B.create () in
  let genesis, blocks = scenario s in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_convert_canonical" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let expected =
        { Settle.genesis_id = Some (B.block_id built genesis)
        ; boundary = Some (Settled { canonicalized = 2; orphaned = 1 })
        }
      in
      let check_result name got =
        Alcotest.(check string)
          name
          (Sexp.to_string (Settle.sexp_of_t expected))
          (Sexp.to_string (Settle.sexp_of_t got))
      in
      let%bind dry = Logic.settle_boundary ~postgres_uri:db.uri ~dry_run:true in
      check_result "dry run reports the change" dry ;
      let%bind () =
        check_statuses db built blocks
          [ ("A", "canonical")
          ; ("B", "pending")
          ; ("C", "pending")
          ; ("D", "pending")
          ; ("genesis", "canonical")
          ]
      in
      let%bind real =
        Logic.settle_boundary ~postgres_uri:db.uri ~dry_run:false
      in
      check_result "run makes the change" real ;
      check_statuses db built blocks
        [ ("A", "canonical")
        ; ("B", "canonical")
        ; ("C", "canonical")
        ; ("D", "orphaned")
        ; ("genesis", "canonical")
        ] )

(* The command's own path: prints the result and succeeds on an archive with
   no fork genesis. *)
let nothing_to_settle server_uri () =
  let s = B.create () in
  ignore (B.block s ~name:"A" ~height:1 Canonical : B.block) ;
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_convert_canonical_none"
    (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) = B.materialize s db in
      let%bind got =
        Logic.settle_boundary ~postgres_uri:db.uri ~dry_run:false
      in
      Alcotest.(check string)
        "nothing settled"
        (Sexp.to_string
           (Settle.sexp_of_t { Settle.genesis_id = None; boundary = None }) )
        (Sexp.to_string (Settle.sexp_of_t got)) ;
      Logic.convert_chain_to_canonical ~postgres_uri:db.uri ~dry_run:true () )

(* The command fails when the boundary cannot be settled: here the fork
   genesis is pending, which it refuses, and nothing changes. *)
let refuses_pending_genesis server_uri () =
  let s = B.create () in
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
  let g =
    B.block ~parent:b ~protocol_version:(5, 0, 0) ~global_slot_since_hard_fork:0
      s ~name:"genesis" ~height:3 Pending
  in
  let blocks = [ ("A", a); ("B", b); ("genesis", g) ] in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_convert_canonical_pending"
    (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind () =
        match%map.Deferred
          Logic.convert_chain_to_canonical ~postgres_uri:db.uri ~dry_run:false
            ()
        with
        | Ok () ->
            Alcotest.fail "expected a failure for a pending fork genesis"
        | Error e ->
            let msg = Error.to_string_hum e in
            if not (String.is_substring msg ~substring:"not canonical") then
              Alcotest.failf "unexpected failure: %s" msg ;
            Ok ()
      in
      check_statuses db built blocks
        [ ("A", "canonical"); ("B", "pending"); ("genesis", "pending") ] )

let tests ~server_uri =
  let run f () =
    Thread_safe.block_on_async_exn (f server_uri) |> Or_error.ok_exn
  in
  [ ( "convert_chain_to_canonical"
    , [ ("dry run, then run", `Quick, run dry_run_then_run)
      ; ("nothing to settle", `Quick, run nothing_to_settle)
      ; ("refuses a pending fork genesis", `Quick, run refuses_pending_genesis)
      ] )
  ]
