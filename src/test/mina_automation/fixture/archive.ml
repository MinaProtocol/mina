open Async
open Core
open Mina_automation
open Intf

let logger = Logger.create ()

type after_bootstrap =
  { archive : Archive.Process.t
  ; network_data : Network_data.t
  ; temp_dir : string
  }

type before_bootstrap =
  { config : Archive.Config.t
  ; network_data : Network_data.t
  ; temp_dir : string
  }

let read_network_data_from_env_var () =
  match Sys.getenv "MINA_TEST_NETWORK_DATA" with
  | Some data ->
      Network_data.create data
  | None ->
      failwith "Environment variable MINA_TEST_NETWORK_DATA is not set"

let read_postgres_uri_from_env_var () =
  match Sys.getenv "MINA_TEST_POSTGRES_URI" with
  | Some uri ->
      uri
  | None ->
      failwith "Environment variable MINA_TEST_POSTGRES_URI is not set"
      
(** [setup_connection ~network_data] sets up a connection to the PostgreSQL database
  and creates a configuration for the Archive service.

  @param network_data The network data containing the genesis ledger path.
  @return A deferred Archive.Config.t value with the configuration for the Archive service.
*)
let setup_connection ~network_data ~postgres_uri ?(server_port = 3030)
    ?(prefix = "random_db") () =
  let open Deferred.Let_syntax in
  let connection = Psql.Conn_str postgres_uri in
  let%map db_name = Psql.create_random_mina_db ~connection ~prefix in
  Archive.Config.create
    ~config_file:(Network_data.genesis_ledger_path network_data)
    ~postgres_uri:(postgres_uri ^ "/" ^ db_name)
    ~server_port

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module Make_FixtureWithBootstrap (M : TestCaseWithBootstrap) :
  Fixture with type t = after_bootstrap = struct
  type t = after_bootstrap

  let test_case = M.test_case

  (** 
    Sets up the archive by performing the following steps:
    1. Retrieves the network data folder path from the environment variable "NETWORK_DATA_FOLDER". 
      (This variable must be set before running the test.)
    2. Creates network data using the retrieved folder path.
    3. Sets up a connection using the created network data.

    @return A record containing the started archive and the network data.
  *)
  let setup () =
    let open Deferred.Or_error.Let_syntax in
    let network_data = read_network_data_from_env_var () in
    let postgres_uri = read_postgres_uri_from_env_var () in
    let%bind.Deferred config =
      setup_connection ~network_data ~postgres_uri ()
    in
    let executor = Archive.of_config config in
    let%bind.Deferred archive = Archive.start executor in
    [%log info] "Archive started successfully" ;
    return
      { archive; network_data; temp_dir = Filename.temp_dir "archive_test" "" }

  let teardown t =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Tearing down archive" ;
    let%bind _ = Archive.Process.force_kill t.archive in
    let%bind.Deferred () =
      Mina_stdlib_unix.File_system.remove_dir @@ t.network_data.folder
    in
    [%log info] "Archive teardown completed" ;
    Deferred.Or_error.ok_unit

  let on_test_fail (t : t) =
    let open Deferred.Let_syntax in
    let%map contents = Process.stdout t.archive.process |> Reader.contents in
    [%log debug] "Archive process output: %s" contents ;
    ()
end

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap = struct
  type t = before_bootstrap

  (* This fixture does not bootstrap the archive, it only sets up the connection. *)
  (* The test case will be run against an already running archive. *)
  (* The archive is expected to be started before running the test case. *)

  (* The test case should handle the connection and any necessary setup. *)
  let test_case = M.test_case

  (** 
    Sets up the network data and configuration for the archive.

    @return A record containing the configuration and network data.

    @raise Sys_error if the environment variable "NETWORK_DATA_FOLDER" is not set.
  *)
  let setup () =
    let open Deferred.Or_error.Let_syntax in
    let network_data = read_network_data_from_env_var () in
    let postgres_uri = read_postgres_uri_from_env_var () in
    let%bind.Deferred config =
      setup_connection ~network_data ~postgres_uri ()
    in
    return
      { config; network_data; temp_dir = Filename.temp_dir "archive_test" "" }

  let teardown _t = Deferred.Or_error.ok_unit

  let on_test_fail _t = Deferred.unit
end
