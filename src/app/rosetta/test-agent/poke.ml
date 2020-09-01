(** Poking the underlying Coda daemon in order to manipulate the sate of
 * the network *)

open Core_kernel
open Lib
open Async

(* TODO: Parameterize this against prod/test networks *)
let pk = "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g"

module Staking = struct
  module Disable =
  [%graphql
  {|
    mutation disableStaking {
      setStaking(input: {publicKeys: []}) {
        lastStaking
      }
    }
  |}]

  let disable ~graphql_uri =
    let open Deferred.Result.Let_syntax in
    let%map res = Graphql.query (Disable.make ()) graphql_uri in
    (res#setStaking)#lastStaking

  module Enable =
  [%graphql
  {|
  mutation enableStaking($publicKey: PublicKey!) {
      setStaking(input: {publicKeys: [$publicKey]}) {
        lastStaking
      }
    }
|}]

  let enable ~graphql_uri =
    let open Deferred.Result.Let_syntax in
    let%map res =
      Graphql.query (Enable.make ~publicKey:(`String pk) ()) graphql_uri
    in
    (res#setStaking)#lastStaking
end

module Account = struct
  module Unlock =
  [%graphql
  {|
      mutation ($password: String!, $public_key: PublicKey!) {
        unlockAccount(input: {password: $password, publicKey: $public_key }) {
          publicKey
        }
      }
    |}]

  let unlock ~graphql_uri =
    let open Deferred.Result.Let_syntax in
    let%map res =
      Graphql.query
        (Unlock.make ~password:"" ~public_key:(`String pk) ())
        graphql_uri
    in
    (res#unlockAccount)#publicKey
end

module SendTransaction = struct
  module Payment =
  [%graphql
  {|
      mutation sendPayment($fee: UInt64!, $amount: UInt64!, $token: TokenId, $to_: PublicKey!, $from: PublicKey!) {
        sendPayment(input: {fee: $fee, amount: $amount, token: $token, to: $to_, from: $from}, signature: null) {
          payment {
            hash
          }
        }
        }
    |}]

  let payment ~fee ~amount ?token ~to_ ~graphql_uri () =
    let open Deferred.Result.Let_syntax in
    let%map res =
      Graphql.query
        (Payment.make ~fee ~amount ?token ~to_ ~from:(`String pk) ())
        graphql_uri
    in
    let (`UserCommand x) = (res#sendPayment)#payment in
    x#hash

  (* Note: These operations below are intentionally constructed from a templated
   * string rather
   * than using a structured User_command_info to serve as living, tested,
   * documentation for a valid operation list for a payment *)

  let payment_operations ~from ~fee ~amount ~to_ =
    assert (String.equal from pk) ;
    let amount_str = Unsigned.UInt64.to_string amount in
    let operations =
      sprintf
        {| [{"operation_identifier":{"index":0},"related_operations":[],"type":"fee_payer_dec","status":"Pending","account":{"address":"%s","metadata":{"token_id":"1"}},"amount":{"value":"-%s","currency":{"symbol":"CODA","decimals":9}}},{"operation_identifier":{"index":1},"related_operations":[],"type":"payment_source_dec","status":"Pending","account":{"address":"%s","metadata":{"token_id":"1"}},"amount":{"value":"-%s","currency":{"symbol":"CODA","decimals":9}}},{"operation_identifier":{"index":2},"related_operations":[{"index":1}],"type":"payment_receiver_inc","status":"Pending","account":{"address":"%s","metadata":{"token_id":"1"}},"amount":{"value":"%s","currency":{"symbol":"CODA","decimals":9}}}] |}
        from
        (Unsigned.UInt64.to_string fee)
        from amount_str to_ amount_str
    in
    let json = Yojson.Safe.from_string operations in
    [%of_yojson: Rosetta_models.Operation.t list] json
    |> Result.ok |> Option.value_exn

  module Delegation =
  [%graphql
  {|

       mutation sendDelegation($fee : UInt64!, $to_: PublicKey!, $from: PublicKey!) {
         sendDelegation(input: {fee: $fee, to: $to_, from: $from}, signature: null) {
           delegation {
             hash
           }
         }
       }
    |}]

  let delegation ~fee ~to_ ~graphql_uri () =
    let open Deferred.Result.Let_syntax in
    let%map res =
      Graphql.query
        (Delegation.make ~fee ~to_ ~from:(`String pk) ())
        graphql_uri
    in
    let (`UserCommand cmd) = (res#sendDelegation)#delegation in
    cmd#hash

  let delegation_operations ~from ~fee ~to_ =
    assert (String.equal from pk) ;
    let operations =
      sprintf
        {| [{"operation_identifier":{"index":0},"related_operations":[],"type":"fee_payer_dec","status":"Pending","account":{"address":"%s","metadata":{"token_id":"1"}},"amount":{"value":"-%s","currency":{"symbol":"CODA","decimals":9}}},{"operation_identifier":{"index":1},"related_operations":[],"type":"delegate_change","status":"Pending","account":{"address":"%s","metadata":{"token_id":"1"}},"amount":null, "metadata": { "delegate_change_target": "%s"} }] |}
        from
        (Unsigned.UInt64.to_string fee)
        from to_
    in
    let json = Yojson.Safe.from_string operations in
    [%of_yojson: Rosetta_models.Operation.t list] json
    |> Result.ok |> Option.value_exn
end
