(* archive_uri.ml -- the archive's connection URI, from the command line or
   the environment. *)

open Core

(* the variables that together name the database, in [make]'s argument
   order *)
let db_settings =
  [ "DB_USERNAME"; "PGPASSWORD"; "DB_HOST"; "DB_PORT"; "DB_NAME" ]

let of_db_settings ~env =
  match Option.all (List.map db_settings ~f:env) with
  | Some [ user; password; host; port; db ] -> (
      match Option.try_with (fun () -> Int.of_string port) with
      | None ->
          Or_error.errorf "DB_PORT must be a port number, but it is %S" port
      | Some port ->
          Ok (Mina_caqti.Connection_uri.make ~user ~password ~host ~port ~db) )
  | Some _ | None ->
      let unset =
        List.filter db_settings ~f:(fun name -> Option.is_none (env name))
      in
      Or_error.errorf
        "no archive database to connect to. Pass --archive-uri, or set \
         PG_CONN, or set all of %s (unset: %s)"
        (String.concat ~sep:", " db_settings)
        (String.concat ~sep:", " unset)

(** The connection URI, from the first of these that is set: [--archive-uri]
    ([flag]), [PG_CONN], or all of [db_settings]. [env] must report an empty
    variable as unset. *)
let resolve ~flag ~env =
  match Option.first_some flag (env Env.pg_conn) with
  | Some uri ->
      Ok (Uri.of_string uri)
  | None ->
      of_db_settings ~env

let%test_module "archive uri" =
  ( module struct
    let env_of assoc name =
      List.Assoc.find assoc name ~equal:String.equal
      |> Option.filter ~f:(fun v -> not (String.is_empty (String.strip v)))

    (* every DB_* variable set, with [port] as DB_PORT *)
    let db_env ?(port = "5432") () =
      env_of
        [ ("DB_USERNAME", "u")
        ; ("PGPASSWORD", "p")
        ; ("DB_HOST", "h")
        ; ("DB_PORT", port)
        ; ("DB_NAME", "archive")
        ]

    let%test "the DB_* variables are assembled into a URI" =
      match resolve ~flag:None ~env:(db_env ()) with
      | Ok uri ->
          String.equal (Uri.to_string uri) "postgres://u:p@h:5432/archive"
      | Error _ ->
          false

    let%test "every unset variable is named, not only the first" =
      match resolve ~flag:None ~env:(env_of [ ("DB_USERNAME", "u") ]) with
      | Error err ->
          let message = Error.to_string_hum err in
          List.for_all [ "PGPASSWORD"; "DB_HOST"; "DB_PORT"; "DB_NAME" ]
            ~f:(fun name -> String.is_substring message ~substring:name)
      | Ok _ ->
          false

    let%test "a DB_PORT that is not a number is rejected" =
      Or_error.is_error (resolve ~flag:None ~env:(db_env ~port:"not-a-port" ()))

    let%test "the flag wins over PG_CONN" =
      match
        resolve ~flag:(Some "postgres://flag@h:5432/db")
          ~env:(env_of [ ("PG_CONN", "postgres://env@h:5432/db") ])
      with
      | Ok uri ->
          String.is_substring (Uri.to_string uri) ~substring:"flag"
      | Error _ ->
          false
  end )
