open Core
open Async
open Integration_test_lib

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Node = struct
  type t = {namespace: string; pod_id: string}

  let run_in_container node cmd =
    let kubectl_cmd =
      Printf.sprintf
        "kubectl -n %s -c coda exec -i $(kubectl get pod -n %s -l \"app=%s\" \
         -o name) -- %s"
        node.namespace node.namespace node.pod_id cmd
    in
    let%bind cwd = Unix.getcwd () in
    Cmd_util.run_cmd_exn cwd "sh" ["-c"; kubectl_cmd]

  let start ~fresh_state node : unit Malleable_error.t =
    let open Malleable_error.Let_syntax in
    let%bind () =
      if fresh_state then
        Deferred.bind ~f:Malleable_error.return
          (run_in_container node "rm -rf .coda-config")
      else Malleable_error.return ()
    in
    Deferred.bind ~f:Malleable_error.return
      (run_in_container node "./start.sh")

  let stop node =
    Deferred.bind ~f:Malleable_error.return (run_in_container node "./stop.sh")

  module Decoders = Graphql_lib.Decoders

  module Graphql = struct
    (* queries on localhost because of port forwarding *)
    let uri port =
      Uri.make
        ~host:Unix.Inet_addr.(localhost |> to_string)
        ~port ~path:"graphql" ()

    let get_pod_name t : string Malleable_error.t =
      let args =
        [ "get"
        ; "pod"
        ; "-n"
        ; t.namespace
        ; "-l"
        ; sprintf "app=%s" t.pod_id
        ; "-o=custom-columns=NAME:.metadata.name"
        ; "--no-headers" ]
      in
      let%bind run_result =
        Deferred.bind ~f:Malleable_error.of_or_error_hard
          (Process.run_lines ~prog:"kubectl" ~args ())
      in
      match run_result with
      | Ok
          { Malleable_error.Accumulator.computation_result= [pod_name]
          ; soft_errors= _ } ->
          Malleable_error.return pod_name
      | Ok {Malleable_error.Accumulator.computation_result= []; soft_errors= _}
        ->
          Malleable_error.of_string_hard_error "get_pod_name: no result"
      | Ok _ ->
          Malleable_error.of_string_hard_error "get_pod_name: too many results"
      | Error
          { Malleable_error.Hard_fail.hard_error= e
          ; Malleable_error.Hard_fail.soft_errors= _ } ->
          Malleable_error.of_error_hard e.error

    (* default port is 3085, may need to be explicit if multiple daemons are running *)
    let set_port_forwarding ~logger t port =
      let open Malleable_error.Let_syntax in
      let%bind name = get_pod_name t in
      let args =
        ["port-forward"; name; "--namespace"; t.namespace; string_of_int port]
      in
      [%log info] "Port forwarding using \"kubectl %s\"\n"
        String.(concat args ~sep:" ") ;
      let%bind.Malleable_error.Let_syntax proc =
        Deferred.bind ~f:Malleable_error.of_or_error_hard
          (Process.create ~prog:"kubectl" ~args ())
      in
      Exit_handlers.register_handler ~logger
        ~description:
          (sprintf "Kubectl port forwarder on pod %s, port %d" t.pod_id port)
        (fun () -> ignore Signal.(send kill (`Pid (Process.pid proc)))) ;
      Deferred.bind ~f:Malleable_error.of_or_error_hard
        (Process.collect_stdout_and_wait proc)

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
            }
          }
      }
    |}]

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
          peers
        }
      }
    |}]
  end

  let set_port_forwarding_exn ~logger t graphql_port =
    match%map.Deferred.Let_syntax
      Graphql.set_port_forwarding ~logger t graphql_port
    with
    | Ok _ ->
        (* not reachable, port forwarder does not terminate *)
        ()
    | Error {Malleable_error.Hard_fail.hard_error= err; soft_errors= _} ->
        [%log fatal] "Error running k8s port forwarding"
          ~metadata:[("error", `String (Error.to_string_hum err.error))] ;
        failwith "Could not run k8s port forwarding"

  (* this function will repeatedly attempt to connect to graphql port <num_tries> times before giving up *)
  let exec_graphql_reqest ?(num_tries = 10) ?(retry_delay_sec = 30.0)
      ?(initial_delay_sec = 30.0) ~logger ~graphql_port
      ?(retry_on_graphql_error = false) ~query_name query_obj =
    let open Malleable_error.Let_syntax in
    [%log info] "Will now attempt to make GraphQL request: %s" query_name ;
    let err_str str = sprintf "%s: %s" query_name str in
    let rec retry n =
      if n <= 0 then (
        let err_str = err_str "too many tries" in
        [%log fatal] "%s" err_str ;
        Malleable_error.of_string_hard_error err_str )
      else
        match%bind
          Deferred.bind ~f:Malleable_error.return
            ((Graphql.Client.query query_obj) (Graphql.uri graphql_port))
        with
        | Ok result ->
            let err_str = err_str "succeeded" in
            [%log info] "%s" err_str ;
            return result
        | Error (`Failed_request err_string) ->
            let err_str =
              err_str
                (sprintf "Failed GraphQL request: %s, %d tries left" err_string
                   (n - 1))
            in
            [%log warn] "%s" err_str ;
            let%bind () =
              Deferred.bind ~f:Malleable_error.return
                (after (Time.Span.of_sec retry_delay_sec))
            in
            retry (n - 1)
        | Error (`Graphql_error err_string) ->
            let err_str = err_str (sprintf "GraphQL error: %s" err_string) in
            [%log error] "%s" err_str ;
            if retry_on_graphql_error then (
              let%bind () =
                Deferred.bind ~f:Malleable_error.return
                  (after (Time.Span.of_sec retry_delay_sec))
              in
              [%log info] "%d tries left" (n - 1) ;
              retry (n - 1) )
            else Malleable_error.of_string_hard_error err_string
    in
    let%bind () =
      Deferred.bind ~f:Malleable_error.return
        (after (Time.Span.of_sec initial_delay_sec))
    in
    retry num_tries

  let get_peer_id ~logger t =
    let open Malleable_error.Let_syntax in
    [%log info] "Getting node's peer_id, and the peer_ids of node's peers"
      ~metadata:
        [("namespace", `String t.namespace); ("pod_id", `String t.pod_id)] ;
    let graphql_port = 3085 in
    Deferred.don't_wait_for (set_port_forwarding_exn ~logger t graphql_port) ;
    let query_obj = Graphql.Query_peer_id.make () in
    let%bind query_result_obj =
      exec_graphql_reqest ~logger ~graphql_port ~retry_on_graphql_error:true
        ~query_name:"query_peer_id" query_obj
    in
    let self_id_obj = ((query_result_obj#daemonStatus)#addrsAndPorts)#peer in
    let%bind self_id =
      match self_id_obj with
      | None ->
          Malleable_error.of_string_hard_error "Peer not found"
      | Some peer ->
          Malleable_error.return peer#peerId
    in
    let peers_ids = (query_result_obj#daemonStatus)#peers in
    return (self_id, Array.to_list peers_ids)

  let get_balance ~logger t ~account_id =
    let open Malleable_error.Let_syntax in
    [%log info] "Getting account balance"
      ~metadata:
        [ ("namespace", `String t.namespace)
        ; ("pod_id", `String t.pod_id)
        ; ("account_id", Coda_base.Account_id.to_yojson account_id) ] ;
    let graphql_port = 3085 in
    Deferred.don't_wait_for (set_port_forwarding_exn ~logger t graphql_port) ;
    let pk = Coda_base.Account_id.public_key account_id in
    let token = Coda_base.Account_id.token_id account_id in
    let get_balance () =
      let get_balance_obj =
        Graphql.Get_balance.make
          ~public_key:(Graphql_lib.Encoders.public_key pk)
          ~token:(Graphql_lib.Encoders.token token)
          ()
      in
      let%bind balance_obj =
        exec_graphql_reqest ~logger ~graphql_port ~retry_on_graphql_error:true
          ~query_name:"get_balance_graphql" get_balance_obj
      in
      match balance_obj#account with
      | None ->
          Malleable_error.of_string_hard_error
            (sprintf
               !"Account with %{sexp:Coda_base.Account_id.t} not found"
               account_id)
      | Some acc ->
          Malleable_error.return (acc#balance)#total
    in
    get_balance ()

  let send_payment ~logger t ~sender ~receiver ~amount ~fee =
    [%log info] "Sending a payment.."
      ~metadata:
        [("namespace", `String t.namespace); ("pod_id", `String t.pod_id)] ;
    let graphql_port = 3085 in
    let open Malleable_error.Let_syntax in
    Deferred.don't_wait_for (set_port_forwarding_exn ~logger t graphql_port) ;
    let sender_pk_str = Signature_lib.Public_key.Compressed.to_string sender in
    [%log info] "send_payment: unlocking account"
      ~metadata:[("sender_pk", `String sender_pk_str)] ;
    let unlock_sender_account_graphql () =
      let unlock_account_obj =
        Graphql.Unlock_account.make ~password:"naughty blue worm"
          ~public_key:(Graphql_lib.Encoders.public_key sender)
          ()
      in
      exec_graphql_reqest ~logger ~graphql_port
        ~query_name:"unlock_sender_account_graphql" unlock_account_obj
    in
    let%bind _ = unlock_sender_account_graphql () in
    let send_payment_graphql () =
      let send_payment_obj =
        Graphql.Send_payment.make
          ~sender:(Graphql_lib.Encoders.public_key sender)
          ~receiver:(Graphql_lib.Encoders.public_key receiver)
          ~amount:(Graphql_lib.Encoders.amount amount)
          ~fee:(Graphql_lib.Encoders.fee fee)
          ()
      in
      (* retry_on_graphql_error=true because the node might be bootstrapping *)
      exec_graphql_reqest ~logger ~graphql_port ~retry_on_graphql_error:true
        ~query_name:"send_payment_graphql" send_payment_obj
    in
    let%map sent_payment_obj = send_payment_graphql () in
    let (`UserCommand id_obj) = (sent_payment_obj#sendPayment)#payment in
    let user_cmd_id = id_obj#id in
    [%log info] "Sent payment"
      ~metadata:[("user_command_id", `String user_cmd_id)] ;
    ()
end

type t =
  { namespace: string
  ; constraint_constants: Genesis_constants.Constraint_constants.t
  ; genesis_constants: Genesis_constants.t
  ; block_producers: Node.t list
  ; snark_coordinators: Node.t list
  ; archive_nodes: Node.t list
  ; testnet_log_filter: string
  ; keypairs: Signature_lib.Keypair.t list }

let all_nodes {block_producers; snark_coordinators; archive_nodes; _} =
  block_producers @ snark_coordinators @ archive_nodes
