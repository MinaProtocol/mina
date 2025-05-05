(**
   This script recursively formats all `.ml` and `.mli` files in a
   given directory using `ocamlformat`. It supports concurrency and can either
   modify files in place or check if formatting is needed.
   The files `dune` are excluded from formatting as they must be formatted using
   `dune fmt` and this requires to run dune rules which is slow.

   It is used instead of `dune fmt [--auto-promote]` to avoid requiring to run
   dune rules and slowing down the process.

   ============================================================================
   USAGE:

    ./reformat.exe --path <path> [--dry-run] [--check]

   ARGUMENTS:

    --path <path>       The root directory to begin traversal from.
    --dry-run           (Optional) Print the ocamlformat commands without running them.
    --check             (Optional) Run in verification mode. Fails if any file needs formatting.
*)
open Core

open Async

(* Files that should not be formatted *)
let trustlist = String.Set.of_list []

(* Directories to skip *)
let dirs_trustlist =
  String.Set.of_list
    [ ".git"
    ; "_build"
    ; "_opam"
    ; ".un~"
    ; "frontend"
    ; "external"
    ; "node_modules"
    ; "opam_switches"
    ; "src/lib/snarky"
    ; "/src/lib/crypto/kimchi_bindings/stubs/kimchi-stubs-vendors/"
    ; "/src/lib/crypto/proof-systems"
    ; ".direnv"
    ]

let rec fold_over_files ~path ~process_path ~f =
  let%bind all = Sys.ls_dir path in
  Deferred.List.iter ~how:(`Max_concurrent_jobs 8) all ~f:(fun x ->
      let full_path = path ^/ x in
      match%bind Sys.is_directory full_path with
      | `Yes when process_path `Dir full_path ->
          fold_over_files ~path:full_path ~process_path ~f
      | `Yes ->
          return ()
      | _ when process_path `File full_path ->
          f full_path
      | _ ->
          return () )

let main dry_run check path =
  let has_error = ref false in
  let%bind () =
    fold_over_files ~path
      ~process_path:(fun kind path ->
        let filename = Filename.basename path in
        match kind with
        | `Dir ->
            not
              (Set.exists dirs_trustlist ~f:(fun s ->
                   String.is_suffix ~suffix:s path ) )
        | `File ->
            (not (Set.mem trustlist path))
            && ( String.is_suffix ~suffix:".ml" filename
               || String.is_suffix ~suffix:".mli" filename ) )
      ~f:(fun file ->
        let dump prog args =
          printf !"%s %{sexp: string list}\n" prog args ;
          return ()
        in
        if check then (
          let prog = "ocamlformat" in
          let args = [ "--check"; file ] in
          match%bind Process.run ~prog ~args () with
          | Ok _ ->
              return ()
          | Error _ ->
              eprintf
                "File: %s needs ocamlformat. You can run `make reformat`\n" file ;
              has_error := true ;
              return () )
        else
          let prog, args = ("ocamlformat", [ "-i"; file ]) in
          if dry_run then dump prog args
          else
            let%map (_ : string) = Process.run_exn ~prog ~args () in
            () )
  in
  if !has_error then exit 1 else exit 0

let _cli =
  let open Command.Let_syntax in
  Command.async ~summary:"Format all .ml and .mli files (with concurrency)"
    (let%map_open path =
       flag "--path" ~aliases:[ "path" ] ~doc:"Path to traverse"
         (required string)
     and dry_run = flag "--dry-run" ~aliases:[ "dry-run" ] no_arg ~doc:"Dry run"
     and check =
       flag "--check" ~aliases:[ "check" ] no_arg
         ~doc:"Return with error code if any file needs formatting"
     in
     fun () -> main dry_run check path )
  |> Command.run

let () = never_returns (Scheduler.go ())
