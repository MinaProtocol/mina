(* Archive_lib.Settle_pending_blocks against hand-built archives: what it
   makes canonical, what it orphans, and what it must leave alone. Needs a
   PostgreSQL server: MINA_TEST_POSTGRES (any database path is ignored). *)

open Core
open Async
module B = Synthetic_archive
module Settle = Archive_lib.Settle_pending_blocks

let v4 = (4, 0, 0)

let v5 = (5, 0, 0)

let to_error e = Error.of_string (Caqti_error.show e)

let with_conn (db : B.Db.t) f =
  match%bind Mina_caqti.connect db.uri with
  | Error e ->
      return (Error (to_error e))
  | Ok (module Conn : Mina_caqti.CONNECTION) ->
      (* disconnect even when [f] raises, or the database cannot be dropped *)
      Monitor.protect ~finally:Conn.disconnect (fun () ->
          f (module Conn : Mina_caqti.CONNECTION)
          >>| Result.map_error ~f:to_error )

let run ?dry_run db = with_conn db (Settle.run ?dry_run)

(* The chain status of each named block, as the archive holds it. *)
let statuses db built blocks =
  with_conn db (fun (module Conn) ->
      let%map results =
        Deferred.List.map blocks ~f:(fun (name, block) ->
            let%map.Deferred.Result b =
              Archive_lib.Processor.Block.load
                (module Conn)
                ~id:(B.block_id built block)
            in
            (name, b.chain_status) )
      in
      Result.all results )

let check_statuses db built expected =
  let open Deferred.Or_error.Let_syntax in
  let%map got = statuses db built (List.map expected ~f:fst) in
  Alcotest.(check (list (pair string string)))
    "chain statuses"
    (List.map expected ~f:(fun ((name, _), status) -> (name, status)))
    got

(* The outcome a scenario expects: the fork genesis it settles at (by name),
   what became of its boundary, and the decided-height orphans. *)
type expected =
  { genesis : B.block option
  ; boundary : Settle.boundary option
  ; orphaned_decided : int
  }

let check_result built expected (got : Settle.t) =
  let want =
    { Settle.genesis_id = Option.map expected.genesis ~f:(B.block_id built)
    ; boundary = expected.boundary
    ; orphaned_decided = expected.orphaned_decided
    }
  in
  Alcotest.(check string)
    "settled"
    (Sexp.to_string (Settle.sexp_of_t want))
    (Sexp.to_string (Settle.sexp_of_t got))

(* Build [scenario] into a fresh database, settle once, and compare. *)
let run_scenario ~server_uri ~name scenario =
  let s = B.create () in
  let expected, statuses = scenario s in
  B.Db.with_fresh ~server_uri ~name (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind got = run db in
      check_result built expected got ;
      check_statuses db built statuses )

let settled canonicalized orphaned =
  Some (Settle.Settled { canonicalized; orphaned })

(* A fork genesis: the first block of the new chain, child of [fork_block]. *)
let fork_genesis ?(protocol_version = v5) s ~fork_block ~height status =
  B.block ~parent:fork_block ~protocol_version ~global_slot_since_hard_fork:0 s
    ~name:"genesis" ~height status

(* The archive canonicalized the old chain past the fork block (D) before the
   new chain arrived; the new chain's genesis shares D's height. *)
let fork_mid_canonical ?(new_version = v5) () s =
  let a = B.block ~protocol_version:v4 s ~name:"A" ~height:1 Canonical in
  let b =
    B.block ~parent:a ~protocol_version:v4 s ~name:"B" ~height:2 Canonical
  in
  let c =
    B.block ~parent:b ~protocol_version:v4 s ~name:"C" ~height:3 Canonical
  in
  let d =
    B.block ~parent:c ~protocol_version:v4 s ~name:"D" ~height:4 Canonical
  in
  let e =
    B.block ~parent:d ~protocol_version:v4 s ~name:"E" ~height:5 Pending
  in
  let g =
    fork_genesis ~protocol_version:new_version s ~fork_block:c ~height:4 Pending
  in
  let n =
    B.block ~parent:g ~protocol_version:new_version s ~name:"N" ~height:5
      Pending
  in
  ( { genesis = Some g; boundary = settled 0 2; orphaned_decided = 0 }
  , [ (("A", a), "canonical")
    ; (("B", b), "canonical")
    ; (("C", c), "canonical")
    ; (("D", d), "orphaned")
    ; (("E", e), "orphaned")
    ; (("genesis", g), "pending")
    ; (("N", n), "pending")
    ] )

let fork_in_canonical_chain server_uri () =
  run_scenario ~server_uri ~name:"test_settle_mid_canonical"
    (fork_mid_canonical ())

(* An emergency fork that keeps the protocol version: parent links only. *)
let fork_same_version server_uri () =
  run_scenario ~server_uri ~name:"test_settle_same_version"
    (fork_mid_canonical ~new_version:v4 ())

(* The watermark is behind the fork block: its pending ancestry becomes
   canonical, the competitors are orphaned. *)
let fork_on_pending server_uri () =
  run_scenario ~server_uri ~name:"test_settle_on_pending" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let c = B.block ~parent:b s ~name:"C" ~height:3 Pending in
      let d = B.block ~parent:b s ~name:"D" ~height:3 Pending in
      let e = B.block ~parent:d s ~name:"E" ~height:4 Pending in
      let g = fork_genesis s ~fork_block:c ~height:4 Pending in
      ( { genesis = Some g; boundary = settled 2 2; orphaned_decided = 0 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("C", c), "canonical")
        ; (("D", d), "orphaned")
        ; (("E", e), "orphaned")
        ; (("genesis", g), "pending")
        ] ) )

(* The archive orphaned the fork block and made its sibling canonical: the
   fork genesis says otherwise. *)
let fork_on_orphaned server_uri () =
  run_scenario ~server_uri ~name:"test_settle_on_orphaned" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Orphaned in
      let b' = B.block ~parent:a s ~name:"B'" ~height:2 Canonical in
      let g = fork_genesis s ~fork_block:b ~height:3 Pending in
      ( { genesis = Some g; boundary = settled 1 1; orphaned_decided = 0 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("B'", b'), "orphaned")
        ; (("genesis", g), "pending")
        ] ) )

(* The fork genesis has no parent link yet, but its fork block is in the
   archive: found by the genesis's parent hash. *)
let fork_genesis_without_parent_link server_uri () =
  run_scenario ~server_uri ~name:"test_settle_no_parent_link" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let b' = B.block ~parent:a s ~name:"B'" ~height:2 Pending in
      let g =
        B.block ~parent_hash:(B.state_hash b) ~protocol_version:v5
          ~global_slot_since_hard_fork:0 s ~name:"genesis" ~height:3 Pending
      in
      ( { genesis = Some g; boundary = settled 1 1; orphaned_decided = 0 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("B'", b'), "orphaned")
        ; (("genesis", g), "pending")
        ] ) )

(* The fork block is not in the archive at all: nothing to anchor to, and
   the result says so. *)
let fork_block_missing server_uri () =
  run_scenario ~server_uri ~name:"test_settle_fork_block_missing" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let g =
        B.block ~protocol_version:v5 ~global_slot_since_hard_fork:0 s
          ~name:"genesis" ~height:4 Pending
      in
      ( { genesis = Some g; boundary = Some No_fork_block; orphaned_decided = 0 }
      , [ (("B", b), "pending"); (("genesis", g), "pending") ] ) )

(* No canonical block on the fork block's ancestry. *)
let fork_unanchored server_uri () =
  run_scenario ~server_uri ~name:"test_settle_unanchored" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Pending in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let g = fork_genesis s ~fork_block:b ~height:3 Pending in
      ( { genesis = Some g
        ; boundary = Some No_canonical_ancestor
        ; orphaned_decided = 0
        }
      , [ (("A", a), "pending")
        ; (("B", b), "pending")
        ; (("genesis", g), "pending")
        ] ) )

(* Only the chain's first genesis: it is not a fork, and nothing is settled
   at a boundary. Losers at decided heights are orphaned; a height without a
   canonical block, and the tip above, stay pending. *)
let decided_heights server_uri () =
  run_scenario ~server_uri ~name:"test_settle_decided" (fun s ->
      let c1 = B.block s ~name:"c1" ~height:1 Canonical in
      let c2 = B.block ~parent:c1 s ~name:"c2" ~height:2 Canonical in
      let lost2 = B.block ~parent:c1 s ~name:"lost2" ~height:2 Pending in
      let gap3 = B.block ~parent:c2 s ~name:"gap3" ~height:3 Pending in
      let c4 = B.block ~parent:gap3 s ~name:"c4" ~height:4 Canonical in
      let lost4 = B.block ~parent:gap3 s ~name:"lost4" ~height:4 Pending in
      let tip5 = B.block ~parent:c4 s ~name:"tip5" ~height:5 Pending in
      ( { genesis = None; boundary = None; orphaned_decided = 2 }
      , [ (("c1", c1), "canonical")
        ; (("lost2", lost2), "orphaned")
        ; (("gap3", gap3), "pending")
        ; (("c4", c4), "canonical")
        ; (("lost4", lost4), "orphaned")
        ; (("tip5", tip5), "pending")
        ] ) )

(* A dry run reports what a run changes and changes nothing; a second run
   finds nothing left to change. *)
let dry_run_and_idempotence server_uri () =
  let s = B.create () in
  let expected, statuses = fork_mid_canonical () s in
  B.Db.with_fresh ~server_uri ~name:"test_settle_dry_run" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let before =
        List.filter_map statuses ~f:(fun ((name, block), _) ->
            match name with
            | "D" ->
                Some ((name, block), "canonical")
            | "E" ->
                Some ((name, block), "pending")
            | _ ->
                None )
      in
      let%bind dry = run ~dry_run:true db in
      check_result built expected dry ;
      let%bind () = check_statuses db built before in
      let%bind real = run db in
      check_result built expected real ;
      let%bind again = run db in
      check_result built { expected with boundary = settled 0 0 } again ;
      check_statuses db built statuses )

(* --- the archive's hook: on_block_added, called as add_block_aux calls it - *)

let added ?link_children db built block =
  with_conn db (fun (module Conn) ->
      let open Deferred.Result.Let_syntax in
      (* add_block_aux links the blocks waiting for this one first *)
      let%bind () =
        match link_children with
        | None ->
            return ()
        | Some parent_hash ->
            Archive_lib.Processor.Block.set_parent_id_if_null
              (module Conn)
              ~parent_hash:
                (Mina_base.State_hash.of_base58_check_exn parent_hash)
              ~parent_id:(B.block_id built block)
      in
      Settle.on_block_added ~logger:(Logger.null ())
        (module Conn)
        ~block_id:(B.block_id built block) )

(* The added block is the fork genesis. *)
let added_fork_genesis server_uri () =
  let s = B.create () in
  let _, statuses = fork_mid_canonical () s in
  let genesis = snd (fst (List.nth_exn statuses 5)) in
  B.Db.with_fresh ~server_uri ~name:"test_settle_added_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind () = added db built genesis in
      check_statuses db built statuses )

(* The fork genesis arrived before its fork block: once the fork block is
   added and linked, the boundary is settled. *)
let added_fork_block_after_genesis server_uri () =
  let s = B.create () in
  let a = B.block s ~name:"A" ~height:1 Canonical in
  (* a real state hash: the archive's linking parses it *)
  let b =
    B.block ~state_hash:"3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ"
      ~parent:a s ~name:"B" ~height:2 Pending
  in
  let b' = B.block ~parent:a s ~name:"B'" ~height:2 Pending in
  let g =
    B.block ~parent_hash:(B.state_hash b) ~protocol_version:v5
      ~global_slot_since_hard_fork:0 s ~name:"genesis" ~height:3 Pending
  in
  B.Db.with_fresh ~server_uri ~name:"test_settle_added_fork_block" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind () = added ~link_children:(B.state_hash b) db built b in
      check_statuses db built
        [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("B'", b'), "orphaned")
        ; (("genesis", g), "pending")
        ] )

(* An ordinary block changes nothing. *)
let added_ordinary_block server_uri () =
  let s = B.create () in
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
  let b' = B.block ~parent:a s ~name:"B'" ~height:2 Pending in
  B.Db.with_fresh ~server_uri ~name:"test_settle_added_ordinary" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind () = added db built b in
      check_statuses db built
        [ (("A", a), "canonical")
        ; (("B", b), "pending")
        ; (("B'", b'), "pending")
        ] )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "settle_pending_blocks"
    [ ( "settle_pending_blocks"
      , [ Alcotest.test_case "fork in the canonical chain" `Quick
            (run fork_in_canonical_chain)
        ; Alcotest.test_case "fork without a protocol version bump" `Quick
            (run fork_same_version)
        ; Alcotest.test_case "fork on a pending block" `Quick
            (run fork_on_pending)
        ; Alcotest.test_case "fork on an orphaned block" `Quick
            (run fork_on_orphaned)
        ; Alcotest.test_case "fork genesis without a parent link" `Quick
            (run fork_genesis_without_parent_link)
        ; Alcotest.test_case "fork block missing" `Quick
            (run fork_block_missing)
        ; Alcotest.test_case "fork without a canonical anchor" `Quick
            (run fork_unanchored)
        ; Alcotest.test_case "first genesis only; decided heights" `Quick
            (run decided_heights)
        ; Alcotest.test_case "dry run, then idempotent" `Quick
            (run dry_run_and_idempotence)
        ] )
    ; ( "on_block_added"
      , [ Alcotest.test_case "the fork genesis" `Quick (run added_fork_genesis)
        ; Alcotest.test_case "the fork block, after its genesis" `Quick
            (run added_fork_block_after_genesis)
        ; Alcotest.test_case "an ordinary block" `Quick
            (run added_ordinary_block)
        ] )
    ]
