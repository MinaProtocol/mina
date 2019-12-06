open Core

type t =
  [ `Corrupted_privkey of Error.t * string
  | `Incorrect_password_or_corrupted_privkey
  | `Cannot_open_file of string
  | `Parent_directory_does_not_exist of string ]

exception Privkey_exn of t

let to_string : t -> string = function
  | `Corrupted_privkey (e, which) ->
      sprintf !"Corrupted %s: %s" which (Error.to_string_hum e)
  | `Incorrect_password_or_corrupted_privkey ->
      "Incorrect_password_or_corrupted_privkey"
  | `Cannot_open_file path ->
      sprintf !"Cannot open file: %s" path
  | `Parent_directory_does_not_exist directory_name ->
      sprintf
        !"Parent directory %s does not exist Hint: mkdir -p %s; chmod 700 %s\n"
        directory_name directory_name directory_name

let raise t = Error.raise (Error.of_string (to_string t))

let corrupted_privkey error which = Error (`Corrupted_privkey (error, which))
