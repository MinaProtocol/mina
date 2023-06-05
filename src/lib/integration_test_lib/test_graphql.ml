open Core_kernel

(* graphql_ppx uses Stdlib symbols instead of Base *)
open Stdlib
open Async
open Mina_transaction
module Scalars = Graphql_lib.Scalars
module Encoders = Mina_graphql.Types.Input

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Requests = struct
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

  module Send_payment_from_input =
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

  module Get_account_data =
  [%graphql
  {|
    query ($public_key: PublicKey!) @encoders(module: "Encoders"){
      account(publicKey: $public_key) {
        nonce
        balance {
          total @ppxCustom(module: "Scalars.Balance")
          liquid
          locked
        }
      }
    }
  |}]

  (* TODO: temporary version *)
  module Send_test_zkapp = Generated_graphql_queries.Send_test_zkapp
  module Pooled_zkapp_commands = Generated_graphql_queries.Pooled_zkapp_commands

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
        stateHash @ppxCustom(module: "Graphql_lib.Scalars.String_json")
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

  module Account =
  [%graphql
  {|
    query ($public_key: PublicKey!, $token: UInt64) {
      account (publicKey : $public_key, token : $token) {
        balance { liquid
                  locked
                  total
                }
        delegate
        nonce
        permissions { editActionState
                      editState
                      incrementNonce
                      receive
                      send
                      access
                      setDelegate
                      setPermissions
                      setZkappUri
                      setTokenSymbol
                      setVerificationKey
                      setVotingFor
                      setTiming
                    }
        actionState
        zkappState
        zkappUri
        timing { cliffTime @ppxCustom(module: "Graphql_lib.Scalars.JSON")
                 cliffAmount
                 vestingPeriod @ppxCustom(module: "Graphql_lib.Scalars.JSON")
                 vestingIncrement
                 initialMinimumBalance
               }
        tokenId
        tokenSymbol
        verificationKey { verificationKey
                          hash
                        }
        votingFor
      }
    }
  |}]
end

module Client = Graphql_lib.Client.Make (struct
  let preprocess_variables_string = Fn.id

  let headers = Core.String.Map.empty
end)

type t =
  { logger_metadata : (string * Yojson.Safe.t) list
  ; uri : Uri.t
  ; enabled : bool
  ; logger : Logger.t
  }

let create ~logger_metadata ~uri ~enabled ~logger =
  { logger_metadata; uri; enabled; logger }

(* this function will repeatedly attempt to connect to graphql port <num_tries> times before giving up *)
let exec t ?(num_tries = 10) ?(retry_delay_sec = 30.0) ?(initial_delay_sec = 0.)
    ~logger ~query_name query_obj =
  let open Deferred.Let_syntax in
  if not t.enabled then
    Deferred.Or_error.error_string
      "graphql is not enabled (hint: set `requires_graphql= true` in the test \
       config)"
  else
    let uri = t.uri in
    let metadata =
      [ ("query", `String query_name)
      ; ("uri", `String (Uri.to_string uri))
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
          "GraphQL request \"$query\" to \"$uri\" failed too many times"
          ~metadata ;
        Deferred.Or_error.errorf
          "GraphQL \"%s\" to \"%s\" request failed too many times" query_name
          (Uri.to_string uri) )
      else
        match%bind Client.query query_obj uri with
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

type metrics_t =
  { block_production_delay : int list
  ; transaction_pool_diff_received : int
  ; transaction_pool_diff_broadcasted : int
  ; transactions_added_to_pool : int
  ; transaction_pool_size : int
  }

let get_metrics t =
  let open Deferred.Or_error.Let_syntax in
  [%log' info t.logger] "Getting node's metrics" ~metadata:t.logger_metadata ;
  let query_obj = Requests.Query_metrics.make () in
  let%bind query_result_obj =
    exec t ~logger:t.logger ~query_name:"query_metrics" query_obj
  in
  [%log' info t.logger] "get_metrics, finished exec_graphql_request" ;
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
  [%log' info t.logger]
    "get_metrics, result of graphql query (block_production_delay; \
     tx_received; tx_broadcasted; txs_added_to_pool; tx_pool_size) (%s; %d; \
     %d; %d; %d)"
    ( Core.String.concat ~sep:", "
    @@ Core.List.map ~f:string_of_int block_production_delay )
    transaction_pool_diff_received transaction_pool_diff_broadcasted
    transactions_added_to_pool transaction_pool_size ;
  return
    { block_production_delay
    ; transaction_pool_diff_broadcasted
    ; transaction_pool_diff_received
    ; transactions_added_to_pool
    ; transaction_pool_size
    }

type signed_command_result =
  { id : string
  ; hash : Transaction_hash.t
  ; nonce : Mina_numbers.Account_nonce.t
  }

let transaction_id_to_string id =
  Yojson.Basic.to_string (Graphql_lib.Scalars.TransactionId.serialize id)

let send_payment_with_raw_sig t ~sender_pub_key ~receiver_pub_key ~amount ~fee
    ~nonce ~memo ~(valid_until : Mina_numbers.Global_slot.t) ~raw_signature =
  [%log' info t.logger] "Sending a payment with raw signature"
    ~metadata:t.logger_metadata ;
  let open Deferred.Or_error.Let_syntax in
  let send_payment_graphql () =
    let open Requests.Send_payment_with_raw_sig in
    let input =
      Mina_graphql.Types.Input.SendPaymentInput.make_input ~from:sender_pub_key
        ~to_:receiver_pub_key ~amount ~fee ~memo ~nonce
        ~valid_until:(Mina_numbers.Global_slot.to_uint32 valid_until)
        ()
    in
    let variables = makeVariables ~input ~rawSignature:raw_signature () in
    let send_payment_obj = make variables in
    let variables_json_basic = variablesToJson (serializeVariables variables) in
    (* An awkward conversion from Yojson.Basic to Yojson.Safe *)
    let variables_json =
      Yojson.Basic.to_string variables_json_basic |> Yojson.Safe.from_string
    in
    [%log' info t.logger] "send_payment_obj with $variables "
      ~metadata:[ ("variables", variables_json) ] ;
    exec ~logger:t.logger t ~query_name:"Send_payment_with_raw_sig_graphql"
      send_payment_obj
  in
  let%map sent_payment_obj = send_payment_graphql () in
  let return_obj = sent_payment_obj.sendPayment.payment in
  let res =
    { id = transaction_id_to_string return_obj.id
    ; hash = return_obj.hash
    ; nonce = Mina_numbers.Account_nonce.of_int return_obj.nonce
    }
  in
  [%log' info t.logger] "Sent payment"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
      ] ;
  res

let send_test_payments ~repeat_count ~repeat_delay_ms t ~senders
    ~receiver_pub_key ~amount ~fee =
  [%log' info t.logger] "Sending a series of test payments"
    ~metadata:t.logger_metadata ;
  let open Deferred.Or_error.Let_syntax in
  let send_payment_graphql () =
    let send_payment_obj =
      Requests.Send_test_payments.(
        make
        @@ makeVariables ~senders ~receiver:receiver_pub_key
             ~amount:(Currency.Amount.to_uint64 amount)
             ~fee:(Currency.Fee.to_uint64 fee)
             ~repeat_count ~repeat_delay_ms ())
    in
    exec ~logger:t.logger t ~query_name:"send_payment_graphql" send_payment_obj
  in
  let%map _ = send_payment_graphql () in
  [%log' info t.logger] "Sent test payments"

let set_snark_worker t ~new_snark_pub_key =
  [%log' info t.logger] "Changing snark worker key" ~metadata:t.logger_metadata ;
  let open Deferred.Or_error.Let_syntax in
  let set_snark_worker_graphql () =
    let input = Some new_snark_pub_key in
    let set_snark_worker_obj =
      Requests.Set_snark_worker.(make @@ makeVariables ~input ())
    in
    exec ~logger:t.logger t ~query_name:"set_snark_worker_graphql"
      set_snark_worker_obj
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
        last |> Scalars.PublicKey.serialize |> Yojson.Basic.to_string
  in
  [%log' info t.logger] "snark worker changed, lastSnarkWorker: %s"
    last_snark_worker
    ~metadata:[ ("lastSnarkWorker", `String last_snark_worker) ] ;
  ()

let send_zkapp_batch (t : t) ~(zkapp_commands : Mina_base.Zkapp_command.t list)
    =
  [%log' info t.logger] "Sending zkapp transactions" ~metadata:t.logger_metadata ;
  let open Deferred.Or_error.Let_syntax in
  let zkapp_commands_json =
    Core.List.map zkapp_commands ~f:(fun zkapp_command ->
        Mina_base.Zkapp_command.to_json zkapp_command |> Yojson.Safe.to_basic )
    |> Array.of_list
  in
  let send_zkapp_graphql () =
    let send_zkapp_obj =
      Requests.Send_test_zkapp.(
        make @@ makeVariables ~zkapp_commands:zkapp_commands_json ())
    in
    exec ~logger:t.logger t ~query_name:"send_zkapp_graphql" send_zkapp_obj
  in
  let%bind sent_zkapp_obj = send_zkapp_graphql () in
  let%bind zkapp_ids =
    Deferred.Array.fold ~init:(Ok []) sent_zkapp_obj.internalSendZkapp
      ~f:(fun acc (zkapp_obj : Requests.Send_test_zkapp.t_internalSendZkapp) ->
        let%bind res =
          match zkapp_obj.zkapp.failureReason with
          | None ->
              let zkapp_id = transaction_id_to_string zkapp_obj.zkapp.id in
              [%log' info t.logger] "Sent zkapp transaction"
                ~metadata:[ ("zkapp_id", `String zkapp_id) ] ;
              return zkapp_id
          | Some s ->
              Deferred.Or_error.errorf "Zkapp failed, reason: %s"
                ( Core.Array.fold ~init:[] s ~f:(fun acc f ->
                      match f with
                      | None ->
                          acc
                      | Some f ->
                          let t =
                            ( Core.Option.value_exn f.index
                            , f.failures |> Array.to_list |> List.rev )
                          in
                          t :: acc )
                |> Mina_base.Transaction_status.Failure.Collection.Display
                   .to_yojson |> Yojson.Safe.to_string )
        in
        let%map acc = Deferred.return acc in
        res :: acc )
  in
  return (List.rev zkapp_ids)

let get_pooled_zkapp_commands (t : t)
    ~(pk : Signature_lib.Public_key.Compressed.t) =
  [%log' info t.logger] "Retrieving zkapp_commands from transaction pool"
    ~metadata:
      ( t.logger_metadata
      @ [ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk) ] ) ;
  let open Deferred.Or_error.Let_syntax in
  let get_pooled_zkapp_commands_graphql () =
    let get_pooled_zkapp_commands =
      Requests.Pooled_zkapp_commands.(
        make
        @@ makeVariables ~public_key:(Graphql_lib.Encoders.public_key pk) ())
    in
    exec ~logger:t.logger t ~query_name:"get_pooled_zkapp_commands"
      get_pooled_zkapp_commands
  in
  let%bind zkapp_pool_obj = get_pooled_zkapp_commands_graphql () in
  let transaction_ids =
    Core.Array.map zkapp_pool_obj.pooledZkappCommands ~f:(fun zkapp_command ->
        zkapp_command.id |> Transaction_id.to_base64 )
    |> Array.to_list
  in
  [%log' info t.logger] "Retrieved zkapp_commands from transaction pool"
    ~metadata:
      ( t.logger_metadata
      @ [ ( "transaction ids"
          , `List (Core.List.map ~f:(fun t -> `String t) transaction_ids) )
        ] ) ;
  return transaction_ids

let send_delegation t ~sender_pub_key ~receiver_pub_key ~fee =
  [%log' info t.logger] "Sending stake delegation" ~metadata:t.logger_metadata ;
  let open Deferred.Or_error.Let_syntax in
  let sender_pk_str =
    Signature_lib.Public_key.Compressed.to_string sender_pub_key
  in
  [%log' info t.logger] "send_delegation: unlocking account"
    ~metadata:[ ("sender_pk", `String sender_pk_str) ] ;
  let unlock_sender_account_graphql () =
    let unlock_account_obj =
      Requests.Unlock_account.(
        make
        @@ makeVariables ~password:"naughty blue worm"
             ~public_key:sender_pub_key ())
    in
    exec ~logger:t.logger t ~query_name:"unlock_sender_account_graphql"
      unlock_account_obj
  in
  let%bind _ = unlock_sender_account_graphql () in
  let send_delegation_graphql () =
    let input =
      Mina_graphql.Types.Input.SendDelegationInput.make_input
        ~from:sender_pub_key ~to_:receiver_pub_key ~fee ()
    in
    let send_delegation_obj =
      Requests.Send_delegation.(make @@ makeVariables ~input ())
    in
    exec ~logger:t.logger t ~query_name:"send_delegation_graphql"
      send_delegation_obj
  in
  let%map result_obj = send_delegation_graphql () in
  let return_obj = result_obj.sendDelegation.delegation in
  let res =
    { id = transaction_id_to_string return_obj.id
    ; hash = return_obj.hash
    ; nonce = Mina_numbers.Account_nonce.of_int return_obj.nonce
    }
  in
  [%log' info t.logger] "stake delegation sent"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
      ] ;
  res

(* if we expect failure, might want retry_on_graphql_error to be false *)
let send_payment t ~password ~sender_pub_key ~receiver_pub_key ~amount ~fee =
  [%log' info t.logger] "Sending a payment" ~metadata:t.logger_metadata ;
  let open Deferred.Or_error.Let_syntax in
  let sender_pk_str =
    Signature_lib.Public_key.Compressed.to_string sender_pub_key
  in
  [%log' info t.logger] "send_payment: unlocking account"
    ~metadata:[ ("sender_pk", `String sender_pk_str) ] ;
  let unlock_sender_account_graphql () =
    let unlock_account_obj =
      Requests.Unlock_account.(
        make @@ makeVariables ~password ~public_key:sender_pub_key ())
    in
    exec ~logger:t.logger t ~initial_delay_sec:0.
      ~query_name:"unlock_sender_account_graphql" unlock_account_obj
  in
  let%bind _unlock_acct_obj = unlock_sender_account_graphql () in
  let send_payment_graphql () =
    let input =
      Mina_graphql.Types.Input.SendPaymentInput.make_input ~from:sender_pub_key
        ~to_:receiver_pub_key ~amount ~fee ()
    in
    let send_payment_obj =
      Requests.Send_payment_from_input.(make @@ makeVariables ~input ())
    in
    exec ~logger:t.logger t ~query_name:"send_payment_graphql" send_payment_obj
  in
  let%map sent_payment_obj = send_payment_graphql () in
  let return_obj = sent_payment_obj.sendPayment.payment in
  let res =
    { id = transaction_id_to_string return_obj.id
    ; hash = return_obj.hash
    ; nonce = Mina_numbers.Account_nonce.of_int return_obj.nonce
    }
  in
  [%log' info t.logger] "Sent payment"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
      ] ;
  res

let permissions_of_account_permissions account_permissions :
    Mina_base.Permissions.t =
  (* the polymorphic variants come from Partial_accounts.auth_required in Mina_graphql *)
  let to_auth_required = function
    | `Either ->
        Mina_base.Permissions.Auth_required.Either
    | `Impossible ->
        Impossible
    | `None ->
        None
    | `Proof ->
        Proof
    | `Signature ->
        Signature
  in
  let open Requests.Account in
  { edit_action_state = to_auth_required account_permissions.editActionState
  ; edit_state = to_auth_required account_permissions.editState
  ; increment_nonce = to_auth_required account_permissions.incrementNonce
  ; receive = to_auth_required account_permissions.receive
  ; send = to_auth_required account_permissions.send
  ; access = to_auth_required account_permissions.access
  ; set_delegate = to_auth_required account_permissions.setDelegate
  ; set_permissions = to_auth_required account_permissions.setPermissions
  ; set_zkapp_uri = to_auth_required account_permissions.setZkappUri
  ; set_token_symbol = to_auth_required account_permissions.setTokenSymbol
  ; set_verification_key =
      to_auth_required account_permissions.setVerificationKey
  ; set_voting_for = to_auth_required account_permissions.setVotingFor
  ; set_timing = to_auth_required account_permissions.setTiming
  }

let graphql_uri t = t.uri |> Uri.to_string

type account_data =
  { nonce : Mina_numbers.Account_nonce.t
  ; total_balance : Currency.Balance.t
  ; liquid_balance_opt : Currency.Balance.t option
  ; locked_balance_opt : Currency.Balance.t option
  }

let get_account t ~account_id =
  let pk = Mina_base.Account_id.public_key account_id in
  let token = Mina_base.Account_id.token_id account_id in
  [%log' info t.logger] "Getting account"
    ~metadata:
      ( ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk)
      :: t.logger_metadata ) ;
  let get_account_obj =
    Requests.Account.(
      make
      @@ makeVariables
           ~public_key:(Graphql_lib.Encoders.public_key pk)
           ~token:(Graphql_lib.Encoders.token token)
           ())
  in
  exec ~logger:t.logger t ~query_name:"get_account_graphql" get_account_obj

let get_account_permissions t ~account_id =
  let open Deferred.Or_error in
  let open Let_syntax in
  let%bind account_obj = get_account t ~account_id in
  match account_obj.account with
  | Some account -> (
      match account.permissions with
      | Some ledger_permissions ->
          return @@ permissions_of_account_permissions ledger_permissions
      | None ->
          fail (Error.of_string "Could not get permissions from ledger account")
      )
  | None ->
      fail (Error.of_string "Could not get account from ledger")

(* return a Account_update.Update.t with all fields `Set` to the
   value in the account, or `Keep` if value unavailable,
   as if this update had been applied to the account
*)
let get_account_update t ~account_id =
  let open Deferred.Or_error in
  let open Let_syntax in
  let%bind account_obj = get_account t ~account_id in
  match account_obj.account with
  | Some account ->
      let open Mina_base.Zkapp_basic.Set_or_keep in
      let%bind app_state =
        match account.zkappState with
        | Some strs ->
            let fields =
              Array.to_list strs |> Base.List.map ~f:(fun s -> Set s)
            in
            return (Mina_base.Zkapp_state.V.of_list_exn fields)
        | None ->
            fail
              (Error.of_string
                 (sprintf
                    "Expected zkApp account with an app state for public key %s"
                    (Signature_lib.Public_key.Compressed.to_base58_check
                       (Mina_base.Account_id.public_key account_id) ) ) )
      in
      let%bind delegate =
        match account.delegate with
        | Some s ->
            return (Set s)
        | None ->
            fail (Error.of_string "Expected delegate in account")
      in
      let%bind verification_key =
        match account.verificationKey with
        | Some vk_obj ->
            let data = vk_obj.verificationKey in
            let hash = vk_obj.hash in
            return (Set ({ data; hash } : _ With_hash.t))
        | None ->
            fail
              (Error.of_string
                 (sprintf
                    "Expected zkApp account with a verification key for \
                     public_key %s"
                    (Signature_lib.Public_key.Compressed.to_base58_check
                       (Mina_base.Account_id.public_key account_id) ) ) )
      in
      let%bind permissions =
        match account.permissions with
        | Some perms ->
            return @@ Set (permissions_of_account_permissions perms)
        | None ->
            fail (Error.of_string "Expected permissions in account")
      in
      let%bind zkapp_uri =
        match account.zkappUri with
        | Some s ->
            return @@ Set s
        | None ->
            fail (Error.of_string "Expected zkApp URI in account")
      in
      let%bind token_symbol =
        match account.tokenSymbol with
        | Some s ->
            return @@ Set s
        | None ->
            fail (Error.of_string "Expected token symbol in account")
      in
      let%bind timing =
        let timing = account.timing in
        let cliff_amount = timing.cliffAmount in
        let cliff_time = timing.cliffTime in
        let vesting_period = timing.vestingPeriod in
        let vesting_increment = timing.vestingIncrement in
        let initial_minimum_balance = timing.initialMinimumBalance in
        match
          ( cliff_amount
          , cliff_time
          , vesting_period
          , vesting_increment
          , initial_minimum_balance )
        with
        | None, None, None, None, None ->
            return @@ Keep
        | Some amt, Some tm, Some period, Some incr, Some bal ->
            let cliff_amount = amt in
            let%bind cliff_time =
              match tm with
              | `String s ->
                  return @@ Mina_numbers.Global_slot.of_string s
              | _ ->
                  fail
                    (Error.of_string
                       "Expected string for cliff time in account timing" )
            in
            let%bind vesting_period =
              match period with
              | `String s ->
                  return @@ Mina_numbers.Global_slot.of_string s
              | _ ->
                  fail
                    (Error.of_string
                       "Expected string for vesting period in account timing" )
            in
            let vesting_increment = incr in
            let initial_minimum_balance = bal in
            return
              (Set
                 ( { initial_minimum_balance
                   ; cliff_amount
                   ; cliff_time
                   ; vesting_period
                   ; vesting_increment
                   }
                   : Mina_base.Account_update.Update.Timing_info.t ) )
        | _ ->
            fail (Error.of_string "Some pieces of account timing are missing")
      in
      let%bind voting_for =
        match account.votingFor with
        | Some s ->
            return @@ Set s
        | None ->
            fail (Error.of_string "Expected voting-for state hash in account")
      in
      return
        ( { app_state
          ; delegate
          ; verification_key
          ; permissions
          ; zkapp_uri
          ; token_symbol
          ; timing
          ; voting_for
          }
          : Mina_base.Account_update.Update.t )
  | None ->
      fail (Error.of_string "Could not get account from ledger")

let get_account_data t ~account_id =
  let open Deferred.Or_error.Let_syntax in
  let public_key = Mina_base.Account_id.public_key account_id in
  let token = Mina_base.Account_id.token_id account_id in
  [%log' info t.logger] "Getting account data, which is its balances and nonce"
    ~metadata:
      ( ("pub_key", Signature_lib.Public_key.Compressed.to_yojson public_key)
      :: t.logger_metadata ) ;
  let%bind account_obj = get_account t ~account_id in
  match account_obj.account with
  | None ->
      Deferred.Or_error.errorf
        !"Account with Account id %{sexp:Mina_base.Account_id.t}, public_key \
          %s, and token %s not found"
        account_id
        (Signature_lib.Public_key.Compressed.to_string public_key)
        (Mina_base.Token_id.to_string token)
  | Some acc ->
      return
        { nonce =
            Core.Option.value_exn
              ~message:
                "the nonce from get_balance is None, which should be impossible"
              acc.nonce
        ; total_balance = acc.balance.total
        ; liquid_balance_opt = acc.balance.liquid
        ; locked_balance_opt = acc.balance.locked
        }

let get_account_data_by_pk t ~(public_key : Signature_lib.Public_key.t) =
  let account_id = Mina_base.Account_id.of_public_key public_key in
  get_account_data t ~account_id

type best_chain_block =
  { state_hash : string; command_transaction_count : int; creator_pk : string }

let get_best_chain ?max_length t =
  let open Deferred.Or_error.Let_syntax in
  let query = Requests.Best_chain.(make @@ makeVariables ?max_length ()) in
  let%bind result = exec ~logger:t.logger t ~query_name:"best_chain" query in
  match result.bestChain with
  | None | Some [||] ->
      Deferred.Or_error.error_string "failed to get best chains"
  | Some chain ->
      return
      @@ Core.List.map
           ~f:(fun block ->
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

let get_peer_id t =
  let open Deferred.Or_error.Let_syntax in
  [%log' info t.logger]
    "Getting node's peer_id, and the peer_ids of node's peers"
    ~metadata:t.logger_metadata ;
  let query_obj = Requests.Query_peer_id.(make @@ makeVariables ()) in
  let%bind query_result_obj =
    exec ~logger:t.logger t ~query_name:"query_peer_id" query_obj
  in
  [%log' info t.logger] "get_peer_id, finished exec_graphql_request" ;
  let self_id_obj = query_result_obj.daemonStatus.addrsAndPorts.peer in
  let%bind self_id =
    match self_id_obj with
    | None ->
        Deferred.Or_error.error_string "Peer not found"
    | Some peer ->
        return peer.peerId
  in
  let peers = query_result_obj.daemonStatus.peers |> Array.to_list in
  let peer_ids = Core.List.map peers ~f:(fun peer -> peer.peerId) in
  [%log' info t.logger]
    "get_peer_id, result of graphql query (self_id,[peers]) (%s,%s)" self_id
    (Core.String.concat ~sep:" " peer_ids) ;
  return (self_id, peer_ids)
