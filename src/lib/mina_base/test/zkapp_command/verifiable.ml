open Core_kernel
open Signature_lib

let call_forest_gen = Zkapp_command_test.Call_forest.gen

open Mina_base
open Zkapp_command
open Zkapp_command.Verifiable

let check_verifiable_property () =
  let processed_account_ids = ref Account_id.Map.empty in
  let find_vk_create vk_hash account_id =
    let () =
      processed_account_ids :=
        Account_id.Map.set !processed_account_ids ~key:account_id ~data:vk_hash
    in
    Ok { With_hash.data = Side_loaded_verification_key.dummy; hash = vk_hash }
  in
  let find_vk_check vk_hash account_id =
    match Account_id.Map.find !processed_account_ids account_id with
    | Some vk_hash' ->
        if Zkapp_basic.F.equal vk_hash' vk_hash then
          Ok
            { With_hash.data = Side_loaded_verification_key.dummy
            ; hash = vk_hash
            }
        else Error (Error.of_string "Verification key hash mismatch")
    | None ->
        Error (Error.of_string "Verification key not found")
  in
  let gen_authorization_kind account_id authorization =
    let open Quickcheck.Generator.Let_syntax in
    let vk_hash = Zkapp_basic.F.random () in
    match authorization with
    | Control.None_given ->
        Quickcheck.Generator.return Account_update.Authorization_kind.None_given
    | Proof p ->
        Quickcheck.Generator.return
          (Account_update.Authorization_kind.Proof vk_hash)
    | Signature _ ->
        Quickcheck.Generator.return Account_update.Authorization_kind.Signature
  in
  let gen_account_upd =
    let open Quickcheck.Generator.Let_syntax in
    let%bind body = Account_update.Body.gen
    and authorization = Control.gen_with_dummies in
    let account_upd = { Account_update.body; authorization } in
    let%map authorization_kind =
      gen_authorization_kind
        (Account_update.account_id account_upd)
        authorization
    in
    let body = { body with authorization_kind } in
    { account_upd with body }
  in
  let gen_cmd =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let gen_call_forest =
      fixed_point (fun self ->
          let%bind calls_length = small_non_negative_int in
          list_with_length calls_length
            (let%map account_update = gen_account_upd and calls = self in
             { With_stack_hash.stack_hash = ()
             ; elt =
                 { Call_forest.Tree.account_update
                 ; account_update_digest = ()
                 ; calls
                 }
             } ) )
    in
    let open Quickcheck.Let_syntax in
    let%map fee_payer = Account_update.Fee_payer.gen
    and account_updates = gen_call_forest
    and memo = Signed_command_memo.gen in
    { Zkapp_command.T.Stable.V1.Wire.fee_payer; account_updates; memo }
  in
  Quickcheck.test ~trials:100 gen_cmd ~f:(fun cmd ->
      let status = Transaction_status.Applied in
      let cmd = T.Stable.V1.of_wire cmd in
      match create cmd ~status ~find_vk:find_vk_create with
      | Ok verifiable_cmd ->
          let (_ : Verification_key_wire.t option Account_id.Map.t) =
            Call_forest.fold verifiable_cmd.account_updates
              ~init:Account_id.Map.empty ~f:(fun vks_overridden (p, vk) ->
                let account_id = Account_update.account_id p in
                let vks_overridden' =
                  match Account_update.verification_key_update_to_option p with
                  | Zkapp_basic.Set_or_keep.Keep ->
                      vks_overridden
                  | Zkapp_basic.Set_or_keep.Set vk_next ->
                      Account_id.Map.set vks_overridden ~key:account_id
                        ~data:vk_next
                in

                let () =
                  match (p.body.authorization_kind, vk) with
                  | Proof _, None | (Signature | None_given), Some _ ->
                      Alcotest.failf "Verification key update failed\n"
                  | (Signature | None_given), None ->
                      ()
                  | Proof vk_hash, Some vk' -> (
                      match Account_id.Map.find vks_overridden account_id with
                      | Some (Some vk_overridden) ->
                          if
                            Zkapp_basic.F.equal
                              (With_hash.hash vk_overridden)
                              vk_hash
                            && Zkapp_basic.F.equal (With_hash.hash vk') vk_hash
                          then ()
                          else Alcotest.failf "Verification key update failed\n"
                      | Some None ->
                          Alcotest.failf "Verification key update failed\n"
                      | None -> (
                          match find_vk_check vk_hash account_id with
                          | Ok ledger_vk ->
                              if
                                Zkapp_basic.F.equal (With_hash.hash vk') vk_hash
                              then ()
                              else
                                Alcotest.failf
                                  "Verification key update failed\n"
                          | Error _ ->
                              Alcotest.failf "Verification key update failed\n"
                          ) )
                in
                vks_overridden' )
          in
          ()
      | Error s ->
          Alcotest.failf "Create failed. %s\n" @@ Error.to_string_hum s )

let () =
  let open Alcotest in
  run "Zkapp command verifiable module" ~verbose:true
    [ ( "verifiable property"
      , [ test_case "check property after create" `Quick
            check_verifiable_property
        ] )
    ]
