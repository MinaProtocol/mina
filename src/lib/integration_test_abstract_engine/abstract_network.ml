open Core_kernel
open Async
open Integration_test_lib
open Mina_transaction
open Config_util

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

let config_path = config_path

let keypairs_path = keypairs_path

let mina_image = mina_image

let alias = alias

let archive_image = archive_image

module Node = struct
  type t =
    { node_id : Node_id.t
    ; network_id : Network_id.t
    ; network_keypair : Network_keypair.t option
    ; node_type : Node_type.t
    ; password : string
    ; graphql_uri : string
    }

  let id { node_id; _ } = node_id

  let network_keypair { network_keypair; _ } = network_keypair

  let start ~fresh_state t : unit Malleable_error.t =
    try
      let args =
        [ ("fresh_state", `Bool fresh_state)
        ; ("network_id", `String t.network_id)
        ; ("node_id", `String t.node_id)
        ]
      in
      let%bind () =
        match%map
          Config_file.run_command ~config:!config_path ~args "start_node"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Node_started.of_yojson |> Result.ok_or_failwith |> ignore
        | _ ->
            failwith "invalid node started response"
      in
      Malleable_error.return ()
    with Failure err -> Malleable_error.hard_error_string err

  let stop t =
    try
      let args =
        [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
      in
      let%bind () =
        match%map
          Config_file.run_command ~config:!config_path ~args "stop_node"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Node_stopped.of_yojson |> Result.ok_or_failwith |> ignore
        | _ ->
            failwith "invalid node stopped response"
      in
      Malleable_error.return ()
    with Failure err -> Malleable_error.hard_error_string err

  let logger_metadata node =
    [ ("network_id", `String node.network_id)
    ; ("node_id", `String node.node_id)
    ]

  module Collections = struct
    let f network_id (node_info : Network_deployed.node_info) =
      { node_id = node_info.node_id
      ; network_id
      ; network_keypair = node_info.network_keypair
      ; node_type = node_info.node_type
      ; password = "naughty blue worm"
      ; graphql_uri = Option.value node_info.graphql_uri ~default:""
      }

    open Network_deployed
    open Core.String.Map

    let network_id t = data t |> List.hd_exn |> network_id

    let archive_nodes t =
      filter ~f:is_archive_node t |> map ~f:(f @@ network_id t)

    let block_producers t =
      filter ~f:is_block_producer t |> map ~f:(f @@ network_id t)

    let seeds t = filter ~f:is_seed_node t |> map ~f:(f @@ network_id t)

    let snark_coordinators t =
      filter t ~f:is_snark_coordinator |> map ~f:(f @@ network_id t)

    let snark_workers t =
      filter ~f:is_snark_worker t |> map ~f:(f @@ network_id t)
  end

  module Scalars = Graphql_lib.Scalars

  module Graphql = struct
    let ingress_uri node = Uri.of_string node.graphql_uri

    module Client = Graphql_lib.Client.Make (struct
      let preprocess_variables_string = Fn.id

      let headers = String.Map.empty
    end)

    (* graphql_ppx uses Stdlib symbols instead of Base *)
    open Stdlib
    module Encoders = Mina_graphql.Types.Input

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

    module Send_test_zkapp = Generated_graphql_queries.Send_test_zkapp
    module Pooled_zkapp_commands =
      Generated_graphql_queries.Pooled_zkapp_commands

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

  (* this function will repeatedly attempt to connect to graphql port <num_tries> times before giving up *)
  let exec_graphql_request ?(num_tries = 10) ?(retry_delay_sec = 30.0)
      ?(initial_delay_sec = 0.) ~logger ~node ~query_name query_obj =
    let open Deferred.Let_syntax in
    let uri = Graphql.ingress_uri node in
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
        match%bind Graphql.Client.query query_obj uri with
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
              ~metadata:(("error", `String err_string) :: metadata) ;
            Deferred.Or_error.error_string err_string
    in
    let%bind () = after (Time.Span.of_sec initial_delay_sec) in
    retry num_tries

  let get_peer_ids ~logger t =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Getting node's peer_id, and the peer_ids of node's peers"
      ~metadata:(logger_metadata t) ;
    let query_obj = Graphql.Query_peer_id.(make @@ makeVariables ()) in
    let%bind query_result_obj =
      exec_graphql_request ~logger ~node:t ~query_name:"query_peer_id" query_obj
    in
    [%log info] "get_peer_ids, finished exec_graphql_request" ;
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
    [%log info]
      "get_peer_ids, result of graphql query (self_id,[peers]) (%s,%s)" self_id
      (String.concat ~sep:" " peer_ids) ;
    return (self_id, peer_ids)

  let must_get_peer_ids ~logger t =
    get_peer_ids ~logger t |> Deferred.bind ~f:Malleable_error.or_hard_error

  let get_best_chain ?max_length ~logger t =
    let open Deferred.Or_error.Let_syntax in
    let query = Graphql.Best_chain.(make @@ makeVariables ?max_length ()) in
    let%bind result =
      exec_graphql_request ~logger ~node:t ~query_name:"best_chain" query
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

  let must_get_best_chain ?max_length ~logger t =
    get_best_chain ?max_length ~logger t
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let get_account ~logger t ~account_id =
    let pk = Mina_base.Account_id.public_key account_id in
    let token = Mina_base.Account_id.token_id account_id in
    [%log info] "Getting account"
      ~metadata:
        ( ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk)
        :: logger_metadata t ) ;
    let get_account_obj =
      Graphql.Account.(
        make
        @@ makeVariables
             ~public_key:(Graphql_lib.Encoders.public_key pk)
             ~token:(Graphql_lib.Encoders.token token)
             ())
    in
    exec_graphql_request ~logger ~node:t ~query_name:"get_account_graphql"
      get_account_obj

  type account_data =
    { nonce : Mina_numbers.Account_nonce.t
    ; total_balance : Currency.Balance.t
    ; liquid_balance_opt : Currency.Balance.t option
    ; locked_balance_opt : Currency.Balance.t option
    }

  let get_account_data ~logger t ~account_id =
    let open Deferred.Or_error.Let_syntax in
    let public_key = Mina_base.Account_id.public_key account_id in
    let token = Mina_base.Account_id.token_id account_id in
    [%log info] "Getting account data, which is its balances and nonce"
      ~metadata:
        ( ("pub_key", Signature_lib.Public_key.Compressed.to_yojson public_key)
        :: logger_metadata t ) ;
    let%bind account_obj = get_account ~logger t ~account_id in
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
                  "the nonce from get_balance is None, which should be \
                   impossible"
                acc.nonce
          ; total_balance = acc.balance.total
          ; liquid_balance_opt = acc.balance.liquid
          ; locked_balance_opt = acc.balance.locked
          }

  let must_get_account_data ~logger t ~account_id =
    get_account_data ~logger t ~account_id
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

  let graphql_uri node = Graphql.ingress_uri node |> Uri.to_string

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
            fail
              (Error.of_string "Could not get permissions from ledger account")
        )
    | None ->
        fail (Error.of_string "Could not get account from ledger")

  (* return an Account_update.Update.t with all fields `Set` to the
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
                      "Expected zkApp account with an app state for public key \
                       %s"
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
  let send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee =
    [%log info] "Sending a payment" ~metadata:(logger_metadata t) ;
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
          @@ makeVariables ~password:t.password ~public_key:sender_pub_key ())
      in
      exec_graphql_request ~logger ~node:t ~initial_delay_sec:0.
        ~query_name:"unlock_sender_account_graphql" unlock_account_obj
    in
    let%bind _unlock_acct_obj = unlock_sender_account_graphql () in
    let send_payment_graphql () =
      let input =
        Mina_graphql.Types.Input.SendPaymentInput.make_input
          ~from:sender_pub_key ~to_:receiver_pub_key ~amount ~fee ()
      in
      let send_payment_obj =
        Graphql.Send_payment.(make @@ makeVariables ~input ())
      in
      exec_graphql_request ~logger ~node:t ~query_name:"send_payment_graphql"
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

  let must_send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
      =
    send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let send_zkapp_batch ~logger (t : t)
      ~(zkapp_commands : Mina_base.Zkapp_command.t list) =
    [%log info] "Sending zkapp transactions"
      ~metadata:
        [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ] ;
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
      exec_graphql_request ~logger ~node:t ~query_name:"send_zkapp_graphql"
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

  let get_pooled_zkapp_commands ~logger (t : t)
      ~(pk : Signature_lib.Public_key.Compressed.t) =
    [%log info] "Retrieving zkapp_commands from transaction pool"
      ~metadata:
        [ ("network_id", `String t.network_id)
        ; ("node_id", `String t.node_id)
        ; ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk)
        ] ;
    let open Deferred.Or_error.Let_syntax in
    let get_pooled_zkapp_commands_graphql () =
      let get_pooled_zkapp_commands =
        Graphql.Pooled_zkapp_commands.(
          make
          @@ makeVariables ~public_key:(Graphql_lib.Encoders.public_key pk) ())
      in
      exec_graphql_request ~logger ~node:t
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
        [ ("network_id", `String t.network_id)
        ; ("node_id", `String t.node_id)
        ; ( "transaction ids"
          , `List (List.map ~f:(fun t -> `String t) transaction_ids) )
        ] ;
    return transaction_ids

  let send_delegation ~logger t ~sender_pub_key ~receiver_pub_key ~fee =
    [%log info] "Sending stake delegation" ~metadata:(logger_metadata t) ;
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
          @@ makeVariables ~password:t.password ~public_key:sender_pub_key ())
      in
      exec_graphql_request ~logger ~node:t
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
      exec_graphql_request ~logger ~node:t ~query_name:"send_delegation_graphql"
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

  let must_send_delegation ~logger t ~sender_pub_key ~receiver_pub_key ~fee =
    send_delegation ~logger t ~sender_pub_key ~receiver_pub_key ~fee
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let send_payment_with_raw_sig ~logger t ~sender_pub_key ~receiver_pub_key
      ~amount ~fee ~nonce ~memo
      ~(valid_until : Mina_numbers.Global_slot_since_genesis.t) ~raw_signature =
    [%log info] "Sending a payment with raw signature"
      ~metadata:(logger_metadata t) ;
    let open Deferred.Or_error.Let_syntax in
    let send_payment_graphql () =
      let open Graphql.Send_payment_with_raw_sig in
      let input =
        Mina_graphql.Types.Input.SendPaymentInput.make_input
          ~from:sender_pub_key ~to_:receiver_pub_key ~amount ~fee ~memo ~nonce
          ~valid_until:
            (Mina_numbers.Global_slot_since_genesis.to_uint32 valid_until)
          ()
      in
      let variables = makeVariables ~input ~rawSignature:raw_signature () in
      let send_payment_obj = make variables in
      let variables_json_basic =
        variablesToJson (serializeVariables variables)
      in
      (* An awkward conversion from Yojson.Basic to Yojson.Safe *)
      let variables_json =
        Yojson.Basic.to_string variables_json_basic |> Yojson.Safe.from_string
      in
      [%log info] "send_payment_obj with $variables "
        ~metadata:[ ("variables", variables_json) ] ;
      exec_graphql_request ~logger ~node:t
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

  let must_send_payment_with_raw_sig ~logger t ~sender_pub_key ~receiver_pub_key
      ~amount ~fee ~nonce ~memo ~valid_until ~raw_signature =
    send_payment_with_raw_sig ~logger t ~sender_pub_key ~receiver_pub_key
      ~amount ~fee ~nonce ~memo ~valid_until ~raw_signature
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
      ~receiver_pub_key ~amount ~fee =
    [%log info] "Sending a series of test payments"
      ~metadata:(logger_metadata t) ;
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
      exec_graphql_request ~logger ~node:t ~query_name:"send_payment_graphql"
        send_payment_obj
    in
    let%map _ = send_payment_graphql () in
    [%log info] "Sent test payments"

  let must_send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
      ~receiver_pub_key ~amount ~fee =
    send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
      ~receiver_pub_key ~amount ~fee
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let set_snark_worker ~logger t ~new_snark_pub_key =
    [%log info] "Changing snark worker key" ~metadata:(logger_metadata t) ;
    let open Deferred.Or_error.Let_syntax in
    let set_snark_worker_graphql () =
      let input = Some new_snark_pub_key in
      let set_snark_worker_obj =
        Graphql.Set_snark_worker.(make @@ makeVariables ~input ())
      in
      exec_graphql_request ~logger ~node:t
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
          last |> Scalars.PublicKey.serialize |> Yojson.Basic.to_string
    in
    [%log info] "snark worker changed, lastSnarkWorker: %s" last_snark_worker
      ~metadata:[ ("lastSnarkWorker", `String last_snark_worker) ] ;
    ()

  let must_set_snark_worker ~logger t ~new_snark_pub_key =
    set_snark_worker ~logger t ~new_snark_pub_key
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let start_filtered_log ~logger ~log_filter t =
    let open Deferred.Let_syntax in
    let query_obj =
      Graphql.StartFilteredLog.(make @@ makeVariables ~filter:log_filter ())
    in
    let%bind res =
      exec_graphql_request ~logger:(Logger.null ()) ~retry_delay_sec:10.0
        ~node:t ~query_name:"StartFilteredLog" query_obj
    in
    match res with
    | Ok query_result_obj ->
        if query_result_obj.startFilteredLog then (
          [%log trace] "%s's log filter started" @@ id t ;
          return (Ok ()) )
        else (
          [%log error]
            "Attempted to start structured log collection on $node, but it had \
             already started"
            ~metadata:[ ("node", `String t.node_id) ] ;
          return (Ok ()) )
    | Error e ->
        [%log error] "Error encountered while starting $node's log filter: $err"
          ~metadata:
            [ ("node", `String (id t))
            ; ("err", `String (Error.to_string_hum e))
            ] ;
        return (Error e)

  let get_filtered_log_entries ~last_log_index_seen t =
    let open Deferred.Or_error.Let_syntax in
    let query_obj =
      Graphql.GetFilteredLogEntries.(
        make @@ makeVariables ~offset:last_log_index_seen ())
    in
    let%bind query_result_obj =
      exec_graphql_request ~logger:(Logger.null ()) ~retry_delay_sec:10.0
        ~node:t ~query_name:"GetFilteredLogEntries" query_obj
    in
    let log_entries = query_result_obj.getFilteredLogEntries in
    if log_entries.isCapturing then return log_entries.logMessages
    else
      Deferred.Or_error.error_string
        "Node is not currently capturing structured log messages"

  let get_metrics ~logger t =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Getting node's metrics" ~metadata:(logger_metadata t) ;
    let query_obj = Graphql.Query_metrics.make () in
    let%bind query_result_obj =
      exec_graphql_request ~logger ~node:t ~query_name:"query_metrics" query_obj
    in
    [%log info] "get_metrics, finished exec_graphql_request" ;
    let block_production_delay =
      Array.to_list
      @@ query_result_obj.daemonStatus.metrics.blockProductionDelay
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
      ( String.concat ~sep:", "
      @@ List.map ~f:string_of_int block_production_delay )
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

  let dump_archive_data ~logger (t : t) ~data_file =
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    if Node_type.(equal t.node_type Archive_node) then
      try
        let%bind dump =
          match%map
            Config_file.run_command ~config:!config_path ~args
              "dump_archive_data"
          with
          | Ok output ->
              Yojson.Safe.from_string output
              |> Archive_data_dump.of_yojson |> Result.ok_or_failwith
          | Error err ->
              raise @@ Archive_data_dump.Invalid_response err
        in
        [%log info] "Dumping archive data to file %s" data_file ;
        Malleable_error.return
        @@ Out_channel.with_file data_file ~f:(fun out_ch ->
               Out_channel.output_string out_ch dump.data )
      with Failure err -> Malleable_error.hard_error_string err
    else
      let node_type = Node_type.to_string t.node_type in
      [%log error] "Node $node_id cannot dump archive data as a $node_type"
        ~metadata:(("node_type", `String node_type) :: args) ;
      Malleable_error.hard_error_string
      @@ sprintf "Node %s of type %s cannot dump archive data" t.node_id
           node_type

  let run_replayer ~logger (t : t) =
    [%log info] "Running replayer on archived data node: %s" t.node_id ;
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    try
      let%bind replay =
        match%map
          Config_file.run_command ~config:!config_path ~args "run_replayer"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Replayer_run.of_yojson |> Result.ok_or_failwith
        | Error err ->
            raise @@ Replayer_run.Invalid_response err
      in
      Malleable_error.return replay.logs
    with Failure err -> Malleable_error.hard_error_string err

  let dump_mina_logs ~logger (t : t) ~log_file =
    [%log info] "Dumping logs from node: %s" t.node_id ;
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    try
      let%bind dump =
        match%map
          Config_file.run_command ~config:!config_path ~args "dump_mina_logs"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Mina_logs_dump.of_yojson |> Result.ok_or_failwith
        | Error err ->
            raise @@ Mina_logs_dump.Invalid_response err
      in
      [%log info] "Dumping logs to file %s" log_file ;
      Malleable_error.return
      @@ Out_channel.with_file log_file ~f:(fun out_ch ->
             Out_channel.output_string out_ch dump.logs )
    with Failure err -> Malleable_error.hard_error_string err

  let dump_precomputed_blocks ~logger (t : t) =
    [%log info] "Dumping precomputed blocks from logs for node: %s" t.node_id ;
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    try
      let%bind dump =
        match%map
          Config_file.run_command ~config:!config_path ~args
            "dump_precomputed_blocks"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Precomputed_block_dump.of_yojson |> Result.ok_or_failwith
        | Error err ->
            raise @@ Precomputed_block_dump.Invalid_response err
      in
      let log_lines =
        String.split dump.blocks ~on:'\n'
        |> List.filter ~f:(String.is_prefix ~prefix:"{\"timestamp\":")
      in
      let jsons = List.map log_lines ~f:Yojson.Safe.from_string in
      let metadata_jsons =
        List.map jsons ~f:(fun json ->
            match Yojson.Safe.Util.member "metadata" json with
            | `Null ->
                failwithf "Log line is missing metadata: %s"
                  (Yojson.Safe.to_string json)
                  ()
            | md ->
                md )
      in
      let state_hash_and_blocks =
        List.fold metadata_jsons ~init:[] ~f:(fun acc json ->
            match Yojson.Safe.Util.member "precomputed_block" json with
            | `Null ->
                acc
            | `Assoc _ as block -> (
                match Yojson.Safe.Util.member "state_hash" json with
                | `String _ as state_hash ->
                    (state_hash, block) :: acc
                | _ ->
                    failwith
                      "Log metadata contains a precomputed block, but no state \
                       hash" )
            | other ->
                failwithf "Expected log line to be a JSON record, got: %s"
                  (Yojson.Safe.to_string other)
                  () )
      in
      let open Deferred.Let_syntax in
      let%bind () =
        Deferred.List.iter state_hash_and_blocks
          ~f:(fun (state_hash_json, block_json) ->
            let double_quoted_state_hash =
              Yojson.Safe.to_string state_hash_json
            in
            let state_hash =
              String.sub double_quoted_state_hash ~pos:1
                ~len:(String.length double_quoted_state_hash - 2)
            in
            let block = Yojson.Safe.pretty_to_string block_json in
            let filename = state_hash ^ ".json" in
            match%map Sys.file_exists filename with
            | `Yes ->
                [%log info]
                  "File already exists for precomputed block with state hash %s"
                  state_hash
            | _ ->
                [%log info]
                  "Dumping precomputed block with state hash %s to file %s"
                  state_hash filename ;
                Out_channel.with_file filename ~f:(fun out_ch ->
                    Out_channel.output_string out_ch block ) )
      in
      Malleable_error.return ()
    with Failure err -> Malleable_error.hard_error_string err
end

type t =
  { constants : Test_config.constants
  ; testnet_log_filter : string
  ; genesis_keypairs : Network_keypair.t Core.String.Map.t
        (* below values are given by CI *)
  ; seeds : Node.t Core.String.Map.t
  ; block_producers : Node.t Core.String.Map.t
  ; snark_coordinators : Node.t Core.String.Map.t
  ; snark_workers : Node.t Core.String.Map.t
  ; archive_nodes : Node.t Core.String.Map.t
  ; network_id : Network_id.t
  }

let id { network_id; _ } = network_id

let constants { constants; _ } = constants

let constraint_constants { constants; _ } = constants.constraints

let genesis_constants { constants; _ } = constants.genesis

let seeds { seeds; _ } = seeds

let block_producers { block_producers; _ } = block_producers

let snark_coordinators { snark_coordinators; _ } = snark_coordinators

let snark_workers { snark_workers; _ } = snark_workers

let archive_nodes { archive_nodes; _ } = archive_nodes

(* all_nodes returns all *actual* mina nodes; note that a snark_worker is a pod within the network but not technically a mina node, therefore not included here.  snark coordinators on the other hand ARE mina nodes *)
let all_nodes { seeds; block_producers; snark_coordinators; archive_nodes; _ } =
  List.concat
    [ Core.String.Map.to_alist seeds
    ; Core.String.Map.to_alist block_producers
    ; Core.String.Map.to_alist snark_coordinators
    ; Core.String.Map.to_alist archive_nodes
    ]
  |> Core.String.Map.of_alist_exn

let all_pods t =
  List.concat
    [ Core.String.Map.to_alist t.seeds
    ; Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ; Core.String.Map.to_alist t.archive_nodes
    ]
  |> Core.String.Map.of_alist_exn

(* all_non_seed_pods returns everything in the network except seed nodes *)
let all_non_seed_pods t =
  List.concat
    [ Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ; Core.String.Map.to_alist t.archive_nodes
    ]
  |> Core.String.Map.of_alist_exn

let genesis_keypairs { genesis_keypairs; _ } = genesis_keypairs

let all_node_id t =
  let pods = all_pods t |> Core.Map.to_alist in
  List.fold pods ~init:[] ~f:(fun acc (_, node) -> node.node_id :: acc)

let[@warning "-27"] initialize_infra ~logger network = Malleable_error.return ()
