(* One call per endpoint against objects that every archive of the network
   has (see [Network.fixtures]). *)

open Core
open Async

let run ~rosetta ~network =
  let fixtures = Network.fixtures network in
  let arg : Endpoint.t -> string = function
    | Network_status | Network_options ->
        ""
    | Block ->
        fixtures.block
    | Account_balance ->
        fixtures.account
    | Payment_transaction ->
        fixtures.payment_transaction
    | Zkapp_transaction ->
        fixtures.zkapp_transaction
  in
  Deferred.Or_error.List.iter Endpoint.all ~f:(fun endpoint ->
      let arg = arg endpoint in
      let%map { result; _ } = Endpoint.call ~rosetta ~network endpoint ~arg in
      match result with
      | Ok () ->
          Proc.log "sanity %s %s: ok" (Endpoint.name endpoint) arg ;
          Ok ()
      | Error msg ->
          Or_error.errorf "sanity %s %s: %s" (Endpoint.name endpoint) arg msg )
