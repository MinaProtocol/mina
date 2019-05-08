// TODO: If we start to get crazy routes, we should implement
// http://www.informatik.uni-marburg.de/~rendel/unparse/
// as demonstrated in https://github.com/pointfreeco/swift-web/

// Law: All route handlers are idempotent!
// (1) It's a good user experience to _see_ what's going to happen in the UI
//     before actions happen
// (2) Other code depends on this property

open Tc;

type t =
  | Send
  | DeleteWallet // TODO: include wallet id in payload
  | Home;

module Decode = {
  let parse =
    fun
    | "send" => Some(Send)
    | "wallet/delete" => Some(DeleteWallet)
    | "" => Some(Home)
    | _ => None;

  let t = json =>
    Json.Decode.string(json)
    |> parse
    |> Option.withDefault(
         ~default=raise(Json.Decode.DecodeError("Path can't parse")),
       );
};

module Encode = {
  let print =
    fun
    | Send => "send"
    | DeleteWallet => "wallet/delete"
    | Home => "";

  let t = t => Json.Encode.string(print(t));
};

let print = Encode.print;

let parse = Decode.parse;
