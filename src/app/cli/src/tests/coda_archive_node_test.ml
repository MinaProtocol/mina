open Core
open Async
open Mina_base

let name = "coda-archive-node-test"

let runtime_config = Runtime_config.Test_configs.split_snarkless

let main () =
  let logger = Logger.create () in
  let%bind precomputed_values, _runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
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
  let%bind pre_stored_transitions =
    Coda_worker_testnet.Api.get_all_transitions testnet 1
      (Account_id.create public_key Token_id.default)
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
  let pre_stored_state_hashes =
    State_hash.Hash_set.of_list
      (List.map (Option.value_exn pre_stored_transitions)
         ~f:(fun {With_hash.hash; _} -> hash))
  in
  let stored_state_hashes =
    State_hash.Hash_set.of_list
      (List.map (Option.value_exn stored_transitions)
         ~f:(fun {With_hash.hash; _} -> hash))
  in
  (* Ignore any state hashes from before we started observing blocks. *)
  let stored_state_hashes =
    Hash_set.diff stored_state_hashes pre_stored_state_hashes
  in
  let module M = struct
    type t = State_hash.Hash_set.t

    let sexp_of_t = State_hash.Hash_set.sexp_of_t

    let equal = Hash_set.equal

    (* Fake compare, we only want this so that [test_eq] will be happy and
       pretty-print the hashsets on failure.
    *)
    let compare x y = if equal x y then 0 else -1
  end in
  [%test_eq: M.t] observed_hashset stored_state_hashes ;
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async
    ~summary:
      "Test showing that an archive node stores all the transitions that it \
       has seen"
    (Command.Param.return main)
