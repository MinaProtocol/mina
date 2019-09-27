open Core
open Async
open Signature_lib

module type Config_intf = sig
  val address : string

  val headers : string String.Map.t

  val preprocess_variables_string : string -> string
end

let make_local_uri port address =
  Uri.of_string ("http://localhost:" ^ string_of_int port ^/ address)

module type S = sig
  val query_or_error :
       < parse: Yojson.Basic.json -> 'response
       ; query: string
       ; variables: Yojson.Basic.json >
    -> int
    -> 'response Deferred.Or_error.t

  val query :
       < parse: Yojson.Basic.json -> 'response
       ; query: string
       ; variables: Yojson.Basic.json >
    -> int
    -> 'response Deferred.t
end

module Make (Config : Config_intf) : S = struct
  let local_uri port = make_local_uri port Config.address

  let query_or_error query_obj port =
    let variables_string =
      Config.preprocess_variables_string
      @@ Yojson.Basic.to_string query_obj#variables
    in
    let body_string =
      Printf.sprintf {|{"query": "%s", "variables": %s}|} query_obj#query
        variables_string
    in
    let open Deferred.Let_syntax in
    let headers =
      List.fold ~init:(Cohttp.Header.init ())
        (("Accept", "application/json") :: Map.to_alist Config.headers)
        ~f:(fun header (key, value) -> Cohttp.Header.add header key value)
    in
    let get_result () =
      let%bind _, body =
        Cohttp_async.Client.post ~headers
          ~body:(Cohttp_async.Body.of_string body_string)
          (local_uri port)
      in
      let%map body = Cohttp_async.Body.to_string body in
      Yojson.Basic.from_string body
      |> Yojson.Basic.Util.member "data"
      |> query_obj#parse
    in
    Deferred.Or_error.try_with ~extract_exn:true get_result

  let query query_obj port =
    match%bind query_or_error query_obj port with
    | Ok r ->
        Deferred.return r
    | Error e ->
        eprintf "Error connecting to graphql endpoint: %s\n"
          (Error.to_string_hum e) ;
        exit 17
end

module Encoders = struct
  let optional = Option.value_map ~default:`Null

  let uint64 value = `String (Unsigned.UInt64.to_string value)

  let uint32 value = `String (Unsigned.UInt32.to_string value)

  let public_key value = `String (Public_key.Compressed.to_base58_check value)
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
