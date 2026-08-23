(** Choose which archive runtime to run.

    A hard fork replaces the archive and its tools with binaries compiled
    against a different schema. Rather than making operators swap paths, unit
    files and scripts, every archive command is a symlink to this program, which
    picks the matching runtime and [exec]s it.

    The daemon solves the same problem with a marker file. That does not work
    here: an archive's filesystem is typically ephemeral, so a marker written
    before a restart is gone when the container is replaced, and the next start
    would route back to the pre-fork binary. The archive's durable state is its
    database, so the database decides.

    What has to be true is that the binary matches the schema. [migration_history]
    records exactly that, and the upgrade script writes it, so it is read
    directly rather than inferred from anything else. A half-applied migration
    stops the node instead of starting the wrong runtime against a broken
    schema.

    Deliberately linked against nothing from [src/lib]. This program chooses
    between two protocol versions and so must not be compiled against either;
    the dependency list is the thing that enforces it. *)

open Core

let program_name = "mina-archive-dispatch"

let default_config_file = "/etc/default/mina-archive-dispatch"

(** Settings, read from a strict [KEY=value] file.

    Not shell-sourced. The daemon's dispatcher sources its configuration, which
    means an OCaml reimplementation would have to reproduce quoting, [export]
    and interpolation -- and would fail silently when it got them wrong. This
    file is a new one, so it can simply not have those semantics. *)
type config =
  { runtimes_base_path : string
  ; prefork_runtime : string
  ; postfork_runtime : string
  ; prefork_protocol_version : string
  ; postfork_protocol_version : string
  ; postgres_uri : string
  }

type outcome =
  | Run of { runtime : string; binary : string; argv : string list }
  | Refuse of { reason : string; detail : string }

let die_json refuse =
  match refuse with
  | Refuse { reason; detail } ->
      printf {|{"error":"%s","message":"%s"}|} reason
        (String.substr_replace_all detail ~pattern:{|"|} ~with_:{|\"|}) ;
      Out_channel.newline stdout ;
      exit 1
  | Run _ ->
      assert false

let die refuse =
  match refuse with
  | Refuse { reason; detail } ->
      eprintf "%s: %s\n%s\n" program_name reason detail ;
      exit 1
  | Run _ ->
      assert false

(* ------------------------------------------------------------------ *)
(* Configuration                                                       *)
(* ------------------------------------------------------------------ *)

let parse_config_lines lines =
  List.filter_map lines ~f:(fun line ->
      let line = String.strip line in
      if String.is_empty line || String.is_prefix line ~prefix:"#" then None
      else
        match String.lsplit2 line ~on:'=' with
        | None ->
            None
        | Some (k, v) ->
            (* Quotes are stripped for the common case of a quoted value, but
               nothing else about shell syntax is honoured. *)
            let v = String.strip v in
            let v =
              if String.length v >= 2
                 && ( (String.is_prefix v ~prefix:"\"" && String.is_suffix v ~suffix:"\"")
                    || (String.is_prefix v ~prefix:"'" && String.is_suffix v ~suffix:"'") )
              then String.sub v ~pos:1 ~len:(String.length v - 2)
              else v
            in
            Some (String.strip k, v) )

let read_config path =
  match Sys_unix.file_exists path with
  | `No | `Unknown ->
      Error
        (Refuse
           { reason = "config_file_not_found"
           ; detail =
               sprintf
                 "expected settings at %s. The archive automode package \
                  installs this file; its absence means the installation is \
                  incomplete."
                 path
           } )
  | `Yes ->
      let pairs = In_channel.read_lines path |> parse_config_lines in
      let get key =
        match List.Assoc.find pairs key ~equal:String.equal with
        | Some v when not (String.is_empty v) ->
            Ok v
        | _ ->
            Error
              (Refuse
                 { reason = "config_key_missing"
                 ; detail = sprintf "%s does not define %s" path key
                 } )
      in
      let open Result.Let_syntax in
      let%bind runtimes_base_path = get "RUNTIMES_BASE_PATH" in
      let%bind prefork_runtime = get "PREFORK_RUNTIME" in
      let%bind postfork_runtime = get "POSTFORK_RUNTIME" in
      let%bind prefork_protocol_version = get "PREFORK_PROTOCOL_VERSION" in
      let%bind postfork_protocol_version = get "POSTFORK_PROTOCOL_VERSION" in
      let%map postgres_uri = get "PGCONN" in
      { runtimes_base_path
      ; prefork_runtime
      ; postfork_runtime
      ; prefork_protocol_version
      ; postfork_protocol_version
      ; postgres_uri
      }

(* ------------------------------------------------------------------ *)
(* Which era is the schema in                                          *)
(* ------------------------------------------------------------------ *)

type schema_era =
  | Prefork
  | Postfork
  | Migration_in_progress of string
  | Unknown_version of string

(** Ask the database which era its schema is in.

    Synchronous on purpose. This process exists to [exec] something else, and an
    async scheduler would have to be torn down first -- with the Postgres socket
    leaking into the replacement unless every descriptor were accounted for. A
    blocking query has none of that. *)
let schema_era_of_database ~(config : config) =
  match
    Or_error.try_with ~backtrace:false (fun () ->
        let conn =
          try new Postgresql.connection ~conninfo:config.postgres_uri ()
          with Postgresql.Error e ->
            failwith (Postgresql.string_of_error e)
        in
        Exn.protect
          ~f:(fun () ->
            let result =
              conn#exec
                "SELECT protocol_version, status FROM migration_history \
                 ORDER BY commit_start_at DESC LIMIT 1"
            in
            match result#status with
            | Postgresql.Tuples_ok when result#ntuples = 0 ->
                (* The table exists but records no migration: nothing has been
                   applied, so the schema is still the pre-fork one. *)
                `Prefork
            | Postgresql.Tuples_ok ->
                `Row (result#getvalue 0 0, result#getvalue 0 1)
            | _ ->
                failwith result#error )
          (* Postgresql raises its own exception type, whose default printer
             says nothing useful. *)
          ~finally:(fun () -> conn#finish ) )
  with
  | Error err ->
      let msg = Error.to_string_hum err in
      (* A missing table means this database has never been migrated, which is
         the ordinary state of a pre-fork archive. Anything else is a real
         failure to reach or read the database. *)
      if String.is_substring msg ~substring:"migration_history" then Ok Prefork
      else
        Error
          (Refuse
             { reason = "database_unreachable"
             ; detail =
                 sprintf
                   "could not read migration_history: %s. Refusing to guess a \
                    runtime -- the archive cannot work without its database in \
                    any case."
                   msg
             } )
  | Ok `Prefork ->
      Ok Prefork
  | Ok (`Row (version, status)) ->
      if not (String.equal status "applied") then
        Ok (Migration_in_progress status)
      else if String.equal version config.prefork_protocol_version then Ok Prefork
      else if String.equal version config.postfork_protocol_version then
        Ok Postfork
      else Ok (Unknown_version version)

(* ------------------------------------------------------------------ *)
(* Dispatch                                                            *)
(* ------------------------------------------------------------------ *)

let resolve ~(config : config) ~invoked_as ~args =
  let open Result.Let_syntax in
  let%bind era = schema_era_of_database ~config in
  let%bind runtime =
    match era with
    | Prefork ->
        Ok config.prefork_runtime
    | Postfork ->
        Ok config.postfork_runtime
    | Migration_in_progress status ->
        Error
          (Refuse
             { reason = "migration_in_progress"
             ; detail =
                 sprintf
                   "the schema migration is in state '%s', so the schema is \
                    mid-change and neither runtime matches it. Nothing is \
                    started until it settles."
                   status
             } )
    | Unknown_version version ->
        Error
          (Refuse
             { reason = "unknown_protocol_version"
             ; detail =
                 sprintf
                   "the schema reports protocol version %s, which is neither \
                    the pre-fork (%s) nor the post-fork (%s) version this \
                    installation knows about."
                   version config.prefork_protocol_version
                   config.postfork_protocol_version
             } )
  in
  let binary =
    Filename.concat (Filename.concat config.runtimes_base_path runtime)
      invoked_as
  in
  match Sys_unix.file_exists binary with
  | `Yes ->
      Ok (Run { runtime; binary; argv = binary :: args })
  | `No | `Unknown ->
      Error
        (Refuse
           { reason = "binary_not_found"
           ; detail =
               sprintf
                 "the %s runtime does not provide %s (looked in %s). The \
                  runtime package may be incomplete."
                 runtime invoked_as binary
           } )

let explain ~(config : config) ~config_file ~invoked_as outcome =
  printf "%s\n" program_name ;
  printf "  invoked as        : %s\n" invoked_as ;
  printf "  settings          : %s\n" config_file ;
  printf "  runtimes          : %s/{%s,%s}\n" config.runtimes_base_path
    config.prefork_runtime config.postfork_runtime ;
  printf "  protocol versions : pre-fork %s, post-fork %s\n"
    config.prefork_protocol_version config.postfork_protocol_version ;
  printf "  decided by        : migration_history in the archive database\n" ;
  match outcome with
  | Run { runtime; binary; _ } ->
      printf "  chose             : %s\n" runtime ;
      printf "  would exec        : %s\n" binary
  | Refuse { reason; detail } ->
      printf "  refused           : %s\n" reason ;
      printf "  because           : %s\n" detail

let () =
  let argv = Sys.get_argv () in
  let invoked_as = Filename.basename argv.(0) in
  (* Direct invocation, for debugging: mina-archive-dispatch <command> [args] *)
  let is_self name =
    (* The installed name, and the names the executable carries before it is
       installed, so that direct invocation works for debugging. *)
    List.mem
      [ program_name; "archive_dispatch"; "archive_dispatch.exe" ]
      name ~equal:String.equal
  in
  let invoked_as, args =
    if is_self invoked_as then
      match Array.to_list argv with
      | _ :: cmd :: rest when not (String.is_prefix cmd ~prefix:"-") ->
          (cmd, rest)
      | _ :: rest ->
          (program_name, rest)
      | [] ->
          (program_name, [])
    else (invoked_as, Array.to_list argv |> List.tl |> Option.value ~default:[])
  in
  let want_explain =
    List.mem args "--explain" ~equal:String.equal
    || Option.is_some (Sys.getenv "MINA_ARCHIVE_DISPATCH_EXPLAIN")
  in
  let args = List.filter args ~f:(fun a -> not (String.equal a "--explain")) in
  let want_json = Option.is_some (Sys.getenv "MINA_ARCHIVE_DISPATCH_JSON") in
  let want_dryrun =
    want_explain || want_json
    || Option.is_some (Sys.getenv "MINA_ARCHIVE_DISPATCH_DRYRUN")
  in
  let config_file =
    Option.value
      (Sys.getenv "MINA_ARCHIVE_DISPATCH_CONFIG")
      ~default:default_config_file
  in
  match read_config config_file with
  | Error refuse ->
      if want_json then die_json refuse else die refuse
  | Ok config -> (
      let outcome =
        match resolve ~config ~invoked_as ~args with
        | Ok run ->
            run
        | Error refuse ->
            refuse
      in
      if want_explain then (
        explain ~config ~config_file ~invoked_as outcome ;
        match outcome with Run _ -> exit 0 | Refuse _ -> exit 1 ) ;
      match outcome with
      | Refuse _ as refuse ->
          if want_json then die_json refuse else die refuse
      | Run { runtime; binary; argv } ->
          if want_json then (
            printf {|{"runtime":"%s","binary":"%s","command":"%s"}|} runtime
              binary
              (String.concat ~sep:" " argv) ;
            Out_channel.newline stdout ;
            exit 0 )
          else if want_dryrun then (
            eprintf "%s DRYRUN: exec %s\n" program_name
              (String.concat ~sep:" " argv) ;
            exit 0 )
          else
            (* Replace this process rather than spawning: the caller's
               supervisor is watching this pid, and signals must reach the
               runtime directly. *)
            never_returns
              (Core_unix.exec ~prog:binary ~argv ~use_path:false ()) )
