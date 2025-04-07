open Core
open Async

module MinaCli = struct
  type t = { port : int; mina_exe : string }

  let create ?(port = 3085) mina_exe = { port; mina_exe }

  let stop_daemon t =
    Process.run () ~prog:t.mina_exe
      ~args:[ "client"; "stop-daemon"; "-daemon-port"; sprintf "%d" t.port ]

  let daemon_status t =
    Process.run ~prog:t.mina_exe
      ~args:[ "client"; "status"; "-daemon-port"; sprintf "%d" t.port ]
      ()

  let ledger_hash t ~ledger_file =
    Process.run ~prog:t.mina_exe
      ~args:[ "ledger"; "hash"; "--ledger-file"; ledger_file ]
      ()

  let ledger_currency t ~ledger_file =
    Process.run ~prog:t.mina_exe
      ~args:[ "ledger"; "currency"; "--ledger-file"; ledger_file ]
      ()

  let test_ledger t ~(n : int) =
    Process.run ~prog:t.mina_exe
      ~args:[ "ledger"; "test"; "generate-accounts"; "-n"; string_of_int n ]
      ()

  let advanced_print_signature_kind t =
    Process.run ~prog:t.mina_exe ~args:[ "advanced"; "print-signature-kind" ] ()

  let advanced_compile_time_constants t ~config_file =
    Process.run
      ~env:(`Extend [ ("MINA_CONFIG_FILE", config_file) ])
      ~prog:t.mina_exe
      ~args:[ "advanced"; "compile-time-constants" ]
      ()

  let advanced_constraint_system_digests t =
    Process.run ~prog:t.mina_exe
      ~args:[ "advanced"; "constraint-system-digests" ]
      ()
end
