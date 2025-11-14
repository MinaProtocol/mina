open Core
open Async
open Archive_hardfork_toolbox_lib
open Caqti_request.Infix

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
    let open Deferred.Or_error.Let_syntax in
    let uri = uri_for conn_str db_name in
    let%bind pool = connect_pool uri in
    f pool

  let drop_database_if_exists conn_str db_name =
    let sql_string = sprintf "DROP DATABASE IF EXISTS %s" db_name in
    let query = (Caqti_type.unit ->. Caqti_type.unit) sql_string in
    with_pool conn_str (fun pool ->
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                Conn.exec query () ) ) )

  let create_database conn_str db_name =
    let sql_string = sprintf "CREATE DATABASE %s" db_name in
    let query = (Caqti_type.unit ->. Caqti_type.unit) sql_string in
    with_pool conn_str (fun pool ->
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                Conn.exec query () ) ) )

  (* This should always be in sync with src/app/archive/create_schema.sql *)
  let create_test_schema conn_str db_name =
    let open Deferred.Or_error.Let_syntax in
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
    let query0 =
      (Caqti_type.unit ->. Caqti_type.unit) chain_status_type_schema
    in
    let query1 =
      (Caqti_type.unit ->. Caqti_type.unit) protocol_versions_schema
    in
    let query2 = (Caqti_type.unit ->. Caqti_type.unit) blocks_schema in
    with_pool conn_str ~db_name (fun pool ->
        let%bind () =
          Deferred.Or_error.try_with (fun () ->
              Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                  Conn.exec query0 () ) )
        in
        let%bind () =
          Deferred.Or_error.try_with (fun () ->
              Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                  Conn.exec query1 () ) )
        in
        Deferred.Or_error.try_with (fun () ->
            Mina_caqti.query pool ~f:(fun (module Conn : Sql.CONNECTION) ->
                Conn.exec query2 () ) ) )

  let insert_protocol_versions conn_str db_name versions =
    let query =
      (Caqti_type.(t3 int int int) ->. Caqti_type.unit)
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
            let ( id
                , state_hash
                , parent_id
                , parent_hash
                , height
                , global_slot_since_genesis
                , global_slot_since_hard_fork
                , protocol_version_id
                , chain_status ) =
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
                Conn.collect_list query () ) ) )
end

(* Test scenarios based on the bash test fixtures *)
module TestScenarios = struct
  type block =
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

  type block_expected_state =
    { state_hash : string; expected_chain_status : string }

  type scenario =
    { name : string
    ; blocks : block list
    ; expected : block_expected_state list
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
  let%bind _drop = TestDb.drop_database_if_exists conn_str db_name in
  let%bind _create = TestDb.create_database conn_str db_name in
  let%bind _setup = TestDb.create_test_schema conn_str db_name in
  let blocks_tuples =
    List.map blocks ~f:(fun b ->
        ( b.id
        , b.state_hash
        , b.parent_id
        , b.parent_hash
        , b.height
        , b.global_slot_since_genesis
        , b.global_slot_since_hard_fork
        , b.protocol_version_id
        , b.chain_status ) )
  in
  let%bind _ =
    TestDb.insert_protocol_versions conn_str db_name [ (1, 0, 0); (2, 0, 0) ]
  in
  let%bind _insert = TestDb.insert_blocks conn_str db_name blocks_tuples in
  (* Run conversion *)
  let postgres_uri = Uri.of_string (sprintf "%s/%s" conn_str db_name) in
  let%bind _result =
    Logic.convert_chain_to_canonical ~postgres_uri
      ~latest_block_state_hash:target_hash
      ~expected_protocol_version_str:protocol_version ~stop_at_slot:None ()
  in

  (* Get results *)
  let%bind actual = TestDb.get_all_blocks conn_str db_name in

  (* Convert expected to tuples for comparison *)
  let expected_tuples =
    List.map expected
      ~f:(fun { TestScenarios.state_hash; expected_chain_status } ->
        (state_hash, expected_chain_status) )
  in

  (* Check results match expected *)
  let matches =
    List.equal
      (fun (h1, s1) (h2, s2) -> String.equal h1 h2 && String.equal s1 s2)
      actual expected_tuples
  in

  if matches then (
    printf "✅ Test %s passed\n" name ;
    Deferred.Or_error.return () )
  else (
    printf "❌ Test %s failed\n" name ;
    printf "Expected: %s\n"
      (List.to_string ~f:(fun (h, s) -> sprintf "%s->%s" h s) expected_tuples) ;
    printf "Actual: %s\n"
      (List.to_string ~f:(fun (h, s) -> sprintf "%s->%s" h s) actual) ;
    Deferred.Or_error.error_string (sprintf "Test %s failed" name) )

let make_test scenario =
  Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map result = test_convert_scenario scenario () in
      Or_error.ok_exn result )

let () =
  Alcotest.run "Archive Hardfork Toolbox Tests"
    [ ( "convert_chain_to_canonical"
      , List.map TestScenarios.all_scenarios ~f:(fun scenario ->
            (scenario.name, `Quick, fun () -> make_test scenario) ) )
    ]
