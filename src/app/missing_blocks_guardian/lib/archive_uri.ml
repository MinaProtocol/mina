(* archive_uri.ml -- assembling and logging a PostgreSQL connection URI.

   There is no shared helper for this in the tree, so it lives here rather
   than inside {!Config}: it is the one place that has to know how a libpq URI
   is shaped, and keeping it apart means a second caller cannot log a
   connection string without also getting the redaction. *)

open Core

(** The settings the URI is built from when [PG_CONN] is not set.  Named here
    so the "what is unset" message and the read stay in step. *)
let parts = [ "DB_USERNAME"; "PGPASSWORD"; "DB_HOST"; "DB_PORT"; "DB_NAME" ]

let resolve ~flag ~env =
  match Option.first_some flag (env "PG_CONN") with
  | Some uri ->
      Ok (Uri.of_string uri)
  | None -> (
      let values = List.map parts ~f:(fun name -> (name, env name)) in
      let unset =
        List.filter_map values ~f:(fun (name, value) ->
            if Option.is_none value then Some name else None )
      in
      match List.map values ~f:snd with
      | [ Some user; Some password; Some host; Some port; Some db ] -> (
          match Option.try_with (fun () -> Int.of_string port) with
          | None ->
              Or_error.errorf "DB_PORT must be a port number, but it is %S" port
          | Some port ->
              Ok
                (Uri.make ~scheme:"postgres"
                   ~userinfo:(user ^ ":" ^ password)
                   ~host ~port ~path:("/" ^ db) () ) )
      | _ ->
          (* Every unset variable is named, not only the first, so that an
             operator with three of them learns all three in one run. *)
          Or_error.errorf
            "no archive database to connect to. Pass --archive-uri, or set \
             PG_CONN, or set all of DB_USERNAME, PGPASSWORD, DB_HOST, DB_PORT \
             and DB_NAME (unset: %s)"
            (String.concat ~sep:", " unset) )

(* Query parameters a libpq connection URI may carry a secret in.  The
   PostgreSQL driver accepts them, so they can appear in PG_CONN. *)
let secret_query_params = [ "password"; "sslpassword" ]

let redacted uri =
  let uri =
    match Uri.password uri with
    | None ->
        uri
    | Some _ ->
        Uri.with_password uri (Some "REDACTED")
  in
  let query =
    List.map (Uri.query uri) ~f:(fun (key, values) ->
        if
          List.mem secret_query_params (String.lowercase key)
            ~equal:String.equal
        then (key, List.map values ~f:(fun _ -> "REDACTED"))
        else (key, values) )
  in
  Uri.to_string (Uri.with_query uri query)

let%test_module "archive uri" =
  ( module struct
    let env_of assoc name =
      List.Assoc.find assoc name ~equal:String.equal
      |> Option.filter ~f:(fun v -> not (String.is_empty (String.strip v)))

    let%test "the DB_* variables are assembled into a URI" =
      match
        resolve ~flag:None
          ~env:
            (env_of
               [ ("DB_USERNAME", "u")
               ; ("PGPASSWORD", "p")
               ; ("DB_HOST", "h")
               ; ("DB_PORT", "5432")
               ; ("DB_NAME", "archive")
               ] )
      with
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
      Or_error.is_error
        (resolve ~flag:None
           ~env:
             (env_of
                [ ("DB_USERNAME", "u")
                ; ("PGPASSWORD", "p")
                ; ("DB_HOST", "h")
                ; ("DB_PORT", "not-a-port")
                ; ("DB_NAME", "archive")
                ] ) )

    let%test "the flag wins over PG_CONN" =
      match
        resolve ~flag:(Some "postgres://flag@h:5432/db")
          ~env:(env_of [ ("PG_CONN", "postgres://env@h:5432/db") ])
      with
      | Ok uri ->
          String.is_substring (Uri.to_string uri) ~substring:"flag"
      | Error _ ->
          false

    let%test "a userinfo password is redacted" =
      let out = redacted (Uri.of_string "postgres://u:hunter2@h:5432/db") in
      (not (String.is_substring out ~substring:"hunter2"))
      && String.is_substring out ~substring:"REDACTED"

    let%test "a query-string password is redacted too" =
      let out =
        redacted
          (Uri.of_string
             "postgres://u@h:5432/db?password=hunter2&sslmode=require" )
      in
      (not (String.is_substring out ~substring:"hunter2"))
      && String.is_substring out ~substring:"REDACTED"
      && String.is_substring out ~substring:"sslmode=require"
  end )
