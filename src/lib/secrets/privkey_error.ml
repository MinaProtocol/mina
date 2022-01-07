open Core

type t =
  [ `Corrupted_privkey of Error.t
  | `Incorrect_password_or_corrupted_privkey
  | `Cannot_open_file of string * Unix.Error.t
  | `Parent_directory_does_not_exist of string
  | `Password_not_in_environment of string list ]

let to_string : t -> string = function
  | `Corrupted_privkey e ->
      sprintf "The key was corrupted: %s" (Error.to_string_hum e)
  | `Incorrect_password_or_corrupted_privkey ->
      "The password was incorrect, or the key is corrupted"
  | `Cannot_open_file (path, e) ->
      sprintf "Cannot open file: %s. Error: %s" path (Unix.Error.message e)
  | `Parent_directory_does_not_exist directory_name ->
      sprintf
        "Parent directory %s does not exist\n\n\
         Hint: mkdir -p %s; chmod 700 %s\n"
        directory_name directory_name directory_name
  | `Password_not_in_environment [ env_var ] ->
      sprintf "No password was specified in environment variable %s" env_var
  | `Password_not_in_environment env_vars ->
      sprintf
        "No password was specified in any of the following environment \
         variables: %s"
        (String.concat env_vars ~sep:", ")

let raise ~which t =
  let where = sprintf "loading %s" which in
  Mina_user_error.raise ~where (to_string t)

let corrupted_privkey error : (_, t) Result.t = Error (`Corrupted_privkey error)
