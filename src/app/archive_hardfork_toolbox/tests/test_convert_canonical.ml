open Core
open Async
open Archive_hardfork_toolbox_lib
open Caqti_request.Infix

module Block = struct
  type t =
    { id : int
    ; state_hash : string
    ; parent_id : int option
    ; parent_hash : string
    ; height : int
    ; global_slot_since_genesis : int
    ; global_slot_since_hard_fork : int
    ; protocol_version_id : int
    ; chain_status : string
    }
end

module BlockState = struct
  type t = { state_hash : string; expected_chain_status : string }
  [@@deriving equal]

  let show { state_hash; expected_chain_status } =
    Printf.sprintf "%s->%s" state_hash expected_chain_status
end

(* Test database setup and teardown *)
(* This setup is purely for tests and should not be used in production or exposed *)
module TestDb = struct
  (* New helpers to de-duplicate connection logic *)
  let uri_for conn_str = function
    | None ->
        Uri.of_string conn_str
    | Some db_name ->
        Uri.of_string (sprintf "%s/%s" conn_str db_name)

  let connect_pool uri =
    match Mina_caqti.connect_pool uri with
    | Ok pool ->
        Deferred.Or_error.return pool
    | Error e ->
        Deferred.Or_error.error_string (Caqti_error.show e)

  let with_pool conn_str ?db_name f =
    let uri = uri_for conn_str db_name in
    let%bind.Deferred.Or_error pool = connect_pool uri in
    f pool

  let drop_database_if_exists conn_str db_name =
    let sql_string = sprintf "DROP DATABASE IF EXISTS %s" db_name in
    let mutation = Caqti_type.(unit ->. unit) sql_string in
    with_pool conn_str (fun pool ->
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                Conn.exec mutation () ) ) )

  let create_database conn_str db_name =
    let sql_string = sprintf "CREATE DATABASE %s" db_name in
    let mutation = Caqti_type.(unit ->. unit) sql_string in
    with_pool conn_str (fun pool ->
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                Conn.exec mutation () ) ) )

  (* This should always be in sync with src/app/archive/create_schema.sql *)
  let create_test_schema conn_str db_name =
    let chain_status_type_schema =
      {sql|
          CREATE TYPE chain_status_type AS ENUM ('canonical', 'orphaned', 'pending')
        |sql}
    in
    let protocol_versions_schema =
      {sql|
          CREATE TABLE protocol_versions (
            id serial NOT NULL,
            transaction int NOT NULL,
            network int NOT NULL,
            patch int NOT NULL,
            CONSTRAINT protocol_versions_pkey PRIMARY KEY (id),
            UNIQUE (transaction,network,patch)
          )
        |sql}
    in
    let blocks_schema =
      {sql|
          CREATE TABLE blocks (
            id serial NOT NULL,
            state_hash text NOT NULL,
            parent_id integer NULL,
            parent_hash text NOT NULL,
            height bigint NOT NULL,
            global_slot_since_hard_fork bigint NOT NULL,
            global_slot_since_genesis bigint NOT NULL,
            protocol_version_id integer NOT NULL,
            chain_status chain_status_type NOT NULL,
            CONSTRAINT blocks_pkey PRIMARY KEY (id)
          )
        |sql}
    in
    let mutations =
      [ chain_status_type_schema; protocol_versions_schema; blocks_schema ]
      |> List.map ~f:Caqti_type.(unit ->. unit)
    in
    with_pool conn_str ~db_name (fun pool ->
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                Deferred.List.fold mutations ~init:(Ok ())
                  ~f:(fun last_result this_mutation ->
                    match last_result with
                    | Ok () ->
                        Conn.exec this_mutation ()
                    | e ->
                        Deferred.return e ) ) ) )

  let insert_protocol_versions conn_str db_name versions =
    let query =
      Caqti_type.(t3 int int int ->. unit)
        {sql|
          INSERT INTO protocol_versions
            (transaction, network, patch)
          VALUES (?, ?, ?)
        |sql}
    in
    with_pool conn_str ~db_name (fun pool ->
        Deferred.Or_error.List.iter versions
          ~f:(fun (transaction, network, patch) ->
            Deferred.Or_error.try_with (fun () ->
                Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                    Conn.exec query (transaction, network, patch) ) ) ) )

  let insert_blocks conn_str db_name blocks =
    with_pool conn_str ~db_name (fun pool ->
        Deferred.Or_error.List.iter blocks ~f:(fun block ->
            let Block.
                  { id
                  ; state_hash
                  ; parent_id
                  ; parent_hash
                  ; height
                  ; global_slot_since_genesis
                  ; global_slot_since_hard_fork
                  ; protocol_version_id
                  ; chain_status
                  } =
              block
            in
            let query =
              ( Caqti_type.(
                  t3
                    (t4 int string (option int) string)
                    (t4 int int int int) string)
              ->. Caqti_type.unit )
                {sql|
                  INSERT INTO blocks
                    (id, state_hash, parent_id, parent_hash, height,
                    global_slot_since_genesis, global_slot_since_hard_fork,
                    protocol_version_id, chain_status)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                |sql}
            in
            let params =
              ( (id, state_hash, parent_id, parent_hash)
              , ( height
                , global_slot_since_genesis
                , global_slot_since_hard_fork
                , protocol_version_id )
              , chain_status )
            in
            Deferred.Or_error.try_with (fun () ->
                Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                    Conn.exec query params ) ) ) )

  let get_all_blocks conn_str db_name =
    let query =
      (Caqti_type.unit ->* Caqti_type.(t2 string string))
        {sql|
          SELECT state_hash, chain_status
          FROM blocks
          ORDER BY state_hash ASC
        |sql}
    in
    with_pool conn_str ~db_name (fun pool ->
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                let%map.Deferred.Result raw_blocks =
                  Conn.collect_list query ()
                in
                List.map
                  ~f:(fun (state_hash, expected_chain_status) ->
                    BlockState.{ state_hash; expected_chain_status } )
                  raw_blocks ) ) )
end

(* Test scenarios based on the bash test fixtures *)
module TestScenarios = struct
  type scenario =
    { name : string
    ; blocks : Block.t list
    ; expected : BlockState.t list
    ; target_hash : string
    ; protocol_version : string
    }

  let test_fork_on_canonical_in_the_middle =
    { name = "test_fork_on_canonical_in_the_middle"
    ; blocks =
        [ { id = 1
          ; state_hash = "A"
          ; parent_id = None
          ; parent_hash = "0"
          ; height = 1
          ; global_slot_since_genesis = 0
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 2
          ; state_hash = "B"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 2
          ; global_slot_since_genesis = 1
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 3
          ; state_hash = "C"
          ; parent_id = Some 2
          ; parent_hash = "B"
          ; height = 3
          ; global_slot_since_genesis = 2
          ; global_slot_since_hard_fork = 2
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 4
          ; state_hash = "D"
          ; parent_id = Some 3
          ; parent_hash = "C"
          ; height = 4
          ; global_slot_since_genesis = 3
          ; global_slot_since_hard_fork = 3
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 5
          ; state_hash = "E"
          ; parent_id = Some 4
          ; parent_hash = "D"
          ; height = 5
          ; global_slot_since_genesis = 4
          ; global_slot_since_hard_fork = 4
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ]
    ; expected =
        [ { state_hash = "A"; expected_chain_status = "canonical" }
        ; { state_hash = "B"; expected_chain_status = "canonical" }
        ; { state_hash = "C"; expected_chain_status = "canonical" }
        ; { state_hash = "D"; expected_chain_status = "orphaned" }
        ; { state_hash = "E"; expected_chain_status = "orphaned" }
        ]
    ; target_hash = "C"
    ; protocol_version = "2.0.0"
    }

  let test_fork_on_new_network =
    { name = "test_fork_on_new_network"
    ; blocks =
        [ { id = 1
          ; state_hash = "A"
          ; parent_id = None
          ; parent_hash = "0"
          ; height = 1
          ; global_slot_since_genesis = 0
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 1
          ; chain_status = "canonical"
          }
        ; { id = 2
          ; state_hash = "B"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 2
          ; global_slot_since_genesis = 1
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 1
          ; chain_status = "canonical"
          }
        ; { id = 3
          ; state_hash = "C"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 3
          ; global_slot_since_genesis = 2
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 4
          ; state_hash = "D"
          ; parent_id = Some 3
          ; parent_hash = "C"
          ; height = 4
          ; global_slot_since_genesis = 3
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ; { id = 5
          ; state_hash = "E"
          ; parent_id = Some 4
          ; parent_hash = "D"
          ; height = 5
          ; global_slot_since_genesis = 4
          ; global_slot_since_hard_fork = 2
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ]
    ; expected =
        [ { state_hash = "A"; expected_chain_status = "canonical" }
        ; { state_hash = "B"; expected_chain_status = "canonical" }
        ; { state_hash = "C"; expected_chain_status = "canonical" }
        ; { state_hash = "D"; expected_chain_status = "orphaned" }
        ; { state_hash = "E"; expected_chain_status = "orphaned" }
        ]
    ; target_hash = "C"
    ; protocol_version = "2.0.0"
    }

  let test_fork_on_last_canonical =
    { name = "test_fork_on_last_canonical"
    ; blocks =
        [ { id = 1
          ; state_hash = "A"
          ; parent_id = None
          ; parent_hash = "0"
          ; height = 1
          ; global_slot_since_genesis = 0
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 2
          ; state_hash = "B"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 2
          ; global_slot_since_genesis = 1
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 3
          ; state_hash = "C"
          ; parent_id = Some 2
          ; parent_hash = "B"
          ; height = 3
          ; global_slot_since_genesis = 2
          ; global_slot_since_hard_fork = 2
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 4
          ; state_hash = "D"
          ; parent_id = Some 3
          ; parent_hash = "C"
          ; height = 4
          ; global_slot_since_genesis = 3
          ; global_slot_since_hard_fork = 3
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ; { id = 5
          ; state_hash = "E"
          ; parent_id = Some 4
          ; parent_hash = "D"
          ; height = 5
          ; global_slot_since_genesis = 4
          ; global_slot_since_hard_fork = 4
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ]
    ; expected =
        [ { state_hash = "A"; expected_chain_status = "canonical" }
        ; { state_hash = "B"; expected_chain_status = "canonical" }
        ; { state_hash = "C"; expected_chain_status = "canonical" }
        ; { state_hash = "D"; expected_chain_status = "orphaned" }
        ; { state_hash = "E"; expected_chain_status = "orphaned" }
        ]
    ; target_hash = "C"
    ; protocol_version = "2.0.0"
    }

  let test_fork_on_orphaned =
    { name = "test_fork_on_orphaned"
    ; blocks =
        [ { id = 1
          ; state_hash = "A"
          ; parent_id = None
          ; parent_hash = "0"
          ; height = 1
          ; global_slot_since_genesis = 0
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 2
          ; state_hash = "B"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 2
          ; global_slot_since_genesis = 1
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 2
          ; chain_status = "orphaned"
          }
        ; { id = 3
          ; state_hash = "C"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 3
          ; global_slot_since_genesis = 2
          ; global_slot_since_hard_fork = 2
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 4
          ; state_hash = "D"
          ; parent_id = Some 3
          ; parent_hash = "C"
          ; height = 4
          ; global_slot_since_genesis = 3
          ; global_slot_since_hard_fork = 3
          ; protocol_version_id = 2
          ; chain_status = "orphaned"
          }
        ; { id = 5
          ; state_hash = "E"
          ; parent_id = Some 4
          ; parent_hash = "D"
          ; height = 5
          ; global_slot_since_genesis = 4
          ; global_slot_since_hard_fork = 4
          ; protocol_version_id = 2
          ; chain_status = "orphaned"
          }
        ]
    ; expected =
        [ { state_hash = "A"; expected_chain_status = "canonical" }
        ; { state_hash = "B"; expected_chain_status = "canonical" }
        ; { state_hash = "C"; expected_chain_status = "orphaned" }
        ; { state_hash = "D"; expected_chain_status = "orphaned" }
        ; { state_hash = "E"; expected_chain_status = "orphaned" }
        ]
    ; target_hash = "B"
    ; protocol_version = "2.0.0"
    }

  let test_fork_on_pending =
    { name = "test_fork_on_pending"
    ; blocks =
        [ { id = 1
          ; state_hash = "A"
          ; parent_id = None
          ; parent_hash = "0"
          ; height = 1
          ; global_slot_since_genesis = 0
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 2
          ; state_hash = "B"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 2
          ; global_slot_since_genesis = 1
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ; { id = 3
          ; state_hash = "C"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 3
          ; global_slot_since_genesis = 2
          ; global_slot_since_hard_fork = 2
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 4
          ; state_hash = "D"
          ; parent_id = Some 3
          ; parent_hash = "C"
          ; height = 4
          ; global_slot_since_genesis = 3
          ; global_slot_since_hard_fork = 3
          ; protocol_version_id = 2
          ; chain_status = "orphaned"
          }
        ]
    ; expected =
        [ { state_hash = "A"; expected_chain_status = "canonical" }
        ; { state_hash = "B"; expected_chain_status = "orphaned" }
        ; { state_hash = "C"; expected_chain_status = "canonical" }
        ; { state_hash = "D"; expected_chain_status = "orphaned" }
        ]
    ; target_hash = "C"
    ; protocol_version = "2.0.0"
    }

  let test_surrounded_by_pendings =
    { name = "test_surrounded_by_pendings"
    ; blocks =
        [ { id = 1
          ; state_hash = "A"
          ; parent_id = None
          ; parent_hash = "0"
          ; height = 1
          ; global_slot_since_genesis = 0
          ; global_slot_since_hard_fork = 0
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 2
          ; state_hash = "B"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 2
          ; global_slot_since_genesis = 1
          ; global_slot_since_hard_fork = 1
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ; { id = 3
          ; state_hash = "C"
          ; parent_id = Some 1
          ; parent_hash = "A"
          ; height = 3
          ; global_slot_since_genesis = 2
          ; global_slot_since_hard_fork = 2
          ; protocol_version_id = 2
          ; chain_status = "canonical"
          }
        ; { id = 4
          ; state_hash = "D"
          ; parent_id = Some 3
          ; parent_hash = "C"
          ; height = 4
          ; global_slot_since_genesis = 3
          ; global_slot_since_hard_fork = 3
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ; { id = 5
          ; state_hash = "E"
          ; parent_id = Some 4
          ; parent_hash = "D"
          ; height = 5
          ; global_slot_since_genesis = 4
          ; global_slot_since_hard_fork = 4
          ; protocol_version_id = 2
          ; chain_status = "pending"
          }
        ]
    ; expected =
        [ { state_hash = "A"; expected_chain_status = "canonical" }
        ; { state_hash = "B"; expected_chain_status = "orphaned" }
        ; { state_hash = "C"; expected_chain_status = "canonical" }
        ; { state_hash = "D"; expected_chain_status = "orphaned" }
        ; { state_hash = "E"; expected_chain_status = "orphaned" }
        ]
    ; target_hash = "C"
    ; protocol_version = "2.0.0"
    }

  let all_scenarios =
    [ test_fork_on_canonical_in_the_middle
    ; test_fork_on_new_network
    ; test_fork_on_last_canonical
    ; test_fork_on_orphaned
    ; test_fork_on_pending
    ; test_surrounded_by_pendings
    ]
end

let get_postgres_uri () =
  match Sys.getenv "POSTGRES_URI" with
  | Some uri ->
      uri
  | None ->
      failwith
        "POSTGRES_URI environment variable is not set. Please set it to run \
         the tests."

let test_convert_scenario
    ({ name; blocks; expected; target_hash; protocol_version } :
      TestScenarios.scenario ) () =
  let open Deferred.Or_error.Let_syntax in
  (* Create test database *)
  let db_name = sprintf "test_%s" name in
  let conn_str = get_postgres_uri () in
  let%bind () = TestDb.drop_database_if_exists conn_str db_name in
  let%bind () = TestDb.create_database conn_str db_name in
  let%bind () = TestDb.create_test_schema conn_str db_name in
  let%bind () =
    TestDb.insert_protocol_versions conn_str db_name [ (1, 0, 0); (2, 0, 0) ]
  in
  let%bind () = TestDb.insert_blocks conn_str db_name blocks in
  (* Run conversion *)
  let postgres_uri = Uri.of_string (sprintf "%s/%s" conn_str db_name) in
  let%bind () =
    Logic.convert_chain_to_canonical ~postgres_uri
      ?target_block_hash:(Some target_hash)
      ?protocol_version_str:(Some protocol_version) ~stop_at_slot:None
      ~dry_run:false ()
  in

  (* Get results *)
  let%bind actual = TestDb.get_all_blocks conn_str db_name in

  (* Check results match expected *)
  if List.equal BlockState.equal actual expected then (
    printf "✅ Test %s passed\n" name ;
    Deferred.Or_error.return () )
  else (
    printf "❌ Test %s failed\n" name ;
    printf "Expected: %s\n" (List.to_string ~f:BlockState.show expected) ;
    printf "Actual: %s\n" (List.to_string ~f:BlockState.show actual) ;
    Deferred.Or_error.error_string (sprintf "Test %s failed" name) )

let make_test scenario =
  Thread_safe.block_on_async_exn (test_convert_scenario scenario)
  |> Or_error.ok_exn

(* Two-protocol-version fixture with a real hard-fork boundary: the pre-fork tail
   (B, C) is left pending, and C is the parent of the post-fork genesis F
   (global_slot_since_hard_fork = 0). Used to exercise auto-detection and dry-run. *)
let auto_detect_blocks : Block.t list =
  [ { id = 1
    ; state_hash = "A"
    ; parent_id = None
    ; parent_hash = "0"
    ; height = 1
    ; global_slot_since_genesis = 0
    ; global_slot_since_hard_fork = 0
    ; protocol_version_id = 1
    ; chain_status = "canonical"
    }
  ; { id = 2
    ; state_hash = "B"
    ; parent_id = Some 1
    ; parent_hash = "A"
    ; height = 2
    ; global_slot_since_genesis = 1
    ; global_slot_since_hard_fork = 1
    ; protocol_version_id = 1
    ; chain_status = "pending"
    }
  ; { id = 3
    ; state_hash = "C"
    ; parent_id = Some 2
    ; parent_hash = "B"
    ; height = 3
    ; global_slot_since_genesis = 2
    ; global_slot_since_hard_fork = 2
    ; protocol_version_id = 1
    ; chain_status = "pending"
    }
  ; { id = 4
    ; state_hash = "F"
    ; parent_id = Some 3
    ; parent_hash = "C"
    ; height = 4
    ; global_slot_since_genesis = 3
    ; global_slot_since_hard_fork = 0
    ; protocol_version_id = 2
    ; chain_status = "canonical"
    }
  ; { id = 5
    ; state_hash = "G"
    ; parent_id = Some 4
    ; parent_hash = "F"
    ; height = 5
    ; global_slot_since_genesis = 4
    ; global_slot_since_hard_fork = 1
    ; protocol_version_id = 2
    ; chain_status = "canonical"
    }
  ]

let setup_db db_name blocks =
  let open Deferred.Or_error.Let_syntax in
  let conn_str = get_postgres_uri () in
  let%bind () = TestDb.drop_database_if_exists conn_str db_name in
  let%bind () = TestDb.create_database conn_str db_name in
  let%bind () = TestDb.create_test_schema conn_str db_name in
  let%bind () =
    TestDb.insert_protocol_versions conn_str db_name [ (1, 0, 0); (2, 0, 0) ]
  in
  let%bind () = TestDb.insert_blocks conn_str db_name blocks in
  return conn_str

let check_blocks conn_str db_name ~name expected =
  let open Deferred.Or_error.Let_syntax in
  let%bind actual = TestDb.get_all_blocks conn_str db_name in
  if List.equal BlockState.equal actual expected then (
    printf "✅ Test %s passed\n" name ;
    Deferred.Or_error.return () )
  else (
    printf "❌ Test %s failed\n" name ;
    printf "Expected: %s\n" (List.to_string ~f:BlockState.show expected) ;
    printf "Actual: %s\n" (List.to_string ~f:BlockState.show actual) ;
    Deferred.Or_error.error_string (sprintf "Test %s failed" name) )

(* With no target/protocol flags, the tool auto-detects the latest boundary:
   parent of F is C (protocol version 1.0.0), so the pre-fork tail A..C becomes
   canonical, while F and G (post-fork) are untouched. *)
let test_auto_detect_latest_boundary () =
  let open Deferred.Or_error.Let_syntax in
  let name = "test_auto_detect_latest_boundary" in
  let db_name = sprintf "test_%s" name in
  let%bind conn_str = setup_db db_name auto_detect_blocks in
  let postgres_uri = Uri.of_string (sprintf "%s/%s" conn_str db_name) in
  let%bind () =
    Logic.convert_chain_to_canonical ~postgres_uri ~stop_at_slot:None
      ~dry_run:false ()
  in
  check_blocks conn_str db_name ~name
    [ { state_hash = "A"; expected_chain_status = "canonical" }
    ; { state_hash = "B"; expected_chain_status = "canonical" }
    ; { state_hash = "C"; expected_chain_status = "canonical" }
    ; { state_hash = "F"; expected_chain_status = "canonical" }
    ; { state_hash = "G"; expected_chain_status = "canonical" }
    ]

(* A dry run auto-detects and reports but writes nothing: statuses stay as in the
   input fixture (B, C remain pending). *)
let test_dry_run_writes_nothing () =
  let open Deferred.Or_error.Let_syntax in
  let name = "test_dry_run_writes_nothing" in
  let db_name = sprintf "test_%s" name in
  let%bind conn_str = setup_db db_name auto_detect_blocks in
  let postgres_uri = Uri.of_string (sprintf "%s/%s" conn_str db_name) in
  let%bind () =
    Logic.convert_chain_to_canonical ~postgres_uri ~stop_at_slot:None
      ~dry_run:true ()
  in
  check_blocks conn_str db_name ~name
    [ { state_hash = "A"; expected_chain_status = "canonical" }
    ; { state_hash = "B"; expected_chain_status = "pending" }
    ; { state_hash = "C"; expected_chain_status = "pending" }
    ; { state_hash = "F"; expected_chain_status = "canonical" }
    ; { state_hash = "G"; expected_chain_status = "canonical" }
    ]

(* Emergency hard fork that does NOT bump the protocol version: pre-fork (A..C, L)
   and post-fork (F, G) all share protocol version 1.0.0. F is the post-fork
   genesis (global_slot_since_hard_fork = 0) built on the fork parent C; L is a
   leftover on the old chain, also a child of C but below the fork boundary. The
   pre-fork tail B, C must become canonical, the leftover L orphaned, and the
   post-fork chain F, G must be left canonical (the boundary protects it even
   though it shares the protocol version). *)
let same_protocol_version_blocks : Block.t list =
  [ { id = 1
    ; state_hash = "A"
    ; parent_id = None
    ; parent_hash = "0"
    ; height = 1
    ; global_slot_since_genesis = 0
    ; global_slot_since_hard_fork = 0
    ; protocol_version_id = 1
    ; chain_status = "canonical"
    }
  ; { id = 2
    ; state_hash = "B"
    ; parent_id = Some 1
    ; parent_hash = "A"
    ; height = 2
    ; global_slot_since_genesis = 1
    ; global_slot_since_hard_fork = 1
    ; protocol_version_id = 1
    ; chain_status = "pending"
    }
  ; { id = 3
    ; state_hash = "C"
    ; parent_id = Some 2
    ; parent_hash = "B"
    ; height = 3
    ; global_slot_since_genesis = 2
    ; global_slot_since_hard_fork = 2
    ; protocol_version_id = 1
    ; chain_status = "pending"
    }
  ; { id = 4
    ; state_hash = "L"
    ; parent_id = Some 3
    ; parent_hash = "C"
    ; height = 4
    ; global_slot_since_genesis = 3
    ; global_slot_since_hard_fork = 3
    ; protocol_version_id = 1
    ; chain_status = "pending"
    }
  ; { id = 5
    ; state_hash = "F"
    ; parent_id = Some 3
    ; parent_hash = "C"
    ; height = 4
    ; global_slot_since_genesis = 4
    ; global_slot_since_hard_fork = 0
    ; protocol_version_id = 1
    ; chain_status = "canonical"
    }
  ; { id = 6
    ; state_hash = "G"
    ; parent_id = Some 5
    ; parent_hash = "F"
    ; height = 5
    ; global_slot_since_genesis = 5
    ; global_slot_since_hard_fork = 1
    ; protocol_version_id = 1
    ; chain_status = "canonical"
    }
  ]

let test_same_protocol_version_fork () =
  let open Deferred.Or_error.Let_syntax in
  let name = "test_same_protocol_version_fork" in
  let db_name = sprintf "test_%s" name in
  let%bind conn_str = setup_db db_name same_protocol_version_blocks in
  let postgres_uri = Uri.of_string (sprintf "%s/%s" conn_str db_name) in
  let%bind () =
    Logic.convert_chain_to_canonical ~postgres_uri ~stop_at_slot:None
      ~dry_run:false ()
  in
  check_blocks conn_str db_name ~name
    [ { state_hash = "A"; expected_chain_status = "canonical" }
    ; { state_hash = "B"; expected_chain_status = "canonical" }
    ; { state_hash = "C"; expected_chain_status = "canonical" }
    ; { state_hash = "F"; expected_chain_status = "canonical" }
    ; { state_hash = "G"; expected_chain_status = "canonical" }
    ; { state_hash = "L"; expected_chain_status = "orphaned" }
    ]

let query_summary_counts conn_str db_name ~canonical_block_ids
    ~fork_boundary_slot ~protocol_version =
  TestDb.with_pool conn_str ~db_name (fun pool ->
      Deferred.Or_error.try_with (fun () ->
          Mina_caqti.query pool
            ~f:
              (Sql.conversion_summary_counts ~canonical_block_ids
                 ~stop_at_slot:None ~fork_boundary_slot ~protocol_version ) ) )

(* Focused unit test for the change-plan summary counts. Uses the
   same-protocol-version fixture: canonical set {A, B, C} (ids 1..3), leftover L
   (id 4) to orphan, and the post-fork chain F, G held out by the boundary slot.
   Asserts the exact 4-tuple (to_canonical, pending_to_canonical, to_orphaned,
   pending_to_orphaned), then re-runs against a fixture where L is already
   orphaned to confirm to_orphaned excludes settled rows (so a re-run reports 0
   rather than recounting them). *)
let test_summary_counts () =
  let open Deferred.Or_error.Let_syntax in
  let canonical_block_ids = [ 1; 2; 3 ] in
  let protocol_version = Sql.Protocol_version.of_string "1.0.0" in
  (* F is the post-fork genesis at global_slot_since_genesis = 4; the boundary
     keeps F, G out of every count while L (slot 3) stays in. *)
  let fork_boundary_slot = Some 4L in
  let check ~name ~blocks ~expected =
    let db_name = sprintf "test_%s" name in
    let%bind conn_str = setup_db db_name blocks in
    let%bind actual =
      query_summary_counts conn_str db_name ~canonical_block_ids
        ~fork_boundary_slot ~protocol_version
    in
    let show (a, b, c, d) = sprintf "(%d, %d, %d, %d)" a b c d in
    if [%equal: int * int * int * int] actual expected then (
      printf "✅ Test %s passed\n" name ;
      Deferred.Or_error.return () )
    else (
      printf "❌ Test %s failed: expected %s, got %s\n" name (show expected)
        (show actual) ;
      Deferred.Or_error.error_string (sprintf "Test %s failed" name) )
  in
  (* Fresh fixture: A,B,C become canonical (2 of them pending), L becomes
     orphaned (pending). *)
  let%bind () =
    check ~name:"summary_counts_fresh" ~blocks:same_protocol_version_blocks
      ~expected:(3, 2, 1, 1)
  in
  (* Re-run: L is already orphaned, so to_orphaned and pending_to_orphaned drop
     to 0 while the canonical counts are unchanged. *)
  let orphaned_leftover_blocks =
    List.map same_protocol_version_blocks ~f:(fun block ->
        if String.equal block.Block.state_hash "L" then
          { block with Block.chain_status = "orphaned" }
        else block )
  in
  check ~name:"summary_counts_rerun" ~blocks:orphaned_leftover_blocks
    ~expected:(3, 2, 0, 0)

let () =
  Alcotest.run "Archive Hardfork Toolbox Tests"
    [ ( "convert_chain_to_canonical"
      , List.map TestScenarios.all_scenarios ~f:(fun scenario ->
            (scenario.name, `Quick, fun () -> make_test scenario) ) )
    ; ( "convert_chain_to_canonical_extras"
      , [ ( "test_auto_detect_latest_boundary"
          , `Quick
          , fun () ->
              Thread_safe.block_on_async_exn test_auto_detect_latest_boundary
              |> Or_error.ok_exn )
        ; ( "test_dry_run_writes_nothing"
          , `Quick
          , fun () ->
              Thread_safe.block_on_async_exn test_dry_run_writes_nothing
              |> Or_error.ok_exn )
        ; ( "test_same_protocol_version_fork"
          , `Quick
          , fun () ->
              Thread_safe.block_on_async_exn test_same_protocol_version_fork
              |> Or_error.ok_exn )
        ; ( "test_summary_counts"
          , `Quick
          , fun () ->
              Thread_safe.block_on_async_exn test_summary_counts
              |> Or_error.ok_exn )
        ] )
    ]
