(* Rosetta Data API wrappers.  See [data.mli].

   Every request is built as the generated Rosetta request model for the
   endpoint and serialised with its own [to_yojson], so the field names,
   the required/optional split and the nesting all come from the schema
   rather than from hand-written JSON objects. *)

open Core
module RM = Rosetta_models

(* A Mina token id travels in [account_identifier.metadata], which the
   Rosetta schema leaves free-form.  Give the one shape we send a type
   of its own so the endpoint wrappers below never assemble JSON. *)
module Token_metadata = struct
  type t = { token_id : string } [@@deriving to_yojson]
end

let account_identifier ?token_id address =
  { RM.Account_identifier.address
  ; sub_account = None
  ; metadata =
      Option.map token_id ~f:(fun token_id ->
          Token_metadata.to_yojson { Token_metadata.token_id } )
  }

let partial_block_identifier ?index ?hash () =
  { RM.Partial_block_identifier.index = Option.map index ~f:Int64.of_int; hash }

(* One decoder for every endpoint, rather than a typed twin per
   endpoint: the raw call is the primitive, and a caller that wants the
   model says which one it wants. *)
let decode of_yojson response =
  Async.Deferred.Or_error.bind response ~f:(fun json ->
      match of_yojson json with
      | Ok response ->
          Async.Deferred.Or_error.return response
      | Error msg ->
          (* [of_yojson] reports the field it stopped at, which is the
             useful half of the diagnostic; say what that means around
             it.  A generated model rejects a response only when a
             required field is absent or ill-typed -- an unknown extra
             field decodes fine -- so this is a server that does not
             speak the schema this build was generated from, not a
             server that is down.  A caller which treats every error as
             an outage would otherwise report it as one. *)
          Async.Deferred.Or_error.errorf
            "server's response does not match the Rosetta schema this build \
             expects (at %s)"
            msg )

let%test_unit "decode parses a matching response and rejects a mismatch" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Async in
      let network_list =
        `Assoc
          [ ( "network_identifiers"
            , `List
                [ `Assoc
                    [ ("blockchain", `String "mina")
                    ; ("network", `String "testnet")
                    ]
                ] )
          ]
      in
      let%bind matching =
        decode RM.Network_list_response.of_yojson
          (Deferred.Or_error.return network_list)
      in
      [%test_eq: int]
        (List.length
           (Or_error.ok_exn matching)
             .RM.Network_list_response.network_identifiers )
        1 ;
      let%map mismatched =
        decode RM.Network_list_response.of_yojson
          (Deferred.Or_error.return (`Assoc []))
      in
      [%test_pred: unit Or_error.t] Or_error.is_error
        (Or_error.map mismatched ~f:ignore) )

(* A request whose only content is the network_identifier: /network/status,
   /network/options and /mempool all take this shape. *)
let network_request t =
  RM.Network_request.to_yojson
    (RM.Network_request.create (Http.network_identifier t))

let network_list t =
  Http.post_json t ~path:"/network/list"
    ~body:(RM.Metadata_request.to_yojson (RM.Metadata_request.create ()))

let network_status t =
  Http.post_json t ~path:"/network/status" ~body:(network_request t)

let network_options t =
  Http.post_json t ~path:"/network/options" ~body:(network_request t)

let block t ?index ?hash () =
  let request =
    RM.Block_request.create
      (Http.network_identifier t)
      (partial_block_identifier ?index ?hash ())
  in
  Http.post_json t ~path:"/block" ~body:(RM.Block_request.to_yojson request)

let account_balance t ~address ?token_id ?block_index () =
  let request =
    { RM.Account_balance_request.network_identifier = Http.network_identifier t
    ; account_identifier = account_identifier ?token_id address
    ; block_identifier =
        Option.map block_index ~f:(fun index ->
            partial_block_identifier ~index () )
    ; currencies = []
    }
  in
  Http.post_json t ~path:"/account/balance"
    ~body:(RM.Account_balance_request.to_yojson request)

let mempool t = Http.post_json t ~path:"/mempool" ~body:(network_request t)

let mempool_transaction t ~tx_hash =
  let request =
    RM.Mempool_transaction_request.create
      (Http.network_identifier t)
      (RM.Transaction_identifier.create tx_hash)
  in
  Http.post_json t ~path:"/mempool/transaction"
    ~body:(RM.Mempool_transaction_request.to_yojson request)

let search_transactions_request t ?address ?tx_hash ?limit () =
  { (RM.Search_transactions_request.create (Http.network_identifier t)) with
    RM.Search_transactions_request.address
  ; transaction_identifier =
      Option.map tx_hash ~f:RM.Transaction_identifier.create
  ; limit = Option.map limit ~f:Int64.of_int
  }

(* [address] is the top-level filter that matches an account regardless
   of its sub-account; [account_identifier] would additionally require
   the sub-account to match, so an address-only search must not set it. *)
let%test_unit "search_transactions uses the top-level address filter" =
  let client = Http.create ~base_uri:(Uri.of_string "http://localhost") () in
  let request = search_transactions_request client ~address:"B62qaddress" () in
  [%test_eq: string option] request.RM.Search_transactions_request.address
    (Some "B62qaddress") ;
  if Option.is_some request.RM.Search_transactions_request.account_identifier
  then failwith "address-only search should not emit account_identifier"

let search_transactions t ?address ?tx_hash ?limit () =
  Http.post_json t ~path:"/search/transactions"
    ~body:
      (RM.Search_transactions_request.to_yojson
         (search_transactions_request t ?address ?tx_hash ?limit ()) )
