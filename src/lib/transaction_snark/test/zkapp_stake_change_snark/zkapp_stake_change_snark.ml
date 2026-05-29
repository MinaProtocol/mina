(** Transaction SNARK (full proving) tests for [stake_change] on zkApp
    transactions.

    Each test mirrors a row of the representative cases in
    [docs/unstaking-stake-change.md] § "Representative test cases" and the unchecked
    counterpart in
    [src/lib/transaction_logic/test/transaction_logic/zkapp_stake_change.ml].
    The harness drives [U.check_zkapp_command_with_merges_exn], which
    proves the zkApp segments and then [%test_eq]'s the proved statement
    against the expected statement built in [test/util.ml]. The expected
    statement's [stake_change] field is computed via
    [Transaction_applied.stake_change_of_transaction] — so a passing test
    establishes that the SNARK's accumulated [stake_change] agrees with
    the unchecked aggregator on the same transaction.

    A failure here means the in-circuit accumulator in
    [zkapp_command_logic.ml] has drifted from the unchecked apply path. *)

open Core
open Mina_base
open Currency
open Mina_ledger
open Signature_lib
module U = Transaction_snark_tests.Util

let%test_module "zkApp stake_change in the transaction SNARK" =
  ( module struct
    let proof_cache =
      Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
      @@ Yojson.Safe.from_file "proof_cache.json"

    let () = Transaction_snark.For_tests.set_proof_cache proof_cache

    [@@@warning "-32"]

    let constraint_constants = U.constraint_constants

    let proof_cache_db = Proof_cache_tag.For_tests.create_db ()

    (* Overwrite an existing default-token account's [delegate]. Panics if
       the account isn't in the ledger. *)
    let set_delegate ledger pk new_delegate =
      let acc_id = Account_id.create pk Token_id.default in
      let loc =
        Option.value_exn
          ~message:
            (sprintf "Location of %s not found in ledger"
               (Account_id.sexp_of_t acc_id |> Sexp.to_string) )
          (Ledger.location_of_account ledger acc_id)
      in
      let acc =
        Option.value_exn
          ~message:
            (sprintf "Empty location %s in ledger"
               (Ledger.Location.sexp_of_t loc |> Sexp.to_string) )
          (Ledger.get ledger loc)
      in
      Ledger.set ledger loc { acc with delegate = new_delegate }

    let memo =
      Signed_command_memo.create_from_string_exn "zkApp stake_change tests"

    let signature_kind = U.signature_kind

    (* Default zkApp body for an account_update that modifies its own state via
       Signature authorization. *)
    let signed_au_body ~(wallet : U.Wallet.t) ~update ~balance_change :
        Account_update.Body.Simple.t =
      { public_key = wallet.account.public_key
      ; token_id = Token_id.default
      ; update
      ; balance_change
      ; increment_nonce = false
      ; events = []
      ; actions = []
      ; call_data = Snark_params.Tick.Field.zero
      ; call_depth = 0
      ; preconditions =
          { Account_update.Preconditions.network =
              Zkapp_precondition.Protocol_state.accept
          ; account = Zkapp_precondition.Account.accept
          ; valid_while = Ignore
          }
      ; use_full_commitment = true
      ; implicit_account_creation_fee = true
      ; may_use_token = No
      ; authorization_kind = Signature
      }

    let signed_au ~(wallet : U.Wallet.t) ~update ~balance_change :
        Account_update.Simple.t =
      Account_update.with_no_aux
        ~body:(signed_au_body ~wallet ~update ~balance_change)
        ~authorization:(Control.Poly.Signature Signature.dummy)

    let none_given_receive_au ~(wallet : U.Wallet.t) ~balance_change :
        Account_update.Simple.t =
      Account_update.with_no_aux
        ~body:
          { (signed_au_body ~wallet ~update:Account_update.Update.noop
               ~balance_change )
            with
            authorization_kind = None_given
          ; use_full_commitment = false
          }
        ~authorization:Control.Poly.None_given

    (* Build, then sign, a zkApp command. [signers] supplies private keys for
       every account_update with Signature authorization (and for the
       fee_payer), keyed by compressed public key. *)
    let build_and_sign ~(fp : U.Wallet.t) ~fee
        ~(account_updates : Account_update.Simple.t list)
        ~(signers : (Public_key.Compressed.t * Private_key.t) list) :
        Zkapp_command.t =
      let simple : Zkapp_command.Simple.t =
        { fee_payer =
            Account_update.Fee_payer.make
              ~body:
                { Account_update.Body.Fee_payer.dummy with
                  public_key = fp.account.public_key
                ; fee
                ; nonce = fp.account.nonce
                }
              ~authorization:Signature.dummy
        ; account_updates
        ; memo
        }
      in
      let cmd =
        Zkapp_command.of_simple ~signature_kind ~proof_cache_db simple
      in
      let commitment = Zkapp_command.commitment cmd in
      let full_commitment =
        Zkapp_command.Transaction_commitment.create_complete commitment
          ~memo_hash:(Signed_command_memo.hash cmd.memo)
          ~fee_payer_hash:
            (Zkapp_command.Digest.Account_update.create ~signature_kind
               (Account_update.of_fee_payer cmd.fee_payer) )
      in
      let find_sk pk =
        match
          List.find signers ~f:(fun (p, _) -> Public_key.Compressed.equal p pk)
        with
        | Some (_, sk) ->
            sk
        | None ->
            failwithf "build_and_sign: no signer for %s"
              (Public_key.Compressed.to_base58_check pk)
              ()
      in
      let fee_payer_sig =
        Schnorr.Chunked.sign ~signature_kind
          (find_sk fp.account.public_key)
          (Random_oracle.Input.Chunked.field full_commitment)
      in
      let account_updates =
        Zkapp_command.Call_forest.map cmd.account_updates
          ~f:(fun (au : (Account_update.Body.t, _, _) Account_update.Poly.t) ->
            match au.body.authorization_kind with
            | Signature ->
                let c =
                  if au.body.use_full_commitment then full_commitment
                  else commitment
                in
                let sig_ =
                  Schnorr.Chunked.sign ~signature_kind
                    (find_sk au.body.public_key)
                    (Random_oracle.Input.Chunked.field c)
                in
                { au with authorization = Control.Poly.Signature sig_ }
            | _ ->
                au )
      in
      { cmd with
        fee_payer = { cmd.fee_payer with authorization = fee_payer_sig }
      ; account_updates
      }

    let install_wallets ledger wallets =
      Array.iter wallets ~f:(fun (w : U.Wallet.t) ->
          Ledger.create_new_account_exn ledger
            (Account.identifier w.account)
            w.account )

    let signer_of (w : U.Wallet.t) = (w.account.public_key, w.private_key)

    let set_delegate_update new_delegatee_pk : Account_update.Update.t =
      { Account_update.Update.noop with
        delegate = Zkapp_basic.Set_or_keep.Set new_delegatee_pk
      }

    let set_delegate_to_empty : Account_update.Update.t =
      { Account_update.Update.noop with
        delegate = Zkapp_basic.Set_or_keep.Set Public_key.Compressed.empty
      }

    let permissions_only_update new_permissions : Account_update.Update.t =
      { Account_update.Update.noop with
        permissions = Zkapp_basic.Set_or_keep.Set new_permissions
      }

    (* Build a fee_payer-only zkApp command (empty call forest) drawing
       [fee] from [fp], with a real Schnorr signature on the fee_payer.
       The SNARK rejects dummy signatures via the
       [signature_verifies = is_signed] assertion in zkapp_command_logic. *)
    let fee_payer_only_zkapp_command ~(fp : U.Wallet.t) ~fee : Zkapp_command.t =
      build_and_sign ~fp ~fee ~account_updates:[] ~signers:[ signer_of fp ]

    (* zkapp_stake_change_row_z1 — fee_payer staked, no other updates.
       Δstake_fp = (balance(fp) − fee)·1 − balance(fp)·1 = −fee. The SNARK
       must compute stake_change = −fee, matching the unchecked aggregator. *)
    let%test_unit "z1 fee_payer staked, no other updates" =
      Test_util.with_randomness 1 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:2 ())
          in
          let fp = wallets.(0) in
          let validator_pk = wallets.(1).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some validator_pk) ;
              let zkapp_command =
                fee_payer_only_zkapp_command ~fp ~fee:(Fee.of_mina_int_exn 1)
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    (* zkapp_stake_change_row_z3 — staked → staked balance change on a non-fp
       target. fee_payer staked, [staked_target] staked. One account_update
       moves [amount] from staked_target to a receiver. Sum: −fee − amount. *)
    let%test_unit "z3 balance change on staked target" =
      Test_util.with_randomness 3 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:4 ())
          in
          let fp = wallets.(0) in
          let staked_target = wallets.(1) in
          let receiver = wallets.(2) in
          let validator_pk = wallets.(3).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some validator_pk) ;
              set_delegate ledger staked_target.account.public_key
                (Some validator_pk) ;
              let amount = Amount.of_mina_int_exn 1 in
              let account_updates =
                [ signed_au ~wallet:staked_target
                    ~update:Account_update.Update.noop
                    ~balance_change:Amount.Signed.(of_unsigned amount |> negate)
                ; none_given_receive_au ~wallet:receiver
                    ~balance_change:(Amount.Signed.of_unsigned amount)
                ]
              in
              let zkapp_command =
                build_and_sign ~fp ~fee:(Fee.of_mina_int_exn 1) ~account_updates
                  ~signers:[ signer_of fp; signer_of staked_target ]
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    (* zkapp_stake_change_row_z4 — opt-in (unstaked → staked) on an existing
       default-token target. This is the SNARK reproducer for the integration
       [update_all] failure mode: a non-fp account_update sets delegate from
       empty to a real pk, transitioning the target's stake contribution
       from 0 to balance. *)
    let%test_unit "z4 opt-in delegate (None -> Set new_delegatee)" =
      Test_util.with_randomness 4 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:4 ())
          in
          let fp = wallets.(0) in
          let opt_in_target = wallets.(1) in
          let new_delegatee_pk = wallets.(2).account.public_key in
          let fp_validator_pk = wallets.(3).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some fp_validator_pk) ;
              set_delegate ledger opt_in_target.account.public_key None ;
              let account_updates =
                [ signed_au ~wallet:opt_in_target
                    ~update:(set_delegate_update new_delegatee_pk)
                    ~balance_change:Amount.Signed.zero
                ]
              in
              let zkapp_command =
                build_and_sign ~fp ~fee:(Fee.of_mina_int_exn 1) ~account_updates
                  ~signers:[ signer_of fp; signer_of opt_in_target ]
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    (* zkapp_stake_change_row_z5 — opt-out (staked → unstaked). delegate goes
       from Some to empty_pk. balance unchanged → Δstake_target = −balance. *)
    let%test_unit "z5 opt-out delegate (Some -> empty_pk)" =
      Test_util.with_randomness 5 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:3 ())
          in
          let fp = wallets.(0) in
          let opt_out_target = wallets.(1) in
          let validator_pk = wallets.(2).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some validator_pk) ;
              set_delegate ledger opt_out_target.account.public_key
                (Some validator_pk) ;
              let account_updates =
                [ signed_au ~wallet:opt_out_target ~update:set_delegate_to_empty
                    ~balance_change:Amount.Signed.zero
                ]
              in
              let zkapp_command =
                build_and_sign ~fp ~fee:(Fee.of_mina_int_exn 1) ~account_updates
                  ~signers:[ signer_of fp; signer_of opt_out_target ]
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    (* zkapp_stake_change_row_z6 — telescoping. Two updates on the same
       [target]: opt-in to intermediate_validator, then opt-out to empty.
       Per-account contribution is post − pre = 0; total = −fee. *)
    let%test_unit "z6 telescoping on same target (None -> v1 -> empty)" =
      Test_util.with_randomness 6 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:4 ())
          in
          let fp = wallets.(0) in
          let target = wallets.(1) in
          let intermediate_validator_pk = wallets.(2).account.public_key in
          let fp_validator_pk = wallets.(3).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some fp_validator_pk) ;
              set_delegate ledger target.account.public_key None ;
              let account_updates =
                [ signed_au ~wallet:target
                    ~update:(set_delegate_update intermediate_validator_pk)
                    ~balance_change:Amount.Signed.zero
                ; signed_au ~wallet:target ~update:set_delegate_to_empty
                    ~balance_change:Amount.Signed.zero
                ]
              in
              let zkapp_command =
                build_and_sign ~fp ~fee:(Fee.of_mina_int_exn 1) ~account_updates
                  ~signers:[ signer_of fp; signer_of target ]
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    (* zkapp_stake_change_row_z7 — sum across distinct targets:
       [opt_in_target] unstaked → opt-in (+balance);
       [opt_out_target] staked → opt-out (−balance).
       Matches the integration update_all shape (multiple non-fp updates,
       each transitioning delegate). *)
    let%test_unit "z7 sum across distinct targets (opt-in + opt-out)" =
      Test_util.with_randomness 7 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:6 ())
          in
          let fp = wallets.(0) in
          let opt_in_target = wallets.(1) in
          let opt_out_target = wallets.(2) in
          let new_delegatee_pk = wallets.(3).account.public_key in
          let fp_validator_pk = wallets.(4).account.public_key in
          let opt_out_validator_pk = wallets.(5).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some fp_validator_pk) ;
              set_delegate ledger opt_in_target.account.public_key None ;
              set_delegate ledger opt_out_target.account.public_key
                (Some opt_out_validator_pk) ;
              let account_updates =
                [ signed_au ~wallet:opt_in_target
                    ~update:(set_delegate_update new_delegatee_pk)
                    ~balance_change:Amount.Signed.zero
                ; signed_au ~wallet:opt_out_target ~update:set_delegate_to_empty
                    ~balance_change:Amount.Signed.zero
                ]
              in
              let zkapp_command =
                build_and_sign ~fp ~fee:(Fee.of_mina_int_exn 1) ~account_updates
                  ~signers:
                    [ signer_of fp
                    ; signer_of opt_in_target
                    ; signer_of opt_out_target
                    ]
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    (* zkapp_stake_change_row_z11 — permissions-only update on a default-token
       target. balance and delegate unchanged → per-account contribution = 0.
       Sum: −fee·fp_staked. Control case mirroring "update permissions" from
       the integration test, which lands. *)
    let%test_unit "z11 permissions-only update on default-token target" =
      Test_util.with_randomness 11 (fun () ->
          let wallets =
            Quickcheck.random_value (U.Wallet.random_wallets ~n:3 ())
          in
          let fp = wallets.(0) in
          let target = wallets.(1) in
          let validator_pk = wallets.(2).account.public_key in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              install_wallets ledger wallets ;
              set_delegate ledger fp.account.public_key (Some validator_pk) ;
              let new_permissions =
                { Permissions.user_default with
                  set_zkapp_uri = Permissions.Auth_required.Proof
                }
              in
              let account_updates =
                [ signed_au ~wallet:target
                    ~update:(permissions_only_update new_permissions)
                    ~balance_change:Amount.Signed.zero
                ]
              in
              let zkapp_command =
                build_and_sign ~fp ~fee:(Fee.of_mina_int_exn 1) ~account_updates
                  ~signers:[ signer_of fp; signer_of target ]
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    let () =
      match Sys.getenv "PROOF_CACHE_OUT" with
      | Some path ->
          Yojson.Safe.to_file path @@ Pickles.Proof_cache.to_yojson proof_cache
      | None ->
          ()
  end )
