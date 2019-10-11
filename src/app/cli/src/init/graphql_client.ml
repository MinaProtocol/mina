open Core
open Async
open Signature_lib

module Client = Graphql_client_lib.Make (struct
  let address = "graphql"

  let preprocess_variables_string = Fn.id

  let headers = String.Map.empty
end)

let query_or_error = Client.query_or_error

let query query_obj port =
  let open Deferred.Let_syntax in
  match%bind query_or_error query_obj port with
  | Ok r ->
      Deferred.return r
  | Error (`Failed_request e) ->
      eprintf
        "Error: Unable to connect to Coda daemon.\n\
         - The daemon might not be running. See logs (in \
         `~/.coda-config/coda.log`) for details.\n\
        \  Run `coda daemon -help` to see how to start daemon.\n\
         - If you just started the daemon, wait a minute for the GraphQL \
         server to start.\n\
         - Alternatively, the daemon may not be running the GraphQL server on \
         port %d.\n\
        \  If so, add flag `-rest-port` with correct port when running this \
         command.\n\
         Error message: %s\n\
         %!"
        port e ;
      exit 17
  | Error (`Graphql_error e) ->
      eprintf "❌ Error: %s\n" e ;
      exit 17

module Encoders = struct
  let optional = Option.value_map ~default:`Null

  let uint64 value = `String (Unsigned.UInt64.to_string value)

  let amount value = `String (Currency.Amount.to_string value)

  let fee value = `String (Currency.Fee.to_string value)

  let nonce value = `String (Coda_base.Account.Nonce.to_string value)

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

  let balance json =
    Yojson.Basic.Util.to_string json |> Currency.Balance.of_string
end
