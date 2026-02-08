open Core_kernel
open Mina_base
open Mina_stdlib
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
    ~(cmd_hash : Mina_transaction.Transaction_hash.t)
    (cmd_with_status : User_command.Verifiable.t With_status.t) =
  match transaction_pool_proxy.find_by_hash cmd_hash with
  | None ->
      `No_fast_forward
  | Some _ ->
      Verifier.Common.verify_command_from_mempool cmd_with_status

let check_commands ledger ~verifier
    ~(transaction_pool_proxy : transaction_pool_proxy)
    (cs : User_command.t With_status.t list)
    (hashes : Mina_transaction.Transaction_hash.t list) =
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
  let partitioner (cmd, cmd_hash) =
    let open Core_kernel.Either in
    match
      verify_command_with_transaction_pool_proxy ~transaction_pool_proxy
        ~cmd_hash cmd
    with
    | `No_fast_forward ->
        Second cmd
    | (`Valid _ | `Missing_verification_key _ | `Unexpected_verification_key _)
      as fast_forward ->
        First fast_forward
  in
  let%map xs =
    List.process_separately ~partitioner ~process_left:Fn.id
      ~process_right:(Verifier.verify_commands verifier)
      ~finalizer:(fun left right_m ~f ->
        let%map.Deferred.Or_error right = right_m in
        f left right )
      (List.zip_exn cs hashes)
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
