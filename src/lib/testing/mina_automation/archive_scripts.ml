(** The archive's SQL scripts: the schema and its migrations. A script is
    looked up in the source tree first, then where the Debian package
    installs it. *)

open Core
open Async

type t = [ `CreateSchema | `DropTables | `Upgrade | `Rollback ]

let file = function
  | `CreateSchema ->
      "create_schema.sql"
  | `DropTables ->
      "drop_tables.sql"
  | `Upgrade ->
      "upgrade.sql"
  | `Rollback ->
      "downgrade.sql"

let source_dir = "src/app/archive"

let installed_dir = "/etc/mina/archive"

let possible_locations = [ installed_dir; source_dir ]

(** The script under the working directory or on [PATH], if any. *)
let filepath t =
  Mina_automation_process.Host.possible_locations ~file:(file t)
    possible_locations

(* the nearest [source_dir] above [dir] *)
let rec find_in_source_tree ~file dir =
  let candidate = dir ^/ source_dir ^/ file in
  match%bind Sys.file_exists candidate with
  | `Yes ->
      return (Some candidate)
  | `No | `Unknown ->
      let parent = Filename.dirname dir in
      if String.equal parent dir then return None
      else find_in_source_tree ~file parent

(** The script of the code under test: the nearest [source_dir] above the
    working directory (a dune test runs inside [_build/default/<dir>], where
    its declared deps are copied), else {!filepath}. *)
let find t =
  let file = file t in
  match%map find_in_source_tree ~file (Core_unix.getcwd ()) with
  | Some path ->
      Ok path
  | None -> (
      match filepath t with
      | Some path ->
          Ok path
      | None ->
          Or_error.errorf
            "cannot find %s: a dune test must declare it, e.g. (deps \
             %%{project_root}/app/archive/%s)"
            file file )
