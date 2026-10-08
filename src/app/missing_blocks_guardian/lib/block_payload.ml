(* block_payload.ml -- the one check that turns bytes into a block.

   A bucket answers a request for a block it does not hold with an HTML or
   XML page, sometimes with status 200. That page means the block is not
   there, so it is reported as a missing block, not as broken JSON. *)

open Core

let is_markup body = String.is_prefix (String.lstrip body) ~prefix:"<"

let of_string ~name ~location body =
  if String.is_empty (String.strip body) then
    Error (Fetch_error.empty_body ~where:location)
  else if is_markup body then
    Error
      (Fetch_error.block_missing ~name ~location
         ~answer:"the answer is an HTML or XML page, not a block" )
  else
    match Yojson.Safe.from_string body with
    | json ->
        Ok json
    | exception Yojson.Json_error reason ->
        Error (Fetch_error.malformed_json ~where:location ~reason ~body)

let%test_module "block payload" =
  ( module struct
    let of_string = of_string ~name:"b.json" ~location:"http://h/b.json"

    let%test "an XML error page is a missing block" =
      match of_string "<?xml version=\"1.0\"?><Error/>" with
      | Error (Fetch_error.Block_missing _) ->
          true
      | _ ->
          false

    let%test "an HTML error page is a missing block" =
      match of_string "  <!DOCTYPE html><html></html>" with
      | Error (Fetch_error.Block_missing _) ->
          true
      | _ ->
          false

    let%test "an empty body is not accepted as a block" =
      Result.is_error (of_string "   ")

    let%test "a JSON body is accepted" = Result.is_ok (of_string "{\"a\":1}")
  end )
