(* The Rosetta calls the test makes, and what a correct answer to each looks
   like. Sanity and load send the same requests and apply the same checks. *)

open Core

type t =
  | Network_status
  | Network_options
  | Block
  | Account_balance
  | Payment_transaction
  | Zkapp_transaction
[@@deriving enumerate, equal, compare, sexp]

let name = function
  | Network_status ->
      "network_status"
  | Network_options ->
      "network_options"
  | Block ->
      "block"
  | Account_balance ->
      "account_balance"
  | Payment_transaction ->
      "payment_transaction"
  | Zkapp_transaction ->
      "zkapp_transaction"

let of_name s =
  match List.find all ~f:(fun t -> String.equal (name t) s) with
  | Some t ->
      t
  | None ->
      failwithf "unknown endpoint %s (one of %s)" s
        (String.concat ~sep:", " (List.map all ~f:name))
        ()

let rosetta_version = "1.4.9"

let path = function
  | Network_status ->
      "/network/status"
  | Network_options ->
      "/network/options"
  | Block ->
      "/block"
  | Account_balance ->
      "/account/balance"
  | Payment_transaction | Zkapp_transaction ->
      "/search/transactions"

(* [arg] is the object the call is about: a block state hash, an account
   public key or a transaction hash. The two network calls take none. *)
let body ~network t ~arg =
  let network_identifier =
    ( "network_identifier"
    , `Assoc
        [ ("blockchain", `String "mina")
        ; ("network", `String (Network.to_string network))
        ] )
  in
  let fields =
    match t with
    | Network_status | Network_options ->
        []
    | Block ->
        [ ("block_identifier", `Assoc [ ("hash", `String arg) ]) ]
    | Account_balance ->
        [ ("account_identifier", `Assoc [ ("address", `String arg) ]) ]
    | Payment_transaction | Zkapp_transaction ->
        [ ("transaction_identifier", `Assoc [ ("hash", `String arg) ]) ]
  in
  `Assoc (network_identifier :: fields)

let expect_string json keys ~expected =
  match Client.string_at json keys with
  | Some s when String.equal s expected ->
      Ok ()
  | Some s ->
      Error
        (sprintf "%s is %s, expected %s"
           (String.concat ~sep:"." keys)
           s expected )
  | None ->
      Error (sprintf "%s missing" (String.concat ~sep:"." keys))

let check t ~arg (json : Yojson.Safe.t) =
  match t with
  | Network_status ->
      expect_string json [ "sync_status"; "stage" ] ~expected:"Synced"
  | Network_options ->
      expect_string json
        [ "version"; "rosetta_version" ]
        ~expected:rosetta_version
  | Block ->
      expect_string json [ "block"; "block_identifier"; "hash" ] ~expected:arg
  | Account_balance ->
      expect_string json
        [ "balances"; "0"; "currency"; "symbol" ]
        ~expected:"MINA"
  | Payment_transaction | Zkapp_transaction ->
      expect_string json
        [ "transactions"; "0"; "transaction"; "transaction_identifier"; "hash" ]
        ~expected:arg

type outcome =
  { latency : Time_ns.Span.t option  (** [None] when no response came back *)
  ; result : (unit, string) Result.t
  }

let call ~rosetta ~network t ~arg =
  let open Async in
  let uri = Uri.with_path rosetta (path t) in
  let%map outcome =
    match%map Client.post uri (body ~network t ~arg) with
    | Error e ->
        { latency = None; result = Error (Error.to_string_hum e) }
    | Ok { status; body; latency } ->
        let result =
          match body with
          | _ when status <> 200 ->
              Error
                (sprintf "HTTP %d: %s" status
                   (Option.value_map body ~default:"<no body>"
                      ~f:Yojson.Safe.to_string ) )
          | None ->
              Error "response is not JSON"
          | Some json ->
              check t ~arg json
        in
        { latency = Some latency; result }
  in
  { outcome with
    result = Result.map_error outcome.result ~f:(fun msg -> arg ^ ": " ^ msg)
  }
