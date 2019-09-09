open Core

exception Corrupted_privkey of Error.t

exception Incorrect_password_or_corrupted_privkey

type t =
  | Corrupted_privkey of Error.t
  | Incorrect_password_or_corrupted_privkey

let to_string = function
  | Corrupted_privkey e ->
      sprintf !"Corrupted_privkey: %s" (Error.to_string_hum e)
  | Incorrect_password_or_corrupted_privkey ->
      "Incorrect_password_or_corrupted_privkey"

let raise = function
  | Corrupted_privkey e ->
      raise (Corrupted_privkey e)
  | Incorrect_password_or_corrupted_privkey ->
      raise Incorrect_password_or_corrupted_privkey

let curropted_privkey error = Error (Corrupted_privkey error)
