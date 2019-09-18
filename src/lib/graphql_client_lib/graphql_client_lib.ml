open Core
open Async
open Signature_lib

let make_local_uri port address =
  Uri.of_string ("http://localhost:" ^ string_of_int port ^/ address)

let query query_obj query_uri =
  let variables_string = Yojson.Basic.to_string query_obj#variables in
  let body_string =
    Printf.sprintf {|{"query": "%s", "variables": %s}|} query_obj#query
      variables_string
  in
  let open Deferred.Let_syntax in
  let get_result () =
    let%bind _, body =
      Cohttp_async.Client.post
        ~headers:
          (Cohttp.Header.add (Cohttp.Header.init ()) "Accept"
             "application/json")
        ~body:(Cohttp_async.Body.of_string body_string)
        query_uri
    in
    let%map body = Cohttp_async.Body.to_string body in
    Yojson.Basic.from_string body
    |> Yojson.Basic.Util.member "data"
    |> query_obj#parse
  in
  match%bind Deferred.Or_error.try_with ~extract_exn:true get_result with
  | Ok e ->
      return e
  | Error e ->
      eprintf "Error connecting to graphql endpoint: %s\n"
        (Error.to_string_hum e) ;
      exit 17

module Encoders = struct
  let optional = Option.value_map ~default:`Null

  let uint64 value = `String (Unsigned.UInt64.to_string value)

  let uint32 value = `String (Unsigned.UInt32.to_string value)

  let public_key public_key =
    Yojson.Safe.to_basic @@ Public_key.Compressed.to_yojson public_key
end

module Decoders = struct
  let optional ~f = function `Null -> None | json -> Some (f json)

  let public_key json =
    Yojson.Basic.Util.to_string json
    |> Public_key.Compressed.of_base58_check_exn

  let optional_public_key = Option.map ~f:public_key

  let uint64 json =
    Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string
end
