// TODO: If we start to get crazy routes, we should implement
// http://www.informatik.uni-marburg.de/~rendel/unparse/
// as demonstrated in https://github.com/pointfreeco/swift-web/

// Law: All route handlers are idempotent!
// (1) It's a good user experience to _see_ what's going to happen in the UI
//     before actions happen
// (2) Other code depends on this property

type t =
  | Send
  | DeleteWallet // TODO: include wallet id in payload
  | Home;

let parse =
  fun
  | "send" => Some(Send)
  | "wallet/delete" => Some(DeleteWallet)
  | "" => Some(Home)
  | _ => None;

let print =
  fun
  | Send => "send"
  | DeleteWallet => "wallet/delete"
  | Home => "";
