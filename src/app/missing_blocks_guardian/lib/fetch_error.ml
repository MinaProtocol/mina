(* fetch_error.ml -- the reasons one block file could not be read, as values.

   Two things follow from naming them instead of writing a string at each
   point of failure.  The retry policy lives next to the taxonomy it depends
   on, so a new case cannot be added without deciding whether it is worth
   retrying.  And the wording an operator reads is in one place, so a message
   cannot drift at one call site while the others keep the old text. *)

open Core

type t =
  | Connection_failed of { location : string; reason : string }
  | Timed_out of { location : string; after : Time_ns.Span.t }
  | Not_found of { name : string; location : string }
  | Redirected of { location : string; code : int; target : string }
  | Access_refused of { location : string; code : int; body : string }
  | Server_error of { location : string; code : int; body : string }
  | Unexpected_status of { location : string; code : int; body : string }
  | File_missing of { path : string; directory : string }
  | File_unreadable of { path : string; reason : string }
  | Empty_body of { where : string }
  | Malformed_json of { where : string; reason : string; body : string }

let connection_failed ~location ~exn =
  Connection_failed { location; reason = Exn.to_string exn }

let timed_out ~location ~after = Timed_out { location; after }

let not_found ~name ~location = Not_found { name; location }

let redirected ~location ~code ~target = Redirected { location; code; target }

let access_refused ~location ~code ~body =
  Access_refused { location; code; body }

let server_error ~location ~code ~body = Server_error { location; code; body }

let unexpected_status ~location ~code ~body =
  Unexpected_status { location; code; body }

let file_missing ~path ~directory = File_missing { path; directory }

let file_unreadable ~path ~exn =
  File_unreadable { path; reason = Exn.to_string exn }

let empty_body ~where = Empty_body { where }

let malformed_json ~where ~reason ~body = Malformed_json { where; reason; body }

let is_retriable = function
  | Connection_failed _ | Timed_out _ | Server_error _ ->
      true
  | Not_found _
  | Redirected _
  | Access_refused _
  | Unexpected_status _
  | File_missing _
  | File_unreadable _
  | Empty_body _
  | Malformed_json _ ->
      false

(* Bucket error pages are HTML or XML and can be long.  Show enough of one to
   recognise it without flooding the log. *)
let snippet_length = 200

let snippet body =
  let cleaned =
    String.map body ~f:(fun c ->
        if Char.is_print c || Char.equal c ' ' then c else ' ' )
    |> String.strip
  in
  if String.length cleaned <= snippet_length then cleaned
  else String.prefix cleaned snippet_length ^ "..."

let reason_phrase code = Cohttp.Code.reason_phrase_of_code code

let to_error = function
  | Connection_failed { location; reason } ->
      Error.createf "could not GET %s: %s" location reason
  | Timed_out { location; after } ->
      Error.createf "GET %s timed out after %s" location
        (Time_ns.Span.to_string_hum after)
  | Not_found { name; location } ->
      Error.createf
        "block file %s is not in the bucket: GET %s returned 404. Check that \
         PRECOMPUTED_BLOCKS_URL (--precomputed-blocks-url) and MINA_NETWORK \
         (--network) name the bucket and network this archive was built from, \
         and that the bucket holds blocks this far back."
        name location
  | Redirected { location; code; target } ->
      Error.createf
        "GET %s was redirected with HTTP %d to %s. Redirects are not followed; \
         set --precomputed-blocks-url (PRECOMPUTED_BLOCKS_URL) to the URL the \
         blocks are actually served from."
        location code target
  | Access_refused { location; code; body } ->
      Error.createf
        "access to %s was refused: HTTP %d %s. The bucket is not public, or \
         the credentials in use cannot read it. Response body: %s"
        location code (reason_phrase code) (snippet body)
  | Server_error { location; code; body }
  | Unexpected_status { location; code; body } ->
      Error.createf "GET %s returned HTTP %d %s. Response body: %s" location
        code (reason_phrase code) (snippet body)
  | File_missing { path; directory } ->
      Error.createf
        "block file %s does not exist. Check that the block source directory \
         %s holds blocks this far back and that the network prefix is right."
        path directory
  | File_unreadable { path; reason } ->
      Error.createf "could not read block file %s: %s" path reason
  | Empty_body { where } ->
      Error.createf "%s is empty. Expected a JSON encoded block." where
  | Malformed_json { where; reason; body } ->
      Error.createf
        "%s is not valid JSON (%s). The first %d bytes of what was read are: %s"
        where reason snippet_length (snippet body)

let%test_module "fetch error" =
  ( module struct
    let%test "a connection failure is worth retrying" =
      is_retriable
        (connection_failed ~location:"http://h/b.json"
           ~exn:(Failure "connection refused") )

    let%test "a server error is worth retrying" =
      is_retriable (server_error ~location:"http://h/b.json" ~code:503 ~body:"")

    let%test "a 404 is not worth retrying" =
      not (not_found ~name:"b.json" ~location:"http://h/b.json" |> is_retriable)

    let%test "a body that is not JSON is not worth retrying" =
      not
        ( malformed_json ~where:"the response" ~reason:"unexpected token"
            ~body:"<html/>"
        |> is_retriable )

    let%test "a long error page is truncated in the message" =
      let body = String.make 5_000 'x' in
      let message =
        Error.to_string_hum
          (to_error (access_refused ~location:"http://h/b" ~code:403 ~body))
      in
      String.length message < 1_000
      && String.is_substring message ~substring:"..."

    let%test "the message names the location that was read" =
      String.is_substring
        (Error.to_string_hum
           (to_error (file_missing ~path:"/b/n-1-h.json" ~directory:"/b")) )
        ~substring:"/b/n-1-h.json"
  end )
