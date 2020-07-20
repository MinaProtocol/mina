open Core
open Async
open Coda_base

let name = "coda-archive-node-test"

let main () =
  let logger = Logger.create () in
  let precomputed_values = Lazy.force Precomputed_values.compiled in
  let public_key =
    Precomputed_values.largest_account_pk_exn precomputed_values
  in
  let n = 2 in
  let block_production_keys i = if i = 0 then Some i else None in
  let snark_work_public_keys i = if i = 0 then Some public_key else None in
  let is_archive_rocksdb i = i = 1 in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~is_archive_rocksdb ~precomputed_values
  in
  let%bind new_block_pipe =
    let%map pipe = Coda_worker_testnet.Api.new_block testnet 1 public_key in
    (Option.value_exn pipe).pipe
  in
  let num_blocks_to_wait = 5 in
  let%bind _, observed_hashes =
    Pipe.fold new_block_pipe ~init:(0, [])
      ~f:(fun (i, acc_hashes) With_hash.{hash; _} ->
        if i >= num_blocks_to_wait then Pipe.close_read new_block_pipe ;
        Deferred.return (i + 1, hash :: acc_hashes) )
  in
  let observed_hashset = State_hash.Hash_set.of_list observed_hashes in
  let%bind stored_transitions =
    Coda_worker_testnet.Api.get_all_transitions testnet 1
      (Account_id.create public_key Token_id.default)
  in
  let stored_state_hashes =
    State_hash.Hash_set.of_list
      (List.map (Option.value_exn stored_transitions)
         ~f:(fun {With_hash.hash; _} -> hash))
  in
  assert (Hash_set.equal observed_hashset stored_state_hashes) ;
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async
    ~summary:
      "Test showing that an archive node stores all the transitions that it \
       has seen"
    (Command.Param.return main)
