(* The Rosetta calls the load tool makes, and what a correct answer to each
   looks like. Sanity and load send the same requests and apply the same
   checks. The requests go through [Rosetta_client.Data]. *)

open Core
open Async

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

let client ?(timeout = 30.) ~rosetta network =
  Rosetta_client.Http.create ~base_uri:rosetta
    ~network:(Network.to_string network)
    ~timeout ()

(* [arg] is the object the call is about: a block state hash, an account
   public key or a transaction hash. The two network calls take none. *)
let request client t ~arg =
  let open Rosetta_client in
  match t with
  | Network_status ->
      Data.network_status client
  | Network_options ->
      Data.network_options client
  | Block ->
      Data.block client ~hash:arg ()
  | Account_balance ->
      Data.account_balance client ~address:arg ()
  | Payment_transaction | Zkapp_transaction ->
      Data.search_transactions client ~tx_hash:arg ()

(* [path json ["a"; "b"]] is json.a.b; a number segment indexes an array. *)
let rec path json = function
  | [] ->
      Some json
  | key :: rest -> (
      match (json, Option.try_with (fun () -> Int.of_string key)) with
      | `List items, Some i ->
          List.nth items i |> Option.bind ~f:(fun j -> path j rest)
      | `Assoc fields, _ ->
          List.Assoc.find fields ~equal:String.equal key
          |> Option.bind ~f:(fun j -> path j rest)
      | _ ->
          None )

let expect_string json keys ~expected =
  match path json keys with
  | Some (`String s) when String.equal s expected ->
      Ok ()
  | Some (`String s) ->
      Error
        (sprintf "%s is %s, expected %s"
           (String.concat ~sep:"." keys)
           s expected )
  | _ ->
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

(* A Rosetta error answer (non-2xx) still came back, so it has a latency;
   only a transport failure or a timeout has none. [Rosetta_client.Http]
   folds both into the error channel; an answer is the one rendered by
   [Rosetta_client.Errors.format_http_body], "HTTP <status> from ...". *)
let call client t ~arg =
  let start = Time_ns.now () in
  let%map response = request client t ~arg in
  let latency = Time_ns.diff (Time_ns.now ()) start in
  let result, latency =
    match response with
    | Ok json ->
        (check t ~arg json, Some latency)
    | Error e ->
        let msg = Error.to_string_hum e in
        let answered = String.is_prefix msg ~prefix:"HTTP " in
        (Error msg, Option.some_if answered latency)
  in
  let with_arg msg = if String.is_empty arg then msg else arg ^ ": " ^ msg in
  { latency; result = Result.map_error result ~f:with_arg }
