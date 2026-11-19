(* Archive_lib.Settle_pending_blocks against hand-built archives: what it
   makes canonical, what it orphans, and what it must leave alone; next to the
   archive's own canonical marking; and at the archive's startup. A test case
   is its input blocks and the chain statuses they end with
   (Settle_scenario); each group below says what its tests do with them.
   Needs a PostgreSQL server: MINA_TEST_POSTGRES (any database path is
   ignored). *)

open Core
open Async
open Settle_scenario

(* --- settle_pending_blocks ---------------------------------------------------

   Each case is settled three times: a dry run, which reports the outcome and
   changes nothing; the run, which changes the outcome's blocks and nothing
   else; and a second run, which finds nothing left to change. *)

let settle_test ~server_uri (c : case) =
  test ~server_uri ~group:"settle_pending_blocks" ~name:c.name c.blocks
    (fun ctx ->
      let open Deferred.Or_error.Let_syntax in
      let settles ?dry_run outcome ~then_changed =
        let%bind got = settle ?dry_run ctx in
        let%bind () = Deferred.return (check_result ctx outcome got) in
        check_statuses ctx then_changed
      in
      let again =
        match c.outcome with Settled _ -> Settled [] | other -> other
      in
      let%bind () =
        step "dry run" (settles ~dry_run:true c.outcome ~then_changed:[])
      in
      let%bind () =
        step "run" (settles c.outcome ~then_changed:(changes c.outcome))
      in
      step "second run" (settles again ~then_changed:(changes c.outcome)) )

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

let settle_cases =
  [ { name = "fork in the canonical chain"
    ; blocks = fork_mid_canonical ()
    ; outcome = Settled [ ("D", Orphaned); ("E", Orphaned) ]
    }
  ; (* An emergency fork that keeps the protocol version: parent links
       only. *)
    { name = "fork without a protocol version bump"
    ; blocks = fork_mid_canonical ~protocol_version:v4 ()
    ; outcome = Settled [ ("D", Orphaned); ("E", Orphaned) ]
    }
  ; (* The watermark is behind the fork block C: its pending ancestry becomes
       canonical, the competitors D and E are orphaned. *)
    { name = "fork on a pending block"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "C" ~parent:"B" ~height:3 Pending
        ; block "D" ~parent:"B" ~height:3 Pending
        ; block "E" ~parent:"D" ~height:4 Pending
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ]
    ; outcome =
        Settled
          [ ("B", Canonical)
          ; ("C", Canonical)
          ; ("D", Orphaned)
          ; ("E", Orphaned)
          ]
    }
  ; (* The archive orphaned the fork block B and made its sibling B'
       canonical: the fork genesis says otherwise. *)
    { name = "fork on an orphaned block"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Orphaned
        ; block "B'" ~parent:"A" ~height:2 Canonical
        ; fork_genesis ~fork_block:"B" ~height:3 ()
        ]
    ; outcome = Settled [ ("B", Canonical); ("B'", Orphaned) ]
    }
  ; (* The fork genesis has no parent link yet, but its fork block B is in the
       archive: found by the genesis's parent hash. *)
    { name = "fork genesis without a parent link"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "B'" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~fork_block:"B" ~unlinked:true ~height:3 ()
        ]
    ; outcome = Settled [ ("B", Canonical); ("B'", Orphaned) ]
    }
  ; (* The fork block is not in the archive at all: nothing to anchor to. *)
    { name = "fork block missing"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~height:4 ()
        ]
    ; outcome = Refused No_fork_block
    }
  ; (* No canonical block on the fork block's ancestry. *)
    { name = "fork without a canonical anchor"
    ; blocks =
        [ block "A" ~height:1 Pending
        ; block "B" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~fork_block:"B" ~height:3 ()
        ]
    ; outcome = Refused No_canonical_ancestor
    }
  ; (* The fork block C is the highest canonical block; the old chain went on
       past it as pending blocks, which are orphaned. *)
    { name = "fork on the last canonical block"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; block "C" ~parent:"B" ~height:3 Canonical
        ; block "D" ~parent:"C" ~height:4 Pending
        ; block "E" ~parent:"D" ~height:5 Pending
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ]
    ; outcome = Settled [ ("D", Orphaned); ("E", Orphaned) ]
    }
  ; (* A fork right after the first genesis: the old chain's canonical block B
       is a sibling of the fork genesis and is orphaned. The new chain's own
       pending blocks D and E are left to the archive's canonical marking. *)
    { name = "fork on a new network"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; fork_genesis ~fork_block:"A" ~height:2 ()
        ; postfork "D" ~parent:"genesis" ~height:3 Pending
        ; postfork "E" ~parent:"D" ~height:4 Pending
        ]
    ; outcome = Settled [ ("B", Orphaned) ]
    }
  ; (* No fork genesis: pending blocks stay pending. *)
    { name = "no fork genesis"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "B'" ~parent:"A" ~height:2 Pending
        ]
    ; outcome = Nothing_to_settle
    }
  ; (* A fork genesis that is not canonical, which the archive never stores
       (only an import of a block exported as pending, or a hand edit). *)
    { name = "pending fork genesis is refused"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "B'" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~fork_block:"B" ~status:Pending ~height:3 ()
        ]
    ; outcome = Refused Fork_genesis_not_canonical
    }
  ; (* Two forks in one archive (devnet and mainnet keep the Berkeley
       genesis): the newer fork genesis, genesis2, is settled; the older
       boundary (A') is not touched. *)
    { name = "newest of two forks"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "A'" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~name:"genesis1" ~fork_block:"A" ~protocol_version:v4
            ~height:2 ()
        ; block "C" ~parent:"genesis1" ~global_slot_since_hard_fork:1 ~height:3
            Canonical
        ; block "D" ~parent:"C" ~global_slot_since_hard_fork:2 ~height:4 Pending
        ; block "D'" ~parent:"C" ~global_slot_since_hard_fork:2 ~height:4
            Pending
        ; fork_genesis ~name:"genesis2" ~fork_block:"D" ~height:5 ()
        ]
    ; outcome = Settled [ ("D", Canonical); ("D'", Orphaned) ]
    }
  ; (* The boundary was settled, then a block of the ended chain, E, was
       stored late (e.g. by a backfill), as pending. Settling again, as
       convert-chain-to-canonical does on demand, orphans it. *)
    { name = "late block of the ended chain"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; block "C" ~parent:"B" ~height:3 Canonical
        ; block "D" ~parent:"C" ~height:4 Orphaned
        ; block "E" ~parent:"D" ~height:5 Pending
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ]
    ; outcome = Settled [ ("E", Orphaned) ]
    }
  ; (* A pending block X competes with the chain below the anchor C (beside
       C, not past it): it is not part of the ended chain, so settling leaves
       it to the archive's marking ("backfill after settling" below). *)
    { name = "pending block below the anchor"
    ; blocks =
        fork_mid_canonical () @ [ block "X" ~parent:"B" ~height:3 Pending ]
    ; outcome = Settled [ ("D", Orphaned); ("E", Orphaned) ]
    }
  ; (* The ended chain has a gap: E's parent D is not in the archive, so E
       has no parent link and settling, which follows parent links, cannot
       reach it. E stays pending; "block after a gap in the ended chain"
       below shows what orphans it. *)
    { name = "gap in the ended chain"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; block "C" ~parent:"B" ~height:3 Pending
        ; block "E" ~height:5 Pending
        ; fork_genesis ~fork_block:"B" ~height:3 ()
        ]
    ; outcome = Settled [ ("C", Orphaned) ]
    }
  ; (* The fork block C's parent is not in the archive: its ancestry stops at
       the gap before any canonical block. *)
    { name = "fork block behind a gap"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "C" ~height:3 Pending
        ; block "C'" ~height:3 Pending
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ]
    ; outcome = Refused No_canonical_ancestor
    }
  ; (* The archive marked the new chain without settling ("new chain marked
       without settling" below): D, beside the fork genesis, is orphaned and
       N1 canonical, but B, C and C' are pending still. Settling finishes
       them. *)
    { name = "after the new chain was marked"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "C" ~parent:"B" ~height:3 Pending
        ; block "C'" ~parent:"B" ~height:3 Pending
        ; block "D" ~parent:"C" ~height:4 Orphaned
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ; postfork "N1" ~parent:"genesis" ~height:5 Canonical
        ; postfork "N2" ~parent:"N1" ~height:6 Pending
        ; postfork "N3" ~parent:"N2" ~height:7 Pending
        ]
    ; outcome = Settled [ ("B", Canonical); ("C", Canonical); ("C'", Orphaned) ]
    }
  ]

(* --- canonical marking -------------------------------------------------------

   A block [arrives] and the archive runs Processor.Block.update_chain_status
   on it (with k = 2): once a block is k above the highest canonical block,
   the chain k below it becomes canonical and every other block at those
   heights is orphaned; a block below the highest canonical block (a
   backfill) makes the chain between the canonical blocks around it
   canonical, the same way. [changes] lists the blocks whose status
   changes. *)

type marking =
  { name : string
  ; blocks : block list
  ; arrives : string
  ; changes : (string * status) list
  }

let marking_test ~server_uri (c : marking) =
  test ~server_uri ~group:"canonical marking" ~name:c.name c.blocks (fun ctx ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () =
        step ("mark " ^ c.arrives) (mark_chain_status ctx c.arrives)
      in
      check_statuses ctx c.changes )

let marking_cases =
  [ (* The boundary is settled (D and E orphaned): the new chain's blocks are
       marked from the fork genesis on, and the boundary is left as it is. *)
    { name = "new chain marked after settling"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; block "C" ~parent:"B" ~height:3 Canonical
        ; block "D" ~parent:"C" ~height:4 Orphaned
        ; block "E" ~parent:"D" ~height:5 Orphaned
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ; postfork "N1" ~parent:"genesis" ~height:5 Pending
        ; postfork "N2" ~parent:"N1" ~height:6 Pending
        ; postfork "N3" ~parent:"N2" ~height:7 Pending
        ]
    ; arrives = "N3"
    ; changes = [ ("N1", Canonical) ]
    }
  ; (* Without settling, the marking of the new chain orphans the old chain's
       blocks at the new chain's heights (D, beside the fork genesis), but
       never reaches the blocks below the fork genesis: B, C and C' stay
       pending however long the new chain grows ("after the new chain was
       marked" above settles them). *)
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
    ; arrives = "N3"
    ; changes = [ ("D", Orphaned); ("N1", Canonical) ]
    }
  ; (* A prefork block X backfilled below the fork genesis, without settling:
       the archive makes the chain between the canonical blocks around it (A
       below, the fork genesis above) canonical and orphans the rest at those
       heights, which settles the boundary below the fork genesis. *)
    { name = "backfill below the fork genesis, not settled"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "C" ~parent:"B" ~height:3 Pending
        ; block "C'" ~parent:"B" ~height:3 Pending
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ; block "X" ~parent:"A" ~height:2 Pending
        ]
    ; arrives = "X"
    ; changes =
        [ ("B", Canonical)
        ; ("C", Canonical)
        ; ("C'", Orphaned)
        ; ("X", Orphaned)
        ]
    }
  ; (* After settling, X, which competes with the canonical fork block C and
       which settling leaves ("pending block below the anchor" above), is
       orphaned when it arrives, as any backfilled block. *)
    { name = "backfill after settling"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; block "C" ~parent:"B" ~height:3 Canonical
        ; block "D" ~parent:"C" ~height:4 Orphaned
        ; block "E" ~parent:"D" ~height:5 Orphaned
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ; block "N" ~parent:"genesis" ~protocol_version:v5 ~height:5 Pending
        ; block "X" ~parent:"B" ~height:3 Pending
        ]
    ; arrives = "X"
    ; changes = [ ("X", Orphaned) ]
    }
  ; (* After settling ("gap in the ended chain" above), E, behind a gap in the
       ended chain, is pending still: it is orphaned once the new chain is k
       above its height. *)
    { name = "block after a gap in the ended chain"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Canonical
        ; block "C" ~parent:"B" ~height:3 Orphaned
        ; block "E" ~height:5 Pending
        ; fork_genesis ~fork_block:"B" ~height:3 ()
        ; postfork "N1" ~parent:"genesis" ~height:4 Pending
        ; postfork "N2" ~parent:"N1" ~height:5 Pending
        ; postfork "N3" ~parent:"N2" ~height:6 Pending
        ; postfork "N4" ~parent:"N3" ~height:7 Pending
        ]
    ; arrives = "N4"
    ; changes = [ ("E", Orphaned); ("N1", Canonical); ("N2", Canonical) ]
    }
  ]

(* --- startup with --config-file -----------------------------------------------

   Processor.startup_with_config, as the archive runs it before it takes
   blocks: write the genesis of --config-file, then with
   --settle-prefork-pending-blocks settle the boundary of its fork genesis
   once. When it starts, the genesis it stored is canonical, and a restart
   changes nothing more. *)

(* The --config-file of a startup. *)
type config =
  | Fork_at of string  (** A hard fork at this block. *)
  | Fork_not_in_archive of int
      (** A hard fork at a block of this height that is not in the archive. *)
  | New_chain  (** A config that starts a new chain, not a hard fork. *)
  | No_config_file

type startup_outcome =
  | Starts of (string * status) list
      (** The archive starts, and these blocks change to these statuses. *)
  | Stops_mentioning of string
      (** The archive stops with this in its message, and changes nothing. *)

type startup =
  { name : string
  ; blocks : block list
  ; config : config
  ; settle_prefork_pending_blocks : bool
  ; outcome : startup_outcome
  }

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

(* The config's runtime config, and the height of the genesis it stores. *)
let config_file ctx = function
  | No_config_file ->
      (None, None)
  | New_chain ->
      (Some (runtime_config ctx ~tag:"new chain" ~fork:None), Some 1)
  | Fork_at name ->
      let fork_height = height ctx name in
      ( Some
          (runtime_config ctx ~tag:name
             ~fork:(Some (ctx.state_hash name, fork_height)) )
      , Some (fork_height + 1) )
  | Fork_not_in_archive fork_height ->
      ( Some
          (runtime_config ctx ~tag:"missing fork block"
             ~fork:
               (Some
                  ( state_hash_not_in_archive ~test:ctx.test "fork block"
                  , fork_height ) ) )
      , Some (fork_height + 1) )

(* The archive's startup: [Ok (Error msg)] when it stopped with [msg]. *)
let run_startup ctx ~settle runtime_config_opt =
  let precomputed = Lazy.force Precomputed_values.for_unit_tests in
  match Mina_caqti.connect_pool ctx.db.uri with
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

(* The geneses stored at [height] (global slot since hard fork 0) are one,
   and canonical. *)
let check_stored_genesis ctx height =
  let open Deferred.Or_error.Let_syntax in
  let%bind got =
    with_conn ctx.db (fun (module Conn) ->
        Conn.collect_list
          (Mina_caqti.collect_req Caqti_type.int Caqti_type.string
             "SELECT chain_status::text FROM blocks WHERE height = ? AND \
              global_slot_since_hard_fork = 0" )
          height )
  in
  if [%equal: string list] got [ "canonical" ] then return ()
  else
    Deferred.Or_error.errorf "geneses at height %d: expected canonical, got %s"
      height
      (String.concat ~sep:", " got)

(* Start the archive with [config], and check [outcome]. *)
let start ?(settle = true) ctx config outcome =
  let open Deferred.Or_error.Let_syntax in
  let runtime_config_opt, genesis_height = config_file ctx config in
  let%bind result = run_startup ctx ~settle runtime_config_opt in
  match (outcome, result) with
  | Starts changes, Ok () ->
      let%bind () =
        match genesis_height with
        | Some height ->
            check_stored_genesis ctx height
        | None ->
            return ()
      in
      check_statuses ctx changes
  | Starts _, Error msg ->
      Deferred.Or_error.errorf "the archive stopped: %s" msg
  | Stops_mentioning expected, Ok () ->
      Deferred.Or_error.errorf "expected the archive to stop (%s)" expected
  | Stops_mentioning expected, Error msg ->
      if String.is_substring msg ~substring:expected then check_statuses ctx []
      else
        Deferred.Or_error.errorf
          "the archive stopped with an unexpected message: %s" msg

let startup_test ~server_uri (c : startup) =
  test ~server_uri ~group:"startup" ~name:c.name c.blocks (fun ctx ->
      let open Deferred.Or_error.Let_syntax in
      let settle = c.settle_prefork_pending_blocks in
      let%bind () = step "startup" (start ~settle ctx c.config c.outcome) in
      match c.outcome with
      | Starts _ ->
          step "restart" (start ~settle ctx c.config c.outcome)
      | Stops_mentioning _ ->
          return () )

(* The old chain went on past its fork block C (height 3): D is canonical, E
   pending. The fork genesis, at height 4, is stored at startup. *)
let fork_chain =
  [ block "A" ~height:1 Canonical
  ; block "B" ~parent:"A" ~height:2 Canonical
  ; block "C" ~parent:"B" ~height:3 Canonical
  ; block "D" ~parent:"C" ~height:4 Canonical
  ; block "E" ~parent:"D" ~height:5 Pending
  ]

let startup_cases =
  [ { name = "settles once"
    ; blocks = fork_chain
    ; config = Fork_at "C"
    ; settle_prefork_pending_blocks = true
    ; outcome = Starts [ ("D", Orphaned); ("E", Orphaned) ]
    }
  ; { name = "without --settle-prefork-pending-blocks"
    ; blocks = fork_chain
    ; config = Fork_at "C"
    ; settle_prefork_pending_blocks = false
    ; outcome = Starts []
    }
  ; (* Devnet and mainnet keep an older fork genesis (Berkeley's), with its
       own unsettled leftovers (A'): startup settles the boundary of its
       config's fork, not the older one. *)
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
    ; config = Fork_at "D"
    ; settle_prefork_pending_blocks = true
    ; outcome = Starts [ ("D", Canonical); ("D'", Orphaned) ]
    }
  ; (* The fork block is not in the archive yet: nothing is settled, the
       archive starts, and convert-chain-to-canonical settles it after a
       backfill. *)
    { name = "fork block missing"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ]
    ; config = Fork_not_in_archive 2
    ; settle_prefork_pending_blocks = true
    ; outcome = Starts []
    }
  ; (* A config that starts a new chain, not a hard fork: nothing to
       settle. *)
    { name = "a new chain's config"
    ; blocks = []
    ; config = New_chain
    ; settle_prefork_pending_blocks = true
    ; outcome = Starts []
    }
  ; (* The archive holds another config's genesis on the same fork block:
       which boundary to settle is ambiguous. *)
    { name = "two fork geneses on the fork block"
    ; blocks =
        fork_chain
        @ [ fork_genesis ~name:"other genesis" ~fork_block:"C" ~height:4 () ]
    ; config = Fork_at "C"
    ; settle_prefork_pending_blocks = true
    ; outcome = Stops_mentioning "2 fork geneses"
    }
  ; (* --settle-prefork-pending-blocks without --config-file: the archive does
       not know the fork, warns, and starts. *)
    { name = "flag without --config-file"
    ; blocks = fork_chain
    ; config = No_config_file
    ; settle_prefork_pending_blocks = true
    ; outcome = Starts []
    }
  ]

(* Two startups with a change to the archive between them. *)

(* The fork genesis was stored, then made pending (an import, a hand edit):
   the archive stops rather than settle on it. *)
let startup_refuses_pending_genesis ~server_uri =
  test ~server_uri ~group:"startup" ~name:"refuses a pending fork genesis"
    fork_chain (fun ctx ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () =
        step "startup without settling"
          (start ~settle:false ctx (Fork_at "C") (Starts []))
      in
      let%bind () =
        exec ctx
          "UPDATE blocks SET chain_status = 'pending' WHERE height = 4 AND \
           global_slot_since_hard_fork = 0"
      in
      step "startup"
        (start ctx (Fork_at "C") (Stops_mentioning "not canonical")) )

(* Two hard forks in turn, each settled at its archive's startup. Fork A at
   FA, pending: FA becomes canonical, FA', which competes with it, is
   orphaned. The chain fork A starts goes on to fork B's block FB, which FB'
   competes with: fork B's startup makes FB canonical and orphans FB'. P1
   follows fork A's genesis, which is not in the archive until fork A's
   startup: it is linked to it then, as the archive links a block stored
   before its parent. *)
let startup_two_forks ~server_uri =
  test ~server_uri ~group:"startup" ~name:"two forks in turn"
    [ block "A" ~height:1 Canonical
    ; block "FA" ~parent:"A" ~height:2 Pending
    ; block "FA'" ~parent:"A" ~height:2 Pending
    ; postfork "P1" ~global_slot_since_genesis:3 ~global_slot_since_hard_fork:1
        ~height:4 Canonical
    ; postfork "FB" ~parent:"P1" ~global_slot_since_genesis:4
        ~global_slot_since_hard_fork:2 ~height:5 Pending
    ; postfork "FB'" ~parent:"P1" ~global_slot_since_genesis:4
        ~global_slot_since_hard_fork:2 ~height:5 Pending
    ]
    (fun ctx ->
      let open Deferred.Or_error.Let_syntax in
      let fork_a = [ ("FA", Canonical); ("FA'", Orphaned) ] in
      let%bind () = step "fork A" (start ctx (Fork_at "FA") (Starts fork_a)) in
      let%bind () =
        step "link P1 to fork A's genesis"
          (exec ctx
             (sprintf
                "UPDATE blocks p1 SET parent_id = g.id, parent_hash = \
                 g.state_hash FROM blocks g WHERE p1.id = %d AND g.height = 3 \
                 AND g.global_slot_since_hard_fork = 0"
                (ctx.id "P1") ) )
      in
      step "fork B"
        (start ctx (Fork_at "FB")
           (Starts (fork_a @ [ ("FB", Canonical); ("FB'", Orphaned) ])) ) )

let () =
  let server_uri = Synthetic_archive.Db.test_server_uri () in
  Alcotest.run "settle_pending_blocks"
    [ ( "settle_pending_blocks"
      , List.map settle_cases ~f:(settle_test ~server_uri) )
    ; ("canonical marking", List.map marking_cases ~f:(marking_test ~server_uri))
    ; ( "startup"
      , List.map startup_cases ~f:(startup_test ~server_uri)
        @ [ startup_refuses_pending_genesis ~server_uri
          ; startup_two_forks ~server_uri
          ] )
    ]
