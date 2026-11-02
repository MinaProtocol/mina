open Core_kernel
open Mina_base
open Pickles

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "verification_key"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_verification_key
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update : Account_update.Update.t =
    let new_verification_key :
        (Side_loaded.Verification_key.t, Zkapp_basic.F.t) With_hash.t =
      let data = Pickles.Side_loaded.Verification_key.dummy in
      let hash = Zkapp_account.dummy_vk_hash () in
      ({ data; hash } : _ With_hash.t)
    in
    { Account_update.Update.dummy with
      verification_key = Zkapp_basic.Set_or_keep.Set new_verification_key
    }

  let is_non_zkapp_update = false
end

let suite () =
  Transaction_snark_test_suite.make ~name:"verification_key"
    ~proof_cache_json:Proof_cache_json.contents
  @@ fun ~test ->
  let module _ = struct
    include
      Transaction_snark_tests.Test_zkapp_update.Make
        (Test_input)
        (struct
          let test = test
        end)

    open Currency
    open Signature_lib
    module U = Transaction_snark_tests.Util
    module Spec = Transaction_snark.For_tests.Update_states_spec
    open Test_input

    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let mk_update_perm_check ~current_auth ~account_perm ?vk_txn_version
        ?failure_expected () =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Amount.of_mina_int_exn 10 in
          let spec = List.hd_exn specs in
          let test_spec : Spec.t =
            { sender = spec.sender
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          U.test_snapp_update ?expected_failure:failure_expected
            ~snapp_permissions:
              (U.permissions_from_update snapp_update ~auth:account_perm)
            ?vk_txn_version test_spec ~init_ledger ~vk ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let older_version =
      let oldest = Mina_numbers.Txn_version.of_int 1 in
      if Mina_numbers.Txn_version.equal_to_current oldest then
        failwith "already oldest version"
      else oldest

    let () =
      test "account update using Signature auth when perm is set to Proof"
      @@ fun () ->
      mk_update_perm_check ~current_auth:Signature ~account_perm:Proof
        ~vk_txn_version:older_version ()

    let () =
      test "account update using Signature auth when perm is set to Impossible"
      @@ fun () ->
      mk_update_perm_check ~current_auth:Signature ~account_perm:Impossible
        ~vk_txn_version:older_version ()

    let () =
      test "account update using Proof auth when perm is set to Proof"
      @@ fun () ->
      mk_update_perm_check ~current_auth:Proof ~account_perm:Proof
        ~vk_txn_version:older_version
        ~failure_expected:Test_input.failure_expected ()

    let () =
      test "account update using Proof auth when perm is set to Either"
      @@ fun () ->
      mk_update_perm_check ~current_auth:Proof ~account_perm:Either
        ~vk_txn_version:older_version
        ~failure_expected:
          ( Transaction_status.Failure.Proof_with_outdated_verification_key
          , Transaction_snark_tests.Util.Pass_2 )
        ()

    (* Scenarios spanning several zkApp commands against one zkApp account,
       checking how the version stored with its verification key evolves. *)

    type step =
      { auth : Permissions.Auth_required.t
      ; update : Account_update.Update.t
      ; expected_failure : (Transaction_status.Failure.t * U.pass_number) option
      }

    let keep = Account_update.Update.dummy

    let set_vk = snapp_update

    let step ?expected_failure auth update = { auth; update; expected_failure }

    (* Run [steps] in order against a fresh zkApp account with [permissions]
       and a key stored with [vk_txn_version] (no key at all if
       [no_verification_key]), then check the account with [check]. *)
    let run_steps ~permissions ?(vk_txn_version = older_version)
        ?(no_verification_key = false) ~check steps =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, zkapp_kp) ->
          let open Mina_transaction_logic.For_tests in
          let spec = List.hd_exn specs in
          let sender_kp, sender_nonce = spec.sender in
          let zkapp_pk = Public_key.compress zkapp_kp.public_key in
          let zkapp_id = Account_id.create zkapp_pk Token_id.default in
          U.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let open Async.Deferred.Let_syntax in
                  Init_ledger.init
                    (module U.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let%bind vk' = vk in
                  Transaction_snark.For_tests.create_trivial_zkapp_account
                    ~permissions ~vk_txn_version ~vk:vk' ~ledger zkapp_pk ;
                  let get_account () =
                    U.Ledger.location_of_account ledger zkapp_id
                    |> Option.value_exn |> U.Ledger.get ledger
                    |> Option.value_exn
                  in
                  ( if no_verification_key then
                    let account = get_account () in
                    U.Ledger.set ledger
                      (Option.value_exn
                         (U.Ledger.location_of_account ledger zkapp_id) )
                      { account with
                        zkapp =
                          Option.map account.zkapp ~f:(fun zkapp ->
                              { zkapp with verification_key = None } )
                      } ) ;
                  let%map () =
                    Async.Deferred.List.iteri ~how:`Sequential steps
                      ~f:(fun i { auth; update; expected_failure } ->
                        let test_spec : Spec.t =
                          { sender =
                              ( sender_kp
                              , Mina_numbers.Account_nonce.(
                                  add sender_nonce (of_int i)) )
                          ; fee = Fee.of_nanomina_int_exn 1_000_000
                          ; fee_payer = None
                          ; receivers = []
                          ; amount = Amount.of_mina_int_exn 10
                          ; zkapp_account_keypairs = [ zkapp_kp ]
                          ; memo
                          ; new_zkapp_account = false
                          ; snapp_update = update
                          ; current_auth = auth
                          ; call_data = Snark_params.Tick.Field.zero
                          ; events = []
                          ; actions = []
                          ; preconditions = None
                          }
                        in
                        let%bind zkapp_command =
                          Transaction_snark.For_tests.update_states
                            ~zkapp_prover_and_vk:(zkapp_prover, vk)
                            ~constraint_constants:U.constraint_constants
                            test_spec
                        in
                        U.check_zkapp_command_with_merges_exn ?expected_failure
                          ledger [ zkapp_command ] )
                  in
                  check (get_account ()) ) ) )

    let vk_txn_version (account : Account.t) =
      Option.bind account.zkapp ~f:(fun zkapp ->
          Option.map zkapp.verification_key ~f:(fun vk -> vk.txn_version) )

    let assert_vk_txn_version expected account =
      [%test_eq: Mina_numbers.Txn_version.t option] (Some expected)
        (vk_txn_version account)

    let vk_not_permitted =
      ( Transaction_status.Failure.Update_not_permitted_verification_key
      , U.Pass_2 )

    let access_not_permitted =
      (Transaction_status.Failure.Update_not_permitted_access, U.Pass_2)

    let () =
      test "a third party's update that keeps the key does not end the fallback"
      @@ fun () ->
      run_steps
        ~permissions:
          { Permissions.user_default with
            set_verification_key =
              (Permissions.Auth_required.Proof, Mina_numbers.Txn_version.current)
          }
        ~check:(assert_vk_txn_version Mina_numbers.Txn_version.current)
        [ (* An unauthorized update paying into the account. *)
          step None keep
        ; (* The owner can still replace the stale key by signature. *)
          step Signature set_vk
        ; (* That stamps the key, so the fallback has ended. *)
          step ~expected_failure:vk_not_permitted Signature set_vk
        ]

    let () =
      test "keeping the key leaves its version unchanged"
      @@ fun () ->
      run_steps ~permissions:Permissions.user_default
        ~check:(assert_vk_txn_version older_version)
        [ step None keep; step Signature keep ]

    let () =
      test "an Impossible-protected stale key can be replaced once"
      @@ fun () ->
      run_steps
        ~permissions:
          { Permissions.user_default with
            set_verification_key = (Impossible, Mina_numbers.Txn_version.current)
          }
        ~check:(assert_vk_txn_version Mina_numbers.Txn_version.current)
        [ step Signature set_vk
        ; step ~expected_failure:vk_not_permitted Signature set_vk
        ]

    let () =
      test "the access fallback lasts until the key is replaced"
      @@ fun () ->
      run_steps
        ~permissions:{ Permissions.user_default with access = Proof }
        ~check:(assert_vk_txn_version Mina_numbers.Txn_version.current)
        [ step Signature keep
        ; step Signature keep
        ; step Signature set_vk
        ; step ~expected_failure:access_not_permitted Signature keep
        ]

    let () =
      test "editing other permissions does not end the fallback"
      @@ fun () ->
      let permissions =
        { Permissions.user_default with
          set_verification_key =
            (Permissions.Auth_required.Proof, Mina_numbers.Txn_version.current)
        }
      in
      run_steps ~permissions
        ~check:(assert_vk_txn_version Mina_numbers.Txn_version.current)
        [ step Signature
            { Account_update.Update.dummy with
              permissions =
                Zkapp_basic.Set_or_keep.Set
                  { permissions with edit_state = Signature }
            }
        ; step Signature set_vk
        ]

    let () =
      test "an account without a key never falls back"
      @@ fun () ->
      run_steps
        ~permissions:
          { Permissions.user_default with
            access = Proof
          ; set_verification_key = (Impossible, Mina_numbers.Txn_version.current)
          }
        ~no_verification_key:true
        ~check:(fun account ->
          [%test_eq: Mina_numbers.Txn_version.t option] None
            (vk_txn_version account) )
        [ step ~expected_failure:access_not_permitted Signature set_vk ]

    let () =
      test "a fresh key is not stale"
      @@ fun () ->
      run_steps
        ~permissions:
          { Permissions.user_default with
            set_verification_key =
              (Permissions.Auth_required.Proof, Mina_numbers.Txn_version.current)
          }
        ~vk_txn_version:Mina_numbers.Txn_version.current
        ~check:(assert_vk_txn_version Mina_numbers.Txn_version.current)
        [ step ~expected_failure:vk_not_permitted Signature set_vk ]
  end in
  ()
