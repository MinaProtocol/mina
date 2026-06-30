(* Rosetta Data API wrappers.  See [data.mli]. *)

module RM = Rosetta_models

let with_ni t pairs =
  `Assoc (("network_identifier", Http.network_identifier t) :: pairs)

let decode_response response ~endpoint of_yojson =
  Async.Deferred.Or_error.bind response ~f:(fun json ->
      match of_yojson json with
      | Ok response ->
          Async.Deferred.Or_error.return response
      | Error msg ->
          Async.Deferred.Or_error.errorf
            "%s response did not match Rosetta schema: %s" endpoint msg )

let network_list t =
  Http.post_json t ~path:"/network/list"
    ~body:(`Assoc [ ("metadata", `Assoc []) ])

let network_list_response t =
  decode_response (network_list t) ~endpoint:"/network/list"
    RM.Network_list_response.of_yojson

let network_status t =
  Http.post_json t ~path:"/network/status"
    ~body:(with_ni t [ ("metadata", `Assoc []) ])

let network_status_response t =
  decode_response (network_status t) ~endpoint:"/network/status"
    RM.Network_status_response.of_yojson

let network_options t =
  Http.post_json t ~path:"/network/options"
    ~body:(with_ni t [ ("metadata", `Assoc []) ])

let network_options_response t =
  decode_response (network_options t) ~endpoint:"/network/options"
    RM.Network_options_response.of_yojson

let block t ?index ?hash () =
  let id =
    match (index, hash) with
    | None, None ->
        `Assoc []
    | Some i, None ->
        `Assoc [ ("index", `Int i) ]
    | None, Some h ->
        `Assoc [ ("hash", `String h) ]
    | Some i, Some h ->
        `Assoc [ ("index", `Int i); ("hash", `String h) ]
  in
  Http.post_json t ~path:"/block" ~body:(with_ni t [ ("block_identifier", id) ])

let account_balance t ~address ?token_id ?block_index () =
  let account_identifier =
    match token_id with
    | Some tid ->
        `Assoc
          [ ("address", `String address)
          ; ("metadata", `Assoc [ ("token_id", `String tid) ])
          ]
    | None ->
        `Assoc [ ("address", `String address) ]
  in
  let base = [ ("account_identifier", account_identifier) ] in
  let with_block =
    match block_index with
    | None ->
        base
    | Some i ->
        base @ [ ("block_identifier", `Assoc [ ("index", `Int i) ]) ]
  in
  Http.post_json t ~path:"/account/balance" ~body:(with_ni t with_block)

let account_coins t ~address ?(include_mempool = false) () =
  Http.post_json t ~path:"/account/coins"
    ~body:
      (with_ni t
         [ ("account_identifier", `Assoc [ ("address", `String address) ])
         ; ("include_mempool", `Bool include_mempool)
         ] )

let mempool t = Http.post_json t ~path:"/mempool" ~body:(with_ni t [])

let mempool_transaction t ~tx_hash =
  Http.post_json t ~path:"/mempool/transaction"
    ~body:
      (with_ni t
         [ ("transaction_identifier", `Assoc [ ("hash", `String tx_hash) ]) ] )

let search_transactions_body t ?address ?tx_hash ?limit () =
  let fields = ref [] in
  ( match address with
  | None ->
      ()
  | Some a ->
      fields := ("address", `String a) :: !fields ) ;
  ( match tx_hash with
  | None ->
      ()
  | Some h ->
      fields :=
        ("transaction_identifier", `Assoc [ ("hash", `String h) ]) :: !fields ) ;
  ( match limit with
  | None ->
      ()
  | Some n ->
      fields := ("limit", `Int n) :: !fields ) ;
  with_ni t !fields

let%test_unit "search_transactions uses top-level address filter" =
  let client = Http.create ~base_uri:(Uri.of_string "http://localhost") () in
  let rec find_field key = function
    | [] ->
        None
    | (k, v) :: rest ->
        if String.equal k key then Some v else find_field key rest
  in
  match search_transactions_body client ~address:"B62qaddress" () with
  | `Assoc fields -> (
      match find_field "address" fields with
      | Some (`String "B62qaddress") -> (
          match find_field "account_identifier" fields with
          | None ->
              ()
          | Some _ ->
              failwith "address-only search should not emit account_identifier"
          )
      | Some other ->
          failwith
            ("unexpected address filter: " ^ Yojson.Safe.to_string other)
      | None ->
          failwith "missing top-level address filter" )
  | _ ->
      failwith "search_transactions_body did not return an object"

let search_transactions t ?address ?tx_hash ?limit () =
  Http.post_json t ~path:"/search/transactions"
    ~body:(search_transactions_body t ?address ?tx_hash ?limit ())
