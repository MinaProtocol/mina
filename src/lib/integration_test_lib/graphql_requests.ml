open Core_kernel
open Async
open Mina_base

let node_password = "naughty blue worm"

module Graphql = struct
  module Client = Graphql_lib.Client.Make (struct
    let preprocess_variables_string = Fn.id

    let headers = String.Map.empty
  end)

  (* graphql_ppx uses Stdlib symbols instead of Base *)
  open Stdlib
  module Encoders = Mina_graphql.Types.Input
  module Scalars = Graphql_lib.Scalars

  module Unlock_account =
  [%graphql
  ({|
    mutation ($password: String!, $public_key: PublicKey!) @encoders(module: "Encoders"){
      unlockAccount(input: {password: $password, publicKey: $public_key }) {
        account {
          public_key: publicKey
        }
      }
    }
  |}
  [@encoders Encoders] )]

  module Send_test_payments =
  [%graphql
  {|
    mutation ($senders: [PrivateKey!]!,
    $receiver: PublicKey!,
    $amount: UInt64!,
    $fee: UInt64!,
    $repeat_count: UInt32!,
    $repeat_delay_ms: UInt32!) @encoders(module: "Encoders"){
      sendTestPayments(
        senders: $senders, receiver: $receiver, amount: $amount, fee: $fee,
        repeat_count: $repeat_count,
        repeat_delay_ms: $repeat_delay_ms)
    }
  |}]

  module Send_payment =
  [%graphql
  {|
   mutation ($input: SendPaymentInput!)@encoders(module: "Encoders"){
      sendPayment(input: $input){
          payment {
            id
            nonce
            hash
          }
        }
    }
  |}]

  module Send_payment_with_raw_sig =
  [%graphql
  {|
   mutation (
   $input:SendPaymentInput!,
   $rawSignature: String!
   )@encoders(module: "Encoders")
    {
      sendPayment(
        input:$input,
        signature: {rawSignature: $rawSignature}
      )
      {
        payment {
          id
          nonce
          hash
        }
      }
    }
  |}]

  module Send_delegation =
  [%graphql
  {|
    mutation ($input: SendDelegationInput!) @encoders(module: "Encoders"){
      sendDelegation(input:$input){
          delegation {
            id
            nonce
            hash
          }
        }
    }
  |}]

  module Set_snark_worker =
  [%graphql
  {|
    mutation ($input: SetSnarkWorkerInput! ) @encoders(module: "Encoders"){
      setSnarkWorker(input:$input){
        lastSnarkWorker
        }
    }
  |}]

  module Set_snark_work_fee =
  [%graphql
  {|
    mutation ($fee: UInt64!) @encoders(module: "Encoders"){
      setSnarkWorkFee(input: {fee: $fee}) {
        lastFee
      }
    }
  |}]

  module Get_account_data =
  [%graphql
  {|
    query ($public_key: PublicKey!) @encoders(module: "Encoders"){
      account(publicKey: $public_key) {
        nonce
        balance {
          total @ppxCustom(module: "Scalars.Balance")
        }
      }
    }
  |}]

  module Query_peer_id =
  [%graphql
  {|
    query {
      daemonStatus {
        addrsAndPorts {
          peer {
            peerId
          }
        }
        peers {  peerId }

      }
    }
  |}]

  module Best_chain =
  [%graphql
  {|
    query ($max_length: Int) @encoders(module: "Encoders"){
      bestChain (maxLength: $max_length) {
        stateHash
        commandTransactionCount
        creatorAccount {
          publicKey @ppxCustom(module: "Graphql_lib.Scalars.JSON")
        }
      }
    }
  |}]

  module Query_metrics =
  [%graphql
  {|
    query {
      daemonStatus {
        metrics {
          blockProductionDelay
          transactionPoolDiffReceived
          transactionPoolDiffBroadcasted
          transactionsAddedToPool
          transactionPoolSize
        }
      }
    }
  |}]

  module StartFilteredLog =
  [%graphql
  {|
    mutation ($filter: [String!]!) @encoders(module: "Encoders"){
      startFilteredLog(filter: $filter)
    }
  |}]

  module GetFilteredLogEntries =
  [%graphql
  {|
    query ($offset: Int!) @encoders(module: "Encoders"){
      getFilteredLogEntries(offset: $offset) {
          logMessages,
          isCapturing,
      }
    }
  |}]
end

(* this function will repeatedly attempt to connect to graphql port <num_tries> times before giving up *)
let exec_graphql_request ?(num_tries = 10) ?(retry_delay_sec = 30.0)
    ?(initial_delay_sec = 0.) ~logger ~node_uri ~query_name query_obj =
  let open Deferred.Let_syntax in
  let metadata =
    [ ("query", `String query_name)
    ; ("uri", `String (Uri.to_string node_uri))
    ; ("init_delay", `Float initial_delay_sec)
    ]
  in
  [%log info]
    "Attempting to send GraphQL request \"$query\" to \"$uri\" after \
     $init_delay sec"
    ~metadata ;
  let rec retry n =
    if n <= 0 then (
      [%log error]
        "GraphQL request \"$query\" to \"$uri\" failed too many times" ~metadata ;
      Deferred.Or_error.errorf
        "GraphQL \"%s\" to \"%s\" request failed too many times" query_name
        (Uri.to_string node_uri) )
    else
      match%bind Graphql.Client.query query_obj node_uri with
      | Ok result ->
          [%log info] "GraphQL request \"$query\" to \"$uri\" succeeded"
            ~metadata ;
          Deferred.Or_error.return result
      | Error (`Failed_request err_string) ->
          [%log warn]
            "GraphQL request \"$query\" to \"$uri\" failed: \"$error\" \
             ($num_tries attempts left)"
            ~metadata:
              ( metadata
              @ [ ("error", `String err_string); ("num_tries", `Int (n - 1)) ]
              ) ;
          let%bind () = after (Time.Span.of_sec retry_delay_sec) in
          retry (n - 1)
      | Error (`Graphql_error err_string) ->
          [%log error]
            "GraphQL request \"$query\" to \"$uri\" returned an error: \
             \"$error\" (this is a graphql error so not retrying)"
            ~metadata:(metadata @ [ ("error", `String err_string) ]) ;
          Deferred.Or_error.error_string err_string
  in
  let%bind () = after (Time.Span.of_sec initial_delay_sec) in
  retry num_tries

let get_peer_id ~logger node_uri =
  let open Deferred.Or_error.Let_syntax in
  [%log info] "Getting node's peer_id, and the peer_ids of node's peers"
    ~metadata:[ ("node_uri", `String (Uri.to_string node_uri)) ] ;
  let query_obj = Graphql.Query_peer_id.(make @@ makeVariables ()) in
  let%bind query_result_obj =
    exec_graphql_request ~logger ~node_uri ~query_name:"query_peer_id" query_obj
  in
  [%log info] "get_peer_id, finished exec_graphql_request" ;
  let self_id_obj = query_result_obj.daemonStatus.addrsAndPorts.peer in
  let%bind self_id =
    match self_id_obj with
    | None ->
        Deferred.Or_error.error_string "Peer not found"
    | Some peer ->
        return peer.peerId
  in
  let peers = query_result_obj.daemonStatus.peers |> Array.to_list in
  let peer_ids = List.map peers ~f:(fun peer -> peer.peerId) in
  [%log info] "get_peer_id, result of graphql query (self_id,[peers]) (%s,%s)"
    self_id
    (String.concat ~sep:" " peer_ids) ;
  return (self_id, peer_ids)

let must_get_peer_id ~logger node_uri =
  get_peer_id ~logger node_uri |> Deferred.bind ~f:Malleable_error.or_hard_error

let get_best_chain ?max_length ~logger node_uri =
  let open Deferred.Or_error.Let_syntax in
  let query = Graphql.Best_chain.(make @@ makeVariables ?max_length ()) in
  let%bind result =
    exec_graphql_request ~logger ~node_uri ~query_name:"best_chain" query
  in
  match result.bestChain with
  | None | Some [||] ->
      Deferred.Or_error.error_string "failed to get best chains"
  | Some chain ->
      return
      @@ List.map
           ~f:(fun block ->
             Intf.
               { state_hash = block.stateHash
               ; command_transaction_count = block.commandTransactionCount
               ; creator_pk =
                   ( match block.creatorAccount.publicKey with
                   | `String pk ->
                       pk
                   | _ ->
                       "unknown" )
               } )
           (Array.to_list chain)

let must_get_best_chain ?max_length ~logger node_uri =
  get_best_chain ?max_length ~logger node_uri
  |> Deferred.bind ~f:Malleable_error.or_hard_error

type account_data =
  { nonce : Unsigned.uint32; total_balance : Currency.Balance.t }

let get_account_data ~logger node_uri ~public_key =
  let open Deferred.Or_error.Let_syntax in
  [%log info] "Getting account balance"
    ~metadata:
      [ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson public_key)
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  (* let pk = Mina_base.Account_id.public_key account_id in *)
  (* let token = Mina_base.Account_id.token_id account_id in *)
  let get_balance_obj =
    Graphql.Get_account_data.(
      make
      @@ makeVariables ~public_key
           (* ~token:(Graphql_lib.Encoders.token token) *)
           ())
  in
  let%bind balance_obj =
    exec_graphql_request ~logger ~node_uri ~query_name:"get_balance_graphql"
      get_balance_obj
  in
  match balance_obj.account with
  | None ->
      Deferred.Or_error.errorf
        !"Account with public_key %s not found"
        (Signature_lib.Public_key.Compressed.to_string public_key)
  | Some acc ->
      return
        { nonce =
            acc.nonce
            |> Option.value_exn ~message:"the nonce from get_balance is None"
            |> Unsigned.UInt32.of_string
        ; total_balance = acc.balance.total
        }

let must_get_account_data ~logger node_uri ~public_key =
  get_account_data ~logger node_uri ~public_key
  |> Deferred.bind ~f:Malleable_error.or_hard_error

type signed_command_result =
  { id : string; hash : Transaction_hash.t; nonce : Unsigned.uint32 }

(* if we expect failure, might want retry_on_graphql_error to be false *)
let send_online_payment ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee =
  [%log info] "Sending a payment"
    ~metadata:
      [ ( "sender_pub_key"
        , Signature_lib.Public_key.Compressed.to_yojson sender_pub_key )
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let sender_pk_str =
    Signature_lib.Public_key.Compressed.to_string sender_pub_key
  in
  [%log info] "send_payment: unlocking account"
    ~metadata:[ ("sender_pk", `String sender_pk_str) ] ;
  let unlock_sender_account_graphql () =
    let unlock_account_obj =
      Graphql.Unlock_account.(
        make
        @@ makeVariables ~password:node_password ~public_key:sender_pub_key ())
    in
    exec_graphql_request ~logger ~node_uri ~initial_delay_sec:0.
      ~query_name:"unlock_sender_account_graphql" unlock_account_obj
  in
  let%bind _ = unlock_sender_account_graphql () in
  let send_payment_graphql () =
    let input =
      Mina_graphql.Types.Input.SendPaymentInput.make_input ~from:sender_pub_key
        ~to_:receiver_pub_key ~amount ~fee ()
    in
    let send_payment_obj =
      Graphql.Send_payment.(make @@ makeVariables ~input ())
    in
    exec_graphql_request ~logger ~node_uri ~query_name:"send_payment_graphql"
      send_payment_obj
  in
  let%map sent_payment_obj = send_payment_graphql () in
  let return_obj = sent_payment_obj.sendPayment.payment in
  let res =
    { id = return_obj.id
    ; hash = Transaction_hash.of_base58_check_exn return_obj.hash
    ; nonce = Unsigned.UInt32.of_int return_obj.nonce
    }
  in
  [%log info] "Sent payment"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Unsigned.UInt32.to_int res.nonce))
      ] ;
  res

let must_send_online_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount
    ~fee =
  send_online_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let send_delegation ~logger node_uri ~sender_pub_key ~receiver_pub_key ~fee =
  [%log info] "Sending stake delegation"
    ~metadata:
      [ ( "sender_pub_key"
        , Signature_lib.Public_key.Compressed.to_yojson sender_pub_key )
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let sender_pk_str =
    Signature_lib.Public_key.Compressed.to_string sender_pub_key
  in
  [%log info] "send_delegation: unlocking account"
    ~metadata:[ ("sender_pk", `String sender_pk_str) ] ;
  let unlock_sender_account_graphql () =
    let unlock_account_obj =
      Graphql.Unlock_account.(
        make
        @@ makeVariables ~password:"naughty blue worm"
             ~public_key:sender_pub_key ())
    in
    exec_graphql_request ~logger ~node_uri
      ~query_name:"unlock_sender_account_graphql" unlock_account_obj
  in
  let%bind _ = unlock_sender_account_graphql () in
  let send_delegation_graphql () =
    let input =
      Mina_graphql.Types.Input.SendDelegationInput.make_input
        ~from:sender_pub_key ~to_:receiver_pub_key ~fee ()
    in
    let send_delegation_obj =
      Graphql.Send_delegation.(make @@ makeVariables ~input ())
    in
    exec_graphql_request ~logger ~node_uri ~query_name:"send_delegation_graphql"
      send_delegation_obj
  in
  let%map result_obj = send_delegation_graphql () in
  let return_obj = result_obj.sendDelegation.delegation in
  let res =
    { id = return_obj.id
    ; hash = Transaction_hash.of_base58_check_exn return_obj.hash
    ; nonce = Unsigned.UInt32.of_int return_obj.nonce
    }
  in
  [%log info] "stake delegation sent"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Unsigned.UInt32.to_int res.nonce))
      ] ;
  res

let must_send_delegation ~logger node_uri ~sender_pub_key
    ~(receiver_pub_key : Account.key) ~fee =
  send_delegation ~logger node_uri ~sender_pub_key ~receiver_pub_key ~fee
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let send_payment_with_raw_sig ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee ~nonce ~memo ~token ~valid_until ~raw_signature =
  [%log info] "Sending a payment with raw signature"
    ~metadata:
      [ ( "sender_pub_key"
        , Signature_lib.Public_key.Compressed.to_yojson sender_pub_key )
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let send_payment_graphql () =
    let open Graphql.Send_payment_with_raw_sig in
    let input =
      Mina_graphql.Types.Input.SendPaymentInput.make_input ~from:sender_pub_key
        ~to_:receiver_pub_key ~amount ~token ~fee ~memo ~nonce ~valid_until ()
    in
    let variables = makeVariables ~input ~rawSignature:raw_signature () in
    let send_payment_obj = make variables in
    let variables_json_basic = variablesToJson (serializeVariables variables) in
    (* An awkward conversion from Yojson.Basic to Yojson.Safe *)
    let variables_json =
      Yojson.Basic.to_string variables_json_basic |> Yojson.Safe.from_string
    in
    [%log info] "send_payment_obj with $variables "
      ~metadata:[ ("variables", variables_json) ] ;
    exec_graphql_request ~logger ~node_uri
      ~query_name:"Send_payment_with_raw_sig_graphql" send_payment_obj
  in
  let%map sent_payment_obj = send_payment_graphql () in
  let return_obj = sent_payment_obj.sendPayment.payment in
  let res =
    { id = return_obj.id
    ; hash = Transaction_hash.of_base58_check_exn return_obj.hash
    ; nonce = Unsigned.UInt32.of_int return_obj.nonce
    }
  in
  [%log info] "Sent payment"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Unsigned.UInt32.to_int res.nonce))
      ] ;
  res

let must_send_payment_with_raw_sig ~logger node_uri ~sender_pub_key
    ~receiver_pub_key ~amount ~fee ~nonce ~memo ~token ~valid_until
    ~raw_signature =
  send_payment_with_raw_sig ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee ~nonce ~memo ~token ~valid_until ~raw_signature
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let sign_and_send_payment ~logger node_uri
    ~(sender_keypair : Import.Signature_keypair.t) ~receiver_pub_key ~amount
    ~fee ~nonce ~memo ~token ~valid_until =
  let sender_pub_key =
    sender_keypair.public_key |> Signature_lib.Public_key.compress
  in
  let payload =
    let body =
      Signed_command_payload.Body.Payment
        { Payment_payload.Poly.receiver_pk = receiver_pub_key
        ; source_pk = sender_pub_key
        ; token_id = token
        ; amount
        }
    in
    let common =
      { Signed_command_payload.Common.Poly.fee
      ; fee_token = Signed_command_payload.Body.token body
      ; fee_payer_pk = sender_pub_key
      ; nonce
      ; valid_until
      ; memo = Signed_command_memo.create_from_string_exn memo
      }
    in
    { Signed_command_payload.Poly.common; body }
  in
  let raw_signature =
    Signed_command.sign_payload sender_keypair.private_key payload
    |> Signature.Raw.encode
  in
  send_payment_with_raw_sig ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee ~nonce ~memo ~token ~valid_until ~raw_signature

let must_sign_and_send_payment ~logger node_uri
    ~(sender_keypair : Import.Signature_keypair.t) ~receiver_pub_key ~amount
    ~fee ~nonce ~memo ~token ~valid_until =
  sign_and_send_payment ~logger node_uri
    ~(sender_keypair : Import.Signature_keypair.t)
    ~receiver_pub_key ~amount ~fee ~nonce ~memo ~token ~valid_until
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let send_test_payments ~(repeat_count : Unsigned.UInt32.t)
    ~(repeat_delay_ms : Unsigned.UInt32.t) ~logger node_uri
    ~(senders : Import.Private_key.t list) ~(receiver_pub_key : Account.key)
    ~amount ~fee =
  [%log info] "Sending a series of test payments"
    ~metadata:[ ("node_uri", `String (Uri.to_string node_uri)) ] ;
  let open Deferred.Or_error.Let_syntax in
  let send_payment_graphql () =
    let send_payment_obj =
      Graphql.Send_test_payments.(
        make
        @@ makeVariables ~senders ~receiver:receiver_pub_key
             ~amount:(Currency.Amount.to_uint64 amount)
             ~fee:(Currency.Fee.to_uint64 fee)
             ~repeat_count ~repeat_delay_ms ())
    in
    exec_graphql_request ~logger ~node_uri ~query_name:"send_payment_graphql"
      send_payment_obj
  in
  let%map _ = send_payment_graphql () in
  [%log info] "Sent test payments"

let must_send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
    ~receiver_pub_key ~amount ~fee =
  send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
    ~receiver_pub_key ~amount ~fee
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let set_snark_worker ~logger node_uri ~new_snark_pub_key =
  [%log info] "Changing snark worker key"
    ~metadata:
      [ ( "new_snark_pub_key"
        , Signature_lib.Public_key.Compressed.to_yojson new_snark_pub_key )
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let set_snark_worker_graphql () =
    let input = Some new_snark_pub_key in
    let set_snark_worker_obj =
      Graphql.Set_snark_worker.(make @@ makeVariables ~input ())
    in
    exec_graphql_request ~logger ~node_uri
      ~query_name:"set_snark_worker_graphql" set_snark_worker_obj
  in
  let%map result_obj = set_snark_worker_graphql () in
  let returned_last_snark_worker_opt =
    result_obj.setSnarkWorker.lastSnarkWorker
  in
  let last_snark_worker =
    match returned_last_snark_worker_opt with
    | None ->
        "<no last snark worker>"
    | Some last ->
        last |> Account.Key.to_yojson |> Yojson.Safe.to_string
  in
  [%log info] "snark worker changed, lastSnarkWorker: %s" last_snark_worker
    ~metadata:[ ("lastSnarkWorker", `String last_snark_worker) ] ;
  ()

let set_snark_work_fee ~logger node_uri ~new_snark_work_fee =
  [%log info] "Changing snark work fee"
    ~metadata:
      [ ("new_snark_work_fee", `Int new_snark_work_fee)
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let set_snark_work_fee_graphql () =
    let set_snark_work_fee_obj =
      Graphql.Set_snark_work_fee.(
        make
        @@ makeVariables ~fee:(Unsigned.UInt64.of_int new_snark_work_fee) ())
    in
    exec_graphql_request ~logger ~node_uri
      ~query_name:"set_snark_work_fee_graphql" set_snark_work_fee_obj
  in
  let%map result_obj = set_snark_work_fee_graphql () in
  let last_snark_work_fee =
    Currency.Fee.to_string result_obj.setSnarkWorkFee.lastFee
  in
  [%log info] "snark work fee changed, lastSnarkWorkFee: %s" last_snark_work_fee
    ~metadata:
      [ ("lastSnarkWorkFee", `String last_snark_work_fee)
      ; ("node_uri", `String (Uri.to_string node_uri))
      ] ;
  ()

let must_set_snark_worker ~logger t ~new_snark_pub_key =
  set_snark_worker ~logger t ~new_snark_pub_key
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let must_set_snark_work_fee ~logger t ~new_snark_work_fee =
  set_snark_work_fee ~logger t ~new_snark_work_fee
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let get_metrics ~logger node_uri =
  let open Deferred.Or_error.Let_syntax in
  [%log info] "Getting node's metrics"
    ~metadata:[ ("node_uri", `String (Uri.to_string node_uri)) ] ;
  let query_obj = Graphql.Query_metrics.make () in
  let%bind query_result_obj =
    exec_graphql_request ~logger ~node_uri ~query_name:"query_metrics" query_obj
  in
  [%log info] "get_metrics, finished exec_graphql_request" ;
  let block_production_delay =
    Array.to_list @@ query_result_obj.daemonStatus.metrics.blockProductionDelay
  in
  let metrics = query_result_obj.daemonStatus.metrics in
  let transaction_pool_diff_received = metrics.transactionPoolDiffReceived in
  let transaction_pool_diff_broadcasted =
    metrics.transactionPoolDiffBroadcasted
  in
  let transactions_added_to_pool = metrics.transactionsAddedToPool in
  let transaction_pool_size = metrics.transactionPoolSize in
  [%log info]
    "get_metrics, result of graphql query (block_production_delay; \
     tx_received; tx_broadcasted; txs_added_to_pool; tx_pool_size) (%s; %d; \
     %d; %d; %d)"
    (String.concat ~sep:", " @@ List.map ~f:string_of_int block_production_delay)
    transaction_pool_diff_received transaction_pool_diff_broadcasted
    transactions_added_to_pool transaction_pool_size ;
  return
    Intf.
      { block_production_delay
      ; transaction_pool_diff_broadcasted
      ; transaction_pool_diff_received
      ; transactions_added_to_pool
      ; transaction_pool_size
      }

let start_filtered_log ~logger ~log_filter node_uri =
  let open Deferred.Let_syntax in
  let query_obj =
    Graphql.StartFilteredLog.(make @@ makeVariables ~filter:log_filter ())
  in
  let%bind res =
    exec_graphql_request ~logger:(Logger.null ()) ~retry_delay_sec:10.0
      ~node_uri ~query_name:"StartFilteredLog" query_obj
  in
  match res with
  | Ok query_result_obj ->
      let had_already_started = query_result_obj.startFilteredLog in
      if had_already_started then return (Ok ())
      else (
        [%log error]
          "Attempted to start structured log collection on $node, but it had \
           already started"
          ~metadata:[ ("node", `String (Uri.to_string node_uri)) ] ;
        (* TODO: If this is common, figure out what to do *)
        return (Ok ()) )
  | Error e ->
      return (Error e)

let get_filtered_log_entries ~last_log_index_seen node_uri =
  let open Deferred.Or_error.Let_syntax in
  let query_obj =
    Graphql.GetFilteredLogEntries.(
      make @@ makeVariables ~offset:last_log_index_seen ())
  in
  let%bind query_result_obj =
    exec_graphql_request ~logger:(Logger.null ()) ~retry_delay_sec:10.0
      ~node_uri ~query_name:"GetFilteredLogEntries" query_obj
  in
  let res = query_result_obj.getFilteredLogEntries in
  if res.isCapturing then return res.logMessages
  else
    Deferred.Or_error.error_string
      "Node is not currently capturing structured log messages"
