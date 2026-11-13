(* Archive_lib.Settle_pending_blocks against hand-built archives: what it
   makes canonical, what it orphans, and what it must leave alone. Needs a
   PostgreSQL server: MINA_TEST_POSTGRES (any database path is ignored). *)

open Core
open Mina_base
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

(* The outcome a scenario expects: the fork genesis it settles at (by name)
   and what became of its boundary. *)
type expected = { genesis : B.block option; boundary : Settle.boundary option }

let check_result built expected (got : Settle.t) =
  let want =
    { Settle.genesis_id = Option.map expected.genesis ~f:(B.block_id built)
    ; boundary = expected.boundary
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
    fork_genesis ~protocol_version:new_version s ~fork_block:c ~height:4
      Canonical
  in
  let n =
    B.block ~parent:g ~protocol_version:new_version s ~name:"N" ~height:5
      Pending
  in
  ( { genesis = Some g; boundary = settled 0 2 }
  , [ (("A", a), "canonical")
    ; (("B", b), "canonical")
    ; (("C", c), "canonical")
    ; (("D", d), "orphaned")
    ; (("E", e), "orphaned")
    ; (("genesis", g), "canonical")
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
      let g = fork_genesis s ~fork_block:c ~height:4 Canonical in
      ( { genesis = Some g; boundary = settled 2 2 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("C", c), "canonical")
        ; (("D", d), "orphaned")
        ; (("E", e), "orphaned")
        ; (("genesis", g), "canonical")
        ] ) )

(* The archive orphaned the fork block and made its sibling canonical: the
   fork genesis says otherwise. *)
let fork_on_orphaned server_uri () =
  run_scenario ~server_uri ~name:"test_settle_on_orphaned" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Orphaned in
      let b' = B.block ~parent:a s ~name:"B'" ~height:2 Canonical in
      let g = fork_genesis s ~fork_block:b ~height:3 Canonical in
      ( { genesis = Some g; boundary = settled 1 1 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("B'", b'), "orphaned")
        ; (("genesis", g), "canonical")
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
          ~global_slot_since_hard_fork:0 s ~name:"genesis" ~height:3 Canonical
      in
      ( { genesis = Some g; boundary = settled 1 1 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("B'", b'), "orphaned")
        ; (("genesis", g), "canonical")
        ] ) )

(* The fork block is not in the archive at all: nothing to anchor to, and
   the result says so. *)
let fork_block_missing server_uri () =
  run_scenario ~server_uri ~name:"test_settle_fork_block_missing" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let g =
        B.block ~protocol_version:v5 ~global_slot_since_hard_fork:0 s
          ~name:"genesis" ~height:4 Canonical
      in
      ( { genesis = Some g; boundary = Some No_fork_block }
      , [ (("B", b), "pending"); (("genesis", g), "canonical") ] ) )

(* No canonical block on the fork block's ancestry. *)
let fork_unanchored server_uri () =
  run_scenario ~server_uri ~name:"test_settle_unanchored" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Pending in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let g = fork_genesis s ~fork_block:b ~height:3 Canonical in
      ( { genesis = Some g; boundary = Some No_canonical_ancestor }
      , [ (("A", a), "pending")
        ; (("B", b), "pending")
        ; (("genesis", g), "canonical")
        ] ) )

(* The fork block is the highest canonical block; the old chain went on past
   it as pending blocks, which are orphaned. *)
let fork_on_last_canonical server_uri () =
  run_scenario ~server_uri ~name:"test_settle_on_last_canonical" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Canonical in
      let c = B.block ~parent:b s ~name:"C" ~height:3 Canonical in
      let d = B.block ~parent:c s ~name:"D" ~height:4 Pending in
      let e = B.block ~parent:d s ~name:"E" ~height:5 Pending in
      let g = fork_genesis s ~fork_block:c ~height:4 Canonical in
      ( { genesis = Some g; boundary = settled 0 2 }
      , [ (("A", a), "canonical")
        ; (("B", b), "canonical")
        ; (("C", c), "canonical")
        ; (("D", d), "orphaned")
        ; (("E", e), "orphaned")
        ; (("genesis", g), "canonical")
        ] ) )

(* A fork right after the first genesis: the old chain's canonical block B is
   a sibling of the fork genesis and is orphaned. The new chain's own pending
   blocks are left to the archive's canonical marking. *)
let fork_on_new_network server_uri () =
  run_scenario ~server_uri ~name:"test_settle_new_network" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Canonical in
      let g = fork_genesis s ~fork_block:a ~height:2 Canonical in
      let d =
        B.block ~parent:g ~protocol_version:v5 s ~name:"D" ~height:3 Pending
      in
      let e =
        B.block ~parent:d ~protocol_version:v5 s ~name:"E" ~height:4 Pending
      in
      ( { genesis = Some g; boundary = settled 0 1 }
      , [ (("A", a), "canonical")
        ; (("B", b), "orphaned")
        ; (("genesis", g), "canonical")
        ; (("D", d), "pending")
        ; (("E", e), "pending")
        ] ) )

(* No fork genesis: nothing to settle, and pending blocks stay pending. *)
let no_fork_genesis server_uri () =
  run_scenario ~server_uri ~name:"test_settle_no_fork_genesis" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let b' = B.block ~parent:a s ~name:"B'" ~height:2 Pending in
      ( { genesis = None; boundary = None }
      , [ (("A", a), "canonical")
        ; (("B", b), "pending")
        ; (("B'", b'), "pending")
        ] ) )

(* A fork genesis that is not canonical, which the archive never stores
   (only an import of a block exported as pending, or a hand edit): refused,
   nothing changes. *)
let pending_fork_genesis server_uri () =
  run_scenario ~server_uri ~name:"test_settle_pending_genesis" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
      let b' = B.block ~parent:a s ~name:"B'" ~height:2 Pending in
      let g = fork_genesis s ~fork_block:b ~height:3 Pending in
      ( { genesis = Some g; boundary = Some Fork_genesis_not_canonical }
      , [ (("A", a), "canonical")
        ; (("B", b), "pending")
        ; (("B'", b'), "pending")
        ; (("genesis", g), "pending")
        ] ) )

(* Two forks in one archive (devnet and mainnet keep the Berkeley genesis): the
   newer fork genesis, by height, is settled; the older boundary is not
   touched. *)
let newest_of_two_forks server_uri () =
  run_scenario ~server_uri ~name:"test_settle_two_forks" (fun s ->
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let old_fork_sibling = B.block ~parent:a s ~name:"A'" ~height:2 Pending in
      let g1 =
        B.block ~parent:a ~protocol_version:v4 ~global_slot_since_hard_fork:0 s
          ~name:"genesis1" ~height:2 Canonical
      in
      let c =
        B.block ~parent:g1 ~global_slot_since_hard_fork:1 s ~name:"C" ~height:3
          Canonical
      in
      let d =
        B.block ~parent:c ~global_slot_since_hard_fork:2 s ~name:"D" ~height:4
          Pending
      in
      let d' =
        B.block ~parent:c ~global_slot_since_hard_fork:2 s ~name:"D'" ~height:4
          Pending
      in
      let g2 =
        B.block ~parent:d ~protocol_version:v5 ~global_slot_since_hard_fork:0 s
          ~name:"genesis2" ~height:5 Canonical
      in
      ( { genesis = Some g2; boundary = settled 1 1 }
      , [ (("A'", old_fork_sibling), "pending")
        ; (("genesis1", g1), "canonical")
        ; (("C", c), "canonical")
        ; (("D", d), "canonical")
        ; (("D'", d'), "orphaned")
        ; (("genesis2", g2), "canonical")
        ] ) )

(* A block of the ended chain stored after the boundary was settled, e.g. by
   a backfill, is pending (here: E set back to pending, as the archive stores
   it). Settling again, as convert-chain-to-canonical does on demand, orphans
   it and changes nothing else. *)
let late_block_of_ended_chain server_uri () =
  let s = B.create () in
  let expected, statuses = fork_mid_canonical () s in
  B.Db.with_fresh ~server_uri ~name:"test_settle_late_block" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind first = run db in
      check_result built expected first ;
      let e =
        List.find_map_exn statuses ~f:(fun ((name, b), _) ->
            Option.some_if (String.equal name "E") b )
      in
      let%bind () =
        with_conn db (fun (module Conn) ->
            Conn.exec
              (Mina_caqti.exec_req Caqti_type.int
                 "UPDATE blocks SET chain_status = 'pending' WHERE id = ?" )
              (B.block_id built e) )
      in
      let%bind again = run db in
      check_result built { expected with boundary = settled 0 1 } again ;
      check_statuses db built statuses )

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

(* --- startup with --config-file -------------------------------------------

   Processor.startup_with_config, as the archive runs it before it takes
   blocks: write the config's genesis, then with
   --settle-prefork-pending-blocks settle the boundary of its fork genesis
   once. *)

(* A real state hash: the config names the fork block by it, and the genesis
   block built from the config has it as its parent hash. *)
let real_state_hash seed =
  State_hash.to_base58_check
    (Quickcheck.random_value ~seed:(`Deterministic seed) State_hash.gen)

(* Each test has its own genesis ledger: the daemon code that loads a config's
   ledger keeps it in an on-disk cache named by its content, which one process
   can open once. *)
let config ~tag ?fork s =
  let accounts =
    List.map [ "alice"; "bob"; "carol" ] ~f:(fun name ->
        { Runtime_config.Accounts.Single.default with
          pk = B.public_key (B.account s (tag ^ "-" ^ name))
        ; balance = Currency.Balance.of_mina_int_exn 2000
        } )
  in
  { Runtime_config.default with
    proof =
      Option.map fork ~f:(fun (state_hash, height) ->
          Runtime_config.Proof_keys.make
            ~fork:
              { Runtime_config.Fork_config.state_hash
              ; blockchain_length = height
              ; global_slot_since_genesis = height
              }
            () )
  ; ledger = Some (Runtime_config.ledger_of_accounts accounts)
  }

(* The archive's startup on [db]: [Error] carries the message it stopped
   with. *)
let startup ?(settle = true) (db : B.Db.t) runtime_config =
  let precomputed = Lazy.force Precomputed_values.for_unit_tests in
  match Mina_caqti.connect_pool db.uri with
  | Error e ->
      Deferred.Or_error.error_string (Caqti_error.show e)
  | Ok pool ->
      (* drain the pool, or the database cannot be dropped *)
      Monitor.protect
        ~finally:(fun () -> Caqti_async.Pool.drain pool.Mina_caqti.Pool.pool)
        (fun () ->
          Monitor.try_with ~extract_exn:true (fun () ->
              Archive_lib.Processor.startup_with_config ~logger:(Logger.null ())
                ~genesis_constants:precomputed.genesis_constants
                ~constraint_constants:precomputed.constraint_constants
                ~chunks_length:2 ~runtime_config_opt:(Some runtime_config)
                ~settle_prefork_pending_blocks:settle pool )
          >>| Result.map_error ~f:Exn.to_string
          |> Deferred.ok )

let expect_ok what = function
  | Ok () ->
      ()
  | Error msg ->
      Alcotest.failf "%s failed: %s" what msg

let expect_failure what ~mentioning = function
  | Ok () ->
      Alcotest.failf "%s: expected the archive to stop" what
  | Error msg ->
      if not (String.is_substring msg ~substring:mentioning) then
        Alcotest.failf "%s: stopped with an unexpected message: %s" what msg

let exec db sql =
  with_conn db (fun (module Conn) ->
      Conn.exec (Mina_caqti.exec_req Caqti_type.unit sql) () )

(* The chain status of each genesis block (global slot since hard fork 0) at
   [height]. *)
let genesis_statuses db ~height =
  with_conn db (fun (module Conn) ->
      Conn.collect_list
        (Mina_caqti.collect_req Caqti_type.int Caqti_type.string
           "SELECT chain_status::text FROM blocks WHERE height = ? AND \
            global_slot_since_hard_fork = 0 ORDER BY id" )
        height )

(* The old chain went on past its fork block C (height 3): D is canonical, E
   pending. The fork genesis, at height 4, is stored at startup. *)
let fork_chain ~fork_hash s =
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b = B.block ~parent:a s ~name:"B" ~height:2 Canonical in
  let c =
    B.block ~state_hash:fork_hash ~parent:b s ~name:"C" ~height:3 Canonical
  in
  let d = B.block ~parent:c s ~name:"D" ~height:4 Canonical in
  let e = B.block ~parent:d s ~name:"E" ~height:5 Pending in
  [ ("A", a); ("B", b); ("C", c); ("D", d); ("E", e) ]

let settled_fork_chain =
  [ "canonical"; "canonical"; "canonical"; "orphaned"; "orphaned" ]

let unsettled_fork_chain =
  [ "canonical"; "canonical"; "canonical"; "canonical"; "pending" ]

let check_chain db built blocks want =
  check_statuses db built
    (List.map2_exn blocks want ~f:(fun (name, block) status ->
         ((name, block), status) ) )

(* The fork genesis is stored at startup and its boundary settled; a second
   start changes nothing. *)
let startup_settles_once server_uri () =
  let s = B.create () in
  let tag = "startup_settles_once" in
  let fork_hash = real_state_hash tag in
  let blocks = fork_chain ~fork_hash s in
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_settles_once" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind first = startup db runtime_config in
      expect_ok "startup" first ;
      let%bind genesis = genesis_statuses db ~height:4 in
      Alcotest.(check (list string)) "fork genesis" [ "canonical" ] genesis ;
      let%bind () = check_chain db built blocks settled_fork_chain in
      let%bind again = startup db runtime_config in
      expect_ok "second startup" again ;
      check_chain db built blocks settled_fork_chain )

(* Without --settle-prefork-pending-blocks the prefork blocks are left as
   they are. *)
let startup_without_settle server_uri () =
  let s = B.create () in
  let tag = "startup_without_settle" in
  let fork_hash = real_state_hash tag in
  let blocks = fork_chain ~fork_hash s in
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_without_settle" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind result = startup ~settle:false db runtime_config in
      expect_ok "startup" result ;
      check_chain db built blocks unsettled_fork_chain )

(* The fork genesis was stored, then made pending (an import, a hand edit):
   the archive stops rather than settle on it, and changes nothing. *)
let startup_refuses_pending_genesis server_uri () =
  let s = B.create () in
  let tag = "startup_refuses_pending_genesis" in
  let fork_hash = real_state_hash tag in
  let blocks = fork_chain ~fork_hash s in
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_pending_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind first = startup ~settle:false db runtime_config in
      expect_ok "first startup" first ;
      let%bind () =
        exec db
          "UPDATE blocks SET chain_status = 'pending' WHERE height = 4 AND \
           global_slot_since_hard_fork = 0"
      in
      let%bind second = startup db runtime_config in
      expect_failure "a pending fork genesis" ~mentioning:"not canonical" second ;
      check_chain db built blocks unsettled_fork_chain )

(* Devnet and mainnet keep an older fork genesis (Berkeley's), with its own
   unsettled leftovers: startup settles the boundary of its config's fork,
   not the older one. *)
let startup_with_older_fork server_uri () =
  let s = B.create () in
  let tag = "startup_with_older_fork" in
  let fork_hash = real_state_hash tag in
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let a' = B.block ~parent:a s ~name:"A'" ~height:2 Pending in
  let g1 =
    B.block ~parent:a ~global_slot_since_hard_fork:0 s ~name:"genesis1"
      ~height:2 Canonical
  in
  let c = B.block ~parent:g1 s ~name:"C" ~height:3 Canonical in
  let d =
    B.block ~state_hash:fork_hash ~parent:c s ~name:"D" ~height:4 Pending
  in
  let d' = B.block ~parent:c s ~name:"D'" ~height:4 Pending in
  let runtime_config = config ~tag ~fork:(fork_hash, 4) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_older_fork" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind result = startup db runtime_config in
      expect_ok "startup" result ;
      check_statuses db built
        [ (("A'", a'), "pending")
        ; (("genesis1", g1), "canonical")
        ; (("C", c), "canonical")
        ; (("D", d), "canonical")
        ; (("D'", d'), "orphaned")
        ] )

(* The fork block is not in the archive yet: nothing is settled, the archive
   starts, and convert-chain-to-canonical settles it after a backfill. *)
let startup_fork_block_missing server_uri () =
  let s = B.create () in
  let tag = "startup_fork_block_missing" in
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b = B.block ~parent:a s ~name:"B" ~height:2 Pending in
  let runtime_config = config ~tag ~fork:(real_state_hash tag, 2) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_fork_block_missing" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind result = startup db runtime_config in
      expect_ok "startup" result ;
      check_statuses db built [ (("A", a), "canonical"); (("B", b), "pending") ] )

(* A config that starts a new chain, not a hard fork: nothing to settle. *)
let startup_new_chain server_uri () =
  let s = B.create () in
  let runtime_config = config ~tag:"startup_new_chain" s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_new_chain" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind result = startup db runtime_config in
      expect_ok "startup" result ;
      let%map genesis = genesis_statuses db ~height:1 in
      Alcotest.(check (list string)) "genesis" [ "canonical" ] genesis )

(* Two hard forks in turn, each settled at its archive's startup. Fork A at
   FA, pending: FA becomes canonical, FA', which competes with it, is
   orphaned. The chain fork A starts goes on
   to fork B's block FB, which FB' competes with: fork B's startup makes FB
   canonical and orphans FB'. *)
let startup_two_forks server_uri () =
  let s = B.create () in
  let tag = "startup_two_forks" in
  let fork_a_hash = real_state_hash (tag ^ "-a") in
  let fork_b_hash = real_state_hash (tag ^ "-b") in
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let fa =
    B.block ~state_hash:fork_a_hash ~parent:a s ~name:"FA" ~height:2 Pending
  in
  let fa' = B.block ~parent:a s ~name:"FA'" ~height:2 Pending in
  (* P1 follows fork A's genesis, which is not in the archive until fork A's
     startup: it is linked to it then *)
  let p1 =
    B.block ~global_slot_since_genesis:3 ~global_slot_since_hard_fork:1
      ~protocol_version:v5 s ~name:"P1" ~height:4 Canonical
  in
  let fb =
    B.block ~state_hash:fork_b_hash ~parent:p1 ~global_slot_since_genesis:4
      ~global_slot_since_hard_fork:2 ~protocol_version:v5 s ~name:"FB" ~height:5
      Pending
  in
  let fb' =
    B.block ~parent:p1 ~global_slot_since_genesis:4
      ~global_slot_since_hard_fork:2 ~protocol_version:v5 s ~name:"FB'"
      ~height:5 Pending
  in
  let config_a = config ~tag:(tag ^ "-a") ~fork:(fork_a_hash, 2) s in
  let config_b = config ~tag:(tag ^ "-b") ~fork:(fork_b_hash, 5) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_two_forks" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind first = startup db config_a in
      expect_ok "startup with fork A's config" first ;
      let%bind () =
        check_statuses db built
          [ (("FA", fa), "canonical"); (("FA'", fa'), "orphaned") ]
      in
      (* link P1 to fork A's genesis, as the archive does for a block stored
         after its parent *)
      let%bind () =
        exec db
          (sprintf
             "UPDATE blocks p1 SET parent_id = g.id, parent_hash = \
              g.state_hash FROM blocks g WHERE p1.id = %d AND g.height = 3 AND \
              g.global_slot_since_hard_fork = 0"
             (B.block_id built p1) )
      in
      let%bind second = startup db config_b in
      expect_ok "startup with fork B's config" second ;
      let%bind ga = genesis_statuses db ~height:3 in
      Alcotest.(check (list string)) "fork A's genesis" [ "canonical" ] ga ;
      let%bind gb = genesis_statuses db ~height:6 in
      Alcotest.(check (list string)) "fork B's genesis" [ "canonical" ] gb ;
      check_statuses db built
        [ (("A", a), "canonical")
        ; (("FA", fa), "canonical")
        ; (("FA'", fa'), "orphaned")
        ; (("P1", p1), "canonical")
        ; (("FB", fb), "canonical")
        ; (("FB'", fb'), "orphaned")
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
        ; Alcotest.test_case "fork on the last canonical block" `Quick
            (run fork_on_last_canonical)
        ; Alcotest.test_case "fork on a new network" `Quick
            (run fork_on_new_network)
        ; Alcotest.test_case "no fork genesis" `Quick (run no_fork_genesis)
        ; Alcotest.test_case "pending fork genesis is refused" `Quick
            (run pending_fork_genesis)
        ; Alcotest.test_case "newest of two forks" `Quick
            (run newest_of_two_forks)
        ; Alcotest.test_case "dry run, then idempotent" `Quick
            (run dry_run_and_idempotence)
        ; Alcotest.test_case "late block of the ended chain" `Quick
            (run late_block_of_ended_chain)
        ] )
    ; ( "startup"
      , [ Alcotest.test_case "settles once" `Quick (run startup_settles_once)
        ; Alcotest.test_case "without --settle-prefork-pending-blocks" `Quick
            (run startup_without_settle)
        ; Alcotest.test_case "refuses a pending fork genesis" `Quick
            (run startup_refuses_pending_genesis)
        ; Alcotest.test_case "with an older fork in the archive" `Quick
            (run startup_with_older_fork)
        ; Alcotest.test_case "fork block missing" `Quick
            (run startup_fork_block_missing)
        ; Alcotest.test_case "a new chain's config" `Quick
            (run startup_new_chain)
        ; Alcotest.test_case "two forks in turn" `Quick (run startup_two_forks)
        ] )
    ]
