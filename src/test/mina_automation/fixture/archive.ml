open Async
open Mina_automation
open Intf

let logger = Logger.create ()

type after_bootstrap =
  { archive : Archive.Process.t; network_data : Network_data.t }

type before_bootstrap =
  { config : Archive.Config.t; network_data : Network_data.t }

let setup_connection ~network_data =
  let open Deferred.Let_syntax in
  let postgres_uri = Sys.getenv_exn "POSTGRES_URI" in
  let connection = Psql.Conn_str postgres_uri in
  let db_name = "random_db" in
  let%bind () = Psql.create_mina_db ~connection ~db:db_name in
  return
    (Archive.Config.create
       ~config_file:(Network_data.genesis_ledger_path network_data)
       ~postgres_uri:(postgres_uri ^ "/" ^ db_name)
       ~server_port:3030 )

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module Make_FixtureWithBootstrap (M : TestCaseWithBootstrap) :
  Fixture with type t = after_bootstrap = struct
  type t = after_bootstrap

  let test_case = M.test_case

  let setup () =
    let open Deferred.Or_error.Let_syntax in
    let network_data_folder = Sys.getenv_exn "NETWORK_DATA_FOLDER" in
    let network_data = Network_data.create network_data_folder in
    let%bind.Deferred config = setup_connection ~network_data in
    let executor = Archive.of_config config in
    let%bind.Deferred archive = Archive.start executor in
    [%log info] "Archive started successfully with " ;
    return { archive; network_data }

  let teardown t =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Tearing down archive" ;
    let%bind _ = Archive.Process.force_kill t.archive in
    Deferred.Or_error.ok_unit

  let on_test_fail (t : t) =
    let open Deferred.Let_syntax in
    let%bind contents = Process.stdout t.archive.process |> Reader.contents in
    [%log debug] "Archive process output: %s" contents ;
    return ()
end

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap = struct
  type t = before_bootstrap

  let test_case = M.test_case

  let setup () =
    let open Deferred.Or_error.Let_syntax in
    let network_data_folder = Sys.getenv_exn "NETWORK_DATA_FOLDER" in
    let network_data = Network_data.create network_data_folder in
    let%bind.Deferred config = setup_connection ~network_data in
    return { config; network_data }

  let teardown _t = Deferred.Or_error.ok_unit

  let on_test_fail _t = Deferred.unit
end
