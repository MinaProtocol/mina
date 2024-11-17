open Async

module type DaemonDefaultTest =
  Test_runner.DefaultTestCase with type t = Daemon.DaemonProcess.t

module Make_DefaultTestCase (M : DaemonDefaultTest) : Test_runner.TestCase =
struct
  type t = M.t

  let test_case = M.test_case

  let setup =
    let executor = Daemon.of_context AutoDetect in
    let config = Daemon.Config.create 1337 in
    let%bind () = Daemon.Config.generate_keys config in
    Daemon.start executor config

  let teardown daemon =
    let open Deferred.Or_error.Let_syntax in
    let%bind _ = Daemon.DaemonProcess.force_kill daemon in
    Deferred.Or_error.ok_unit

  let on_test_fail (daemon : Daemon.DaemonProcess.t) =
    let contents =
      Core.In_channel.(
        with_file
          (Daemon.Config.ConfigDirs.mina_log daemon.config.dirs)
          ~f:input_all)
    in
    printf
      !"**** DAEMON CRASHED (OUTPUT BELOW) ****\n%s\n************\n%!"
      contents ;
    Deferred.unit
end
