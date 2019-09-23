open Core
open Async
open Coda_base
open Archive_lib
open Pipe_lib

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
  let t = {Processor.uri= Graphql_commands.graphql_uri 9000} in
  Thread_safe.block_on_async_exn
  @@ fun () ->
  let map = User_command.Map.of_alist_exn [(user_command, block_time)] in
  let reader, writer =
    Strict_pipe.create ~name:"archive"
      (Buffered (`Capacity 10, `Overflow Crash))
  in
  let deferred = Processor.run t reader in
  Strict_pipe.Writer.write writer
    (Transaction_pool
       {Diff.Transaction_pool.added= map; removed= User_command.Set.empty}) ;
  Strict_pipe.Writer.close writer ;
  deferred
