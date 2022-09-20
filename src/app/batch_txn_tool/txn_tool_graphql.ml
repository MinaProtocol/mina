open Core
open Async
open Signature_lib
module Serializing = Graphql_lib.Serializing

module Client = Graphql_lib.Client.Make (struct
  let preprocess_variables_string = Fn.id

  let headers = String.Map.empty
end)

let ingress_uri ~graphql_target_node =
  let target = Str.split (Str.regexp ":") graphql_target_node in
  let host =
    match List.nth target 0 with Some data -> data | None -> "127.0.0.1"
  in
  let port =
    match List.nth target 1 with
    | Some data ->
        int_of_string data
    | None ->
        3085
  in
  let path = "/graphql" in
  Uri.make ~scheme:"http" ~host ~path ~port ()

(* this function will repeatedly attempt to connect to graphql port <num_tries> times before giving up *)
(* copied from src/lib/integration_test_cloud_engine/kubernetes_network.ml and tweaked *)
let exec_graphql_request ?(num_tries = 10) ?(retry_delay_sec = 30.0)
    ?(initial_delay_sec = 30.0) ~graphql_target_node query_obj =
  let open Deferred.Let_syntax in
  let uri = ingress_uri ~graphql_target_node in
  let rec retry n =
    if n <= 0 then
      Deferred.Or_error.errorf "GraphQL request to %s failed too many times"
        graphql_target_node
    else
      match%bind Client.query query_obj uri with
      | Ok result ->
          Deferred.Or_error.return result
      | Error (`Failed_request _) ->
          let%bind () = after (Time.Span.of_sec retry_delay_sec) in
          retry (n - 1)
      | Error (`Graphql_error err_string) ->
          Deferred.Or_error.error_string err_string
  in
  let%bind () = after (Time.Span.of_sec initial_delay_sec) in
  retry num_tries

(* copied from src/app/cli/src/init/graphql_queries.ml and tweaked*)
module Send_payment =
[%graphql
{|
mutation ($sender: PublicKey!,
          $receiver: PublicKey!,
          $amount: UInt64!,
          $token: UInt64,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String,
          $field: String,
          $scalar: String) {
  sendPayment(input:
    {from: $sender, to: $receiver, amount: $amount, token: $token, fee: $fee, nonce: $nonce, memo: $memo},
    signature: {field: $field, scalar: $scalar}) {
    payment {
      id
    }
  }
}
|}]

module Get_account_data =
[%graphql
{|
query ($public_key: PublicKey!) {
  account(publicKey: $public_key) {
    nonce
    balance {
      total
      liquid
      locked
    }
  }
}
|}]

let get_account_data ~public_key ~graphql_target_node =
  let open Deferred.Or_error.Let_syntax in
  let pk = public_key |> Public_key.compress in
  let get_acct_data_obj =
    Get_account_data.(
      make @@ makeVariables ~public_key:(Graphql_lib.Encoders.public_key pk) ())
  in
  let%bind balance_obj =
    exec_graphql_request ~graphql_target_node get_acct_data_obj
  in
  match balance_obj.account with
  | None ->
      Deferred.Or_error.errorf "Account with %s not found"
        (Public_key.Compressed.to_string pk)
  | Some acc -> (
      match acc.nonce with
      | Some s ->
          return s
      | None ->
          Deferred.Or_error.errorf "Account with %s somehow doesnt have a nonce"
            (Public_key.Compressed.to_string pk) )

let send_signed_transaction ~sender_priv_key ~nonce ~receiver_pub_key ~amount
    ~fee ~graphql_target_node =
  let open Deferred.Or_error.Let_syntax in
  let sender_pub_key =
    Public_key.of_private_key_exn sender_priv_key |> Public_key.compress
  in
  let receiver_pk = receiver_pub_key |> Public_key.compress in

  let field, scalar =
    Mina_base.Signed_command.sign_payload sender_priv_key
      { common =
          { fee
          ; fee_payer_pk = sender_pub_key
          ; nonce
          ; valid_until = Mina_numbers.Global_slot.max_value
          ; memo = Mina_base.Signed_command_memo.empty
          }
      ; body = Payment { source_pk = sender_pub_key; receiver_pk; amount }
      }
  in
  let graphql_query =
    Send_payment.(
      make
      @@ makeVariables
           ~receiver:(Graphql_lib.Encoders.public_key receiver_pk)
           ~sender:(Graphql_lib.Encoders.public_key sender_pub_key)
           ~amount:(Graphql_lib.Encoders.amount amount)
           ~fee:(Graphql_lib.Encoders.fee fee)
           ~nonce:(Graphql_lib.Encoders.nonce nonce)
           ~field:(Snark_params.Tick.Field.to_string field)
           ~scalar:(Snark_params.Tick.Inner_curve.Scalar.to_string scalar)
           ())
  in
  let%map res = exec_graphql_request ~graphql_target_node graphql_query in
  res.sendPayment.payment.id
