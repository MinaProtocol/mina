open Core_kernel
open Mina_base
open Async
open Mina_transaction
module Ledger = Mina_ledger.Ledger

type transaction_pool_proxy =
  { find_by_hash :
         Mina_transaction.Transaction_hash.t
      -> Mina_transaction.Transaction_hash.User_command_with_valid_signature.t
         option
  }

let dummy_transaction_pool_proxy : transaction_pool_proxy =
  { find_by_hash = const None }

(* NOTE: when we have access to txn pool, any txns in pool should be already
   verified, hence we could utilize this fact to perform a faster version of
   command verification *)
let verify_command_with_transaction_pool_proxy
    ~(transaction_pool_proxy : transaction_pool_proxy)
    (cmd_with_status : User_command.Verifiable.t With_status.t) =
  let With_status.{ data = verifiable_cmd; _ } = cmd_with_status in
  let cmd_hash =
    User_command.of_verifiable verifiable_cmd |> Transaction_hash.hash_command
  in
  match transaction_pool_proxy.find_by_hash cmd_hash with
  | None ->
      `No_fast_forward
  | Some _ ->
      Verifier.Common.verify_command_from_mempool cmd_with_status

(** [process_separately] splits the list in two, and applies transformations
  * to both parts, then it merges the list back in the same order it was originally.
  * [process_left] and [process_right] are expected to return the same number
  * of elements processed in the same order.
  *)
let process_separately
    (type input left right left_output right_output output_item final_output)
    ~(partitioner : input -> (left, right) Either.t)
    ~(process_left : left list -> left_output)
    ~(process_right : right list -> right_output)
    ~(finalizer :
          left_output
       -> right_output
       -> f:(output_item list -> output_item list -> output_item list)
       -> final_output ) (input : input list) : final_output =
  let open Deferred.Or_error.Let_syntax in
  let input_with_indices = List.mapi input ~f:(fun idx el -> (idx, el)) in
  let lefts, rights =
    List.partition_map input_with_indices ~f:(fun (idx, el) ->
        match partitioner el with
        | First x ->
            First (idx, x)
        | Second y ->
            Second (idx, y) )
  in
  let batch_process_snd ~f = Fn.compose (Tuple2.map_snd ~f) List.unzip in
  let lefts_idx, lefts_processed = batch_process_snd ~f:process_left lefts in
  let rights_idx, rights_processed =
    batch_process_snd ~f:process_right rights
  in

  finalizer lefts_processed rights_processed
    ~f:(fun left_materialized right_materialized ->
      let left_materialized_indexed =
        List.zip_exn lefts_idx left_materialized
      in
      let right_materialized_indexed =
        List.zip_exn rights_idx right_materialized
      in
      List.merge left_materialized_indexed right_materialized_indexed
        ~compare:(fun (left_idx, _) (right_idx, _) ->
          compare left_idx right_idx )
      |> List.map ~f:snd )

let check_commands ledger ~verifier
    ~(transaction_pool_proxy : transaction_pool_proxy)
    (cs : User_command.t With_status.t list) =
  let open Deferred.Or_error.Let_syntax in
  let%bind cs =
    User_command.Applied_sequence.to_all_verifiable cs
      ~load_vk_cache:(fun account_ids ->
        let account_ids = Set.to_list account_ids in
        Zkapp_command.Verifiable.load_vks_from_ledger account_ids
          ~location_of_account_batch:(Ledger.location_of_account_batch ledger)
          ~get_batch:(Ledger.get_batch ledger) )
    |> Deferred.return
  in
  let partitioner cmd =
    let open Core_kernel.Either in
    match
      verify_command_with_transaction_pool_proxy ~transaction_pool_proxy cmd
    with
    | `No_fast_forward ->
        Second cmd
    | (`Valid _ | `Missing_verification_key _ | `Unexpected_verification_key _)
      as fast_forward ->
        First fast_forward
  in
  let%map xs =
    process_separately ~partitioner ~process_left:Fn.id
      ~process_right:(Verifier.verify_commands verifier)
      ~finalizer:(fun left right_m ~f ->
        let%map.Deferred.Or_error right = right_m in
        f left right )
      cs
  in
  Result.all
    (List.map xs ~f:(function
      | `Valid x ->
          Ok x
      | ( `Invalid_keys _
        | `Invalid_signature _
        | `Invalid_proof _
        | `Missing_verification_key _
        | `Unexpected_verification_key _
        | `Mismatched_authorization_kind _ ) as invalid ->
          Error
            (Verifier.Failure.Verification_failed
               (Error.tag ~tag:"verification failed on command"
                  (Verifier.invalid_to_error invalid) ) )
      | `Valid_assuming _ ->
          Error
            (Verifier.Failure.Verification_failed
               (Error.of_string "batch verification failed") ) ) )
