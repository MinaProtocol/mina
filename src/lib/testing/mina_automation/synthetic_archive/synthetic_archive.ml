open Core
open Async

module Db = struct
  type t = { name : string; uri : Uri.t }

  (* create drops a database of the same name first, so only names that are
     obviously a test's are accepted *)
  let check_name name =
    if String.is_prefix name ~prefix:"test_" then Ok ()
    else
      Or_error.errorf
        "refusing database %S: test databases must be named test_*, since \
         create drops a database of the same name"
        name

  let on_server server_uri db =
    Mina_automation.Psql.Conn_str
      (Uri.to_string (Uri.with_path server_uri ("/" ^ db)))

  let drop { name; uri } =
    let open Deferred.Or_error.Let_syntax in
    let%bind () = Deferred.return (check_name name) in
    Mina_automation.Psql.drop_db_if_exists
      ~connection:(on_server uri "postgres") ~db:name
    >>| ignore

  let load_script db script =
    let open Deferred.Or_error.Let_syntax in
    let%bind path = Mina_automation.Archive.Scripts.find script in
    Mina_automation.Psql.run_script_or_error
      ~connection:(on_server db.uri db.name) path

  let create ?(upgrade = false) ~server_uri ~name () =
    let open Deferred.Or_error.Let_syntax in
    let%bind () = Deferred.return (check_name name) in
    let db = { name; uri = Uri.with_path server_uri ("/" ^ name) } in
    let%bind () = drop db in
    let%bind (_ : string) =
      Mina_automation.Psql.create_empty_db
        ~connection:(on_server server_uri "postgres")
        ~db:name
    in
    let%bind () = load_script db `CreateSchema in
    let%map () = if upgrade then load_script db `Upgrade else return () in
    db

  let run_script = load_script

  let test_server_env = "MINA_TEST_POSTGRES"

  let test_server_uri () =
    match Sys.getenv test_server_env with
    | Some uri ->
        Uri.of_string uri
    | None ->
        (* Stdlib's: Async's prerr_endline only writes once its scheduler
           runs, and exit comes first *)
        Stdlib.prerr_endline
          (sprintf
             "%s is not set. Database tests need a PostgreSQL server, e.g. \
              %s=postgres://postgres:postgres@localhost:5432"
             test_server_env test_server_env ) ;
        Stdlib.exit 2

  let with_connection { uri; _ } f =
    let%bind conn =
      Mina_caqti.connect uri >>| Mina_caqti.ok_exn ~ctx:"connect"
    in
    let (module Conn : Mina_caqti.CONNECTION) = conn in
    Monitor.protect ~finally:Conn.disconnect (fun () -> f conn)

  let with_fresh ?upgrade ?(keep = false) ~server_uri ~name f =
    let open Deferred.Or_error.Let_syntax in
    let%bind db = create ?upgrade ~server_uri ~name () in
    (* f raising -- a failed check, an ok_exn -- still drops the database *)
    let%bind.Deferred result =
      Deferred.map ~f:Or_error.join (Monitor.try_with_or_error (fun () -> f db))
    in
    let%bind () = if keep then return () else drop db in
    Deferred.return result
end

include Scenario

type built = Rows.ids

let block_id (built : built) b = Hashtbl.find_exn built.blocks b.index

let user_command_id (built : built) c =
  Hashtbl.find_exn built.user_commands c.command_hash

let zkapp_command_id (built : built) c =
  Hashtbl.find_exn built.zkapp_commands c.zkapp_hash

let coinbase_id (built : built) c =
  Hashtbl.find_exn built.coinbases (coinbase_hash c)

let materialize (t : t) (db : Db.t) =
  if t.materialized then
    Deferred.Or_error.error_string "this scenario was already written"
  else (
    t.materialized <- true ;
    Rows.write t ~uri:db.uri ~db_name:db.name )
