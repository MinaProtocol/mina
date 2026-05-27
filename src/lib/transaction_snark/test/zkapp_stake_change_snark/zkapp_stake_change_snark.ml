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

    (* Overwrite an existing default-token account's [delegate]. Panics if
       the account isn't in the ledger. *)
    let set_delegate ledger pk new_delegate =
      let acc_id = Account_id.create pk Token_id.default in
      let loc =
        Option.value_exn
          ~message:
            (sprintf "Location of %s not found in ledger"
               (Account_id.sexp_of_t acc_id |> string_of_sexp) )
          (Ledger.location_of_account ledger acc_id)
      in
      let acc =
        Option.value_exn
          ~message:
            (sprintf "Empty location %s in ledger"
               (Ledger.Location.sexp_of_t loc |> string_of_sexp) )
          (Ledger.get ledger loc)
      in
      Ledger.set ledger loc { acc with delegate = new_delegate }

    let memo =
      Signed_command_memo.create_from_string_exn "zkApp stake_change tests"

    let signature_kind = U.signature_kind

    (* Build a fee_payer-only zkApp command (empty call forest) drawing
       [fee] from [fp], with a real Schnorr signature on the fee_payer.
       The SNARK rejects dummy signatures via the
       [signature_verifies = is_signed] assertion in zkapp_command_logic. *)
    let fee_payer_only_zkapp_command ~(fp : U.Wallet.t) ~fee : Zkapp_command.t =
      let unsigned : Zkapp_command.t =
        { fee_payer =
            Account_update.Fee_payer.make
              ~body:
                { Account_update.Body.Fee_payer.dummy with
                  public_key = fp.account.public_key
                ; fee
                ; nonce = fp.account.nonce
                }
              ~authorization:Signature.dummy
        ; account_updates = []
        ; memo
        }
      in
      let commitment = Zkapp_command.commitment unsigned in
      let full_commitment =
        Zkapp_command.Transaction_commitment.create_complete commitment
          ~memo_hash:(Signed_command_memo.hash unsigned.memo)
          ~fee_payer_hash:
            (Zkapp_command.Digest.Account_update.create ~signature_kind
               (Account_update.of_fee_payer unsigned.fee_payer) )
      in
      let signature =
        Schnorr.Chunked.sign ~signature_kind fp.private_key
          (Random_oracle.Input.Chunked.field full_commitment)
      in
      { unsigned with
        fee_payer = { unsigned.fee_payer with authorization = signature }
      }

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
              Array.iter wallets ~f:(fun { account; _ } ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              set_delegate ledger fp.account.public_key (Some validator_pk) ;
              let zkapp_command =
                fee_payer_only_zkapp_command ~fp ~fee:(Fee.of_mina_int_exn 1)
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
