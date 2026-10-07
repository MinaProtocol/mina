(* Archive_lib.Pending_blocks against hand-built archives: what it makes
   canonical, what it orphans, and what it must leave alone. Needs a PostgreSQL
   server: MINA_TEST_POSTGRES (any database path is ignored). *)

open Core
open Async
module B = Synthetic_archive
module Pending_blocks = Archive_lib.Pending_blocks

let v4 = (4, 0, 0)

let v5 = (5, 0, 0)

let to_error e = Error.of_string (Caqti_error.show e)

let with_conn (db : B.Db.t) f =
  match%bind Mina_caqti.connect db.uri with
  | Error e ->
      return (Error (to_error e))
  | Ok (module Conn : Mina_caqti.CONNECTION) ->
      let%bind result = f (module Conn : Mina_caqti.CONNECTION) in
      let%map () = Conn.disconnect () in
      Result.map_error result ~f:to_error

let settle ?dry_run db = with_conn db (Pending_blocks.settle ?dry_run)

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

let check_result what expected got =
  Alcotest.(check string)
    what
    (Sexp.to_string (Pending_blocks.sexp_of_t expected))
    (Sexp.to_string (Pending_blocks.sexp_of_t got))

let result ?(canonicalized = 0) ?(orphaned_after_fork = 0)
    ?(orphaned_decided = 0) ?(fork_unresolved = false) () =
  { Pending_blocks.canonicalized
  ; orphaned_after_fork
  ; orphaned_decided
  ; fork_unresolved
  }

(* Build [scenario] into a fresh database, settle once, and compare. *)
let run_scenario ~server_uri ~name ~expected_result scenario =
  let s = B.create () in
  let expected = scenario s in
  B.Db.with_fresh ~server_uri ~name (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind got = settle db in
      check_result "settled" expected_result got ;
      check_statuses db built expected )

(* A fork genesis: the first block of the new chain, child of [fork_block]. *)
let fork_genesis s ?(protocol_version = v5) ~fork_block ~height status =
  B.block s ~name:"genesis" ~height ~parent:fork_block ~protocol_version
    ~global_slot_since_hard_fork:0 status

(* The archive canonicalized the old chain past the fork block (D) before the
   new chain arrived; the new chain's genesis shares D's height. *)
let fork_mid_canonical ?(new_version = v5) () s =
  let a = B.block s ~name:"A" ~height:1 ~protocol_version:v4 Canonical in
  let b =
    B.block s ~name:"B" ~height:2 ~parent:a ~protocol_version:v4 Canonical
  in
  let c =
    B.block s ~name:"C" ~height:3 ~parent:b ~protocol_version:v4 Canonical
  in
  let d =
    B.block s ~name:"D" ~height:4 ~parent:c ~protocol_version:v4 Canonical
  in
  let e =
    B.block s ~name:"E" ~height:5 ~parent:d ~protocol_version:v4 Pending
  in
  let g =
    fork_genesis s ~protocol_version:new_version ~fork_block:c ~height:4 Pending
  in
  let n =
    B.block s ~name:"N" ~height:5 ~parent:g ~protocol_version:new_version
      Pending
  in
  [ (("A", a), "canonical")
  ; (("B", b), "canonical")
  ; (("C", c), "canonical")
  ; (("D", d), "orphaned")
  ; (("E", e), "orphaned")
  ; (("genesis", g), "pending")
  ; (("N", n), "pending")
  ]

let fork_in_canonical_chain server_uri () =
  run_scenario ~server_uri ~name:"test_pending_blocks_mid_canonical"
    ~expected_result:(result ~orphaned_after_fork:2 ())
    (fork_mid_canonical ())

(* An emergency fork that keeps the protocol version is read the same way:
   through parent links. *)
let fork_same_version server_uri () =
  run_scenario ~server_uri ~name:"test_pending_blocks_same_version"
    ~expected_result:(result ~orphaned_after_fork:2 ())
    (fork_mid_canonical ~new_version:v4 ())

(* The watermark is behind the fork block: its pending ancestry becomes
   canonical, the competitors are orphaned. *)
let fork_on_pending server_uri () =
  run_scenario ~server_uri ~name:"test_pending_blocks_on_pending"
    ~expected_result:(result ~canonicalized:2 ~orphaned_after_fork:2 ())
    (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block s ~name:"B" ~height:2 ~parent:a Pending in
      let c = B.block s ~name:"C" ~height:3 ~parent:b Pending in
      let d = B.block s ~name:"D" ~height:3 ~parent:b Pending in
      let e = B.block s ~name:"E" ~height:4 ~parent:d Pending in
      let g = fork_genesis s ~fork_block:c ~height:4 Pending in
      [ (("A", a), "canonical")
      ; (("B", b), "canonical")
      ; (("C", c), "canonical")
      ; (("D", d), "orphaned")
      ; (("E", e), "orphaned")
      ; (("genesis", g), "pending")
      ] )

(* The archive orphaned the fork block and made its sibling canonical: the
   fork genesis says otherwise. *)
let fork_on_orphaned server_uri () =
  run_scenario ~server_uri ~name:"test_pending_blocks_on_orphaned"
    ~expected_result:(result ~canonicalized:1 ~orphaned_after_fork:1 ())
    (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block s ~name:"B" ~height:2 ~parent:a Orphaned in
      let b' = B.block s ~name:"B'" ~height:2 ~parent:a Canonical in
      let g = fork_genesis s ~fork_block:b ~height:3 Pending in
      [ (("A", a), "canonical")
      ; (("B", b), "canonical")
      ; (("B'", b'), "orphaned")
      ; (("genesis", g), "pending")
      ] )

(* No canonical block on the fork block's ancestry: nothing to anchor the
   boundary to, so it is left as it is and reported. *)
let fork_unanchored server_uri () =
  run_scenario ~server_uri ~name:"test_pending_blocks_unanchored"
    ~expected_result:(result ~fork_unresolved:true ()) (fun s ->
      let a = B.block s ~name:"A" ~height:1 Pending in
      let b = B.block s ~name:"B" ~height:2 ~parent:a Pending in
      let g = fork_genesis s ~fork_block:b ~height:3 Pending in
      [ (("A", a), "pending")
      ; (("B", b), "pending")
      ; (("genesis", g), "pending")
      ] )

(* Without a fork: losers at heights that have a canonical block are
   orphaned; a height without one, and the tip above, stay pending. *)
let decided_heights server_uri () =
  run_scenario ~server_uri ~name:"test_pending_blocks_decided"
    ~expected_result:(result ~orphaned_decided:2 ()) (fun s ->
      let c1 = B.block s ~name:"c1" ~height:1 Canonical in
      let c2 = B.block s ~name:"c2" ~height:2 ~parent:c1 Canonical in
      let lost2 = B.block s ~name:"lost2" ~height:2 ~parent:c1 Pending in
      let gap3 = B.block s ~name:"gap3" ~height:3 ~parent:c2 Pending in
      let c4 = B.block s ~name:"c4" ~height:4 ~parent:gap3 Canonical in
      let lost4 = B.block s ~name:"lost4" ~height:4 ~parent:gap3 Pending in
      let tip5 = B.block s ~name:"tip5" ~height:5 ~parent:c4 Pending in
      [ (("c1", c1), "canonical")
      ; (("lost2", lost2), "orphaned")
      ; (("gap3", gap3), "pending")
      ; (("c4", c4), "canonical")
      ; (("lost4", lost4), "orphaned")
      ; (("tip5", tip5), "pending")
      ] )

(* A dry run reports what a run changes and changes nothing; a second run
   finds nothing left. *)
let dry_run_and_idempotence server_uri () =
  let s = B.create () in
  let expected = fork_mid_canonical () s in
  let before =
    List.map expected ~f:(fun ((name, block), _) ->
        ( (name, block)
        , match name with "D" -> "canonical" | "E" -> "pending" | _ -> "" ) )
    |> List.filter ~f:(fun (_, status) -> not (String.is_empty status))
  in
  B.Db.with_fresh ~server_uri ~name:"test_pending_blocks_dry_run" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind dry = settle ~dry_run:true db in
      check_result "dry run" (result ~orphaned_after_fork:2 ()) dry ;
      let%bind () = check_statuses db built before in
      let%bind run = settle db in
      check_result "run" (result ~orphaned_after_fork:2 ()) run ;
      let%bind again = settle db in
      check_result "second run" (result ()) again ;
      check_statuses db built expected )

(* The archive's start-up flag settles before it accepts blocks. *)
let archive_flag server_uri () =
  let s = B.create () in
  let expected = fork_mid_canonical () s in
  let want = List.map expected ~f:(fun ((name, _), status) -> (name, status)) in
  B.Db.with_fresh ~server_uri ~name:"test_pending_blocks_archive_flag"
    (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let port =
        let server =
          Tcp.Server.create_sock_inet ~on_handler_error:`Raise
            Tcp.Where_to_listen.of_port_chosen_by_os (fun _ _ -> Deferred.unit)
        in
        let port = Tcp.Server.listening_on server in
        don't_wait_for (Tcp.Server.close server) ;
        port
      in
      let%bind archive =
        Process.create ~prog:"../../archive.exe"
          ~args:
            [ "run"
            ; "--postgres-uri"
            ; Uri.to_string db.uri
            ; "--server-port"
            ; Int.to_string port
            ; "--settle-pending-blocks"
            ]
          ()
      in
      don't_wait_for (Reader.drain (Process.stdout archive)) ;
      don't_wait_for (Reader.drain (Process.stderr archive)) ;
      let rec until_settled tries =
        let%bind got = statuses db built (List.map expected ~f:fst) in
        if [%equal: (string * string) list] got want || tries = 0 then
          return got
        else
          let%bind () = Deferred.ok (after (Time.Span.of_sec 1.)) in
          until_settled (tries - 1)
      in
      let%bind got =
        Monitor.protect
          (fun () -> until_settled 60)
          ~finally:(fun () ->
            Signal.send_i Signal.term (`Pid (Process.pid archive)) ;
            Deferred.ignore_m (Process.wait archive) )
      in
      Alcotest.(check (list (pair string string))) "chain statuses" want got ;
      return () )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "pending_blocks"
    [ ( "pending_blocks"
      , [ Alcotest.test_case "fork in the canonical chain" `Quick
            (run fork_in_canonical_chain)
        ; Alcotest.test_case "fork without a protocol version bump" `Quick
            (run fork_same_version)
        ; Alcotest.test_case "fork on a pending block" `Quick
            (run fork_on_pending)
        ; Alcotest.test_case "fork on an orphaned block" `Quick
            (run fork_on_orphaned)
        ; Alcotest.test_case "fork without a canonical anchor" `Quick
            (run fork_unanchored)
        ; Alcotest.test_case "decided heights, gaps and tip" `Quick
            (run decided_heights)
        ; Alcotest.test_case "dry run, then idempotent" `Quick
            (run dry_run_and_idempotence)
        ; Alcotest.test_case "the archive's --settle-pending-blocks" `Quick
            (run archive_flag)
        ] )
    ]
