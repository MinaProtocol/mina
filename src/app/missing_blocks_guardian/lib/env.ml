(* env.ml -- the environment variables the guardian reads. Each one has a
   command line flag that overrides it. *)

open Core

let pg_conn = "PG_CONN"

let precomputed_blocks_url = "PRECOMPUTED_BLOCKS_URL"

let network = "MINA_NETWORK"

let blocks_format = "BLOCKS_FORMAT"

let timeout = "TIMEOUT"

(** The variable's value; an empty variable counts as unset. *)
let get name =
  match Sys.getenv name with
  | Some value when not (String.is_empty (String.strip value)) ->
      Some (String.strip value)
  | _ ->
      None

(** A variable holding a number, which must parse when it is set. *)
let float name =
  match get name with
  | None ->
      Ok None
  | Some raw -> (
      match Option.try_with (fun () -> Float.of_string raw) with
      | Some value ->
          Ok (Some value)
      | None ->
          Or_error.errorf "%s must be a number, but it is %S" name raw )
