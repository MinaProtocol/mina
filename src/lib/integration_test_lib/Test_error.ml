open Core_kernel

type remote_error = {node_id: string; error_message: Logger.Message.t}

(* NB: equality on internal errors ignores timestamp *)
type internal_error =
  { occurrence_time: Time.t sexp_opaque [@equal fun _ _ -> true]
  ; error: Error.t
        [@equal
          fun a b ->
            String.equal (Error.to_string_hum a) (Error.to_string_hum b)] }
[@@deriving eq, sexp, compare]

type t = Remote_error of remote_error | Internal_error of internal_error

let raw_internal_error error = {occurrence_time= Time.now (); error}

let internal_error error = Internal_error (raw_internal_error error)

let to_string = function
  | Remote_error {node_id; error_message} ->
      Printf.sprintf "[%s] %s: %s"
        (Time.to_string error_message.timestamp)
        node_id
        (Yojson.Safe.to_string (Logger.Message.to_yojson error_message))
  | Internal_error {occurrence_time; error} ->
      Printf.sprintf "[%s] test_executive: %s"
        (Time.to_string occurrence_time)
        (Error.to_string_hum error)

let occurrence_time = function
  | Remote_error {error_message; _} ->
      error_message.timestamp
  | Internal_error {occurrence_time; _} ->
      occurrence_time

module Set = struct
  type nonrec t = {soft_errors: t list; hard_errors: t list}

  let empty = {soft_errors= []; hard_errors= []}

  let soft_singleton err = {empty with soft_errors= [err]}

  let hard_singleton err = {empty with hard_errors= [err]}

  let merge a b =
    { soft_errors= a.soft_errors @ b.soft_errors
    ; hard_errors= a.hard_errors @ b.hard_errors }

  let combine = List.fold_left ~init:empty ~f:merge
end
