open Core_kernel
open Async
open Mina_base
open Mina_transaction

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

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

(** this function will repeatedly attempt to connect to graphql port <num_tries> times before giving up *)
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

let unlock_account ~logger node_uri ~public_key ~password =
  let unlock_account_obj =
    Graphql.Unlock_account.(
      make
      @@ makeVariables ~password ~public_key ())
  in
  exec_graphql_request ~logger ~node_uri ~initial_delay_sec:0.
    ~query_name:"unlock_sender_account_graphql" unlock_account_obj

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

let get_account ~logger node_uri ~account_id =
  let pk = Mina_base.Account_id.public_key account_id in
  let token = Mina_base.Account_id.token_id account_id in
  [%log info] "Getting account"
    ~metadata:[ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk) ] ;
  let get_account_obj =
    Graphql.Account.(
      make
      @@ makeVariables
           ~public_key:(Graphql_lib.Encoders.public_key pk)
           ~token:(Graphql_lib.Encoders.token token)
           ())
  in
  exec_graphql_request ~logger ~node_uri ~query_name:"get_account_graphql"
    get_account_obj

type account_data =
  { nonce : Mina_numbers.Account_nonce.t
  ; total_balance : Currency.Balance.t
  ; liquid_balance_opt : Currency.Balance.t option
  ; locked_balance_opt : Currency.Balance.t option
  }

let get_account_data ~logger node_uri ~account_id =
  let open Deferred.Or_error.Let_syntax in
  let public_key = Mina_base.Account_id.public_key account_id in
  let token = Mina_base.Account_id.token_id account_id in
  [%log info] "Getting account data, which is its balances and nonce"
    ~metadata:
      [ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson public_key) ] ;
  let%bind account_obj = get_account ~logger node_uri ~account_id in
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
            Option.value_exn
              ~message:
                "the nonce from get_balance is None, which should be impossible"
              acc.nonce
        ; total_balance = acc.balance.total
        ; liquid_balance_opt = acc.balance.liquid
        ; locked_balance_opt = acc.balance.locked
        }

let must_get_account_data ~logger node_uri ~account_id =
  get_account_data ~logger node_uri ~account_id
  |> Deferred.bind ~f:Malleable_error.or_hard_error

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
  let open Graphql.Account in
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

let get_account_permissions ~logger t ~account_id =
  let open Deferred.Or_error in
  let open Let_syntax in
  let%bind account_obj = get_account ~logger t ~account_id in
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

(** return a Account_update.Update.t with all fields `Set` to the
   value in the account, or `Keep` if value unavailable,
   as if this update had been applied to the account
*)
let get_account_update ~logger t ~account_id =
  let open Deferred.Or_error in
  let open Let_syntax in
  let%bind account_obj = get_account ~logger t ~account_id in
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
                  return @@ Mina_numbers.Global_slot_since_genesis.of_string s
              | _ ->
                  fail
                    (Error.of_string
                       "Expected string for cliff time in account timing" )
            in
            let%bind vesting_period =
              match period with
              | `String s ->
                  return @@ Mina_numbers.Global_slot_span.of_string s
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

type signed_command_result =
  { id : string
  ; hash : Transaction_hash.t
  ; nonce : Mina_numbers.Account_nonce.t
  }

let transaction_id_to_string id =
  Yojson.Basic.to_string (Graphql_lib.Scalars.TransactionId.serialize id)

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
  let%bind _ = unlock_account ~logger node_uri ~password:node_password ~public_key:sender_pub_key in
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
    { id = transaction_id_to_string return_obj.id
    ; hash = return_obj.hash
    ; nonce = Mina_numbers.Account_nonce.of_int return_obj.nonce
    }
  in
  [%log info] "Sent payment"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
      ] ;
  res

let must_send_online_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount
    ~fee =
  send_online_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let send_zkapp_batch ~logger node_uri
    ~(zkapp_commands : Mina_base.Zkapp_command.t list) =
  [%log info] "Sending zkapp transactions"
    ~metadata:[ ("node_uri", `String (Uri.to_string node_uri)) ] ;
  let open Deferred.Or_error.Let_syntax in
  let zkapp_commands_json =
    List.map zkapp_commands ~f:(fun zkapp_command ->
        Mina_base.Zkapp_command.to_json zkapp_command |> Yojson.Safe.to_basic )
    |> Array.of_list
  in
  let send_zkapp_graphql () =
    let send_zkapp_obj =
      Graphql.Send_test_zkapp.(
        make @@ makeVariables ~zkapp_commands:zkapp_commands_json ())
    in
    exec_graphql_request ~logger ~node_uri ~query_name:"send_zkapp_graphql"
      send_zkapp_obj
  in
  let%bind sent_zkapp_obj = send_zkapp_graphql () in
  let%bind zkapp_ids =
    Deferred.Array.fold ~init:(Ok []) sent_zkapp_obj.internalSendZkapp
      ~f:(fun acc (zkapp_obj : Graphql.Send_test_zkapp.t_internalSendZkapp) ->
        let%bind res =
          match zkapp_obj.zkapp.failureReason with
          | None ->
              let zkapp_id = transaction_id_to_string zkapp_obj.zkapp.id in
              [%log info] "Sent zkapp transaction"
                ~metadata:[ ("zkapp_id", `String zkapp_id) ] ;
              return zkapp_id
          | Some s ->
              Deferred.Or_error.errorf "Zkapp failed, reason: %s"
                ( Array.fold ~init:[] s ~f:(fun acc f ->
                      match f with
                      | None ->
                          acc
                      | Some f ->
                          let t =
                            ( Option.value_exn f.index
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

let get_pooled_zkapp_commands ~logger node_uri
    ~(pk : Signature_lib.Public_key.Compressed.t) =
  [%log info] "Retrieving zkapp_commands from transaction pool"
    ~metadata:
      [ ("node_uri", `String (Uri.to_string node_uri))
      ; ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk)
      ] ;
  let open Deferred.Or_error.Let_syntax in
  let get_pooled_zkapp_commands_graphql () =
    let get_pooled_zkapp_commands =
      Graphql.Pooled_zkapp_commands.(
        make
        @@ makeVariables ~public_key:(Graphql_lib.Encoders.public_key pk) ())
    in
    exec_graphql_request ~logger ~node_uri
      ~query_name:"get_pooled_zkapp_commands" get_pooled_zkapp_commands
  in
  let%bind zkapp_pool_obj = get_pooled_zkapp_commands_graphql () in
  let transaction_ids =
    Array.map zkapp_pool_obj.pooledZkappCommands ~f:(fun zkapp_command ->
        zkapp_command.id |> Transaction_id.to_base64 )
    |> Array.to_list
  in
  [%log info] "Retrieved zkapp_commands from transaction pool"
    ~metadata:
      [ ("node_uri", `String (Uri.to_string node_uri))
      ; ( "transaction ids"
        , `List (List.map ~f:(fun t -> `String t) transaction_ids) )
      ] ;
  return transaction_ids

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
  let%bind _ = unlock_account ~logger node_uri ~password:node_password ~public_key:sender_pub_key in
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
    { id = transaction_id_to_string return_obj.id
    ; hash = return_obj.hash
    ; nonce = Mina_numbers.Account_nonce.of_int return_obj.nonce
    }
  in
  [%log info] "stake delegation sent"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
      ] ;
  res

let get_nonce ~logger node_uri ~public_key = 
  let open Deferred.Let_syntax in
  let%bind querry_result =
      get_account_data ~logger node_uri ~account_id:(Mina_base.Account_id.of_public_key public_key)
  in
  Deferred.return (Or_error.map querry_result ~f:(fun querry_result -> querry_result.nonce))

let must_send_delegation ~logger node_uri ~sender_pub_key
    ~(receiver_pub_key : Account.key) ~fee =
  send_delegation ~logger node_uri ~sender_pub_key ~receiver_pub_key ~fee
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let send_payment_with_raw_sig ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee ~nonce ~memo
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t) ~raw_signature =
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
        ~to_:receiver_pub_key ~amount ~fee ~memo ~nonce
        ~valid_until:
          (Mina_numbers.Global_slot_since_genesis.to_uint32 valid_until)
        ()
    in
    let variables = makeVariables ~input ~rawSignature:raw_signature () in
    let send_payment_obj = make variables in
    [%log info]
      "send_payment_obj with $from $to $amount $fee $memo $nonce $valid_until \
       $raw_signature "
      ~metadata:
        [ ("from", Signature_lib.Public_key.Compressed.to_yojson sender_pub_key)
        ; ("to", Signature_lib.Public_key.Compressed.to_yojson receiver_pub_key)
        ; ("amount", Currency.Amount.to_yojson amount)
        ; ("fee", Currency.Fee.to_yojson fee)
        ; ("memo", `String memo)
        ; ("nonce", Account.Nonce.to_yojson nonce)
        ; ( "valid_until"
          , Mina_numbers.Global_slot_since_genesis.to_yojson valid_until )
        ; ("raw_signature", `String raw_signature)
        ] ;
    exec_graphql_request ~logger ~node_uri
      ~query_name:"Send_payment_with_raw_sig_graphql" send_payment_obj
  in
  let%map sent_payment_obj = send_payment_graphql () in
  let return_obj = sent_payment_obj.sendPayment.payment in
  let res =
    { id = transaction_id_to_string return_obj.id
    ; hash = return_obj.hash
    ; nonce = Mina_numbers.Account_nonce.of_int return_obj.nonce
    }
  in
  [%log info] "Sent payment"
    ~metadata:
      [ ("user_command_id", `String res.id)
      ; ("hash", `String (Transaction_hash.to_base58_check res.hash))
      ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
      ] ;
  res

let must_send_payment_with_raw_sig ~logger node_uri ~sender_pub_key
    ~receiver_pub_key ~amount ~fee ~nonce ~memo
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t) ~raw_signature =
  send_payment_with_raw_sig ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee ~nonce ~memo
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t)
    ~raw_signature
  |> Deferred.bind ~f:Malleable_error.or_hard_error

let sign_and_send_payment ~logger node_uri
    ~(sender_keypair : Import.Signature_keypair.t) ~receiver_pub_key ~amount
    ~fee ~nonce ~memo ~valid_until =
  let sender_pub_key =
    sender_keypair.public_key |> Signature_lib.Public_key.compress
  in
  let payload =
    let body =
      Signed_command_payload.Body.Payment
        { Payment_payload.Poly.receiver_pk = receiver_pub_key; amount }
    in
    let common =
      { Signed_command_payload.Common.Poly.fee
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
    ~amount ~fee ~nonce ~memo ~valid_until ~raw_signature

let must_sign_and_send_payment ~logger node_uri
    ~(sender_keypair : Import.Signature_keypair.t) ~receiver_pub_key ~amount
    ~fee ~nonce ~memo ~valid_until =
  sign_and_send_payment ~logger node_uri
    ~(sender_keypair : Import.Signature_keypair.t)
    ~receiver_pub_key ~amount ~fee ~nonce ~memo ~valid_until
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

let must_set_snark_worker ~logger t ~new_snark_pub_key =
  set_snark_worker ~logger t ~new_snark_pub_key
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
