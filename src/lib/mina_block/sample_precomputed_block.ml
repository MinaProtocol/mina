(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1676398307700)
 (protocol_state
  ((previous_state_hash
    6015213778799164743705381332887935226819166012453542567863482729120123228169)
   (body
    ((genesis_state_hash
      6015213778799164743705381332887935226819166012453542567863482729120123228169)
     (blockchain_state
      ((staged_ledger_hash
        ((non_snark
          ((ledger_hash
            3822519095581726623254550915595812996323438043516959995318394783901487958677)
           (aux_hash
            "+I\006\t\240,\241\159\164\178\186S\152b`s\132\022Q\164^_\031\003\236V\226gz\214\169\014")
           (pending_coinbase_aux
            "\147\141\184\201\248,\140\181\141?>\244\253%\0006\164\141&\167\018u=/\222Z\189\003\168\\\171\244")))
         (pending_coinbase_hash
          6723016672987959500222763393199258228089565039036321517797417968629063599288)))
       (genesis_ledger_hash
        15400080997311014633075963973772062339916544638575500775226582420161761724602)
       (ledger_proof_statement
        ((source
          ((first_pass_ledger
            15400080997311014633075963973772062339916544638575500775226582420161761724602)
           (second_pass_ledger
            15400080997311014633075963973772062339916544638575500775226582420161761724602)
           (pending_coinbase_stack
            ((data
              13478948633790621346997153068092516261975764161208078295837519850718904039733)
             (state ((init 0) (curr 0)))))
           (local_state
            ((stack_frame
              0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C)
             (call_stack
              0x0000000000000000000000000000000000000000000000000000000000000000)
             (transaction_commitment
              0x0000000000000000000000000000000000000000000000000000000000000000)
             (full_transaction_commitment
              0x0000000000000000000000000000000000000000000000000000000000000000)
             (excess ((magnitude 0) (sgn Pos)))
             (supply_increase ((magnitude 0) (sgn Pos))) (ledger 0)
             (success true) (account_update_index 0) (failure_status_tbl ())
             (will_succeed true)))))
         (target
          ((first_pass_ledger
            15400080997311014633075963973772062339916544638575500775226582420161761724602)
           (second_pass_ledger
            15400080997311014633075963973772062339916544638575500775226582420161761724602)
           (pending_coinbase_stack
            ((data
              13478948633790621346997153068092516261975764161208078295837519850718904039733)
             (state ((init 0) (curr 0)))))
           (local_state
            ((stack_frame
              0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C)
             (call_stack
              0x0000000000000000000000000000000000000000000000000000000000000000)
             (transaction_commitment
              0x0000000000000000000000000000000000000000000000000000000000000000)
             (full_transaction_commitment
              0x0000000000000000000000000000000000000000000000000000000000000000)
             (excess ((magnitude 0) (sgn Pos)))
             (supply_increase ((magnitude 0) (sgn Pos))) (ledger 0)
             (success true) (account_update_index 0) (failure_status_tbl ())
             (will_succeed true)))))
         (connecting_ledger_left
          15400080997311014633075963973772062339916544638575500775226582420161761724602)
         (connecting_ledger_right
          15400080997311014633075963973772062339916544638575500775226582420161761724602)
         (supply_increase ((magnitude 0) (sgn Pos)))
         (fee_excess
          ((fee_token_l
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (fee_excess_l ((magnitude 0) (sgn Pos)))
           (fee_token_r
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (fee_excess_r ((magnitude 0) (sgn Pos)))))
         (sok_digest ())))
       (timestamp 1676398307700)
       (body_reference
        "\255\242\2436c:`\178\"\194:/\242\132g\199\205r\251\197%\133\\\028\190\163#\236\221\247\178\157")))
     (consensus_state
      ((blockchain_length 2) (epoch_count 0) (min_window_density 6)
       (sub_window_densities (1 0 0))
       (last_vrf_output
        "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000")
       (total_currency 10016120000000000)
       (curr_global_slot ((slot_number (Since_hard_fork 6)) (slots_per_epoch 576)))
       (global_slot_since_genesis (Since_genesis 6))
       (staking_epoch_data
        ((ledger
          ((hash
            15400080997311014633075963973772062339916544638575500775226582420161761724602)
           (total_currency 10016100000000000)))
         (seed 0) (start_checkpoint 0) (lock_checkpoint 0) (epoch_length 1)))
       (next_epoch_data
        ((ledger
          ((hash
            15400080997311014633075963973772062339916544638575500775226582420161761724602)
           (total_currency 10016100000000000)))
         (seed
          11097254031198438328229081175959322858342266757425965220770466547940953006797)
         (start_checkpoint 0)
         (lock_checkpoint
          6015213778799164743705381332887935226819166012453542567863482729120123228169)
         (epoch_length 3)))
       (has_ancestor_in_same_checkpoint_window true)
       (block_stake_winner
        B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
       (block_creator
        B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
       (coinbase_receiver
        B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo)
       (supercharge_coinbase true)))
     (constants
      ((k 24) (slots_per_epoch 576) (slots_per_sub_window 2) (delta 0)
       (genesis_state_timestamp 1548878400000)))))))
 (protocol_state_proof
  _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAACyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAAOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BvwlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAphReNqY2RNR6xs6SF5-jbqYXopjxCDzoibTKCa9Rxhzf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAEvwOjTlWCgsCMWjWpRghNlWQE8N9FewsLuEoPGubd7HQHCYmpoFFNIbqXUE_DqAwz11zHwq9_mMsdKKmmDte4PFwGFWckwTe35TyNm1Niq88nCr1wqszmKWu9My4OaUN68NQGdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQGtC9t5svFvTRQn4Nr-cMBjEPpGBrk-tEKCU4-D2ijxPwGV0WIswKfy24qZ2BVlNNVyB6rzu8alpqGjFc2SQmiCHwFS0reBvhwwDB3LQCBfYCQHWpkLPtZAaF6khi9l6UbpGgE2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAABcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4BDlAZ71lbeW-HLtrodN8-a9HpRCSu17pNesX-WuIlJBUBzs6SSvEomyJvu2y--Am5RCKp2R8Hgq2g2H78g9AZuRsBSk7p2M7zfnBNV4NuK9QsaWRm4nGX4WblpKyHr28XqSQB3n5X7QI17RMV7nx2WC_oXvE0EFcadTe81705GfJm7B4BfqjA-yV-URjlSNnH1Z9YWMoVO594UGIxPSUOJOIDKRQBnVPIW9vIufiV_TzyhUCa3iTQd8ax-4hL6O0DpgkgehUBmYTeWtMJHFI_kNtnklJrNrPQk2vaiqiqghEnSOGq-y0B0j1EVVxWkyQGfYKBdjKktIvjFCZxAaCYcxlyddAoTwUAAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAcMYHYfQq0qZzsiFs9TeUbC8oyswbr7OjcoahyvA78QdASiIwnFkuQs0GpeogsVFT1hoqNaHlrPxjvVCgO4_lig6Ac_m9fzHUjk9y_yUElbCuoSZ0yIorhrdEg0PvszZOJIzARfm_NoAYyHSb2jilosISHY2B_gy-a2wuqcaFbkveYglAf_bTpCddyllde8WLbcxWBaTqK4aJijp17EU9uZIMjAKAUASitwyPOzSS19N7_g0vpYMkKXJfRbObRI-3oyVsr88AAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPACP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwcBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAA8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBt2Z2Ql6HY3BcSnLE6gxakcHe6oNmQPRnIuciJP6PlEMkxFg96rSncZ6lI7T1YmX1kb9UTfY8tIEqLV7B8ZfxwUAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsB1EsiOTZOB4lB-rhHtowcba9M0zzvJ--ghUBS4RJqhw4BA_s2pG54hVSYXxPwaMdK4ko36E6cBmw8QSkCDAJoAQEBeMt_EQj_Mj7XIQA1qtI54ZYGHx7r80FIwmWEAhM9UAcBEDdmitoyunH7NCrgAZf_-UEnOr6ftLtFR23A66Llzh4B_duZ0AJg1WK-uayaHn7di7Z_q_hI0geY3cRL87PjQzQBy4Bg-tI3rKvBUoUw0cKB2xodcB9SmG_urppHNmVFuAsB2TwlrTTBFZYLae1PZY5eylm0lHeq-X9jF1v364JkGDkBptZkJiOve5lib6jfaoqJsYo_LQ7AUyP1s39p43pgIisBOW0qhQlwxLdlmvnPBQ3UFDk6WiURVgnsVZd4gXy_5gYBX41FSQNwr56cZdku_ZOW17EWJCs5tdFwQAYjD6bj_RwBFj7Z8vbR9xM_jV5N7vlIG2qZ3JenFOR6KD9ESqzp4CcB0zc4EtZU5P32Izpktkrf061GJ83mpdbXG4mD9j9mTCkBTMVLMejFlc_Ym2R8zwv5VCO2FQXJoST5pQG3-FIABTIBzAlqGdXjaCmuXHdv9DgTS2upfQyF6xaaBdt0INYcPRoBhnv-hGcgXzA_JLlMlxQ7tgiPIxqJy3GSw865aEdRfw0Bi8xLg5ERG4_WJ1D02y8FBJotAZF0Z_LIIhrZ9OG4sQABfE_2OwZ6RG13nh-5zgU2eub0HP_m_YlnEwuhZ0jHPAMBafxzT2qv8y7gICuSbmfRA8qI0OgzvgZ49PdSkaaY7zIB4i_MC-fg9HbN7iLECVbnILy6j3uVaZNCuQmHxs_ccTABIeomYvoTflIbEOcNR4BZGPc2vp-h6lDAaSlegJFT0w4BNV8KCkdC7YE0Uab5d2iEDZF6Vvm2ZxcEGTjP2VMK1DcBZW4VBuwhUXqAieE42n7RTbRe2KGx6PDxo65FryquySoBhJZ8MnB0A6hoc-3LMlPaDUL1skkSGeaYvb9Zk806HDoBJVOW_GzCFinO9qONnJhuUDFrtC4fKKPhr4cfdWn6yw0BRs_rddU_qtvcYFVMmbzdaoUl8qb057CoI-1A3VD8DQABaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSQBbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBEvaoh_mbxRUz5lGYEMed1_582A-NjLSDpPZSZGfKcx4BO9d3ZgCHqNalqD9kAAa8p8E238w1kwjrxET-AOaCaxgBcxdru8TDWkDLAvjZchjKzZjyY91Yta6PwbgV8snF3SkAATxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGAbWUMVDxqsXeU2I7i61f-mNljqu8Y456Yyex_6krMXoeAbJzsLxx_-vxxcTgFIpl6QZbJIiHu-iZYH0C8RcMe0YCAeVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQnAXUz3r-qPXovuFZ9Gb9iVhRsorwSG1I8--QnkuCzUyIsAVf6n7Zxvg2KMRUE8TEiEYahi-BEdxBzDEu6p0yjSN4yAfTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AQGF71eQABy-bk4IlED8UiScebtNMSCK98XYgQjcx4kWAdw-P8ei6BNwYFA1-WDLiFT7gzUZhsyIM_3fev86_LAVAVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEEAecivws4T8FIO6UNiUYE3FVG5DTEyrYAHMK8WfrHmFoqAXpKhKdWXxXytcpMDc3xn5mTcQm5ayHnpUHRQgEkFlE2AegJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMAaZhYz7Ulx7DpQE427Z8fUhCv_7vsQPljZNAGvcE9MwdAfaBPnHxIfuqZh3LgJRe8Rg-w88Qt8Y3GEpQOxqukQgLAVK-m_DwuxGRnVBt8Du4n_a1OpLW-A8Blh3FQCVcmFQgAX5Ysk_SKe-xbhIFpktcu5hlZq-EGuxqTY2lQgBdOXYVAZea-CYLzOknlfQSOM8013tDYOHkFNHHk32sa3nnTeU5AfNyjRaA4QloG0tvgBH-pqdY-Okn3C4W7PPEGb5vlXYWAXhk_zWdaiB7cj8Yf3eGFdLwcys3rxaZd5TPg0lk2Hk5ASemdT48FrmJIdU9GFQC6HTzGKgZ_fLzrGZnJiBFqoomAWZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAS5TYFuAGtf-p0XpdmrdjantM1iddY-zOf7UDDKcWaonAbd6h4iwf3zRycYWGHVcyj0NMDp7CWEkzgwC3F9FGg8DAS4eaHMdALhHIAOII3d-xlItmh6eNlkgw-fOBkreDC4eAdltYuVKCknTpEyRnrSwiTM9ZKI27c2hkhJ0rGkDutk3Aczjp436JC2MU-iUZ8yYbf0zLbmH12xm53NaR-806Q8oAcN9aSyEc6qaJGu4XlxDI80MWmnkuc4a4WD5YUR8Ma4uAdgtOHF4Qr3jFxV-3xhqWypawqA1oGmxihu3kNihtg4mAWmU4nDyhKVXxBiv6_qsonlMivakdssblHjCBeipARcPAAFxcRXllxPIT4i6vi7AKSUYBg0syCtU6anJotKofOkeFQFd2TybLD_O4w-jSWDyRy_NBNnehIb2Ncm5bXdvrjEiHwGoT5Sg1tZL4LlwSbkq4sWKjLk-eSF5-rV_oyxGlavnJAEsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFwEW66Lr2p_qxELinvkpP1xFdpM9UxpuPAdRjjUiQQVfPQHc9bLhJFO4NpxCDnatoPtsbhc_InGqGextuAEBEmEWBQE1Ni2YbyDFmOU8PeC4_EEwBIQkMXKviTzJnKGZqhYWPAHwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLgE3vvqdgMYo-4s_f1MWkSwXVCagrZqD23gIR9Y28cyrCQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgABzXHIr-GnGfLl6D_OeUH7mjE-K5JiSAr6aGddz6tksgoB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDkBlqEGQhG1K8NNJlh4dQck6NVSrpzo-uVJLH0UqeZudRcAqQo6KIPhdezV26TVKEkCtWuqotEd7mZ3BHUPkF8gViA=)
 (staged_ledger_diff
  ((diff
    (((completed_works ())
      (commands
       (((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
                 (amount 1000000001))))))
            (signer B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
            (signature
             (12111743824613875246396256599696584946741163393155172960494343780790554589057
              26455993013160231973660641045470494372603616753978130418498772880275121307241)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz)
                 (amount 1000000001))))))
            (signer B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
            (signature
             (14795072409126491535671281351674037834312602328711686842306942019865081370265
              7810660103212599245108730171345387245498159346522336632834273532276077787689)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
                 (amount 1000000001))))))
            (signer B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
            (signature
             (12991445923922625997917334482570043173055660561511726223038392605694129396534
              12446396713246041205482585153536263013924378293697309357016177558779569394961)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
                 (amount 1000000001))))))
            (signer B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
            (signature
             (1529834518509102195046878086307110115729852588670168723373213029014368191007
              8899291178189602445857900304577868087065006720018487680720931356069638441487)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD)
                 (amount 1000000001))))))
            (signer B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
            (signature
             (23292983422643254614726749143961450356830357756240441304945704220123822142259
              28680236673311287066346537227527112522791386462024177198295928417395933047336)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis)
                 (amount 1000000001))))))
            (signer B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
            (signature
             (18340963624502325597854862749338808638866357252684600127945805750738989715326
              20904615230053119450113429686420536769745681190870885891209622695105214071979)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
                 (amount 1000000001))))))
            (signer B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
            (signature
             (22499651728538207005910357716049978340631095673070502882028605031745076772395
              21266536673826554532093395738082641944736479358210082051896629070545311602022)))))
         (status Applied))))
      (coinbase (One ())) (internal_command_statuses (Applied)))
     ()))))
 (delta_transition_chain_proof
  (6015213778799164743705381332887935226819166012453542567863482729120123228169
   ()))
 (protocol_version ((major 1) (minor 0) (patch 0)))
 (proposed_protocol_version ())
 (accounts_accessed
  ((2
    ((public_key B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      1756052024613657634730554264564165361515062420964192359191855470145283983189)
     (delegate (B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (1
    ((public_key B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 98999999999) (nonce 1)
     (receipt_chain_hash
      14724034866503804719874943167124323851595977937051716261242157735099618131240)
     (delegate (B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (14
    ((public_key B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (3
    ((public_key B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      16097722112531256871937176655429045871577436884363597261289761147678877237138)
     (delegate (B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (15
    ((public_key B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (6
    ((public_key B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      3789829474818306949906721224783620372752646928473927977428294954344374533872)
     (delegate (B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (7
    ((public_key B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (5
    ((public_key B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      8533797999234991471367202436629983958250732378960523831599964589517571228325)
     (delegate (B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (11
    ((public_key B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (0
    ((public_key B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 10000000000000000) (nonce 1)
     (receipt_chain_hash
      23293976437428080852645890265900229412344252883925841424431974907470362218153)
     (delegate (B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (4
    ((public_key B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      11341467036951506593129937196842083980413513803534502611689999876031423969561)
     (delegate (B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (8
    ((public_key B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1020000000000) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))))
 (accounts_created ())
 (tokens_used
  ((0x0000000000000000000000000000000000000000000000000000000000000001 ()))))
   |sexp}

let sample_block_json =
  {json|
{
  "version": 3,
  "data": {
    "scheduled_time": "1676398307700",
    "protocol_state": {
      "previous_state_hash": "3NK7737N7wtHWHqCLsXbtHb5c3UWpPvGyhBBj9QJcAtqGtaXC1AA",
      "body": {
        "genesis_state_hash": "3NK7737N7wtHWHqCLsXbtHb5c3UWpPvGyhBBj9QJcAtqGtaXC1AA",
        "blockchain_state": {
          "staged_ledger_hash": {
            "non_snark": {
              "ledger_hash": "jxETnrUY5t2VqubaYN4baZr1BcmzrhQ8aSKFBd5PJRRmGuhPdkk",
              "aux_hash": "UYV8jYxDVJLZttXEJskc45QrrjVg91cwiDbZgpmpHUzVaXUT5A",
              "pending_coinbase_aux": "XH9htC21tQMDKM6hhATkQjecZPRUGpofWATXPkjB5QKxpTBv7H"
            },
            "pending_coinbase_hash": "2n1uyi3KnXW5H9scVb7fz8aoKVCAZ5bi2GgjLxtGEenFJdbcMWdV"
          },
          "genesis_ledger_hash": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
          "ledger_proof_statement": {
            "source": {
              "first_pass_ledger": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
              "second_pass_ledger": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
              "pending_coinbase_stack": {
                "data": "4QNrZFBTDQCPfEZqBZsaPYx8qdaNFv1nebUyCUsQW9QUJqyuD3un",
                "state": {
                  "init": "4Yx5U3t3EYQycZ91yj4478bHkLwGkhDHnPbCY9TxgUk69SQityej",
                  "curr": "4Yx5U3t3EYQycZ91yj4478bHkLwGkhDHnPbCY9TxgUk69SQityej"
                }
              },
              "local_state": {
                "stack_frame": "0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C",
                "call_stack": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "full_transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "excess": {
                  "magnitude": "0",
                  "sgn": [
                    "Pos"
                  ]
                },
                "supply_increase": {
                  "magnitude": "0",
                  "sgn": [
                    "Pos"
                  ]
                },
                "ledger": "jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd",
                "success": true,
                "account_update_index": "0",
                "failure_status_tbl": [],
                "will_succeed": true
              }
            },
            "target": {
              "first_pass_ledger": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
              "second_pass_ledger": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
              "pending_coinbase_stack": {
                "data": "4QNrZFBTDQCPfEZqBZsaPYx8qdaNFv1nebUyCUsQW9QUJqyuD3un",
                "state": {
                  "init": "4Yx5U3t3EYQycZ91yj4478bHkLwGkhDHnPbCY9TxgUk69SQityej",
                  "curr": "4Yx5U3t3EYQycZ91yj4478bHkLwGkhDHnPbCY9TxgUk69SQityej"
                }
              },
              "local_state": {
                "stack_frame": "0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C",
                "call_stack": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "full_transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "excess": {
                  "magnitude": "0",
                  "sgn": [
                    "Pos"
                  ]
                },
                "supply_increase": {
                  "magnitude": "0",
                  "sgn": [
                    "Pos"
                  ]
                },
                "ledger": "jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd",
                "success": true,
                "account_update_index": "0",
                "failure_status_tbl": [],
                "will_succeed": true
              }
            },
            "connecting_ledger_left": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
            "connecting_ledger_right": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
            "supply_increase": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "fee_excess": [
              {
                "token": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
                "amount": {
                  "magnitude": "0",
                  "sgn": [
                    "Pos"
                  ]
                }
              },
              {
                "token": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
                "amount": {
                  "magnitude": "0",
                  "sgn": [
                    "Pos"
                  ]
                }
              }
            ],
            "sok_digest": null
          },
          "timestamp": "1676398307700",
          "body_reference": "fff2f336633a60b222c23a2ff28467c7cd72fbc525855c1cbea323ecddf7b29d"
        },
        "consensus_state": {
          "blockchain_length": "2",
          "epoch_count": "0",
          "min_window_density": "6",
          "sub_window_densities": [
            "1",
            "0",
            "0"
          ],
          "last_vrf_output": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
          "total_currency": "10016120000000000",
          "curr_global_slot": {
            "slot_number": ["Since_hard_fork","6"],
            "slots_per_epoch": "576"
          },
          "global_slot_since_genesis": ["Since_genesis","6"],
          "staking_epoch_data": {
            "ledger": {
              "hash": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
              "total_currency": "10016100000000000"
            },
            "seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "epoch_length": "1"
          },
          "next_epoch_data": {
            "ledger": {
              "hash": "jxWeLYSia8TdyUCVupiciBjxqqR1wXFRhTBvbZGwybDYLohXopX",
              "total_currency": "10016100000000000"
            },
            "seed": "2vbhjwHdFZqQaG1zZVkrnHacQba792hNoPuBd4KLTnMgwCSP5f4d",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK7737N7wtHWHqCLsXbtHb5c3UWpPvGyhBBj9QJcAtqGtaXC1AA",
            "epoch_length": "3"
          },
          "has_ancestor_in_same_checkpoint_window": true,
          "block_stake_winner": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "block_creator": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "coinbase_receiver": "B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo",
          "supercharge_coinbase": true
        },
        "constants": {
          "k": "24",
          "slots_per_epoch": "576",
          "slots_per_sub_window": "2",
          "delta": "0",
          "genesis_state_timestamp": "1548878400000"
        }
      }
    },
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAACyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAAOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BvwlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAphReNqY2RNR6xs6SF5-jbqYXopjxCDzoibTKCa9Rxhzf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAEvwOjTlWCgsCMWjWpRghNlWQE8N9FewsLuEoPGubd7HQHCYmpoFFNIbqXUE_DqAwz11zHwq9_mMsdKKmmDte4PFwGFWckwTe35TyNm1Niq88nCr1wqszmKWu9My4OaUN68NQGdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQGtC9t5svFvTRQn4Nr-cMBjEPpGBrk-tEKCU4-D2ijxPwGV0WIswKfy24qZ2BVlNNVyB6rzu8alpqGjFc2SQmiCHwFS0reBvhwwDB3LQCBfYCQHWpkLPtZAaF6khi9l6UbpGgE2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAABcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4BDlAZ71lbeW-HLtrodN8-a9HpRCSu17pNesX-WuIlJBUBzs6SSvEomyJvu2y--Am5RCKp2R8Hgq2g2H78g9AZuRsBSk7p2M7zfnBNV4NuK9QsaWRm4nGX4WblpKyHr28XqSQB3n5X7QI17RMV7nx2WC_oXvE0EFcadTe81705GfJm7B4BfqjA-yV-URjlSNnH1Z9YWMoVO594UGIxPSUOJOIDKRQBnVPIW9vIufiV_TzyhUCa3iTQd8ax-4hL6O0DpgkgehUBmYTeWtMJHFI_kNtnklJrNrPQk2vaiqiqghEnSOGq-y0B0j1EVVxWkyQGfYKBdjKktIvjFCZxAaCYcxlyddAoTwUAAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAcMYHYfQq0qZzsiFs9TeUbC8oyswbr7OjcoahyvA78QdASiIwnFkuQs0GpeogsVFT1hoqNaHlrPxjvVCgO4_lig6Ac_m9fzHUjk9y_yUElbCuoSZ0yIorhrdEg0PvszZOJIzARfm_NoAYyHSb2jilosISHY2B_gy-a2wuqcaFbkveYglAf_bTpCddyllde8WLbcxWBaTqK4aJijp17EU9uZIMjAKAUASitwyPOzSS19N7_g0vpYMkKXJfRbObRI-3oyVsr88AAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPACP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwcBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAA8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBt2Z2Ql6HY3BcSnLE6gxakcHe6oNmQPRnIuciJP6PlEMkxFg96rSncZ6lI7T1YmX1kb9UTfY8tIEqLV7B8ZfxwUAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsB1EsiOTZOB4lB-rhHtowcba9M0zzvJ--ghUBS4RJqhw4BA_s2pG54hVSYXxPwaMdK4ko36E6cBmw8QSkCDAJoAQEBeMt_EQj_Mj7XIQA1qtI54ZYGHx7r80FIwmWEAhM9UAcBEDdmitoyunH7NCrgAZf_-UEnOr6ftLtFR23A66Llzh4B_duZ0AJg1WK-uayaHn7di7Z_q_hI0geY3cRL87PjQzQBy4Bg-tI3rKvBUoUw0cKB2xodcB9SmG_urppHNmVFuAsB2TwlrTTBFZYLae1PZY5eylm0lHeq-X9jF1v364JkGDkBptZkJiOve5lib6jfaoqJsYo_LQ7AUyP1s39p43pgIisBOW0qhQlwxLdlmvnPBQ3UFDk6WiURVgnsVZd4gXy_5gYBX41FSQNwr56cZdku_ZOW17EWJCs5tdFwQAYjD6bj_RwBFj7Z8vbR9xM_jV5N7vlIG2qZ3JenFOR6KD9ESqzp4CcB0zc4EtZU5P32Izpktkrf061GJ83mpdbXG4mD9j9mTCkBTMVLMejFlc_Ym2R8zwv5VCO2FQXJoST5pQG3-FIABTIBzAlqGdXjaCmuXHdv9DgTS2upfQyF6xaaBdt0INYcPRoBhnv-hGcgXzA_JLlMlxQ7tgiPIxqJy3GSw865aEdRfw0Bi8xLg5ERG4_WJ1D02y8FBJotAZF0Z_LIIhrZ9OG4sQABfE_2OwZ6RG13nh-5zgU2eub0HP_m_YlnEwuhZ0jHPAMBafxzT2qv8y7gICuSbmfRA8qI0OgzvgZ49PdSkaaY7zIB4i_MC-fg9HbN7iLECVbnILy6j3uVaZNCuQmHxs_ccTABIeomYvoTflIbEOcNR4BZGPc2vp-h6lDAaSlegJFT0w4BNV8KCkdC7YE0Uab5d2iEDZF6Vvm2ZxcEGTjP2VMK1DcBZW4VBuwhUXqAieE42n7RTbRe2KGx6PDxo65FryquySoBhJZ8MnB0A6hoc-3LMlPaDUL1skkSGeaYvb9Zk806HDoBJVOW_GzCFinO9qONnJhuUDFrtC4fKKPhr4cfdWn6yw0BRs_rddU_qtvcYFVMmbzdaoUl8qb057CoI-1A3VD8DQABaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSQBbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBEvaoh_mbxRUz5lGYEMed1_582A-NjLSDpPZSZGfKcx4BO9d3ZgCHqNalqD9kAAa8p8E238w1kwjrxET-AOaCaxgBcxdru8TDWkDLAvjZchjKzZjyY91Yta6PwbgV8snF3SkAATxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGAbWUMVDxqsXeU2I7i61f-mNljqu8Y456Yyex_6krMXoeAbJzsLxx_-vxxcTgFIpl6QZbJIiHu-iZYH0C8RcMe0YCAeVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQnAXUz3r-qPXovuFZ9Gb9iVhRsorwSG1I8--QnkuCzUyIsAVf6n7Zxvg2KMRUE8TEiEYahi-BEdxBzDEu6p0yjSN4yAfTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AQGF71eQABy-bk4IlED8UiScebtNMSCK98XYgQjcx4kWAdw-P8ei6BNwYFA1-WDLiFT7gzUZhsyIM_3fev86_LAVAVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEEAecivws4T8FIO6UNiUYE3FVG5DTEyrYAHMK8WfrHmFoqAXpKhKdWXxXytcpMDc3xn5mTcQm5ayHnpUHRQgEkFlE2AegJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMAaZhYz7Ulx7DpQE427Z8fUhCv_7vsQPljZNAGvcE9MwdAfaBPnHxIfuqZh3LgJRe8Rg-w88Qt8Y3GEpQOxqukQgLAVK-m_DwuxGRnVBt8Du4n_a1OpLW-A8Blh3FQCVcmFQgAX5Ysk_SKe-xbhIFpktcu5hlZq-EGuxqTY2lQgBdOXYVAZea-CYLzOknlfQSOM8013tDYOHkFNHHk32sa3nnTeU5AfNyjRaA4QloG0tvgBH-pqdY-Okn3C4W7PPEGb5vlXYWAXhk_zWdaiB7cj8Yf3eGFdLwcys3rxaZd5TPg0lk2Hk5ASemdT48FrmJIdU9GFQC6HTzGKgZ_fLzrGZnJiBFqoomAWZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAS5TYFuAGtf-p0XpdmrdjantM1iddY-zOf7UDDKcWaonAbd6h4iwf3zRycYWGHVcyj0NMDp7CWEkzgwC3F9FGg8DAS4eaHMdALhHIAOII3d-xlItmh6eNlkgw-fOBkreDC4eAdltYuVKCknTpEyRnrSwiTM9ZKI27c2hkhJ0rGkDutk3Aczjp436JC2MU-iUZ8yYbf0zLbmH12xm53NaR-806Q8oAcN9aSyEc6qaJGu4XlxDI80MWmnkuc4a4WD5YUR8Ma4uAdgtOHF4Qr3jFxV-3xhqWypawqA1oGmxihu3kNihtg4mAWmU4nDyhKVXxBiv6_qsonlMivakdssblHjCBeipARcPAAFxcRXllxPIT4i6vi7AKSUYBg0syCtU6anJotKofOkeFQFd2TybLD_O4w-jSWDyRy_NBNnehIb2Ncm5bXdvrjEiHwGoT5Sg1tZL4LlwSbkq4sWKjLk-eSF5-rV_oyxGlavnJAEsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFwEW66Lr2p_qxELinvkpP1xFdpM9UxpuPAdRjjUiQQVfPQHc9bLhJFO4NpxCDnatoPtsbhc_InGqGextuAEBEmEWBQE1Ni2YbyDFmOU8PeC4_EEwBIQkMXKviTzJnKGZqhYWPAHwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLgE3vvqdgMYo-4s_f1MWkSwXVCagrZqD23gIR9Y28cyrCQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgABzXHIr-GnGfLl6D_OeUH7mjE-K5JiSAr6aGddz6tksgoB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDkBlqEGQhG1K8NNJlh4dQck6NVSrpzo-uVJLH0UqeZudRcAqQo6KIPhdezV26TVKEkCtWuqotEd7mZ3BHUPkF8gViA=",
    "staged_ledger_diff": {
      "diff": [
        {
          "completed_works": [],
          "commands": [
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
                  "signature": "7mXFbws8zFVHDngRcRgUAs9gvWcJ4ZDmXrjXozyhhNyM1KrR2XsBzSQGDSR4ghD5Dip13iFrnweGKB5mguDmDLhk1h87etB8"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
                  "signature": "7mXJfHCobCvXcpAZRKgqmnrsewVuEcUaQ2dkjfYuodwqR2bYZUZkmJZmNoTKM9HJ8tV6hW7pRFjL7oeNvzbRiPGt9pyf93hJ"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
                  "signature": "7mX5n1jgC1m2jhuo7JMks6veDCNofPXZwFeZLv47ok83RVQkftUFKcD35k4RTo2v7fyroQjB9LSRJHm3S7RQfzesJwJtcFqS"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
                  "signature": "7mX2irhVDZy7bbc6K6q21hpQiB3x7LKw9v6jS5tZBzzEdroQFc5hzT1MwgzK2CavFX6ZkAcHYaxKAz8qwAdruerR7mbFLKa6"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
                  "signature": "7mX5N43QQWMjKoXo2bAwPo6jvHNfpVcMse51uy6eXumfWiChmWQb2hejbTn9MaNsYcpNhDpd4oFnsdzqzDveaRuq8xRRJxmK"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
                  "signature": "7mXFA6dbZCNV7bowrxiWK5zCST3YurHRNiC6m7n39jUgu6jC7VMV3g9xLEP8sraVfoUHhsfaMyYgdXAXmYEgU3WJwdZdqe8Q"
                }
              ],
              "status": [
                "Applied"
              ]
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
                      "nonce": "0",
                      "valid_until": ["Since_genesis","4294967295"],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
                  "signature": "7mX4KgEbFoWZjtNn4ihvSpVaEKGMUVXWVAJuvyrPWWst1miV7eBXLnhRc1V5RfCJ2bvLDrTdCqEhJmaUJMwdTgCF7rFGYcFY"
                }
              ],
              "status": [
                "Applied"
              ]
            }
          ],
          "coinbase": [
            "One",
            null
          ],
          "internal_command_statuses": [
            [
              "Applied"
            ]
          ]
        },
        null
      ]
    },
    "delta_transition_chain_proof": [
      "jwApG9UCFomnbgkG3Bn8NYisGGLdnwHBqKka9bGCuc1BFPvN4jK",
      []
    ],
    "protocol_version": { "major": 1, "minor": 0, "patch": 0 },
    "accounts_accessed": [
      [
        2,
        {
          "public_key": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2n1AGrTWkL9TfbJA11CvoGBBtqsJ9EyF4ZTqFYEEJPjHA6ycdnau",
          "delegate": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        1,
        {
          "public_key": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "98999999999",
          "nonce": "1",
          "receipt_chain_hash": "2mzpSLHbM5rsMb39yLCacPLB5xHQfHeFeBHkT3nT7FWvfxEGoXyy",
          "delegate": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        14,
        {
          "public_key": "B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1001000000001",
          "nonce": "0",
          "receipt_chain_hash": "2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm",
          "delegate": "B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        3,
        {
          "public_key": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "998999999999",
          "nonce": "1",
          "receipt_chain_hash": "2n1d1nTxxRYqNw2na1ftzZZj4PMawTBrwjdfseFvs7dCpAYcCSRG",
          "delegate": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        15,
        {
          "public_key": "B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1001000000001",
          "nonce": "0",
          "receipt_chain_hash": "2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm",
          "delegate": "B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        6,
        {
          "public_key": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "998999999999",
          "nonce": "1",
          "receipt_chain_hash": "2n2LjxUVcHwExytU4mmhfD9sWfwimxH6Y76hxx1mPEmqEGj256fT",
          "delegate": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        7,
        {
          "public_key": "B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1001000000001",
          "nonce": "0",
          "receipt_chain_hash": "2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm",
          "delegate": "B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        5,
        {
          "public_key": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "998999999999",
          "nonce": "1",
          "receipt_chain_hash": "2n1mH3T8FkE39CjK8Nvu6arQHwPVtrZfN4YAenRP6PsPukSHKqYQ",
          "delegate": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        11,
        {
          "public_key": "B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1001000000001",
          "nonce": "0",
          "receipt_chain_hash": "2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm",
          "delegate": "B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        0,
        {
          "public_key": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "10000000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2n1oHBHCbsNxHGhzUgtRQ7EjaZtRUJJQaLY3iJKrFx1vHYCx285b",
          "delegate": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        4,
        {
          "public_key": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2mzi3baSqb9RvoXijUo4aF9uGPCFeKN1ovmASASJ4HhSWJFS3e35",
          "delegate": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ],
      [
        8,
        {
          "public_key": "B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1020000000000",
          "nonce": "0",
          "receipt_chain_hash": "2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm",
          "delegate": "B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo",
          "voting_for": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
          "timing": [
            "Untimed"
          ],
          "permissions": {
            "edit_state": [
              "Signature"
            ],
            "access": [
              "None"
            ],
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "set_delegate": [
              "Signature"
            ],
            "set_permissions": [
              "Signature"
            ],
            "set_verification_key": [
              "Signature"
            ],
            "set_zkapp_uri": [
              "Signature"
            ],
            "edit_action_state": [
              "Signature"
            ],
            "set_token_symbol": [
              "Signature"
            ],
            "increment_nonce": [
              "Signature"
            ],
            "set_voting_for": [
              "Signature"
            ],
            "set_timing": [
              "Signature"
            ]
          },
          "zkapp": null
        }
      ]
    ],
    "accounts_created": [],
    "tokens_used": [
      [
        "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
        null
      ]
    ]
  }
}
    |json}
