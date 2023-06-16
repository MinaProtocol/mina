open Core
open Async
open Config

module TestRunner = struct
  let () =
    Backtrace.elide := false ;
    Async.Scheduler.set_record_backtraces true

  let remove_config_dirs dirs =
    Deferred.List.iter dirs ~f:(fun dir ->
        Deferred.ignore_m @@ Process.run_exn ~prog:"rm" ~args:[ "-rf"; dir ] () )

  let run test_case =
    let test_failed = ref false in
    let open Deferred.Let_syntax in
    let config = Config.default 1337 in
    let%bind () = ConfigDirs.generate_keys config.dirs in
    Monitor.protect
      ~finally:(fun () ->
        ( if !test_failed then
          let contents =
            Core.In_channel.(
              with_file (ConfigDirs.mina_log config.dirs) ~f:input_all)
          in
          printf
            !"**** DAEMON CRASHED (OUTPUT BELOW) ****\n%s\n************\n%!"
            contents ) ;
        if config.clean_up then remove_config_dirs (ConfigDirs.dirs config.dirs)
        else Deferred.unit )
      (fun () ->
        match%map test_case config with
        | Ok () ->
            ()
        | Error err ->
            test_failed := true ;
            Error.raise err )
end
