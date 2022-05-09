open Core
open Async
open Async.Deferred.Let_syntax

let error_raise e ~error_ctx = Error.tag ~tag:error_ctx e |> Error.raise

module Make_terminal_stdin (KP : sig
  type t

  val env : string

  val env_deprecated : string option

  val read :
       privkey_path:string
    -> password:Secret_file.password
    -> (t, Privkey_error.t) Deferred.Result.t

  val write_exn :
    t -> privkey_path:string -> password:Secret_file.password -> unit Deferred.t
end) =
struct
  open KP

  let rec prompt_password prompt =
    let open Deferred.Let_syntax in
    let%bind pw1 = Password.hidden_line_or_env prompt ~env in
    let%bind pw2 = Password.hidden_line_or_env "Again to confirm: " ~env in
    if not (Bytes.equal pw1 pw2) then (
      eprintf "Error: passwords don't match, try again\n" ;
      prompt_password prompt )
    else return pw2

  let read_exn ?(should_prompt_user = true) ?(should_reask = true) ~which path =
    let read_privkey password = read ~privkey_path:path ~password in
    let%bind result =
      match (Sys.getenv env, Option.bind env_deprecated ~f:Sys.getenv) with
      | Some password, _ ->
          (* this function is only called from client commands that can prompt for
             a password, so printing a message, rather than a formatted log, is OK
          *)
          printf "Using %s private-key password from environment variable %s\n"
            which env ;
          read_privkey (lazy (Deferred.return @@ Bytes.of_string password))
      | None, Some password ->
          (* this function is only called from client commands that can prompt for
             a password, so printing a message, rather than a formatted log, is OK
          *)
          printf
            "Using %s private-key password from deprecated environment \
             variable %s\n"
            which
            (Option.value_exn env_deprecated) ;
          printf "Please use environment variable %s instead\n" env ;
          read_privkey (lazy (Deferred.return @@ Bytes.of_string password))
      | None, None ->
          if should_prompt_user then
            let read_file () =
              read_privkey
                ( lazy
                  (Password.read_hidden_line ~error_help_message:""
                     "Private-key password: " ) )
            in
            let rec read_until_correct () =
              match%bind read_file () with
              | Ok result ->
                  Deferred.Result.return result
              | Error `Incorrect_password_or_corrupted_privkey ->
                  eprintf "Wrong password! Please try again\n" ;
                  read_until_correct ()
              | Error exn ->
                  Deferred.Result.fail exn
            in
            if should_reask then read_until_correct () else read_file ()
          else
            let checked_envs =
              env
              :: Option.value_map env_deprecated ~f:(fun x -> [ x ]) ~default:[]
            in
            Deferred.Result.fail (`Password_not_in_environment checked_envs)
    in
    match result with
    | Ok result ->
        return result
    | Error e ->
        Privkey_error.raise ~which e

  let write_exn kp ~privkey_path =
    write_exn kp ~privkey_path
      ~password:(lazy (prompt_password "Password for new private key file: "))
end
