open Async

type init =
  { archive : Archive.ArchiveProcess.t; network_data_folder : Network_data.t }

module type ArchiveDefaultTest = Test_runner.DefaultTestCase with type t = init

module Make_DefaultTestCase (M : ArchiveDefaultTest) :
  Test_runner.TestCase with type t = init = struct
  type t = init

  let test_case = M.test_case

  let setup =
    let network_data_folder = Sys.getenv_exn "NETWORK_DATA_FOLDER" in
    let postgres_uri = Sys.getenv_exn "POSTGRES_URI" in
    let executor = Archive.of_context AutoDetect in
    let network_data = Network_data.create network_data_folder in
    let connection = Psql.Conn_str postgres_uri in
    let db_name = "random_db" in
    let%bind () = Psql.create_mina_db ~connection ~db:db_name in
    let config =
      Archive.Config.create
        ~config_file:(Network_data.genesis_ledger_path network_data)
        ~postgres_uri:(postgres_uri ^ "/" ^ db_name)
        ~server_port:3030
    in
    let%bind archive = Archive.start config executor in
    return { archive; network_data_folder = network_data }

  let teardown t =
    let open Deferred.Or_error.Let_syntax in
    let%bind _ = Archive.ArchiveProcess.force_kill t.archive in
    Deferred.Or_error.ok_unit

  let on_test_fail (t : t) =
    let%bind contents = Process.stdout t.archive.process |> Reader.contents in
    Async.printf
      !"**** Archive CRASHED (OUTPUT BELOW) ****\n%s\n************\n%!"
      contents ;
    Deferred.unit
end
