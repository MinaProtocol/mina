WIP list documenting all types needed:

?: children not visited yet
%: already visited children
$: repeat prefix above
=: directly equal to parent

Leafs only depend on native (or external) types

## Compatible

Network_pool.Transaction_pool.Diff_versioned.V1.t
- Mina_base.User_command.t
  - $.$.Poly.Stable.V1.t
  - $.Signed_command.Stable.V1.t
    - $.$.Poly.Stable.V1.t
    - $.Signed_command_payload.Stable.V1.t
      - $.$.Poly.Stable.V1.t
      - $.$.Common.Stable.V1.t
        - $.$.$.Poly.Stable.V1.t
        - Currency.Fee.Stable.V1.t
        - Public_key.Compressed.Stable.V1.t
          - Non_zero_curve_point.Compressed.Stable.V1.t
            - $.Compressed_poly.Stable.V1.t
            - Snark_params.Tick.Field.t
              = Crypto_params.Tick.Field.t
              = Pickles.Impls.Step.Internal_basic.Field.t
              = Zexe_backend.Pasta.Vesta_based_plonk.Field.t
              = Marlin_plonk_bindings.Pasta_fp.t
        - $.Token_id.Stable.V1.t
          - Mina_numbers.Nat.Make64.Stable.V1.t
        - Mina_numbers.Account_nonce.Stable.V1.t
        - Mina_numbers.Global_slot.Stable.V1.t
        - $.Signed_command_memo.Stable.V1.t
      - $.$.Body.Stable.V1.t
        - $.Payment_payload.t
          - Poly.Stable.V1.t
          - Currency.Amount.Stable.V1.t
          - %
        - $.Stake_delegation.t
          - %
        - $.New_token_payload.t
          - %
        - $.New_account_payload.t
          - %
        - $.Minting_payload.t
          - %
    - Public_key.Stable.V1.t
      - Non_zero_curve_point.Stable.V1.t
        - %
    - $.Signature.Stable.V1.t
      - Snark_params.Tick.Inner_curve.t
        = Pickles.Backend.Tick.Inner_curve.t
        = Zexe_backend.Pasta.Pallas.t
        = Curve.Make (Fp) (Fq) (Params) (Pasta_pallas)
        = Marlin_plonk_bindings.Pasta_pallas.t
      - %
  - $.Snapp_command.Stable.V1.t
    - $.$.Inner.Stable.V1.t
      - $.Other_fee_payer.Stable.V1.t
        - $.$.Payload.Stable.V1.t
        - %
      - %
    - $.$.Party.Authorized.Proved.Stable.V1.t
      - $.$.$.Poly.Stable.V1.t
      - $.$.$.Predicated.Proved.Stable.V1.t
        - $.$.$.Body.Stable.V1.t
          - Update.Stable.V1.t
            - Pickles.Backend.Tick.Field.Stable.V1.t %
            - Set_or_keep.Stable.V1.t
            - Pickles.Side_loaded.Verification_key.Stable.V1.t
              - $.Backend.Tock.Curve.Affine.t
                = Marlin_plonk_bindings.Pasta_pallas.t %
              - $.$.Vk.t
                - $.Impls.Wrap.Verification_key.t
                - %
              - $.$.$.Poly.Stable.V1.t
            - With_hash.Stable.V1.t
            - Mina_base.Permissions.Stable.V1.t
              - $.$.Auth_required.Stable.V1.t
              - $.$.Poly.Stable.V1.t
          Poly.Stable.V1.t
          - Sgn.Stable.V1.t
          - Signed_poly.Stable.V1.t
          - $.$.$.$.Poly.Stable.V1.t
          - %
        - $.Snapp_predicate.Stable.V1.t
          - Account.Stable.V1.t
            - Currency.Balance.Stable.V1.t
            - Numeric.Stable.V1.t
              - Closed_interval.Stable.V1.t
              - Or_ignore.Stable.V1.t
            - $.Receipt.Chain_hash.Stable.V1.t %
            - Eq_data.Stable.V1.t
              = Or_ignore.Stable.V1.t
            - Poly.Stable.V1.t
            - %
          - Protocol_state.Stable.V1.t
            - Frozen_ledger_hash.Stable.V1.t %
            - Epoch_ledger.Poly.Stable.V1.t
            - Epoch_seed.Stable.V1.t %
            - State_hash.Stable.V1.t %
            - Length.Stable.V1.t
            - Poly.Stable.V1.t
          - Other.Stable.V1.t
          - $.$.Poly.Stable.V1.t
          - %
        - $.$.$.$.Poly.Stable.V1.t
      - $.Control.Stable.V1.t
        - Pickles.Side_loaded.Proof.Stable.V1.t
          - Verification_key.Max_width.n (NAT MACHINERY)
          - $.Proof.t
            - Proof.With_data.t
              - Base.Me_only.Dlog_based.t
                - Tock.Inner_curve.Affine.t
                  - Marlin_plonk_bindings.Pasta_fq.t
                    - Challenge.Constant.t ?
                    - Scalar_challenge.t
                    - Bulletproof_challenge.t
                    - Wrap_bp_vec.t (NAT MACHINERY)
                - Challenges_vector.t %
                - Vector.t (NAT MACHINERY)
                - Dlog_based.Proof_state.Me_only.t
              - Step_bp_vec.t (NAT MACHINERY)
              - Base.Me_only.Pairing_based.t
        - %
    - $.$.Party.Authorized.Empty.Stable.V1.t
      - $.$.$.Predicated.Empty.Stable.V1.t
        - %
      - %
    - $.$.Party.Authorized.Signed.Stable.V1.t
      - $.$.$.Predicated.Signed.Stable.V1.t
        - %

Network_pool.Snark_pool.Diff_versioned.Stable.V1.t
- Transaction_snark_work.Statement.Stable.V1.t
  - Ledger_proof.Stable.V1.t
    - Transaction_snark.Stable.V1.t
      - Statement.With_sok.Stable.V1.t
        - Pending_coinbase_stack_state.Stable.V1.t
          - Pending_coinbase.Stack_versioned.Stable.V1.t
            - Coinbase_stack.Stawantble.V1.t
            - State_stack.Stable.V1.t
              - Stack_hash.Stable.V1.t
              - Poly.Stable.V1.t
            - Poly.Stable.V1.t
        - Fee_excess.Stable.V1.t
          - Poly.Stable.V1.t
          - %
        - Sok_message.Digest.Stable.V1.t
        - Poly.Stable.V1.t
        - %
      - Proof.Stable.V1.t
        - Pickles.Proof.Branching_2.Stable.V1.t ?
  - One_or_two.Stable.V1.t
  - Priced_proof.Stable.V1.t
    - Fee_with_prover.Stable.V1.t
    - %
  - Core.Time.Stable.With_utc_sexp.V2.t
  - Transaction_snark_work.Statement.Stable.V1.Table.t
- %

Mina_block.External_transition.Raw.Stable.V1.t
- Protocol_state.Value.Stable.V1.t
  - Body.Value.Stable.V1.t
    - Blockchain_state.Value.Stable.V1.t
      - Staged_ledger_hash.Stable.V1.t
        - Non_snark.Stable.V1.t
          - Ledger_hash.Stable.V1.t
          - Aux_hash.Stable.V1.t
          - Pending_coinbase_aux.Stable.V1.t
        - Pending_coinbase.Hash_versioned.Stable.V1.t
        - Poly.Stable.V1.t
      - Block_time.Stable.V1.t
      - Poly.Stable.V1.t
    - Consensus.Data.Consensus_state.Value.Stable.V1.t
      - Length.Stable.V1.t
      - Vrf.Output.Truncated.Stable.V1.t
      - Global_slot.Stable.V1.t
        - Mina_numbers.Global_slot.Stable.V1.t
      - Epoch_data.Staking_value_versioned.Value.Stable.V1.t
        - Epoch_ledger.Value.Stable.V1.t
          - Frozen_ledger_hash0.Stable.V1.t
          - Poly.Stable.V1.t
        - Lock_checkpoint.Stable.V1.t
        - Poly.Stable.V1.t
      - Epoch_data.Next_value_versioned.Value.Stable.V1.t %
      - Poly.Stable.V1.t
    - Protocol_constants_checked.Value.Stable.V1.t
      - Poly.Stable.V1.t
      - %
    - Poly.Stable.V1.t
  - Poly.Stable.V1.t
- Staged_ledger_diff.Stable.V1.t
  - Diff.t
    - Pre_diff_with_at_most_two_coinbase.t
      - Transaction_snark_work.t
        - %
      - With_status.t
        - Transaction_status.Stable.V1.t
          - Auxiliary_data.Stable.V1.t
          - Balance_data.Stable.V1.t
          - Failure.Stable.V1.t
      - Pre_diff_two.t
        - Coinbase.Fee_transfer.t
        - At_most_two.t
        - Transaction_status.Internal_command_balance_data.t
          - Coinbase_balance_data.Stable.V1.t
          - Fee_transfer_balance_data.Stable.V1.t
    - Pre_diff_with_at_most_one_coinbase.t
      - At_most_one.t
- State_body_hash.Stable.V1.t
- Protocol_version.Stable.V1.t
- Validate_content.t

## Develop

?
