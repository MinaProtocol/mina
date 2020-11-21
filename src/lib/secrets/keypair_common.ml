open Core
open Async
open Async.Deferred.Let_syntax

let error_raise e ~error_ctx = Error.tag ~tag:error_ctx e |> Error.raise

module Make_terminal_stdin (KP : sig
  type t

  val env : string

  val read :
       privkey_path:string
    -> password:Secret_file.password
    -> (t, Privkey_error.t) Deferred.Result.t

  val write_exn :
       t
    -> privkey_path:string
    -> password:Secret_file.password
    -> unit Deferred.t
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

  let read_exn ?(should_reask = true) ~which path =
    let read_privkey password = read ~privkey_path:path ~password in
    let%bind result =
      match Sys.getenv env with
      | Some password ->
          read_privkey (lazy (Deferred.return @@ Bytes.of_string password))
      | None ->
          let read_file () =
            read_privkey
              ( lazy
                (Password.read_hidden_line ~error_help_message:""
                   "Secret key password: ") )
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
    in
    match result with
    | Ok result ->
        return result
    | Error e ->
        Privkey_error.raise ~which e

  let read_from_env_exn ~which path =
    let read_privkey password = read ~privkey_path:path ~password in
    let%bind result =
      match Sys.getenv env with
      | Some password ->
          read_privkey (lazy (Deferred.return @@ Bytes.of_string password))
      | None ->
          Deferred.Result.fail (`Password_not_in_environment env)
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
