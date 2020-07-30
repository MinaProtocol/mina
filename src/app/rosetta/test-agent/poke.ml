(** Poking the underlying Coda daemon in order to manipulate the sate of
 * the network *)

open Core_kernel
open Lib
open Async

(* TODO: Parameterize this against prod/test networks *)
let pk =
  `String "ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8"

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
    let%map res = Graphql.query (Enable.make ~publicKey:pk ()) graphql_uri in
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
      Graphql.query (Unlock.make ~password:"" ~public_key:pk ()) graphql_uri
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
        (Payment.make ~fee ~amount ?token ~to_ ~from:pk ())
        graphql_uri
    in
    let (`UserCommand x) = (res#sendPayment)#payment in
    x#hash
end
