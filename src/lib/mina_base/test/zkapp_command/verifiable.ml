open Core_kernel
open Signature_lib

let call_forest_gen = Call_forest.gen

open Mina_base
open Zkapp_command
open Zkapp_command.Verifiable

let%test_unit "check verifiable property" =
  let find_vk _ _ = Or_error.error "" () Unit.sexp_of_t in
  (* TODO: *)
  let transaction_status_gen =
    Quickcheck.Generator.of_list
      [ Transaction_status.Applied; Transaction_status.Failed [] ]
  in
  Quickcheck.test
    (Quickcheck.Generator.tuple2 T.Stable.V1.Wire.gen transaction_status_gen)
    ~f:(fun (cmd, status) ->
      let status = Transaction_status.Applied in
      let cmd = T.Stable.V1.of_wire cmd in
      match create cmd ~status ~find_vk with
      | Ok verifiable_cmd ->
          let _, check_result =
            Call_forest.fold verifiable_cmd.account_updates
              ~init:(Account_id.Map.empty, true)
              ~f:(fun (vks_overridden, acc) (p, vk) ->
                if not acc then (vks_overridden, false)
                else
                  let account_id = Account_update.account_id p in
                  let vks_overridden' =
                    match
                      Account_update.verification_key_update_to_option p
                    with
                    | Zkapp_basic.Set_or_keep.Keep ->
                        vks_overridden
                    | Zkapp_basic.Set_or_keep.Set vk_next ->
                        Account_id.Map.set vks_overridden ~key:account_id
                          ~data:vk_next
                  in
                  let acc' =
                    match (p.body.authorization_kind, vk) with
                    | Proof _, None | (Signature | None_given), Some _ ->
                        false
                    | (Signature | None_given), None ->
                        acc
                    | Proof vk_hash, Some vk' -> (
                        match Account_id.Map.find vks_overridden account_id with
                        | Some (Some vk_overridden) ->
                            Zkapp_basic.F.equal
                              (With_hash.hash vk_overridden)
                              vk_hash
                            && Zkapp_basic.F.equal (With_hash.hash vk') vk_hash
                        | Some None ->
                            false
                        | None -> (
                            match find_vk vk_hash account_id with
                            | Ok ledger_vk ->
                                Zkapp_basic.F.equal (With_hash.hash vk') vk_hash
                            | Error _ ->
                                false ) )
                  in
                  (vks_overridden', acc') )
          in
          if not check_result then failwith "Verification key update failed"
      | Error _ ->
          () )
