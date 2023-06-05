open Core
open Async
open Signature_lib
open Integration_test_lib
open Mina_base

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

let graphql_api ~logger ~graphql_target_node =
  let uri = ingress_uri ~graphql_target_node in
  Test_graphql.create ~logger ~uri ~logger_metadata:[] ~enabled:true

let get_account_data ~logger ~public_key ~graphql_target_node =
  let open Deferred.Or_error.Let_syntax in
  let graphql = graphql_api ~logger ~graphql_target_node in
  let%map account = Test_graphql.get_account_data_by_pk graphql ~public_key in
  account.nonce

let send_signed_transaction ~logger ~sender_priv_key ~nonce ~receiver_pub_key
    ~amount ~fee ~graphql_target_node =
  let open Deferred.Or_error.Let_syntax in
  let sender_pub_key =
    Public_key.of_private_key_exn sender_priv_key |> Public_key.compress
  in
  let receiver_pk = receiver_pub_key |> Public_key.compress in
  let graphql = graphql_api ~logger ~graphql_target_node in

  let payload =
    let common =
      { Signed_command_payload.Common.Poly.fee
      ; fee_payer_pk = sender_pub_key
      ; nonce
      ; valid_until = Mina_numbers.Global_slot.max_value
      ; memo = Signed_command_memo.empty
      }
    in
    let payment_payload = { Payment_payload.Poly.receiver_pk; amount } in
    let body = Signed_command_payload.Body.Payment payment_payload in
    { Signed_command_payload.Poly.common; body }
  in
  let raw_signature =
    Signed_command.sign_payload sender_priv_key payload |> Signature.Raw.encode
  in
  let%map res =
    Test_graphql.send_payment_with_raw_sig graphql ~sender_pub_key
      ~receiver_pub_key:receiver_pk ~amount ~fee ~nonce ~memo:""
      ~valid_until:Mina_numbers.Global_slot.max_value ~raw_signature
  in
  res.id
