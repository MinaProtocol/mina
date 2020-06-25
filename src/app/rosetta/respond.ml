open Cohttp_async

let json ?status json =
  Server.respond_string ?status
    (Yojson.Safe.to_string json)
    ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])

let error_404 = Server.respond (Cohttp.Code.status_of_code 404)

let user_error ?(retriable = true) message =
  json
    ~status:(Cohttp.Code.status_of_code 500)
    (Models.Error.to_yojson
       {Models.Error.code= Int32.of_int 400; message; retriable})

module Parse_arg = struct
  module Let_syntax = struct
    let map v ~f =
      match v with Error e -> user_error ("Error parsing " ^ e) | Ok v -> f v
  end
end
