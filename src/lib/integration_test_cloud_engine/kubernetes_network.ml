open Async
open Core

module Node = struct
  (* a pod name, e.g., test-block-producer-1 *)
  type t = string

  let to_string t = t

  let full_name_opt : string option ref = ref None

  let set_full_name name = full_name_opt := Some name

  let get_full_name () = !full_name_opt

  let set_name_from_network ~logger ~namespace ~node =
    let open Deferred.Let_syntax in
    let args =
      [ "get"
      ; "pods"
      ; "--namespace"
      ; namespace
      ; "-o"
      ; "custom-columns=NAME:.metadata.name"
      ; "--no-headers" ]
    in
    [%log info] "Running kubectl %s\n" String.(concat args ~sep:" ") ;
    match%bind Process.run_lines ~prog:"kubectl" ~args () with
    | Ok lines ->
        let prefix = to_string node in
        let re = Str.regexp " +" in
        let rec go lines =
          match lines with
          | line :: rest -> (
            match Str.split re line with
            | [name] ->
                if String.is_prefix name ~prefix then (
                  [%log info] "Found node $name in $namespace using $prefix"
                    ~metadata:
                      [ ("name", `String name)
                      ; ("namespace", `String namespace)
                      ; ("prefix", `String prefix) ] ;
                  set_full_name name ;
                  return (Ok ()) )
                else go rest
            | _ ->
                return (Error (Error.of_string "Expected node name")) )
          | [] ->
              return
                (Error (Error.of_string "Could not find desired node name"))
        in
        go lines
    | Error err ->
        return (Error err)

  (* run Coda CLI command *)
  let run_coda ~logger ~name ~namespace ~cmd ~subcmd ~flags =
    if Option.is_none !full_name_opt then
      failwith "run_coda: node name has not been set" ;
    let kubectl_args =
      ["exec"; name; "--namespace"; namespace; "-c"; "coda"; "--"]
    in
    let coda_args = ["coda"; cmd; subcmd] @ flags in
    let args = kubectl_args @ coda_args in
    [%log info] "Running kubectl %s\n" String.(concat args ~sep:" ") ;
    Process.run_lines_exn ~prog:"kubectl" ~args ()

  let start _ = failwith "TODO"

  let stop _ = failwith "TODO"

  module Decoders = Graphql_lib.Decoders

  module Graphql = struct
    let port = 3085

    (* queries on localhost because of port forwarding *)
    let uri =
      Uri.make
        ~host:Unix.Inet_addr.(localhost |> to_string)
        ~port:3085 ~path:"graphql" ()

    let set_port_forwarding ~logger ~name ~namespace =
      let args =
        ["port-forward"; name; "--namespace"; namespace; string_of_int port]
      in
      [%log info] "Running kubectl %s\n" String.(concat args ~sep:" ") ;
      let%bind.Deferred.Or_error.Let_syntax proc =
        Process.create ~prog:"kubectl" ~args ()
      in
      Exit_handlers.register_handler ~logger
        ~description:"Kubectl port forwarder" (fun () ->
          ignore Signal.(send kill (`Pid (Process.pid proc))) ) ;
      Process.collect_stdout_and_wait proc

    module Client = Graphql_lib.Client.Make (struct
      let preprocess_variables_string = Fn.id

      let headers = String.Map.empty
    end)

    module Unlock_account =
    [%graphql
    {|
          mutation ($password: String!,
          $public_key: PublicKey!) {
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
  end

  let send_payment ~logger ~namespace ~node ~sender ~receiver ~amount ~fee =
    [%log info] "Running send_payment test"
      ~metadata:[("namespace", `String namespace); ("node", `String node)] ;
    let open Deferred.Or_error.Let_syntax in
    let%bind () = set_name_from_network ~logger ~namespace ~node in
    let name = Option.value_exn (get_full_name ()) in
    Deferred.don't_wait_for
      ( match%map.Deferred.Let_syntax
          Graphql.set_port_forwarding ~logger ~name ~namespace
        with
      | Ok _ ->
          (* not reachable, port forwarder does not terminate *)
          ()
      | Error err ->
          [%log fatal] "Error running k8s port forwarding"
            ~metadata:[("error", `String (Error.to_string_hum err))] ;
          failwith "Could not run k8s port forwarding" ) ;
    let sender_pk_str = Signature_lib.Public_key.Compressed.to_string sender in
    [%log info] "send_payment: unlocking account"
      ~metadata:[("sender_pk", `String sender_pk_str)] ;
    let unlock_sender_account_graphql () =
      let num_tries = 10 in
      let initial_delay_sec = 30.0 in
      let retry_delay_sec = 30.0 in
      let unlock_account_obj =
        Graphql.Unlock_account.make ~password:"naughty blue worm"
          ~public_key:(Graphql_lib.Encoders.public_key sender)
          ()
      in
      (* GraphQL not immediately available, retry as needed *)
      let rec go n =
        if n <= 0 then (
          [%log fatal] "unlock_sender_account_graphql: too many tries" ;
          failwith "unlock_sender_account_graphql: too many tries" )
        else
          let open Deferred.Let_syntax in
          match%bind (Graphql.Client.query unlock_account_obj) Graphql.uri with
          | Ok _ ->
              [%log info] "unlock sender account succeeded" ;
              return (Ok ())
          | Error (`Failed_request err) ->
              [%log warn]
                "unlock_sender_account_graphql, Failed GraphQL request: %s, \
                 %d tries left"
                (to_string err) (n - 1) ;
              let%bind () = after (Time.Span.of_sec retry_delay_sec) in
              go (n - 1)
          | Error (`Graphql_error err) ->
              [%log error] "unlock_sender_account_graphql, GraphQL error: %s"
                (to_string err) ;
              return (Error (Error.of_string err))
      in
      let%bind.Deferred.Let_syntax () =
        after (Time.Span.of_sec initial_delay_sec)
      in
      go num_tries
    in
    let%bind () = unlock_sender_account_graphql () in
    let send_payment_graphql () =
      let num_tries = 10 in
      let initial_delay_sec = 30.0 in
      let retry_delay_sec = 30.0 in
      let send_payment_obj =
        Graphql.Send_payment.make
          ~sender:(Graphql_lib.Encoders.public_key sender)
          ~receiver:(Graphql_lib.Encoders.public_key receiver)
          ~amount:(Graphql_lib.Encoders.amount amount)
          ~fee:(Graphql_lib.Encoders.fee fee)
          ()
      in
      (* may have to retry if bootstrapping *)
      let open Deferred in
      let open Let_syntax in
      let rec go n =
        if n <= 0 then (
          [%log error] "send_payment_graphql: too many tries" ;
          return
            (Error (Error.of_string "send_payment_graphql: too many tries")) )
        else
          match%bind (Graphql.Client.query send_payment_obj) Graphql.uri with
          | Ok result ->
              [%log info] "send payment GraphQL succeeded" ;
              return (Ok result)
          | Error (`Failed_request err) ->
              [%log warn]
                "send_payment_graphql, Failed GraphQL request: %s, %d tries \
                 left"
                (to_string err) (n - 1) ;
              let%bind () = after (Time.Span.of_sec retry_delay_sec) in
              go (n - 1)
          | Error (`Graphql_error err) ->
              (* errors are not fatal here, like "still bootstrapping" *)
              [%log info]
                "send_payment_graphql, GraphQL error: %s, %d tries left"
                (to_string err) (n - 1) ;
              let%bind () = after (Time.Span.of_sec retry_delay_sec) in
              go (n - 1)
      in
      let%bind () = after (Time.Span.of_sec initial_delay_sec) in
      go num_tries
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
