(* Archive_lib.Processor.Genesis_accounts: the writer of the genesis ledger
   rows, and the reader balance queries fall back to. Needs a PostgreSQL
   server: MINA_TEST_POSTGRES (any database path is ignored). *)

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

let add ?chunk_size db ~genesis_height accounts =
  with_conn db (fun conn ->
      G.add ?chunk_size conn
        ~genesis_height:(Int64.of_int genesis_height)
        accounts )

let outcome = function
  | `No_table ->
      "no table"
  | `Already_loaded ->
      "already loaded"
  | `Added (n, 0) ->
      sprintf "added %d" n
  | `Added (n, before) ->
      sprintf "added %d after %d" n before
  | `Mismatch { G.differing; not_in_ledger } ->
      sprintf "mismatch: %d differ, %d not in the ledger" differing
        not_in_ledger

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
      let%bind again = add db ~genesis_height:1 [ bob; alice ] in
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

(* An import that stopped after its first chunks: the next one writes only
   the rest, in chunks, and the ledger then reads back whole. *)
let interrupted server_uri () =
  let accounts =
    List.init 7 ~f:(fun i -> untimed (sprintf "account%d" i) ~balance:(i + 1))
  in
  (* the order the writer uses *)
  let in_order =
    List.sort accounts ~compare:(fun a b ->
        let key x =
          let r = G.row_of_account x in
          (r.public_key, r.token)
        in
        [%compare: string * string] (key a) (key b) )
  in
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_resume" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      (* what an import interrupted after two chunks of two left *)
      let%bind first =
        add ~chunk_size:2 db ~genesis_height:1 (List.take in_order 4)
      in
      check_outcome "the interrupted import" "added 4" first ;
      let%bind rest = add ~chunk_size:2 db ~genesis_height:1 accounts in
      check_outcome "the next import" "added 3 after 4" rest ;
      let%bind again = add ~chunk_size:2 db ~genesis_height:1 accounts in
      check_outcome "once complete" "already loaded" again ;
      Deferred.List.iteri ~how:`Sequential accounts ~f:(fun i account ->
          let name = sprintf "account%d" i in
          let%map.Deferred found = latest db name ~height:1 in
          check_row name
            (Some (1, G.row_of_account account))
            (Or_error.ok_exn found) )
      |> Deferred.ok )

(* An import that stopped part way, whatever rows it wrote (here every other
   account, not a prefix of the writer's order): the next one writes the
   others. *)
let partial_in_any_order server_uri () =
  let accounts =
    List.init 7 ~f:(fun i -> untimed (sprintf "account%d" i) ~balance:(i + 1))
  in
  let written = List.filteri accounts ~f:(fun i _ -> i % 2 = 0) in
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_partial" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind first = add db ~genesis_height:1 written in
      check_outcome "the partial import" "added 4" first ;
      let%bind rest = add ~chunk_size:2 db ~genesis_height:1 accounts in
      check_outcome "the next import" "added 3 after 4" rest ;
      let%map again = add db ~genesis_height:1 accounts in
      check_outcome "once complete" "already loaded" again )

(* The height holds another ledger: an account with another balance (an older
   config of the same chain, another network's ledger). Nothing is written or
   overwritten, and the result says how many rows differ. *)
let another_ledger server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_another" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : _) = add db ~genesis_height:1 [ alice ] in
      let alice' = untimed "alice" ~balance:5 in
      let%bind got = add db ~genesis_height:1 [ alice'; bob ] in
      check_outcome "another ledger" "mismatch: 1 differ, 0 not in the ledger"
        got ;
      let%bind a = latest db "alice" ~height:1 in
      check_row "alice kept" (Some (1, G.row_of_account alice)) a ;
      let%map b = latest db "bob" ~height:1 in
      check_row "bob not written" None b )

(* The height holds accounts the ledger does not have: also another ledger. *)
let accounts_not_in_ledger server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_extra" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : _) = add db ~genesis_height:1 [ alice; bob ] in
      let%map got = add db ~genesis_height:1 [ alice ] in
      check_outcome "a smaller ledger" "mismatch: 0 differ, 1 not in the ledger"
        got )

(* A database created before the table was added: nothing is written and
   nothing is found, and neither is an error. *)
let without_table server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_genesis_accounts_no_table" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () =
        with_conn db (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.exec
              (Caqti_request.Infix.( ->. ) Caqti_type.unit Caqti_type.unit
                 "DROP TABLE genesis_accounts" )
              () )
      in
      let%bind written = add db ~genesis_height:1 [ alice ] in
      check_outcome "write" "no table" written ;
      let%map found = latest db "alice" ~height:1 in
      check_row "read" None found )

(* --- startup with --config-file: helpers -------------------------------- *)

let v5 = (5, 0, 0)

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

(* A fork genesis: the first block of the new chain, child of [fork_block]. *)
let fork_genesis s ~fork_block ~height status =
  B.block ~parent:fork_block ~protocol_version:v5 ~global_slot_since_hard_fork:0
    s ~name:"genesis" ~height status

(* --- startup with --config-file -------------------------------------------

   Processor.genesis_at_startup, as the archive runs it before it takes
   blocks: store the config's genesis block, write its ledger to
   genesis_accounts (or accounts_accessed with --legacy-genesis-accounts). *)

(* A real state hash: the config names the fork block by it, and the genesis
   block built from the config has it as its parent hash. *)
let real_state_hash seed =
  Mina_base.State_hash.to_base58_check
    (Quickcheck.random_value ~seed:(`Deterministic seed)
       Mina_base.State_hash.gen )

let mina = 1_000_000_000

(* The genesis ledger of the configs below, as (account, mina). *)
(* Each test has its own accounts: the daemon code that loads a config's
   ledger keeps it open in an on-disk cache named by its content, which one
   process can open once. *)
let ledger ~tag s =
  [ (B.account s (tag ^ "-alice"), 2000)
  ; (B.account s (tag ^ "-bob"), 2001)
  ; (B.account s (tag ^ "-carol"), 2002)
  ]

(* A config whose genesis ledger is [ledger ~tag s]; with [fork], a fork config:
   the fork block's state hash and height, the fork genesis one above it. *)
(* A config whose genesis ledger is [accounts], as (account, mina); with
   [fork], a fork config. *)
let config_of ?fork accounts =
  let accounts =
    List.map accounts ~f:(fun (account, balance) ->
        { Runtime_config.Accounts.Single.default with
          pk = B.public_key account
        ; balance = Currency.Balance.of_mina_int_exn balance
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

let config ~tag ?fork s = config_of ?fork (ledger ~tag s)

(* --config-file as the archive loads it: the runtime config and its
   precomputed values, loaded once per config: the ledger cache they open can
   be opened once per process. *)
let load runtime_config =
  let precomputed = Lazy.force Precomputed_values.for_unit_tests in
  Archive_lib.Processor.precomputed_values_of_config ~logger:(Logger.null ())
    ~runtime_config ~genesis_constants:precomputed.genesis_constants
    ~constraint_constants:precomputed.constraint_constants
  >>| (fun values -> (runtime_config, values))
  |> Deferred.ok

(* The archive's startup on [db] with [config_file] (see [load]): [Error]
   carries the message it stopped with. *)
let startup ?(legacy = false) (db : B.Db.t) config_file =
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
              Archive_lib.Processor.genesis_at_startup ~logger:(Logger.null ())
                ~genesis_constants:precomputed.genesis_constants
                ~constraint_constants:precomputed.constraint_constants
                ~chunks_length:2 ~config_file:(Some config_file)
                ~legacy_genesis_accounts:legacy pool )
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

let query_int db sql =
  with_conn db (fun (module Conn) ->
      Conn.find (Mina_caqti.find_req Caqti_type.unit Caqti_type.int sql) () )

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

let genesis_rows db ~height =
  query_int db
    (sprintf
       "SELECT count(*)::int FROM genesis_accounts WHERE genesis_height = %d"
       height )

let accounts_accessed db =
  query_int db "SELECT count(*)::int FROM accounts_accessed"

(* The old chain went on past its fork block C (height 3): D is canonical, E
   pending. The fork genesis, at height 4, is not in the archive: the archive
   starts before the new chain's daemons send it. *)
let fork_chain ~fork_hash s =
  let a = B.block s ~name:"A" ~height:1 Canonical in
  let b = B.block ~parent:a s ~name:"B" ~height:2 Canonical in
  let c =
    B.block ~state_hash:fork_hash ~parent:b s ~name:"C" ~height:3 Canonical
  in
  let d = B.block ~parent:c s ~name:"D" ~height:4 Canonical in
  let e = B.block ~parent:d s ~name:"E" ~height:5 Pending in
  [ ("A", a); ("B", b); ("C", c); ("D", d); ("E", e) ]

let unsettled_fork_chain =
  [ "canonical"; "canonical"; "canonical"; "canonical"; "pending" ]

let check_chain db built blocks want =
  check_statuses db built
    (List.map2_exn blocks want ~f:(fun (name, block) status ->
         ((name, block), status) ) )

(* The fork genesis is missing: startup stores it, canonical, and writes its
   ledger to genesis_accounts (not accounts_accessed); the prefork blocks are
   left as they are. *)
let startup_stores_genesis server_uri () =
  let s = B.create () in
  let tag = "startup_stores_genesis" in
  let fork_hash = real_state_hash "startup-stores-genesis" in
  let blocks = fork_chain ~fork_hash s in
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_stores_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind config = load runtime_config in
      let%bind accessed_before = accounts_accessed db in
      let%bind result = startup db config in
      expect_ok "startup" result ;
      let%bind genesis = genesis_statuses db ~height:4 in
      Alcotest.(check (list string)) "fork genesis" [ "canonical" ] genesis ;
      let%bind rows = genesis_rows db ~height:4 in
      Alcotest.(check int) "genesis_accounts rows" 3 rows ;
      let%bind accessed_after = accounts_accessed db in
      Alcotest.(check int)
        "accounts_accessed unchanged" accessed_before accessed_after ;
      let%bind again = startup db config in
      expect_ok "second startup" again ;
      let%bind genesis = genesis_statuses db ~height:4 in
      Alcotest.(check (list string)) "one fork genesis" [ "canonical" ] genesis ;
      let%bind rows = genesis_rows db ~height:4 in
      Alcotest.(check int) "genesis_accounts rows after a restart" 3 rows ;
      check_chain db built blocks unsettled_fork_chain )

(* The fork genesis was stored, then made pending (an import, a hand edit):
   the archive stops rather than settle on it, and changes nothing. *)
let startup_refuses_pending_genesis server_uri () =
  let s = B.create () in
  let tag = "startup_refuses_pending_genesis" in
  let fork_hash = real_state_hash "startup-pending-genesis" in
  let blocks = fork_chain ~fork_hash s in
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_pending_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind config = load runtime_config in
      let%bind first = startup db config in
      expect_ok "first startup" first ;
      let%bind () =
        exec db
          "UPDATE blocks SET chain_status = 'pending' WHERE height = 4 AND \
           global_slot_since_hard_fork = 0"
      in
      let%bind second = startup db config in
      expect_failure "a pending fork genesis" ~mentioning:"not canonical" second ;
      check_chain db built blocks unsettled_fork_chain )

(* Another block is the genesis at that height (another network, another
   config): the archive stops before it writes anything. *)
let startup_refuses_another_genesis server_uri () =
  let s = B.create () in
  let tag = "startup_refuses_another_genesis" in
  let fork_hash = real_state_hash "startup-another-genesis" in
  let blocks = fork_chain ~fork_hash s in
  let c = List.Assoc.find_exn blocks ~equal:String.equal "C" in
  ignore (fork_genesis s ~fork_block:c ~height:4 Canonical : B.block) ;
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_another_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind config = load runtime_config in
      let%bind result = startup db config in
      expect_failure "another genesis block" ~mentioning:"another genesis block"
        result ;
      let%bind rows = genesis_rows db ~height:4 in
      Alcotest.(check int) "no genesis_accounts rows" 0 rows ;
      check_chain db built blocks unsettled_fork_chain )

(* genesis_accounts at the genesis height holds another ledger (an older
   config, another network): the archive stops and overwrites nothing. *)
let startup_refuses_another_ledger server_uri () =
  let s = B.create () in
  let tag = "startup_refuses_another_ledger" in
  let fork_hash = real_state_hash "startup-another-ledger" in
  let blocks = fork_chain ~fork_hash s in
  B.genesis_account s ~genesis_height:4 (B.account s "mallory") ~balance:1 ;
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_another_ledger" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind config = load runtime_config in
      let%bind result = startup db config in
      expect_failure "another ledger" ~mentioning:"another genesis ledger"
        result ;
      let%bind rows = genesis_rows db ~height:4 in
      Alcotest.(check int) "the other ledger's row only" 1 rows ;
      check_chain db built blocks unsettled_fork_chain )

(* An earlier start wrote part of the ledger: this one writes the rest. *)
let startup_resumes_partial_ledger server_uri () =
  let s = B.create () in
  let tag = "startup_resumes_partial_ledger" in
  let fork_hash = real_state_hash "startup-partial-ledger" in
  let blocks = fork_chain ~fork_hash s in
  let account, balance = List.nth_exn (ledger ~tag s) 1 in
  B.genesis_account s ~genesis_height:4 account ~balance:(balance * mina) ;
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_partial_ledger" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind config = load runtime_config in
      let%bind result = startup db config in
      expect_ok "startup" result ;
      let%bind rows = genesis_rows db ~height:4 in
      Alcotest.(check int) "genesis_accounts rows" 3 rows ;
      check_chain db built blocks unsettled_fork_chain )

(* A database that never ran upgrade.sql has no genesis_accounts table: the
   archive stops and says so; with --legacy-genesis-accounts it writes the
   ledger to accounts_accessed instead. *)
let startup_without_table server_uri () =
  let s = B.create () in
  let tag = "startup_without_table" in
  let fork_hash = real_state_hash "startup-no-table" in
  let blocks = fork_chain ~fork_hash s in
  let runtime_config = config ~tag ~fork:(fork_hash, 3) s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_no_table" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let%bind config = load runtime_config in
      (* an archive created before the table was added *)
      let%bind () = exec db "DROP TABLE genesis_accounts" in
      let%bind result = startup db config in
      expect_failure "no table" ~mentioning:"no genesis_accounts table" result ;
      let%bind () = check_chain db built blocks unsettled_fork_chain in
      let%bind legacy = startup ~legacy:true db config in
      expect_ok "legacy startup" legacy ;
      let%bind on_genesis =
        query_int db
          "SELECT count(*)::int FROM accounts_accessed aa JOIN blocks b ON \
           b.id = aa.block_id WHERE b.height = 4 AND \
           b.global_slot_since_hard_fork = 0"
      in
      Alcotest.(check int) "accounts_accessed of the fork genesis" 3 on_genesis ;
      check_chain db built blocks unsettled_fork_chain )

(* A config that starts a new chain, not a hard fork: its genesis block and
   ledger are stored at height 1; there is nothing to settle. *)
let startup_new_chain server_uri () =
  let s = B.create () in
  let tag = "startup_new_chain" in
  let runtime_config = config ~tag s in
  B.Db.with_fresh ~server_uri ~name:"test_startup_new_chain" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind config = load runtime_config in
      let%bind result = startup db config in
      expect_ok "startup" result ;
      let%bind genesis = genesis_statuses db ~height:1 in
      Alcotest.(check (list string)) "genesis" [ "canonical" ] genesis ;
      let%map rows = genesis_rows db ~height:1 in
      Alcotest.(check int) "genesis_accounts rows" 3 rows )

(* Two hard forks in turn. Fork A: its config's genesis block and ledger are
   stored at height 3. The new chain then has a payment from alice to dave.
   Fork B, at that chain's block FB: its genesis and ledger, which carries
   the payment, are stored at height 6. A balance lookup gets each era's
   ledger, the blocks keep their own account states, and starting again with
   either config changes nothing. *)
let startup_two_forks server_uri () =
  let s = B.create () in
  let account name = B.account s ("startup_two_forks-" ^ name) in
  let alice = account "alice" in
  let bob = account "bob" in
  let carol = account "carol" in
  let dave = account "dave" in
  let fork_a_hash = real_state_hash "two-forks-a" in
  let fork_b_hash = real_state_hash "two-forks-b" in
  let config_a =
    config_of ~fork:(fork_a_hash, 2)
      [ (alice, 2000); (bob, 2001); (carol, 2002) ]
  in
  let config_b =
    config_of ~fork:(fork_b_hash, 5)
      [ (alice, 1500); (bob, 2001); (carol, 2002); (dave, 500) ]
  in
  let token = Mina_base.Token_id.(to_string default) in
  let balance mina = Currency.Balance.(to_string (of_mina_int_exn mina)) in
  let latest db account ~height =
    with_conn db (fun conn ->
        Archive_lib.Processor.Genesis_accounts.latest conn
          ~public_key:(B.public_key account) ~token
          ~height:(Int64.of_int height) )
    |> Deferred.Or_error.map
         ~f:
           (Option.map
              ~f:(fun (found : Archive_lib.Processor.Genesis_accounts.found) ->
                (Int64.to_int_exn found.genesis_height, found.row.balance) ) )
  in
  let check_latest db what account ~height want =
    let%map.Deferred.Or_error got = latest db account ~height in
    Alcotest.(check (option (pair int string))) what want got
  in
  B.Db.with_fresh ~server_uri ~name:"test_startup_two_forks" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind pa = load config_a in
      let%bind pb = load config_b in
      let genesis_a_hash =
        Archive_lib.Processor.genesis_block_of ~precomputed_values:(snd pa)
        |> Mina_base.State_hash.With_state_hashes.state_hash
        |> Mina_base.State_hash.to_base58_check
      in
      (* the first chain to fork A's block FA *)
      let a = B.block s ~name:"A" ~height:1 Canonical in
      let fa =
        B.block ~state_hash:fork_a_hash ~parent:a s ~name:"FA" ~height:2
          Canonical
      in
      (* the chain fork A starts: P1 has the payment, FB is fork B's block,
         FB' competes with it *)
      let p1 =
        B.block ~parent_hash:genesis_a_hash ~global_slot_since_genesis:3
          ~global_slot_since_hard_fork:1 ~protocol_version:v5 s ~name:"P1"
          ~height:4 Canonical
      in
      ignore
        ( B.payment s ~name:"pay" ~source:alice ~receiver:dave
            ~in_:[ (p1, Applied) ]
          : B.user_command ) ;
      B.account_state s p1 alice ~balance:(1500 * mina) ;
      B.account_state s p1 dave ~balance:(500 * mina) ;
      let fb =
        B.block ~state_hash:fork_b_hash ~parent:p1 ~global_slot_since_genesis:4
          ~global_slot_since_hard_fork:2 ~protocol_version:v5 s ~name:"FB"
          ~height:5 Pending
      in
      let fb' =
        B.block ~parent:p1 ~global_slot_since_genesis:4
          ~global_slot_since_hard_fork:2 ~protocol_version:v5 s ~name:"FB'"
          ~height:5 Pending
      in
      let%bind built = B.materialize s db in
      let%bind accessed_before = accounts_accessed db in
      let%bind first = startup db pa in
      expect_ok "startup with fork A's config" first ;
      (* P1 was written before fork A's genesis was in the archive: link it
         to its parent, as the archive does for a block stored after its
         parent *)
      let%bind () =
        exec db
          "UPDATE blocks c SET parent_id = p.id FROM blocks p WHERE \
           c.parent_id IS NULL AND p.state_hash = c.parent_hash"
      in
      let%bind second = startup db pb in
      expect_ok "startup with fork B's config" second ;
      let%bind ga = genesis_statuses db ~height:3 in
      Alcotest.(check (list string)) "fork A's genesis" [ "canonical" ] ga ;
      let%bind gb = genesis_statuses db ~height:6 in
      Alcotest.(check (list string)) "fork B's genesis" [ "canonical" ] gb ;
      let%bind rows_a = genesis_rows db ~height:3 in
      Alcotest.(check int) "fork A's ledger" 3 rows_a ;
      let%bind rows_b = genesis_rows db ~height:6 in
      Alcotest.(check int) "fork B's ledger" 4 rows_b ;
      let%bind () =
        check_latest db "alice in era A" alice ~height:3 (Some (3, balance 2000))
      in
      let%bind () =
        check_latest db "alice before fork B" alice ~height:5
          (Some (3, balance 2000))
      in
      let%bind () =
        check_latest db "alice in era B" alice ~height:6 (Some (6, balance 1500))
      in
      let%bind () = check_latest db "dave before fork B" dave ~height:5 None in
      let%bind () =
        check_latest db "dave in era B" dave ~height:9 (Some (6, balance 500))
      in
      let%bind () =
        check_latest db "carol in era B" carol ~height:9 (Some (6, balance 2002))
      in
      let%bind accessed_after = accounts_accessed db in
      Alcotest.(check int)
        "the blocks' account states only" accessed_before accessed_after ;
      let%bind again_a = startup db pa in
      expect_ok "fork A's config again" again_a ;
      let%bind again_b = startup db pb in
      expect_ok "fork B's config again" again_b ;
      let%bind rows_a = genesis_rows db ~height:3 in
      Alcotest.(check int) "fork A's ledger after restarts" 3 rows_a ;
      let%bind rows_b = genesis_rows db ~height:6 in
      Alcotest.(check int) "fork B's ledger after restarts" 4 rows_b ;
      check_statuses db built
        [ (("A", a), "canonical")
        ; (("FA", fa), "canonical")
        ; (("P1", p1), "canonical")
        ; (("FB", fb), "pending")
        ; (("FB'", fb'), "pending")
        ] )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "genesis_accounts"
    [ ( "genesis_accounts"
      , [ Alcotest.test_case "write, read, and a later era" `Quick
            (run write_and_read)
        ; Alcotest.test_case "an interrupted import continues" `Quick
            (run interrupted)
        ; Alcotest.test_case "a partial import in any order continues" `Quick
            (run partial_in_any_order)
        ; Alcotest.test_case "another ledger at the height" `Quick
            (run another_ledger)
        ; Alcotest.test_case "accounts not in the ledger" `Quick
            (run accounts_not_in_ledger)
        ; Alcotest.test_case "a database without the table" `Quick
            (run without_table)
        ] )
    ; ( "startup"
      , [ Alcotest.test_case "stores the genesis block and ledger" `Quick
            (run startup_stores_genesis)
        ; Alcotest.test_case "refuses a pending fork genesis" `Quick
            (run startup_refuses_pending_genesis)
        ; Alcotest.test_case "refuses another genesis block" `Quick
            (run startup_refuses_another_genesis)
        ; Alcotest.test_case "refuses another genesis ledger" `Quick
            (run startup_refuses_another_ledger)
        ; Alcotest.test_case "resumes a partial genesis ledger" `Quick
            (run startup_resumes_partial_ledger)
        ; Alcotest.test_case "without the genesis_accounts table" `Quick
            (run startup_without_table)
        ; Alcotest.test_case "a new chain's config" `Quick
            (run startup_new_chain)
        ; Alcotest.test_case "two forks in turn" `Quick (run startup_two_forks)
        ] )
    ]
