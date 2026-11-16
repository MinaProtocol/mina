(* Archive_lib.Settle_pending_blocks against hand-built archives: what it
   makes canonical, what it orphans, and what it must leave alone; next to the
   archive's own canonical marking; and at the archive's startup. Each test
   case is a scenario (Settle_scenario): its blocks, then steps with what each
   expects. Needs a PostgreSQL server: MINA_TEST_POSTGRES (any database path is
   ignored). *)

open Core
open Async
open Settle_scenario

(* --- settle_pending_blocks ------------------------------------------------ *)

(* The archive canonicalized the old chain past the fork block C before the
   new chain arrived: D and E go on past C, and the fork genesis shares D's
   height. *)
let fork_mid_canonical ?(protocol_version = v5) () =
  [ block "A" ~height:1 Canonical
  ; block "B" ~parent:"A" ~height:2 Canonical
  ; block "C" ~parent:"B" ~height:3 Canonical
  ; block "D" ~parent:"C" ~height:4 Canonical
  ; block "E" ~parent:"D" ~height:5 Pending
  ; fork_genesis ~fork_block:"C" ~protocol_version ~height:4 ()
  ; block "N" ~parent:"genesis" ~protocol_version ~height:5 Pending
  ]

let fork_mid_canonical_settled =
  [ ("A", Canonical)
  ; ("B", Canonical)
  ; ("C", Canonical)
  ; ("D", Orphaned)
  ; ("E", Orphaned)
  ; ("genesis", Canonical)
  ; ("N", Pending)
  ]

let fork_in_canonical_chain =
  { name = "fork in the canonical chain"
  ; blocks = fork_mid_canonical ()
  ; steps = [ Settle (settled 0 2); Expect fork_mid_canonical_settled ]
  }

(* An emergency fork that keeps the protocol version: parent links only. *)
let fork_same_version =
  { name = "fork without a protocol version bump"
  ; blocks = fork_mid_canonical ~protocol_version:v4 ()
  ; steps = [ Settle (settled 0 2); Expect fork_mid_canonical_settled ]
  }

(* The watermark is behind the fork block C: its pending ancestry becomes
   canonical, the competitors D and E are orphaned. *)
let fork_on_pending =
  { name = "fork on a pending block"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "C" ~parent:"B" ~height:3 Pending
      ; block "D" ~parent:"B" ~height:3 Pending
      ; block "E" ~parent:"D" ~height:4 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ]
  ; steps =
      [ Settle (settled 2 2)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("C", Canonical)
          ; ("D", Orphaned)
          ; ("E", Orphaned)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* The archive orphaned the fork block B and made its sibling B' canonical:
   the fork genesis says otherwise. *)
let fork_on_orphaned =
  { name = "fork on an orphaned block"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Orphaned
      ; block "B'" ~parent:"A" ~height:2 Canonical
      ; fork_genesis ~fork_block:"B" ~height:3 ()
      ]
  ; steps =
      [ Settle (settled 1 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("B'", Orphaned)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* The fork genesis has no parent link yet, but its fork block B is in the
   archive: found by the genesis's parent hash. *)
let fork_genesis_without_parent_link =
  { name = "fork genesis without a parent link"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "B'" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~fork_block:"B" ~unlinked:true ~height:3 ()
      ]
  ; steps =
      [ Settle (settled 1 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("B'", Orphaned)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* The fork block is not in the archive at all: nothing to anchor to. *)
let fork_block_missing =
  { name = "fork block missing"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~height:4 ()
      ]
  ; steps =
      [ Settle (unsettled No_fork_block)
      ; Expect [ ("B", Pending); ("genesis", Canonical) ]
      ]
  }

(* No canonical block on the fork block's ancestry. *)
let fork_unanchored =
  { name = "fork without a canonical anchor"
  ; blocks =
      [ block "A" ~height:1 Pending
      ; block "B" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~fork_block:"B" ~height:3 ()
      ]
  ; steps =
      [ Settle (unsettled No_canonical_ancestor)
      ; Expect [ ("A", Pending); ("B", Pending); ("genesis", Canonical) ]
      ]
  }

(* The fork block C is the highest canonical block; the old chain went on
   past it as pending blocks, which are orphaned. *)
let fork_on_last_canonical =
  { name = "fork on the last canonical block"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Canonical
      ; block "C" ~parent:"B" ~height:3 Canonical
      ; block "D" ~parent:"C" ~height:4 Pending
      ; block "E" ~parent:"D" ~height:5 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ]
  ; steps =
      [ Settle (settled 0 2)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("C", Canonical)
          ; ("D", Orphaned)
          ; ("E", Orphaned)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* A fork right after the first genesis: the old chain's canonical block B is
   a sibling of the fork genesis and is orphaned. The new chain's own pending
   blocks are left to the archive's canonical marking. *)
let fork_on_new_network =
  { name = "fork on a new network"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Canonical
      ; fork_genesis ~fork_block:"A" ~height:2 ()
      ; postfork "D" ~parent:"genesis" ~height:3 Pending
      ; postfork "E" ~parent:"D" ~height:4 Pending
      ]
  ; steps =
      [ Settle (settled 0 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Orphaned)
          ; ("genesis", Canonical)
          ; ("D", Pending)
          ; ("E", Pending)
          ]
      ]
  }

(* No fork genesis: nothing to settle, and pending blocks stay pending. *)
let no_fork_genesis =
  { name = "no fork genesis"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "B'" ~parent:"A" ~height:2 Pending
      ]
  ; steps =
      [ Settle no_fork
      ; Expect [ ("A", Canonical); ("B", Pending); ("B'", Pending) ]
      ]
  }

(* A fork genesis that is not canonical, which the archive never stores
   (only an import of a block exported as pending, or a hand edit): refused,
   nothing changes. *)
let pending_fork_genesis =
  { name = "pending fork genesis is refused"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "B'" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~fork_block:"B" ~status:Pending ~height:3 ()
      ]
  ; steps =
      [ Settle (unsettled Fork_genesis_not_canonical)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Pending)
          ; ("B'", Pending)
          ; ("genesis", Pending)
          ]
      ]
  }

(* Two forks in one archive (devnet and mainnet keep the Berkeley genesis): the
   newer fork genesis, by height, is settled; the older boundary (A') is not
   touched. *)
let newest_of_two_forks =
  { name = "newest of two forks"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "A'" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~name:"genesis1" ~fork_block:"A" ~protocol_version:v4
          ~height:2 ()
      ; block "C" ~parent:"genesis1" ~global_slot_since_hard_fork:1 ~height:3
          Canonical
      ; block "D" ~parent:"C" ~global_slot_since_hard_fork:2 ~height:4 Pending
      ; block "D'" ~parent:"C" ~global_slot_since_hard_fork:2 ~height:4 Pending
      ; fork_genesis ~name:"genesis2" ~fork_block:"D" ~height:5 ()
      ]
  ; steps =
      [ Settle (settled ~genesis:"genesis2" 1 1)
      ; Expect
          [ ("A'", Pending)
          ; ("genesis1", Canonical)
          ; ("C", Canonical)
          ; ("D", Canonical)
          ; ("D'", Orphaned)
          ; ("genesis2", Canonical)
          ]
      ]
  }

(* A dry run reports what a run changes and changes nothing; a second run
   finds nothing left to change. *)
let dry_run_and_idempotence =
  { name = "dry run, then idempotent"
  ; blocks = fork_mid_canonical ()
  ; steps =
      [ Dry_run (settled 0 2)
      ; Expect [ ("D", Canonical); ("E", Pending) ]
      ; Settle (settled 0 2)
      ; Settle (settled 0 0)
      ; Expect fork_mid_canonical_settled
      ]
  }

(* A block of the ended chain stored after the boundary was settled, e.g. by
   a backfill, is pending (here: E set back to pending, as the archive stores
   it). Settling again, as convert-chain-to-canonical does on demand, orphans
   it and changes nothing else. *)
let late_block_of_ended_chain =
  { name = "late block of the ended chain"
  ; blocks = fork_mid_canonical ()
  ; steps =
      [ Settle (settled 0 2)
      ; Set_status ("E", Pending)
      ; Settle (settled 0 1)
      ; Expect fork_mid_canonical_settled
      ]
  }

(* The ended chain has a gap: E's parent D is not in the archive, so E has no
   parent link and settling, which follows parent links, cannot reach it. E
   stays pending; "block after a gap in the ended chain" in the canonical
   marking group shows what orphans it. *)
let gap_in_ended_chain =
  { name = "gap in the ended chain"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Canonical
      ; block "C" ~parent:"B" ~height:3 Pending
      ; block "E" ~height:5 Pending
      ; fork_genesis ~fork_block:"B" ~height:3 ()
      ]
  ; steps =
      [ Settle (settled 0 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("C", Orphaned)
          ; ("E", Pending)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* The fork block C's parent is not in the archive: its ancestry stops at the
   gap before any canonical block, so nothing changes. *)
let fork_block_behind_gap =
  { name = "fork block behind a gap"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "C" ~height:3 Pending
      ; block "C'" ~height:3 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ]
  ; steps =
      [ Settle (unsettled No_canonical_ancestor)
      ; Expect
          [ ("A", Canonical)
          ; ("C", Pending)
          ; ("C'", Pending)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* --- canonical marking ------------------------------------------------------

   As each block arrives the archive runs Processor.Block.update_chain_status
   (the Mark step, with k = 2): once a block is k above the highest canonical
   block, the chain k below it becomes canonical and every other block at
   those heights is orphaned; a block below the highest canonical block (a
   backfill) makes the chain between the canonical blocks around it canonical,
   the same way. *)

(* After settling, the new chain's blocks are marked from the fork genesis
   on; the settled boundary is left as it is. *)
let marking_after_settle =
  { name = "new chain marked after settling"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Canonical
      ; block "C" ~parent:"B" ~height:3 Canonical
      ; block "D" ~parent:"C" ~height:4 Pending
      ; block "E" ~parent:"D" ~height:5 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ; postfork "N1" ~parent:"genesis" ~height:5 Pending
      ; postfork "N2" ~parent:"N1" ~height:6 Pending
      ; postfork "N3" ~parent:"N2" ~height:7 Pending
      ]
  ; steps =
      [ Settle (settled 0 2)
      ; Mark "N3"
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("C", Canonical)
          ; ("D", Orphaned)
          ; ("E", Orphaned)
          ; ("genesis", Canonical)
          ; ("N1", Canonical)
          ; ("N2", Pending)
          ; ("N3", Pending)
          ]
      ]
  }

(* Without settling, the marking of the new chain orphans the old chain's
   blocks at the new chain's heights (D, beside the fork genesis), but never
   reaches the blocks below the fork genesis: B, C and C' stay pending however
   long the new chain grows. Settling finishes them. *)
let marking_without_settle =
  { name = "new chain marked without settling"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "C" ~parent:"B" ~height:3 Pending
      ; block "C'" ~parent:"B" ~height:3 Pending
      ; block "D" ~parent:"C" ~height:4 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ; postfork "N1" ~parent:"genesis" ~height:5 Pending
      ; postfork "N2" ~parent:"N1" ~height:6 Pending
      ; postfork "N3" ~parent:"N2" ~height:7 Pending
      ]
  ; steps =
      [ Mark "N3"
      ; Expect
          [ ("A", Canonical)
          ; ("B", Pending)
          ; ("C", Pending)
          ; ("C'", Pending)
          ; ("D", Orphaned)
          ; ("genesis", Canonical)
          ; ("N1", Canonical)
          ]
      ; Settle (settled 2 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("C", Canonical)
          ; ("C'", Orphaned)
          ; ("D", Orphaned)
          ; ("genesis", Canonical)
          ; ("N1", Canonical)
          ]
      ]
  }

(* A prefork block X backfilled below the fork genesis, without settling: the
   archive makes the chain between the canonical blocks around it (A below,
   the fork genesis above) canonical and orphans the rest at those heights,
   which settles the boundary below the fork genesis. A later settle finds
   nothing left. *)
let backfill_without_settle =
  let settled_by_backfill =
    [ ("A", Canonical)
    ; ("B", Canonical)
    ; ("C", Canonical)
    ; ("C'", Orphaned)
    ; ("genesis", Canonical)
    ; ("X", Orphaned)
    ]
  in
  { name = "backfill below the fork genesis, not settled"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "C" ~parent:"B" ~height:3 Pending
      ; block "C'" ~parent:"B" ~height:3 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ; block "X" ~parent:"A" ~height:2 Pending
      ]
  ; steps =
      [ Mark "X"
      ; Expect settled_by_backfill
      ; Settle (settled 0 0)
      ; Expect settled_by_backfill
      ]
  }

(* A pending block X that competes with the chain below the settle's anchor
   (beside the canonical fork block C) is not part of the ended chain, so
   settling leaves it; the marking orphans it when it arrives, as for any
   backfilled block. *)
let backfill_after_settle =
  { name = "backfill after settling"
  ; blocks = fork_mid_canonical () @ [ block "X" ~parent:"B" ~height:3 Pending ]
  ; steps =
      [ Settle (settled 0 2)
      ; Expect [ ("X", Pending) ]
      ; Mark "X"
      ; Expect (fork_mid_canonical_settled @ [ ("X", Orphaned) ])
      ]
  }

(* E, after a gap in the ended chain, which settling cannot reach, is
   orphaned once the new chain is k above its height. *)
let gap_in_ended_chain_marked =
  { name = "block after a gap in the ended chain"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Canonical
      ; block "C" ~parent:"B" ~height:3 Pending
      ; block "E" ~height:5 Pending
      ; fork_genesis ~fork_block:"B" ~height:3 ()
      ; postfork "N1" ~parent:"genesis" ~height:4 Pending
      ; postfork "N2" ~parent:"N1" ~height:5 Pending
      ; postfork "N3" ~parent:"N2" ~height:6 Pending
      ; postfork "N4" ~parent:"N3" ~height:7 Pending
      ]
  ; steps =
      [ Settle (settled 0 1)
      ; Expect [ ("E", Pending) ]
      ; Mark "N4"
      ; Expect
          [ ("C", Orphaned)
          ; ("E", Orphaned)
          ; ("genesis", Canonical)
          ; ("N1", Canonical)
          ; ("N2", Canonical)
          ; ("N3", Pending)
          ]
      ]
  }

(* --- startup with --config-file ---------------------------------------------

   Processor.startup_with_config, as the archive runs it before it takes
   blocks: write the genesis of --config-file, then with
   --settle-prefork-pending-blocks settle the boundary of its fork genesis
   once. *)

(* The --config-file of a startup. *)
type config =
  | Fork_at of string  (** A hard fork at this block of the scenario. *)
  | Fork_not_in_archive of int
      (** A hard fork at a block of this height that is not in the archive. *)
  | New_chain  (** A config that starts a new chain, not a hard fork. *)
  | No_config_file

type startup_result = Starts | Stops_mentioning of string

(* Each config has its own genesis ledger, named by the test case and [tag]:
   the daemon code that loads a config's ledger keeps it in an on-disk cache
   named by its content, which one process can open once. *)
let runtime_config ctx ~tag ~fork =
  let accounts =
    List.map [ "alice"; "bob"; "carol" ] ~f:(fun name ->
        { Runtime_config.Accounts.Single.default with
          pk = ctx.public_key (sprintf "%s %s %s" ctx.test tag name)
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

(* The archive's startup: [Ok (Error msg)] when it stopped with [msg]. *)
let run_startup (db : Synthetic_archive.Db.t) ~settle runtime_config_opt =
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
                ~chunks_length:2 ~runtime_config_opt
                ~settle_prefork_pending_blocks:settle pool )
          >>| Result.map_error ~f:Exn.to_string
          |> Deferred.ok )

let describe_config = function
  | Fork_at name ->
      "the fork at " ^ name
  | Fork_not_in_archive height ->
      sprintf "a fork at height %d, not in the archive" height
  | New_chain ->
      "a new chain's config"
  | No_config_file ->
      "no --config-file"

(* A startup step: the archive starts with [config] (and
   --settle-prefork-pending-blocks unless [~settle:false]) and [expect]s to
   start or to stop. *)
let startup ?(settle = true) ?(expect = Starts) config =
  let check = function
    | Starts, Ok () ->
        Ok ()
    | Starts, Error msg ->
        Or_error.errorf "the archive stopped: %s" msg
    | Stops_mentioning expected, Ok () ->
        Or_error.errorf "expected the archive to stop (%s)" expected
    | Stops_mentioning expected, Error msg ->
        if String.is_substring msg ~substring:expected then Ok ()
        else
          Or_error.errorf "the archive stopped with an unexpected message: %s"
            msg
  in
  Do
    ( sprintf "startup with %s%s" (describe_config config)
        (if settle then ", settling" else "")
    , fun ctx ->
        let runtime_config_opt =
          match config with
          | No_config_file ->
              None
          | New_chain ->
              Some (runtime_config ctx ~tag:"new chain" ~fork:None)
          | Fork_at name ->
              Some
                (runtime_config ctx ~tag:name
                   ~fork:(Some (ctx.state_hash name, ctx.height name)) )
          | Fork_not_in_archive height ->
              Some
                (runtime_config ctx ~tag:"missing fork block"
                   ~fork:
                     (Some
                        ( state_hash_not_in_archive ~test:ctx.test "fork block"
                        , height ) ) )
        in
        let%map.Deferred result =
          run_startup ctx.db ~settle runtime_config_opt
        in
        Or_error.bind result ~f:(fun result -> check (expect, result)) )

(* The old chain went on past its fork block C (height 3): D is canonical, E
   pending. The fork genesis, at height 4, is stored at startup. *)
let fork_chain =
  [ block "A" ~height:1 Canonical
  ; block "B" ~parent:"A" ~height:2 Canonical
  ; block "C" ~parent:"B" ~height:3 Canonical
  ; block "D" ~parent:"C" ~height:4 Canonical
  ; block "E" ~parent:"D" ~height:5 Pending
  ]

let fork_chain_settled =
  [ ("A", Canonical)
  ; ("B", Canonical)
  ; ("C", Canonical)
  ; ("D", Orphaned)
  ; ("E", Orphaned)
  ]

let fork_chain_unsettled =
  [ ("A", Canonical)
  ; ("B", Canonical)
  ; ("C", Canonical)
  ; ("D", Canonical)
  ; ("E", Pending)
  ]

(* The fork genesis is stored at startup and its boundary settled; a second
   start changes nothing. *)
let startup_settles_once =
  { name = "settles once"
  ; blocks = fork_chain
  ; steps =
      [ startup (Fork_at "C")
      ; Expect_geneses (4, [ Canonical ])
      ; Expect fork_chain_settled
      ; startup (Fork_at "C")
      ; Expect fork_chain_settled
      ]
  }

(* Without --settle-prefork-pending-blocks the prefork blocks are left as
   they are. *)
let startup_without_settle =
  { name = "without --settle-prefork-pending-blocks"
  ; blocks = fork_chain
  ; steps = [ startup ~settle:false (Fork_at "C"); Expect fork_chain_unsettled ]
  }

(* The fork genesis was stored, then made pending (an import, a hand edit):
   the archive stops rather than settle on it, and changes nothing. *)
let startup_refuses_pending_genesis =
  { name = "refuses a pending fork genesis"
  ; blocks = fork_chain
  ; steps =
      [ startup ~settle:false (Fork_at "C")
      ; Sql
          "UPDATE blocks SET chain_status = 'pending' WHERE height = 4 AND \
           global_slot_since_hard_fork = 0"
      ; startup ~expect:(Stops_mentioning "not canonical") (Fork_at "C")
      ; Expect fork_chain_unsettled
      ]
  }

(* Devnet and mainnet keep an older fork genesis (Berkeley's), with its own
   unsettled leftovers (A'): startup settles the boundary of its config's
   fork, not the older one. *)
let startup_with_older_fork =
  { name = "with an older fork in the archive"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "A'" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~name:"genesis1" ~fork_block:"A" ~protocol_version:v4
          ~height:2 ()
      ; block "C" ~parent:"genesis1" ~height:3 Canonical
      ; block "D" ~parent:"C" ~height:4 Pending
      ; block "D'" ~parent:"C" ~height:4 Pending
      ]
  ; steps =
      [ startup (Fork_at "D")
      ; Expect
          [ ("A'", Pending)
          ; ("genesis1", Canonical)
          ; ("C", Canonical)
          ; ("D", Canonical)
          ; ("D'", Orphaned)
          ]
      ]
  }

(* The fork block is not in the archive yet: nothing is settled, the archive
   starts, and convert-chain-to-canonical settles it after a backfill. *)
let startup_fork_block_missing =
  { name = "fork block missing"
  ; blocks =
      [ block "A" ~height:1 Canonical; block "B" ~parent:"A" ~height:2 Pending ]
  ; steps =
      [ startup (Fork_not_in_archive 2)
      ; Expect [ ("A", Canonical); ("B", Pending) ]
      ]
  }

(* A config that starts a new chain, not a hard fork: nothing to settle. *)
let startup_new_chain =
  { name = "a new chain's config"
  ; blocks = []
  ; steps = [ startup New_chain; Expect_geneses (1, [ Canonical ]) ]
  }

(* Two hard forks in turn, each settled at its archive's startup. Fork A at
   FA, pending: FA becomes canonical, FA', which competes with it, is
   orphaned. The chain fork A starts goes on to fork B's block FB, which FB'
   competes with: fork B's startup makes FB canonical and orphans FB'. P1
   follows fork A's genesis, which is not in the archive until fork A's
   startup: it is linked to it then, as the archive links a block stored
   before its parent. *)
let startup_two_forks =
  { name = "two forks in turn"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "FA" ~parent:"A" ~height:2 Pending
      ; block "FA'" ~parent:"A" ~height:2 Pending
      ; postfork "P1" ~global_slot_since_genesis:3
          ~global_slot_since_hard_fork:1 ~height:4 Canonical
      ; postfork "FB" ~parent:"P1" ~global_slot_since_genesis:4
          ~global_slot_since_hard_fork:2 ~height:5 Pending
      ; postfork "FB'" ~parent:"P1" ~global_slot_since_genesis:4
          ~global_slot_since_hard_fork:2 ~height:5 Pending
      ]
  ; steps =
      [ startup (Fork_at "FA")
      ; Expect [ ("FA", Canonical); ("FA'", Orphaned) ]
      ; Do
          ( "link P1 to fork A's genesis"
          , fun ctx ->
              exec ctx
                (sprintf
                   "UPDATE blocks p1 SET parent_id = g.id, parent_hash = \
                    g.state_hash FROM blocks g WHERE p1.id = %d AND g.height = \
                    3 AND g.global_slot_since_hard_fork = 0"
                   (ctx.id "P1") ) )
      ; startup (Fork_at "FB")
      ; Expect_geneses (3, [ Canonical ])
      ; Expect_geneses (6, [ Canonical ])
      ; Expect
          [ ("A", Canonical)
          ; ("FA", Canonical)
          ; ("FA'", Orphaned)
          ; ("P1", Canonical)
          ; ("FB", Canonical)
          ; ("FB'", Orphaned)
          ]
      ]
  }

(* The archive holds another config's genesis on the same fork block: which
   boundary to settle is ambiguous, so the archive stops and changes
   nothing. *)
let startup_two_geneses_on_fork_block =
  { name = "two fork geneses on the fork block"
  ; blocks =
      fork_chain
      @ [ fork_genesis ~name:"other genesis" ~fork_block:"C" ~height:4 () ]
  ; steps =
      [ startup ~expect:(Stops_mentioning "2 fork geneses") (Fork_at "C")
      ; Expect fork_chain_unsettled
      ]
  }

(* --settle-prefork-pending-blocks without --config-file: the archive does
   not know the fork, warns, starts, and changes nothing. *)
let startup_settle_without_config =
  { name = "flag without --config-file"
  ; blocks = fork_chain
  ; steps = [ startup No_config_file; Expect fork_chain_unsettled ]
  }

let () =
  let server_uri = Synthetic_archive.Db.test_server_uri () in
  let group name cases =
    (name, List.map cases ~f:(test_case ~server_uri ~group:name))
  in
  Alcotest.run "settle_pending_blocks"
    [ group "settle_pending_blocks"
        [ fork_in_canonical_chain
        ; fork_same_version
        ; fork_on_pending
        ; fork_on_orphaned
        ; fork_genesis_without_parent_link
        ; fork_block_missing
        ; fork_unanchored
        ; fork_on_last_canonical
        ; fork_on_new_network
        ; no_fork_genesis
        ; pending_fork_genesis
        ; newest_of_two_forks
        ; dry_run_and_idempotence
        ; late_block_of_ended_chain
        ; gap_in_ended_chain
        ; fork_block_behind_gap
        ]
    ; group "canonical marking"
        [ marking_after_settle
        ; marking_without_settle
        ; backfill_without_settle
        ; backfill_after_settle
        ; gap_in_ended_chain_marked
        ]
    ; group "startup"
        [ startup_settles_once
        ; startup_without_settle
        ; startup_refuses_pending_genesis
        ; startup_with_older_fork
        ; startup_fork_block_missing
        ; startup_new_chain
        ; startup_two_forks
        ; startup_two_geneses_on_fork_block
        ; startup_settle_without_config
        ]
    ]
