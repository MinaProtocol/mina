(* block_payload.ml -- the one check that turns bytes into a block.

   A bucket may answer with an XML or HTML error page under any status code,
   so neither transport may treat the bytes it read as a block.  Both hand
   them here first. *)

open Core

let of_string ~where body =
  if String.is_empty (String.strip body) then
    Error (Fetch_error.empty_body ~where)
  else
    match Yojson.Safe.from_string body with
    | json ->
        Ok json
    | exception Yojson.Json_error reason ->
        Error (Fetch_error.malformed_json ~where ~reason ~body)

let%test_module "block payload" =
  ( module struct
    let%test "an HTML error page is not accepted as a block" =
      Result.is_error
        (of_string ~where:"the response" "<?xml version=\"1.0\"?><Error/>")

    let%test "an empty body is not accepted as a block" =
      Result.is_error (of_string ~where:"the response" "   ")

    let%test "a JSON body is accepted" =
      Result.is_ok (of_string ~where:"the response" "{\"a\":1}")
  end )
