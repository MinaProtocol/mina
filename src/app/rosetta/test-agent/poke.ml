(** Poking the underlying Coda daemon in order to manipulate the sate of
 * the network *)

open Core_kernel
open Lib
open Async

module DisableStaking =
[%graphql
{|
    mutation disableStaking {
      setStaking(input: {publicKeys: []}) {
        lastStaking
      }
    }
  |}]

let disableStaking ~graphql_uri =
  let open Deferred.Result.Let_syntax in
  let%map res = Graphql.query (DisableStaking.make ()) graphql_uri in
  (res#setStaking)#lastStaking
