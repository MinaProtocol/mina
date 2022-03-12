open Core
open Async
open Integration_test_lib

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

let mina_archive_container_id = "archive"

let node_password = "naughty blue worm"

type config =
  { testnet_name : string
  ; cluster : string
  ; namespace : string
  ; graphql_enabled : bool
  }

let base_kube_args { cluster; namespace; _ } =
  [ "--cluster"; cluster; "--namespace"; namespace ]

module Node = struct
  type info =
    { network_keypair : Network_keypair.t option
    ; has_archive_container : bool
    ; primary_container_id : string
    }

  type t = { app_id : string; pod_id : string; info : info; config : config }

  let id { pod_id; _ } = pod_id

  let network_keypair { info = { network_keypair; _ }; _ } = network_keypair

  let base_kube_args t = [ "--cluster"; t.cluster; "--namespace"; t.namespace ]

  let get_logs_in_container ?container_id { pod_id; config; info; _ } =
    let container_id =
      Option.value container_id ~default:info.primary_container_id
    in
    let%bind cwd = Unix.getcwd () in
    Util.run_cmd_exn cwd "kubectl"
      (base_kube_args config @ [ "logs"; "-c"; container_id; pod_id ])

  let run_in_container ?container_id ~cmd { pod_id; config; info; _ } =
    let container_id =
      Option.value container_id ~default:info.primary_container_id
    in
    let%bind cwd = Unix.getcwd () in
    Util.run_cmd_exn cwd "kubectl"
      ( base_kube_args config
      @ [ "exec"; "-c"; container_id; "-i"; pod_id; "--" ]
      @ cmd )

  let start ~fresh_state node : unit Malleable_error.t =
    let open Deferred.Let_syntax in
    let%bind () =
      if fresh_state then
        Deferred.ignore_m
          (run_in_container node ~cmd:[ "sh"; "-c"; "rm -rf .mina-config/*" ])
      else Deferred.return ()
    in
    let%bind () =
      Deferred.ignore_m (run_in_container node ~cmd:[ "/start.sh" ])
    in
    Malleable_error.return ()

  let stop node =
    let open Deferred.Let_syntax in
    let%bind () =
      Deferred.ignore_m (run_in_container node ~cmd:[ "/stop.sh" ])
    in
    Malleable_error.return ()

  let logger_metadata node =
    [ ("namespace", `String node.config.namespace)
    ; ("app_id", `String node.app_id)
    ; ("pod_id", `String node.pod_id)
    ]

  module Decoders = Graphql_lib.Decoders

  module Graphql = struct
    let ingress_uri node =
      let host =
        Printf.sprintf "%s.graphql.test.o1test.net" node.config.testnet_name
      in
      let path = Printf.sprintf "/%s/graphql" node.app_id in
      Uri.make ~scheme:"http" ~host ~path ~port:80 ()

    module Client = Graphql_lib.Client.Make (struct
      let preprocess_variables_string = Fn.id

      let headers = String.Map.empty
    end)

    module Unlock_account =
    [%graphql
    {|
      mutation ($password: String!, $public_key: PublicKey!) {
        unlockAccount(input: {password: $password, publicKey: $public_key }) {
          public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
        }
      }
    |}]

    module Send_payment =
    [%graphql
    {|
      mutation ($sender: PublicKey!,
      $receiver: PublicKey!,
      $amount: UInt64!,
      $token: UInt64,
      $fee: UInt64!,
      $nonce: UInt32,
      $memo: String) {
        sendPayment(input:
          {from: $sender, to: $receiver, amount: $amount, token: $token, fee: $fee, nonce: $nonce, memo: $memo}) {
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
      mutation ($sender: PublicKey!,
      $receiver: PublicKey!,
      $amount: UInt64!,
      $token: UInt64,
      $fee: UInt64!,
      $nonce: UInt32,
      $memo: String) {
        sendDelegation(input:
          {from: $sender, to: $receiver, amount: $amount, token: $token, fee: $fee, nonce: $nonce, memo: $memo}) {
            delegation {
              id
              nonce
              hash
            }
          }
      }
    |}]

    (* TODO: temporary version *)
    module Send_test_snapp = Generated_graphql_queries.Send_test_snapp

    module Get_balance =
    [%graphql
    {|
      query ($public_key: PublicKey, $token: UInt64) {
        account(publicKey: $public_key, token: $token) {
          balance {
            total @bsDecoder(fn: "Decoders.balance")
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
      query {
        bestChain {
          stateHash
        }
      }
    |}]

    module Account =
    [%graphql
    {|
      query ($public_key: PublicKey, $token: UInt64) {
        account (publicKey : $public_key, token : $token) {
          balance { liquid
                    locked
                    total
                  }
          delegate
          nonce
          permissions { editSequenceState
                        editState
                        incrementNonce
                        receive
                        send
                        setDelegate
                        setPermissions
                        setSnappUri
                        setTokenSymbol
                        setVerificationKey
                        setVotingFor
                      }
          sequenceEvents
          snappState
          snappUri
          timing { cliffTime
                   cliffAmount
                   vestingPeriod
                   vestingIncrement
                   initialMinimumBalance
                 }
          token
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
      ?(initial_delay_sec = 30.0) ~logger ~node ~query_name query_obj =
    let open Deferred.Let_syntax in
    if not node.config.graphql_enabled then
      Deferred.Or_error.error_string
        "graphql is not enabled (hint: set `requires_graphql= true` in the \
         test config)"
    else
      let uri = Graphql.ingress_uri node in
      let metadata =
        [ ("query", `String query_name); ("uri", `String (Uri.to_string uri)) ]
      in
      [%log info] "Attempting to send GraphQL request \"$query\" to \"$uri\""
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
                  @ [ ("error", `String err_string)
                    ; ("num_tries", `Int (n - 1))
                    ] ) ;
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

  let get_peer_id ~logger t =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Getting node's peer_id, and the peer_ids of node's peers"
      ~metadata:(logger_metadata t) ;
    let query_obj = Graphql.Query_peer_id.make () in
    let%bind query_result_obj =
      exec_graphql_request ~logger ~node:t ~query_name:"query_peer_id" query_obj
    in
    [%log info] "get_peer_id, finished exec_graphql_request" ;
    let self_id_obj = query_result_obj#daemonStatus#addrsAndPorts#peer in
    let%bind self_id =
      match self_id_obj with
      | None ->
          Deferred.Or_error.error_string "Peer not found"
      | Some peer ->
          return peer#peerId
    in
    let peers = query_result_obj#daemonStatus#peers |> Array.to_list in
    let peer_ids = List.map peers ~f:(fun peer -> peer#peerId) in
    [%log info] "get_peer_id, result of graphql query (self_id,[peers]) (%s,%s)"
      self_id
      (String.concat ~sep:" " peer_ids) ;
    return (self_id, peer_ids)

  let must_get_peer_id ~logger t =
    get_peer_id ~logger t |> Deferred.bind ~f:Malleable_error.or_hard_error

  let get_best_chain ~logger t =
    let open Deferred.Or_error.Let_syntax in
    let query = Graphql.Best_chain.make () in
    let%bind result =
      exec_graphql_request ~logger ~node:t ~query_name:"best_chain" query
    in
    match result#bestChain with
    | None | Some [||] ->
        Deferred.Or_error.error_string "failed to get best chains"
    | Some chain ->
        return
        @@ List.map ~f:(fun block -> block#stateHash) (Array.to_list chain)

  let must_get_best_chain ~logger t =
    get_best_chain ~logger t |> Deferred.bind ~f:Malleable_error.or_hard_error

  let get_balance ~logger t ~account_id =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Getting account balance"
      ~metadata:
        ( ("account_id", Mina_base.Account_id.to_yojson account_id)
        :: logger_metadata t ) ;
    let pk = Mina_base.Account_id.public_key account_id in
    let token = Mina_base.Account_id.token_id account_id in
    let get_balance_obj =
      Graphql.Get_balance.make
        ~public_key:(Graphql_lib.Encoders.public_key pk)
        ~token:(Graphql_lib.Encoders.token token)
        ()
    in
    let%bind balance_obj =
      exec_graphql_request ~logger ~node:t ~query_name:"get_balance_graphql"
        get_balance_obj
    in
    match balance_obj#account with
    | None ->
        Deferred.Or_error.errorf
          !"Account with %{sexp:Mina_base.Account_id.t} not found"
          account_id
    | Some acc ->
        return acc#balance#total

  let must_get_balance ~logger t ~account_id =
    get_balance ~logger t ~account_id
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let get_account ~logger t ~account_id =
    [%log info] "Getting account"
      ~metadata:
        ( ("account_id", Mina_base.Account_id.to_yojson account_id)
        :: logger_metadata t ) ;
    let pk = Mina_base.Account_id.public_key account_id in
    let token = Mina_base.Account_id.token_id account_id in
    let get_account_obj =
      Graphql.Account.make
        ~public_key:(Graphql_lib.Encoders.public_key pk)
        ~token:(Graphql_lib.Encoders.token token)
        ()
    in
    exec_graphql_request ~logger ~node:t ~query_name:"get_account_graphql"
      get_account_obj

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
    { edit_sequence_state =
        to_auth_required account_permissions#editSequenceState
    ; edit_state = to_auth_required account_permissions#editState
    ; increment_nonce = to_auth_required account_permissions#incrementNonce
    ; receive = to_auth_required account_permissions#receive
    ; send = to_auth_required account_permissions#send
    ; set_delegate = to_auth_required account_permissions#setDelegate
    ; set_permissions = to_auth_required account_permissions#setPermissions
    ; set_snapp_uri = to_auth_required account_permissions#setSnappUri
    ; set_token_symbol = to_auth_required account_permissions#setTokenSymbol
    ; set_verification_key =
        to_auth_required account_permissions#setVerificationKey
    ; set_voting_for = to_auth_required account_permissions#setVotingFor
    }

  let get_account_permissions ~logger t ~account_id =
    let open Deferred.Or_error in
    let open Let_syntax in
    let%bind account_obj = get_account ~logger t ~account_id in
    match account_obj#account with
    | Some account -> (
        match account#permissions with
        | Some ledger_permissions ->
            return @@ permissions_of_account_permissions ledger_permissions
        | None ->
            fail
              (Error.of_string "Could not get permissions from ledger account")
        )
    | None ->
        fail (Error.of_string "Could not get account from ledger")

  (* return a Party.Update.t with all fields `Set` to the
     value in the account, or `Keep` if value unavailable,
     as if this update had been applied to the account
  *)
  let get_account_update ~logger t ~account_id =
    let open Deferred.Or_error in
    let open Let_syntax in
    let%bind account_obj = get_account ~logger t ~account_id in
    match account_obj#account with
    | Some account ->
        let open Mina_base.Snapp_basic.Set_or_keep in
        let%bind app_state =
          match account#snappState with
          | Some strs ->
              let fields =
                Array.to_list strs
                |> Base.List.map ~f:(fun s ->
                       Set (Pickles.Backend.Tick.Field.of_string s))
              in
              return (Mina_base.Snapp_state.V.of_list_exn fields)
          | None ->
              fail
                (Error.of_string
                   (sprintf
                      "Expected snapp account with an app state for public key \
                       %s"
                      (Signature_lib.Public_key.Compressed.to_base58_check
                         (Mina_base.Account_id.public_key account_id))))
        in
        let%bind delegate =
          match account#delegate with
          | Some (`String s) ->
              return
                (Set (Signature_lib.Public_key.Compressed.of_base58_check_exn s))
          | Some json ->
              fail
                (Error.of_string
                   (sprintf "Expected string encoding of delegate, got %s"
                      (Yojson.Basic.to_string json)))
          | None ->
              fail (Error.of_string "Expected delegate in account")
        in
        let%bind verification_key =
          match account#verificationKey with
          | Some vk_obj ->
              let data =
                Pickles.Side_loaded.Verification_key.of_base58_check_exn
                  vk_obj#verificationKey
              in
              let hash = Pickles.Backend.Tick.Field.of_string vk_obj#hash in
              return (Set ({ data; hash } : _ With_hash.t))
          | None ->
              fail
                (Error.of_string
                   (sprintf
                      "Expected snapp account with a verification key for \
                       public_key %s"
                      (Signature_lib.Public_key.Compressed.to_base58_check
                         (Mina_base.Account_id.public_key account_id))))
        in
        let%bind permissions =
          match account#permissions with
          | Some perms ->
              return @@ Set (permissions_of_account_permissions perms)
          | None ->
              fail (Error.of_string "Expected permissions in account")
        in
        let%bind snapp_uri =
          match account#snappUri with
          | Some s ->
              return @@ Set s
          | None ->
              fail (Error.of_string "Expected snapp URI in account")
        in
        let%bind token_symbol =
          match account#tokenSymbol with
          | Some s ->
              return @@ Set s
          | None ->
              fail (Error.of_string "Expected token symbol in account")
        in
        let%bind timing =
          let timing = account#timing in
          let cliff_amount = timing#cliffAmount in
          let cliff_time = timing#cliffTime in
          let vesting_period = timing#vestingPeriod in
          let vesting_increment = timing#vestingIncrement in
          let initial_minimum_balance = timing#initialMinimumBalance in
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
              let%bind cliff_amount =
                match amt with
                | `String s ->
                    return @@ Currency.Amount.of_string s
                | _ ->
                    fail
                      (Error.of_string
                         "Expected string for cliff amount in account timing")
              in
              let%bind cliff_time =
                match tm with
                | `String s ->
                    return @@ Mina_numbers.Global_slot.of_string s
                | _ ->
                    fail
                      (Error.of_string
                         "Expected string for cliff time in account timing")
              in
              let%bind vesting_period =
                match period with
                | `String s ->
                    return @@ Mina_numbers.Global_slot.of_string s
                | _ ->
                    fail
                      (Error.of_string
                         "Expected string for vesting period in account timing")
              in
              let%bind vesting_increment =
                match incr with
                | `String s ->
                    return @@ Currency.Amount.of_string s
                | _ ->
                    fail
                      (Error.of_string
                         "Expected string for vesting increment in account \
                          timing")
              in
              let%bind initial_minimum_balance =
                match bal with
                | `String s ->
                    return @@ Currency.Balance.of_string s
                | _ ->
                    fail
                      (Error.of_string
                         "Expected string for vesting increment in account \
                          timing")
              in
              return
                (Set
                   ( { initial_minimum_balance
                     ; cliff_amount
                     ; cliff_time
                     ; vesting_period
                     ; vesting_increment
                     }
                     : Mina_base.Party.Update.Timing_info.t ))
          | _ ->
              fail (Error.of_string "Some pieces of account timing are missing")
        in
        let%bind voting_for =
          match account#votingFor with
          | Some s ->
              return @@ Set (Mina_base.State_hash.of_base58_check_exn s)
          | None ->
              fail (Error.of_string "Expected voting-for state hash in account")
        in
        return
          ( { app_state
            ; delegate
            ; verification_key
            ; permissions
            ; snapp_uri
            ; token_symbol
            ; timing
            ; voting_for
            }
            : Mina_base.Party.Update.t )
    | None ->
        fail (Error.of_string "Could not get account from ledger")

  type signed_command_result =
    { id : string; hash : string; nonce : Mina_numbers.Account_nonce.t }

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
        Graphql.Unlock_account.make ~password:node_password
          ~public_key:(Graphql_lib.Encoders.public_key sender_pub_key)
          ()
      in
      exec_graphql_request ~logger ~node:t
        ~query_name:"unlock_sender_account_graphql" unlock_account_obj
    in
    let%bind _unlock_acct_obj = unlock_sender_account_graphql () in
    let send_payment_graphql () =
      let send_payment_obj =
        Graphql.Send_payment.make
          ~sender:(Graphql_lib.Encoders.public_key sender_pub_key)
          ~receiver:(Graphql_lib.Encoders.public_key receiver_pub_key)
          ~amount:(Graphql_lib.Encoders.amount amount)
          ~fee:(Graphql_lib.Encoders.fee fee)
          ()
      in
      exec_graphql_request ~logger ~node:t ~query_name:"send_payment_graphql"
        send_payment_obj
    in
    let%map sent_payment_obj = send_payment_graphql () in
    let (`UserCommand return_obj) = sent_payment_obj#sendPayment#payment in
    let res =
      { id = return_obj#id
      ; hash = return_obj#hash
      ; nonce = Mina_numbers.Account_nonce.of_int return_obj#nonce
      }
    in
    [%log info] "Sent payment"
      ~metadata:
        [ ("user_command_id", `String res.id)
        ; ("hash", `String res.hash)
        ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
        ] ;
    res

  let must_send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
      =
    send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let send_snapp ~logger (t : t) ~(parties : Mina_base.Parties.t) =
    [%log info] "Sending a snapp"
      ~metadata:
        [ ("namespace", `String t.config.namespace)
        ; ("pod_id", `String (id t))
        ] ;
    let open Deferred.Or_error.Let_syntax in
    let fee_payer_pk = parties.fee_payer.data.body.public_key in
    let fee_payer_pk_str =
      fee_payer_pk |> Signature_lib.Public_key.Compressed.to_base58_check
    in
    [%log info] "send_snapp: unlocking fee payer account"
      ~metadata:[ ("fee_payer_pk", `String fee_payer_pk_str) ] ;
    let unlock_sender_account_graphql () =
      let unlock_account_obj =
        Graphql.Unlock_account.make ~password:node_password
          ~public_key:(Graphql_lib.Encoders.public_key fee_payer_pk)
          ()
      in
      exec_graphql_request ~logger ~node:t
        ~query_name:"unlock_fee_payer_account_graphql" unlock_account_obj
    in
    let%bind _unlock_acct_obj = unlock_sender_account_graphql () in
    let parties_json =
      Mina_base.Parties.to_json parties |> Yojson.Safe.to_basic
    in
    let send_snapp_graphql () =
      let send_snapp_obj =
        Graphql.Send_test_snapp.make ~parties:parties_json ()
      in
      exec_graphql_request ~logger ~node:t ~query_name:"send_snapp_graphql"
        send_snapp_obj
    in
    let%bind sent_snapp_obj = send_snapp_graphql () in
    let%bind () =
      match sent_snapp_obj#internalSendSnapp#snapp#failureReason with
      | None ->
          return ()
      | Some s ->
          Deferred.Or_error.errorf "Snapp failed, reason: %s" s
    in
    let snapp_id = sent_snapp_obj#internalSendSnapp#snapp#id in
    [%log info] "Sent snapp" ~metadata:[ ("snapp_id", `String snapp_id) ] ;
    return snapp_id

  let send_delegation ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee =
    [%log info] "Sending stake delegation" ~metadata:(logger_metadata t) ;
    let open Deferred.Or_error.Let_syntax in
    let sender_pk_str =
      Signature_lib.Public_key.Compressed.to_string sender_pub_key
    in
    [%log info] "send_delegation: unlocking account"
      ~metadata:[ ("sender_pk", `String sender_pk_str) ] ;
    let unlock_sender_account_graphql () =
      let unlock_account_obj =
        Graphql.Unlock_account.make ~password:"naughty blue worm"
          ~public_key:(Graphql_lib.Encoders.public_key sender_pub_key)
          ()
      in
      exec_graphql_request ~logger ~node:t
        ~query_name:"unlock_sender_account_graphql" unlock_account_obj
    in
    let%bind _ = unlock_sender_account_graphql () in
    let send_delegation_graphql () =
      let send_delegation_obj =
        Graphql.Send_delegation.make
          ~sender:(Graphql_lib.Encoders.public_key sender_pub_key)
          ~receiver:(Graphql_lib.Encoders.public_key receiver_pub_key)
          ~amount:(Graphql_lib.Encoders.amount amount)
          ~fee:(Graphql_lib.Encoders.fee fee)
          ()
      in
      exec_graphql_request ~logger ~node:t ~query_name:"send_delegation_graphql"
        send_delegation_obj
    in
    let%map result_obj = send_delegation_graphql () in
    let (`UserCommand return_obj) = result_obj#sendDelegation#delegation in
    let res =
      { id = return_obj#id
      ; hash = return_obj#hash
      ; nonce = Mina_numbers.Account_nonce.of_int return_obj#nonce
      }
    in
    [%log info] "stake delegation sent"
      ~metadata:
        [ ("user_command_id", `String res.id)
        ; ("hash", `String res.hash)
        ; ("nonce", `Int (Mina_numbers.Account_nonce.to_int res.nonce))
        ] ;
    res

  let must_send_delegation ~logger t ~sender_pub_key ~receiver_pub_key ~amount
      ~fee =
    send_delegation ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let dump_archive_data ~logger (t : t) ~data_file =
    (* this function won't work if t doesn't happen to be an archive node *)
    if not t.info.has_archive_container then
      failwith
        "No archive container found.  One can only dump archive data of an \
         archive node." ;
    let open Malleable_error.Let_syntax in
    [%log info] "Dumping archive data from (node: %s, container: %s)" t.pod_id
      mina_archive_container_id ;
    let%map data =
      Deferred.bind ~f:Malleable_error.return
        (run_in_container t ~container_id:mina_archive_container_id
           ~cmd:
             [ "pg_dump"
             ; "--create"
             ; "--no-owner"
             ; "postgres://postgres:foobar@archive-1-postgresql:5432/archive"
             ])
    in
    [%log info] "Dumping archive data to file %s" data_file ;
    Out_channel.with_file data_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch data)

  let dump_mina_logs ~logger (t : t) ~log_file =
    let open Malleable_error.Let_syntax in
    [%log info] "Dumping container logs from (node: %s, container: %s)" t.pod_id
      t.info.primary_container_id ;
    let%map logs =
      Deferred.bind ~f:Malleable_error.return (get_logs_in_container t)
    in
    [%log info] "Dumping container log to file %s" log_file ;
    Out_channel.with_file log_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch logs)

  let dump_precomputed_blocks ~logger (t : t) =
    let open Malleable_error.Let_syntax in
    [%log info]
      "Dumping precomputed blocks from logs for (node: %s, container: %s)"
      t.pod_id t.info.primary_container_id ;
    let%bind logs =
      Deferred.bind ~f:Malleable_error.return (get_logs_in_container t)
    in
    (* kubectl logs may include non-log output, like "Using password from environment variable" *)
    let log_lines =
      String.split logs ~on:'\n'
      |> List.filter ~f:(String.is_prefix ~prefix:"{\"timestamp\":")
    in
    let jsons = List.map log_lines ~f:Yojson.Safe.from_string in
    let metadata_jsons =
      List.map jsons ~f:(fun json ->
          match json with
          | `Assoc items -> (
              match List.Assoc.find items ~equal:String.equal "metadata" with
              | Some md ->
                  md
              | None ->
                  failwithf "Log line is missing metadata: %s"
                    (Yojson.Safe.to_string json)
                    () )
          | other ->
              failwithf "Expected log line to be a JSON record, got: %s"
                (Yojson.Safe.to_string other)
                ())
    in
    let state_hash_and_blocks =
      List.fold metadata_jsons ~init:[] ~f:(fun acc json ->
          match json with
          | `Assoc items -> (
              match
                List.Assoc.find items ~equal:String.equal "precomputed_block"
              with
              | Some block -> (
                  match
                    List.Assoc.find items ~equal:String.equal "state_hash"
                  with
                  | Some state_hash ->
                      (state_hash, block) :: acc
                  | None ->
                      failwith
                        "Log metadata contains a precomputed block, but no \
                         state hash" )
              | None ->
                  acc )
          | other ->
              failwithf "Expected log line to be a JSON record, got: %s"
                (Yojson.Safe.to_string other)
                ())
    in
    let%bind.Deferred () =
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
          match%map.Deferred Sys.file_exists filename with
          | `Yes ->
              [%log info]
                "File already exists for precomputed block with state hash %s"
                state_hash
          | _ ->
              [%log info]
                "Dumping precomputed block with state hash %s to file %s"
                state_hash filename ;
              Out_channel.with_file filename ~f:(fun out_ch ->
                  Out_channel.output_string out_ch block))
    in
    Malleable_error.return ()
end

module Workload = struct
  type t = { workload_id : string; node_info : Node.info list }

  let get_nodes t ~config =
    let%bind cwd = Unix.getcwd () in
    let%bind app_id =
      Util.run_cmd_exn cwd "kubectl"
        ( base_kube_args config
        @ [ "get"
          ; "deployment"
          ; t.workload_id
          ; "-o"
          ; "jsonpath={.spec.selector.matchLabels.app}"
          ] )
    in
    let%map pod_ids_str =
      Util.run_cmd_exn cwd "kubectl"
        ( base_kube_args config
        @ [ "get"; "pod"; "-l"; "app=" ^ app_id; "-o"; "name" ] )
    in
    let pod_ids =
      String.split pod_ids_str ~on:'\n'
      |> List.filter ~f:(Fn.compose not String.is_empty)
      |> List.map ~f:(String.substr_replace_first ~pattern:"pod/" ~with_:"")
    in
    if List.length t.node_info <> List.length pod_ids then
      failwithf
        "Unexpected number of replicas in kubernetes deployment for workload \
         %s: expected %d, got %d"
        t.workload_id (List.length t.node_info) (List.length pod_ids) () ;
    List.zip_exn t.node_info pod_ids
    |> List.map ~f:(fun (info, pod_id) -> { Node.app_id; pod_id; info; config })
end

type t =
  { namespace : string
  ; constants : Test_config.constants
  ; seeds : Node.t list
  ; block_producers : Node.t list
  ; snark_coordinators : Node.t list
  ; snark_workers : Node.t list
  ; archive_nodes : Node.t list
  ; testnet_log_filter : string
  ; keypairs : Signature_lib.Keypair.t list
  ; nodes_by_pod_id : Node.t String.Map.t
  }

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
  List.concat [ seeds; block_producers; snark_coordinators; archive_nodes ]

(* all_pods returns everything in the network.  remember that snark_workers will never initialize and will never sync, and aren't supposed to *)
let all_pods
    { seeds
    ; block_producers
    ; snark_coordinators
    ; snark_workers
    ; archive_nodes
    ; _
    } =
  List.concat
    [ seeds; block_producers; snark_coordinators; snark_workers; archive_nodes ]

(* all_non_seed_pods returns everything in the network except seed nodes *)
let all_non_seed_pods
    { block_producers; snark_coordinators; snark_workers; archive_nodes; _ } =
  List.concat
    [ block_producers; snark_coordinators; snark_workers; archive_nodes ]

let keypairs { keypairs; _ } = keypairs

let lookup_node_by_pod_id t = Map.find t.nodes_by_pod_id

let all_pod_ids t = Map.keys t.nodes_by_pod_id

let initialize ~logger network =
  let open Malleable_error.Let_syntax in
  let poll_interval = Time.Span.of_sec 15.0 in
  let max_polls = 60 (* 15 mins *) in
  let all_pods =
    all_nodes network
    |> List.map ~f:(fun { pod_id; _ } -> pod_id)
    |> String.Set.of_list
  in
  let kube_get_pods () =
    Util.run_cmd_or_error_timeout ~timeout_seconds:60 "/" "kubectl"
      [ "-n"
      ; network.namespace
      ; "get"
      ; "pods"
      ; "-ojsonpath={range \
         .items[*]}{.metadata.name}{':'}{.status.phase}{'\\n'}{end}"
      ]
  in
  let parse_pod_statuses result_str =
    result_str |> String.split_lines
    |> List.map ~f:(fun line ->
           let parts = String.split line ~on:':' in
           assert (List.length parts = 2) ;
           (List.nth_exn parts 0, List.nth_exn parts 1))
    |> List.filter ~f:(fun (pod_name, _) -> String.Set.mem all_pods pod_name)
    |> String.Map.of_alist_exn
  in
  let rec poll n =
    [%log debug] "Checking kubernetes pod statuses, n=%d" n ;
    let is_successful_pod_status = String.equal "Running" in
    let poll_again () =
      if n < max_polls then
        let%bind () =
          after poll_interval |> Deferred.bind ~f:Malleable_error.return
        in
        poll (n + 1)
      else (
        [%log fatal] "Not all pods were assigned to nodes and ready in time." ;
        Malleable_error.hard_error_string
          "Some pods either were not assigned to nodes or did not deploy \
           properly." )
    in
    match%bind Deferred.bind ~f:Malleable_error.return (kube_get_pods ()) with
    | Ok str ->
        let pod_statuses = parse_pod_statuses str in
        let all_pods_are_present =
          List.for_all (String.Set.elements all_pods) ~f:(fun pod_id ->
              String.Map.mem pod_statuses pod_id)
        in
        let any_pods_are_not_running =
          List.exists
            (String.Map.data pod_statuses)
            ~f:(Fn.compose not is_successful_pod_status)
        in
        if not all_pods_are_present then (
          [%log fatal]
            "Not all pods were found when querying namespace; this indicates a \
             deployment error. Refusing to continue. Expected pods: [%s]"
            (String.Set.elements all_pods |> String.concat ~sep:"; ") ;
          Malleable_error.hard_error_string
            "Some pods were not found in namespace." )
        else if any_pods_are_not_running then (
          let failed_pod_statuses =
            List.filter (String.Map.to_alist pod_statuses)
              ~f:(fun (_, status) -> not (is_successful_pod_status status))
          in
          [%log debug] "Got bad pod statuses, polling again ($failed_statuses"
            ~metadata:
              [ ( "failed_statuses"
                , `Assoc
                    (List.Assoc.map failed_pod_statuses ~f:(fun v -> `String v))
                )
              ] ;
          poll_again () )
        else return ()
    | Error _ ->
        [%log debug] "`kubectl get pods` timed out, polling again" ;
        poll_again ()
  in
  [%log info] "Waiting for pods to be assigned nodes and become ready" ;
  let res = poll 0 in
  match%bind.Deferred res with
  | Error _ ->
      [%log error]
        "Since not all pods were assigned nodes, daemons will not be started" ;
      res
  | Ok _ ->
      [%log info] "Starting the daemons within the pods" ;
      let start_print (node : Node.t) =
        let open Malleable_error.Let_syntax in
        [%log info] "starting %s ..." node.pod_id ;
        let%bind res = Node.start ~fresh_state:false node in
        [%log info] "%s started" node.pod_id ;
        Malleable_error.return res
      in
      let seed_nodes = network |> seeds in
      let non_seed_pods = network |> all_non_seed_pods in
      (* TODO: parallelize (requires accumlative hard errors) *)
      let%bind () = Malleable_error.List.iter seed_nodes ~f:start_print in
      (* put a short delay before starting other nodes, to help avoid artifact generation races *)
      let%bind () =
        after (Time.Span.of_sec 30.0) |> Deferred.bind ~f:Malleable_error.return
      in
      Malleable_error.List.iter non_seed_pods ~f:start_print
