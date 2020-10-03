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
          mutation (
            $password: String!,
            $public_key: PublicKey!
          )
          {
            unlockAccount(
              input: {
                password: $password, 
                publicKey: $public_key 
              }
            )
            {
              public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
            }
          }
    |}]

    module Send_payment =
    [%graphql
    {|
        mutation (
          $sender: PublicKey!,
          $receiver: PublicKey!,
          $amount: UInt64!,
          $token: UInt64,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String
        )
        {
          sendPayment(
            input: {
              from: $sender, 
              to: $receiver, 
              amount: $amount, 
              token: $token, 
              fee: $fee, 
              nonce: $nonce, 
              memo: $memo
            }
          )
          {
            payment {
              id
            }
          }
        }
    |}]

    module Query_peer_id =
    [%graphql
    {|
        query
        {
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

  (* let get_peers_id ~logger (node : t) : unit Malleable_error.t =
    let graphql_port = 3085 in
    let open Malleable_error.Let_syntax in
    Deferred.don't_wait_for
      ( match%map.Deferred.Let_syntax
          Graphql.set_port_forwarding ~logger node graphql_port
        with
      | Ok _ ->
          (* not reachable, port forwarder does not terminate *)
          ()
      | Error {Malleable_error.Hard_fail.hard_error= err; soft_errors= _} ->
          [%log fatal] "Error running k8s port forwarding"
            ~metadata:[("error", `String (Error.to_string_hum err.error))] ;
          failwith "Could not run k8s port forwarding" ) ; *)

  let rec retry_graphql ~logger ~graphql_port ~retry_delay_sec
      ~gql_err_is_fatal ~graphql_object ~descr ~num_tries =
    let open Malleable_error.Let_syntax in
    if num_tries <= 0 then (
      [%log fatal] "%s: too many tries" descr ;
      failwith (sprintf "%s: too many tries" descr) )
    else
      (* let open Malleable_error.Let_syntax in *)
      match%bind
        Deferred.bind ~f:Malleable_error.return
          ((Graphql.Client.query graphql_object) (Graphql.uri graphql_port))
      with
      | Ok result ->
          [%log info] "%s succeeded" descr ;
          return result
      | Error (`Failed_request err_string) ->
          [%log warn] "%s, Failed GraphQL request: %s, %d tries left" descr
            err_string (num_tries - 1) ;
          let%bind () =
            Deferred.bind ~f:Malleable_error.return
              (after (Time.Span.of_sec retry_delay_sec))
          in
          retry_graphql ~logger ~graphql_port ~retry_delay_sec
            ~gql_err_is_fatal ~graphql_object ~descr ~num_tries:(num_tries - 1)
      | Error (`Graphql_error err_string) ->
          if gql_err_is_fatal then (
            [%log error] "%s, GraphQL error: %s" descr err_string ;
            Malleable_error.of_string_hard_error err_string )
          else (
            [%log warn] "%s, Failed GraphQL request: %s, %d tries left" descr
              err_string (num_tries - 1) ;
            let%bind () =
              Deferred.bind ~f:Malleable_error.return
                (after (Time.Span.of_sec retry_delay_sec))
            in
            retry_graphql ~logger ~graphql_port ~retry_delay_sec
              ~gql_err_is_fatal ~graphql_object ~descr
              ~num_tries:(num_tries - 1) )

  let send_payment ~logger t ~sender ~receiver ~amount ~fee =
    [%log info] "Running send_payment test"
      ~metadata:
        [("namespace", `String t.namespace); ("pod_id", `String t.pod_id)] ;
    let graphql_port = 3085 in
    let open Malleable_error.Let_syntax in
    Deferred.don't_wait_for
      ( match%map.Deferred.Let_syntax
          Graphql.set_port_forwarding ~logger t graphql_port
        with
      | Ok _ ->
          (* not reachable, port forwarder does not terminate *)
          ()
      | Error {Malleable_error.Hard_fail.hard_error= err; soft_errors= _} ->
          [%log fatal] "Error running k8s port forwarding"
            ~metadata:[("error", `String (Error.to_string_hum err.error))] ;
          failwith "Could not run k8s port forwarding" ) ;
    let sender_pk_str = Signature_lib.Public_key.Compressed.to_string sender in
    [%log info] "send_payment: unlocking account"
      ~metadata:[("sender_pk", `String sender_pk_str)] ;
    let unlock_sender_account_graphql () : unit Malleable_error.t =
      let unlock_account_obj =
        Graphql.Unlock_account.make ~password:"naughty blue worm"
          ~public_key:(Graphql_lib.Encoders.public_key sender)
          ()
      in
      let%bind () =
        (* initial delay *)
        Deferred.bind ~f:Malleable_error.return (after (Time.Span.of_sec 30.0))
      in
      (* GraphQL not immediately available, retry as needed *)
      let%bind _ =
        retry_graphql ~logger ~graphql_port ~retry_delay_sec:30.0
          ~gql_err_is_fatal:true ~graphql_object:unlock_account_obj
          ~descr:"unlock_sender_account_graphql" ~num_tries:10
      in
      return ()
    in
    let%bind () = unlock_sender_account_graphql () in
    let send_payment_graphql () =
      let initial_delay_sec = 30.0 in
      let send_payment_obj =
        Graphql.Send_payment.make
          ~sender:(Graphql_lib.Encoders.public_key sender)
          ~receiver:(Graphql_lib.Encoders.public_key receiver)
          ~amount:(Graphql_lib.Encoders.amount amount)
          ~fee:(Graphql_lib.Encoders.fee fee)
          ()
      in
      (* may have to retry if bootstrapping *)
      let%bind () =
        Deferred.bind ~f:Malleable_error.return
          (after (Time.Span.of_sec initial_delay_sec))
      in
      retry_graphql ~logger ~graphql_port ~retry_delay_sec:30.0
        ~gql_err_is_fatal:false ~graphql_object:send_payment_obj
        ~descr:"unlock_sender_account_graphql" ~num_tries:10
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
  ; testnet_log_filter: string }

let all_nodes {block_producers; snark_coordinators; archive_nodes; _} =
  block_producers @ snark_coordinators @ archive_nodes
