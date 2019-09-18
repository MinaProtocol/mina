open Core
open Async
open Coda_base
open Archive_lib

let () =
  let keys = Array.init 2 ~f:(fun _ -> Signature_lib.Keypair.create ()) in
  let user_command =
    Quickcheck.random_value
      (User_command.Gen.payment_with_random_participants ~keys
         ~max_amount:10000 ~max_fee:1000 ())
  in
  let block_time =
    Block_time.of_span_since_epoch @@ Block_time.Span.of_ms (Int64.of_int 100)
  in
  let graphql_obj = Types.User_command.encode user_command block_time in
  let graphql =
    Graphql_commands.Transaction_pool_insert.make
      ~user_commands:[|graphql_obj|] ()
  in
  let graphql_port = 9000 in
  Async.Thread_safe.block_on_async_exn
  @@ fun () ->
  let%map _ =
    Graphql_client_lib.query graphql
      (Graphql_commands.graphql_uri graphql_port)
  in
  ()
