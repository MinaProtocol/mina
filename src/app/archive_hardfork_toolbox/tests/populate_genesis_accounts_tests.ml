(* populate-genesis-accounts writes a genesis ledger to accounts_accessed with
   set-based statements. The rows must read back, through the archive's own
   Load_data, as the ledger's accounts, and match what the archive's
   per-account writer stores. *)

open Core
open Async
open Mina_base
module B = Synthetic_archive

module Populate = Archive_hardfork_toolbox_lib.Populate_genesis_accounts

module Processor = Archive_lib.Processor

let logger = Logger.null ()

let random gen ~seed = Quickcheck.random_value ~seed:(`Deterministic seed) gen

(* Plain, delegated, timed, custom-token and zkApp accounts; two zkApp
   accounts share their state and permissions. *)
let ledger =
  let plain =
    List.init 6 ~f:(fun i ->
        let account = random Account.gen ~seed:(sprintf "plain%d" i) in
        if i % 2 = 0 then { account with delegate = Some account.public_key }
        else account )
  in
  let timed =
    List.init 4 ~f:(fun i ->
        random Account.gen_timed ~seed:(sprintf "timed%d" i) )
  in
  let zkapp i ~with_vk =
    let account = random Account.gen ~seed:(sprintf "zk%d" i) in
    let zk = random Zkapp_account.gen ~seed:(sprintf "zkstate%d" i) in
    let verification_key =
      if with_vk then
        let data = Pickles.Side_loaded.Verification_key.dummy in
        Some { With_hash.data; hash = Zkapp_account.digest_vk data }
      else None
    in
    { account with
      zkapp =
        Some
          { zk with
            verification_key
          ; proved_state = true
          ; last_action_slot = Mina_numbers.Global_slot_since_genesis.of_int i
          }
    ; permissions =
        random (Permissions.gen ~auth_tag:Proof) ~seed:(sprintf "perm%d" i)
    }
  in
  let zkapps = List.init 4 ~f:(fun i -> zkapp i ~with_vk:(i % 2 = 0)) in
  let shared =
    let source = List.hd_exn zkapps in
    let account = random Account.gen ~seed:"shared" in
    { account with zkapp = source.zkapp; permissions = source.permissions }
  in
  List.mapi
    (plain @ timed @ zkapps @ [ shared ])
    ~f:(fun i account -> (i, account))

let to_error e = Error.of_string (Caqti_error.show e)

(* A database with one block; [f] gets the database and the block id. *)
let with_block ~server_uri ~name f =
  let s = B.create () in
  let genesis = B.block s ~name:"genesis" ~height:1 Canonical in
  B.Db.with_fresh ~server_uri ~name (fun db ->
      let%bind.Deferred.Or_error built = B.materialize s db in
      f db (B.block_id built genesis) )

let fast ?(chunk_size = 3) (db : B.Db.t) ~block_id accounts =
  B.Db.with_connection db (fun conn ->
      Populate.run ~chunk_size ~logger conn ~block_id accounts
      >>| Result.map_error ~f:to_error )

(* The archive's own per-account writer. *)
let slow (db : B.Db.t) ~block_id accounts =
  B.Db.with_connection db (fun conn ->
      Processor.Accounts_accessed.add_accounts_if_don't_exist conn block_id
        accounts
      >>| Result.map_error ~f:to_error
      >>| Result.map ~f:ignore )

(* The block's accounts as Load_data reads them, by ledger index. *)
let read_back (db : B.Db.t) ~block_id =
  match Mina_caqti.connect_pool db.uri with
  | Error e ->
      return (Error (to_error e))
  | Ok pool ->
      Monitor.protect
        ~finally:(fun () -> Caqti_async.Pool.drain pool.pool)
        (fun () ->
          match%bind
            Mina_caqti.Pool.use
              (fun conn ->
                Processor.Accounts_accessed.all_from_block conn block_id )
              pool
          with
          | Error e ->
              return (Error (to_error e))
          | Ok rows ->
              let%map accounts =
                Deferred.List.map rows
                  ~f:(Archive_lib.Load_data.get_account_accessed ~pool)
              in
              Ok
                (List.sort accounts ~compare:(fun (a, _) (b, _) ->
                     Int.compare a b ) ) )

let check_accounts expected got =
  Alcotest.(check (list int))
    "ledger indexes" (List.map expected ~f:fst) (List.map got ~f:fst) ;
  List.iter2_exn expected got ~f:(fun (i, want) (_, have) ->
      if not (Account.equal want have) then
        Alcotest.failf "account %d differs:\n%s\n%s" i
          (Sexp.to_string_hum (Account.sexp_of_t want))
          (Sexp.to_string_hum (Account.sexp_of_t have)) )

let dedup_tables =
  [ "public_keys"
  ; "tokens"
  ; "account_identifiers"
  ; "token_symbols"
  ; "voting_for"
  ; "timing_info"
  ; "zkapp_permissions"
  ; "zkapp_field"
  ; "zkapp_states"
  ; "zkapp_action_states"
  ; "zkapp_verification_key_hashes"
  ; "zkapp_verification_keys"
  ; "zkapp_uris"
  ; "zkapp_accounts"
  ; "accounts_accessed"
  ]

let row_counts (db : B.Db.t) =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      Mina_caqti.deferred_result_list_map dedup_tables ~f:(fun table ->
          Conn.find
            (Caqti_request.Infix.( ->! ) Caqti_type.unit Caqti_type.int
               (sprintf "SELECT count(*)::int FROM %s" table) )
            ()
          |> Deferred.Result.map ~f:(fun n -> (table, n)) )
      >>| Result.map_error ~f:to_error )

let counts = Alcotest.(list (pair string int))

let reads_back_as_the_ledger server_uri () =
  with_block ~server_uri ~name:"test_populate_reads_back" (fun db block_id ->
      let open Deferred.Or_error.Let_syntax in
      let%bind written = fast db ~block_id ledger in
      Alcotest.(check int) "written" (List.length ledger) written ;
      let%map got = read_back db ~block_id in
      check_accounts ledger got )

(* Half the ledger written by the archive's writer, the rest by this one: the
   same rows as the archive's writer alone, and a second run adds nothing. *)
let continues_after_the_archive_writer server_uri () =
  let open Deferred.Or_error.Let_syntax in
  let%bind reference =
    with_block ~server_uri ~name:"test_populate_reference" (fun db block_id ->
        let%bind () = slow db ~block_id ledger in
        row_counts db )
  in
  with_block ~server_uri ~name:"test_populate_mixed" (fun db block_id ->
      let first, _ = List.split_n ledger (List.length ledger / 2) in
      let%bind () = slow db ~block_id first in
      let%bind written = fast db ~block_id ledger in
      Alcotest.(check int)
        "written"
        (List.length ledger - List.length first)
        written ;
      let%bind mixed = row_counts db in
      Alcotest.check counts "rows, as the archive's writer" reference mixed ;
      let%bind again = fast db ~block_id ledger in
      Alcotest.(check int) "second run" 0 again ;
      let%bind after = row_counts db in
      Alcotest.check counts "rows after a second run" mixed after ;
      let%map got = read_back db ~block_id in
      check_accounts ledger got )

let tests ~server_uri =
  let run f () =
    Thread_safe.block_on_async_exn (f server_uri) |> Or_error.ok_exn
  in
  [ ("reads back as the ledger", `Quick, run reads_back_as_the_ledger)
  ; ( "continues after the archive's writer"
    , `Quick
    , run continues_after_the_archive_writer )
  ]
