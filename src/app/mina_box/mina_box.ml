(* mina-box: a busybox-style multicall binary bundling every OCaml
   executable that ships in Mina's production debian packages.

   Dispatch is on [Filename.basename Sys.argv.(0)]: each installed name
   (e.g. mina-archive) is a symlink to this binary.  Invoking it directly
   as [mina-box <applet> <args>] re-execs itself with argv shifted by
   one, so an applet's own argument parsing (including [Command_unix.run]
   reading [Sys.argv]) sees exactly what it would as a standalone
   binary. *)

let applets : (string * (unit -> unit)) list =
  [ ("mina", Mina_cli_entrypoint.run)
  ; ("mina-archive", Archive_applet.run)
  ; ("mina-archive-blocks", Archive_blocks_lib.run)
  ; ("mina-archive-hardfork-toolbox", Archive_hardfork_toolbox_applet.run)
  ; ("mina-archive-healthcheck", Mina_archive_healthcheck_lib.run)
  ; ("mina-create-genesis", Runtime_genesis_ledger_applet.run)
  ; ("mina-dump-slot-ledger", Dump_slot_ledger_lib.run)
  ; ("mina-extract-blocks", Extract_blocks_lib.run)
  ; ("mina-generate-keypair", Generate_keypair_lib.run)
  ; ("mina-graphql-client", Mina_graphql_client_app_lib.run)
  ; ("mina-healthcheck", Mina_healthcheck_applet.run)
  ; ("mina-missing-blocks-auditor", Missing_blocks_auditor_lib.run)
  ; ("mina-ocaml-signer", Signer_applet.run)
  ; ("mina-replayer", Replayer_lib.run)
  ; ("mina-rosetta", Rosetta_applet.run)
  ; ("mina-standalone-snark-worker", Run_snark_worker_applet.run)
  ; ("mina-validate-keypair", Validate_keypair_lib.run)
  ; ("rosetta-client", Rosetta_client_applet.run)
  ; ("rosetta-healthcheck", Rosetta_healthcheck_applet.run)
  ]

let usage () =
  prerr_endline
    "Usage: <applet> [args]     (via a symlink named after the applet)" ;
  prerr_endline "       mina-box <applet> [args]" ;
  prerr_endline "Available applets:" ;
  List.iter (fun (name, _) -> prerr_endline ("  " ^ name)) applets

let () =
  let argv = Sys.argv in
  match List.assoc_opt (Filename.basename argv.(0)) applets with
  | Some run ->
      run ()
  | None ->
      if Array.length argv >= 2 && List.mem_assoc argv.(1) applets then
        Unix.execv Sys.executable_name
          (Array.sub argv 1 (Array.length argv - 1))
      else (usage () ; exit 1)
