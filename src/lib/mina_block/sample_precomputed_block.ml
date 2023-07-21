(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1689848375258)
 (protocol_state
  ((previous_state_hash
    10115977094844455374713551278657613163509605061976408400723445818495653211738)
   (body
    ((genesis_state_hash
      10115977094844455374713551278657613163509605061976408400723445818495653211738)
     (blockchain_state
      ((staged_ledger_hash
        ((non_snark
          ((ledger_hash
            11235129808339719828441077968248644529442490453632411531320497062745766305489)
           (aux_hash
            "\248-\143\194\028\"+\018\143\210\215\243\200'\001\001\250\238=\183b\191k*`\150A\205\167\130z&")
           (pending_coinbase_aux
            "\147\141\184\201\248,\140\181\141?>\244\253%\0006\164\141&\167\018u=/\222Z\189\003\168\\\171\244")))
         (pending_coinbase_hash
          27993047687139103827798614125063477283923971454338719747883093420345271612401)))
       (genesis_ledger_hash
        10421238217240502528350368624667864609415417947604085583395946985055770775615)
       (ledger_proof_statement
        ((source
          ((first_pass_ledger
            10421238217240502528350368624667864609415417947604085583395946985055770775615)
           (second_pass_ledger
            10421238217240502528350368624667864609415417947604085583395946985055770775615)
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
            10421238217240502528350368624667864609415417947604085583395946985055770775615)
           (second_pass_ledger
            10421238217240502528350368624667864609415417947604085583395946985055770775615)
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
          10421238217240502528350368624667864609415417947604085583395946985055770775615)
         (connecting_ledger_right
          10421238217240502528350368624667864609415417947604085583395946985055770775615)
         (supply_increase ((magnitude 0) (sgn Pos)))
         (fee_excess
          ((fee_token_l
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (fee_excess_l ((magnitude 0) (sgn Pos)))
           (fee_token_r
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (fee_excess_r ((magnitude 0) (sgn Pos)))))
         (sok_digest ())))
       (timestamp 1689848375258)
       (body_reference
        "eQ\232\246f\144\187\222\166xoR\245c@\216Xw\161\180\209a\241:\007\184\140s\006\228\213\141")))
     (consensus_state
      ((blockchain_length 2) (epoch_count 0) (min_window_density 77)
       (sub_window_densities (2 7 7 7 7 7 7 7 7 7 7))
       (last_vrf_output
        "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000")
       (total_currency 10016820000000000)
       (curr_global_slot
        ((slot_number (Since_hard_fork 6)) (slots_per_epoch 7140)))
       (global_slot_since_genesis (Since_genesis 6))
       (staking_epoch_data
        ((ledger
          ((hash
            10421238217240502528350368624667864609415417947604085583395946985055770775615)
           (total_currency 10016100000000000)))
         (seed 0) (start_checkpoint 0) (lock_checkpoint 0) (epoch_length 1)))
       (next_epoch_data
        ((ledger
          ((hash
            10421238217240502528350368624667864609415417947604085583395946985055770775615)
           (total_currency 10016100000000000)))
         (seed
          11097254031198438328229081175959322858342266757425965220770466547940953006797)
         (start_checkpoint 0)
         (lock_checkpoint
          10115977094844455374713551278657613163509605061976408400723445818495653211738)
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
      ((k 290) (slots_per_epoch 7140) (slots_per_sub_window 7) (delta 0)
       (genesis_state_timestamp 1600251300000)))))))
 (protocol_state_proof
  _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAABB3qgkt6gpTffkVSfK3I-5Xk-75uvmesJrb8WSS3KzIQDcLZHIyY2X88GsySXlYnJ57rqes-D_N8sf3w9ONKuhM_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAOjxhMkfRBN2MXLSPWcnL5QI32cJLGrzhbeWwuamVTzfyukoCMt_wXVK8rrE2b7q_fg_8LHDGGp_TM01WH1LuDQGRcm3zFOqITIObmcmMDASKyW_ZlWNNo62HMJuHBr0XMgFE_TW806pKZPj7W6ANTt69OqzyXltpeKlzouEjCh-yFgE2YsugvZ6JNdgw_IvY9y4lGs6onyl4Lh2yBCB_Zo_KIgGyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAEOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BgGP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgGmFF42pjZE1HrGzpIXn6NupheimPEIPOiJtMoJr1HGHAHf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAABL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4AAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPADfFIsPJvAfi1Zu3B5RbKkhShEa2pj61ErHDi6kSQlXOwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwcBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAA8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBtRv8EIE_EVG8Rsjo4uOrzQLQMyTtbam_7_JAw2_Qt2Lx-TPYOS9LiZFIb7baLp_6V1mDxvDtwMxdGN4eq69RU1AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBX-1mkCiImxySpfFBYzP5cEPkG3JHlL561JSxCetGMAgBpBtvoIGVFJ3-cGWI02-oTRl2ia73isB0mXR2WWeGgQMBaXlKoIgKPevyE8Q3Is6g9kqXaFp6s5Pa9ImS8BYyrBUBdmdkJeh2NwXEpyxOoMWpHB3uqDZkD0ZyLnIiT-j5RDIBTEWD3qtKdxnqUjtPViZfWRv1RN9jy0gSotXsHxl_HBQBqQo6KIPhdezV26TVKEkCtWuqotEd7mZ3BHUPkF8gViABvIPH4nPEEVtGX6AszQsLm552SN2F5dfInpLzBbCiAS8BngFKmlOUDSIxdudcKwoPfGZTfq9tUsDA9A1dj8Zu5TUB1EsiOTZOB4lB-rhHtowcba9M0zzvJ--ghUBS4RJqhw4BA_s2pG54hVSYXxPwaMdK4ko36E6cBmw8QSkCDAJoAQEBeMt_EQj_Mj7XIQA1qtI54ZYGHx7r80FIwmWEAhM9UAcBEDdmitoyunH7NCrgAZf_-UEnOr6ftLtFR23A66Llzh4B_duZ0AJg1WK-uayaHn7di7Z_q_hI0geY3cRL87PjQzQBy4Bg-tI3rKvBUoUw0cKB2xodcB9SmG_urppHNmVFuAsB2TwlrTTBFZYLae1PZY5eylm0lHeq-X9jF1v364JkGDkBptZkJiOve5lib6jfaoqJsYo_LQ7AUyP1s39p43pgIisBOW0qhQlwxLdlmvnPBQ3UFDk6WiURVgnsVZd4gXy_5gYBX41FSQNwr56cZdku_ZOW17EWJCs5tdFwQAYjD6bj_RwBFj7Z8vbR9xM_jV5N7vlIG2qZ3JenFOR6KD9ESqzp4CcB0zc4EtZU5P32Izpktkrf061GJ83mpdbXG4mD9j9mTCkBTMVLMejFlc_Ym2R8zwv5VCO2FQXJoST5pQG3-FIABTIBzAlqGdXjaCmuXHdv9DgTS2upfQyF6xaaBdt0INYcPRoBhnv-hGcgXzA_JLlMlxQ7tgiPIxqJy3GSw865aEdRfw0Bi8xLg5ERG4_WJ1D02y8FBJotAZF0Z_LIIhrZ9OG4sQABfE_2OwZ6RG13nh-5zgU2eub0HP_m_YlnEwuhZ0jHPAMBafxzT2qv8y7gICuSbmfRA8qI0OgzvgZ49PdSkaaY7zIB4i_MC-fg9HbN7iLECVbnILy6j3uVaZNCuQmHxs_ccTABIeomYvoTflIbEOcNR4BZGPc2vp-h6lDAaSlegJFT0w4BNV8KCkdC7YE0Uab5d2iEDZF6Vvm2ZxcEGTjP2VMK1DcBZW4VBuwhUXqAieE42n7RTbRe2KGx6PDxo65FryquySoAAYSWfDJwdAOoaHPtyzJT2g1C9bJJEhnmmL2_WZPNOhw6ASVTlvxswhYpzvajjZyYblAxa7QuHyij4a-HH3Vp-ssNAUbP63XVP6rb3GBVTJm83WqFJfKm9OewqCPtQN1Q_A0AAWkKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kAW6OhvPbUUo9_az3dQZoC-ow0OhFw8DWV_pMZMlaGyUoARL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMeATvXd2YAh6jWpag_ZAAGvKfBNt_MNZMI68RE_gDmgmsYAXMXa7vEw1pAywL42XIYys2Y8mPdWLWuj8G4FfLJxd0pATxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGAbWUMVDxqsXeU2I7i61f-mNljqu8Y456Yyex_6krMXoeAbJzsLxx_-vxxcTgFIpl6QZbJIiHu-iZYH0C8RcMe0YCAeVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQnAXUz3r-qPXovuFZ9Gb9iVhRsorwSG1I8--QnkuCzUyIsAVf6n7Zxvg2KMRUE8TEiEYahi-BEdxBzDEu6p0yjSN4yAfTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AQGF71eQABy-bk4IlED8UiScebtNMSCK98XYgQjcx4kWAdw-P8ei6BNwYFA1-WDLiFT7gzUZhsyIM_3fev86_LAVAVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEEAecivws4T8FIO6UNiUYE3FVG5DTEyrYAHMK8WfrHmFoqAXpKhKdWXxXytcpMDc3xn5mTcQm5ayHnpUHRQgEkFlE2AegJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMAaZhYz7Ulx7DpQE427Z8fUhCv_7vsQPljZNAGvcE9MwdAfaBPnHxIfuqZh3LgJRe8Rg-w88Qt8Y3GEpQOxqukQgLAVK-m_DwuxGRnVBt8Du4n_a1OpLW-A8Blh3FQCVcmFQgAX5Ysk_SKe-xbhIFpktcu5hlZq-EGuxqTY2lQgBdOXYVAZea-CYLzOknlfQSOM8013tDYOHkFNHHk32sa3nnTeU5AfNyjRaA4QloG0tvgBH-pqdY-Okn3C4W7PPEGb5vlXYWAXhk_zWdaiB7cj8Yf3eGFdLwcys3rxaZd5TPg0lk2Hk5ASemdT48FrmJIdU9GFQC6HTzGKgZ_fLzrGZnJiBFqoomAWZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAAEuU2BbgBrX_qdF6XZq3Y2p7TNYnXWPszn-1AwynFmqJwG3eoeIsH980cnGFhh1XMo9DTA6ewlhJM4MAtxfRRoPAwEuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHgHZbWLlSgpJ06RMkZ60sIkzPWSiNu3NoZISdKxpA7rZNwHM46eN-iQtjFPolGfMmG39My25h9dsZudzWkfvNOkPKAHDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLgHYLThxeEK94xcVft8YalsqWsKgNaBpsYobt5DYobYOJgFplOJw8oSlV8QYr-v6rKJ5TIr2pHbLG5R4wgXoqQEXDwFxcRXllxPIT4i6vi7AKSUYBg0syCtU6anJotKofOkeFQFd2TybLD_O4w-jSWDyRy_NBNnehIb2Ncm5bXdvrjEiHwGoT5Sg1tZL4LlwSbkq4sWKjLk-eSF5-rV_oyxGlavnJAEsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFwEW66Lr2p_qxELinvkpP1xFdpM9UxpuPAdRjjUiQQVfPQHc9bLhJFO4NpxCDnatoPtsbhc_InGqGextuAEBEmEWBQABNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4BN776nYDGKPuLP39TFpEsF1QmoK2ag9t4CEfWNvHMqwkB4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xwBa98jDsB6kVMZxgatkwxB3X8JciKtondqSE51X-stSRwB7oAr6vTduvO2lphonX52tnDKpl3b2SGXInqwyN-6NiQBtcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xABwEQWKAElGddv7wEHQ03Fa7F059FhDN4vyG1qpyt1rRoBzXHIr-GnGfLl6D_OeUH7mjE-K5JiSAr6aGddz6tksgoB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDkBlqEGQhG1K8NNJlh4dQck6NVSrpzo-uVJLH0UqeZudRcAzioSgyJqnNMLk4KXtDxWzAUyzyCAcSQAOd4bI87hZws=)
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
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
                 (amount 1000000001))))))
            (signer B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz)
            (signature
             (3985507281911194889139485494217955213771157043018616149041262302339791989635
              20218330583434660678698571793559588140423523302755717687249753640727573252523)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R)
                 (amount 1000000001))))))
            (signer B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo)
            (signature
             (21553083009318877164001283562752473611427701611836115817990223249863465863267
              10593666096733975275130461177164571673536399793588215324260414204488213497733)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
                 (amount 1000000001))))))
            (signer B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j)
            (signature
             (7026636994026441883914112223314814955069643147839253136595972284752900864031
              8514336829145956424495315078216193271663870358670975784517439658006729187736)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j)
                 (amount 1000000001))))))
            (signer B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM)
            (signature
             (678992438520489413351108175231319357789032533765918743528861414457128076250
              28604316570673351337286512716237018930808290116142635959260262888345299820918)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
                 (amount 1000000001))))))
            (signer B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
            (signature
             (21686553626894838272364353555318388472143477998260753613397767664842416864243
              13314817713387529676112399909458717751022799228128822160684705795248055807515)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
                 (amount 1000000001))))))
            (signer B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm)
            (signature
             (5841587837065863028636128444733770801813754976076178708938208558594065184668
              12114824567829285033495000154610511014238381971348451097790714732802646110463)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
                 (amount 1000000001))))))
            (signer B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY)
            (signature
             (26131356008680782459373814422164291323844821465045018862396937091892805439754
              22836388835925527755085002208275588700465662783735727194997268825658363422563)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
                 (amount 1000000001))))))
            (signer B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis)
            (signature
             (4298430914060618194208064140705049269684052464938405934221277001096623455129
              22894865588488298574014965787681211591533089676210417275410566849381259794074)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
                 (amount 1000000001))))))
            (signer B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD)
            (signature
             (15118116658634594907508214034143542362858819909391217220801760109144909292867
              24114809989429733800042724057580565868658548356458614554149267529595350615214)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j)
                 (amount 1000000001))))))
            (signer B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2)
            (signature
             (17425837324998289330048325361651877059090237990751743344613819566173069748691
              13129316448041689879677504237989226911931939869393592487670689224584405603365)))))
         (status Applied))
        ((data
          (Signed_command
           ((payload
             ((common
               ((fee 0)
                (fee_payer_pk
                 B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R)
                (nonce 0) (valid_until (Since_genesis 4294967295))
                (memo
                 "\000 \014WQ\192&\229C\178\232\171.\176`\153\218\161\209\229\223Gw\143w\135\250\171E\205\241/\227\168")))
              (body
               (Payment
                ((receiver_pk
                  B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM)
                 (amount 1000000001))))))
            (signer B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R)
            (signature
             (12895306117136817458037588680737311691937842918336283519030143547021181720854
              26144733902740750193411542381053524630471690798587203609873797577669744887938)))))
         (status Applied))))
      (coinbase (One ())) (internal_command_statuses (Applied)))
     ()))))
 (delta_transition_chain_proof
  (10115977094844455374713551278657613163509605061976408400723445818495653211738
   ()))
 (protocol_version ((major 0) (minor 0) (patch 0)))
 (proposed_protocol_version ())
 (accounts_accessed
  ((12
    ((public_key B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      19661891629520091035445657764823652790119546413640729839481628650138410260651)
     (delegate (B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (10
    ((public_key B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      5825308537576172258812290304452216750508838198746420257467283239350771167928)
     (delegate (B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_action_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)
       (set_timing Signature)))
     (zkapp ())))
   (2
    ((public_key B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1002000000002) (nonce 1)
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
   (16
    ((public_key B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      2172885967341007848883570803506127489869983609097736902541539888976275066116)
     (delegate (B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2))
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
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      21133762550805014181160136992577899669426300703257268243577761909476884907777)
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
   (13
    ((public_key B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      3152436377515287993788929187619170938306623003119149994394364535779665217326)
     (delegate (B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY))
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
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      4023466025980982376138182232018759680945953211039193067328301025266080877006)
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
     (token_symbol "") (balance 1001000000001) (nonce 1)
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
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      22352902723542554975852268548289924398663130477394902604662802802328660149338)
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
   (9
    ((public_key B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1001000000001) (nonce 1)
     (receipt_chain_hash
      11001371326626898280803926196366096044508772451133242368230924118448362515539)
     (delegate (B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j))
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
     (token_symbol "") (balance 1000000000000) (nonce 1)
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
     (token_symbol "") (balance 1002000000002) (nonce 1)
     (receipt_chain_hash
      25594277989494822757549480239898789824213499862209836867184631339272762034467)
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
   (17
    ((public_key B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      19399608589897485686369849756393016837126085857834851400534956941020249448679)
     (delegate (B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R))
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
     (token_symbol "") (balance 1718999999999) (nonce 1)
     (receipt_chain_hash
      21104598045545990974199373284464973541904555984292363591320136906533967336427)
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
    "scheduled_time": "1689848375258",
    "protocol_state": {
      "previous_state_hash": "3NKiigEqgn8ZCsT6q3gVeReVdPu3XiBD6XmqnuvUUQzJ9MLWWKi3",
      "body": {
        "genesis_state_hash": "3NKiigEqgn8ZCsT6q3gVeReVdPu3XiBD6XmqnuvUUQzJ9MLWWKi3",
        "blockchain_state": {
          "staged_ledger_hash": {
            "non_snark": {
              "ledger_hash": "jxghdwXwjDD4SNufjC26dir6PLfjhXCFHodQV4523tUPdwScFP8",
              "aux_hash": "W6iqtzFDC2NgLg7GT4Wat2jSMhcAzN55swE5DYFFFai7B669M9",
              "pending_coinbase_aux": "XH9htC21tQMDKM6hhATkQjecZPRUGpofWATXPkjB5QKxpTBv7H"
            },
            "pending_coinbase_hash": "2n2LwfFqq932Lmk7Nka1RZ6e9PX8i8VNmCq17TfdguoQDC7c9PXm"
          },
          "genesis_ledger_hash": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
          "ledger_proof_statement": {
            "source": {
              "first_pass_ledger": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
              "second_pass_ledger": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
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
              "first_pass_ledger": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
              "second_pass_ledger": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
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
            "connecting_ledger_left": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
            "connecting_ledger_right": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
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
          "timestamp": "1689848375258",
          "body_reference": "6551e8f66690bbdea6786f52f56340d85877a1b4d161f13a07b88c7306e4d58d"
        },
        "consensus_state": {
          "blockchain_length": "2",
          "epoch_count": "0",
          "min_window_density": "77",
          "sub_window_densities": [
            "2",
            "7",
            "7",
            "7",
            "7",
            "7",
            "7",
            "7",
            "7",
            "7",
            "7"
          ],
          "last_vrf_output": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
          "total_currency": "10016820000000000",
          "curr_global_slot": {
            "slot_number": [
              "Since_hard_fork",
              "6"
            ],
            "slots_per_epoch": "7140"
          },
          "global_slot_since_genesis": [
            "Since_genesis",
            "6"
          ],
          "staking_epoch_data": {
            "ledger": {
              "hash": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
              "total_currency": "10016100000000000"
            },
            "seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "epoch_length": "1"
          },
          "next_epoch_data": {
            "ledger": {
              "hash": "jwaNt2QtmqjzLaxrUC39VrGoTsmcRWxUyWHGdPRYzbYybEJaTw4",
              "total_currency": "10016100000000000"
            },
            "seed": "2vbhjwHdFZqQaG1zZVkrnHacQba792hNoPuBd4KLTnMgwCSP5f4d",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NKiigEqgn8ZCsT6q3gVeReVdPu3XiBD6XmqnuvUUQzJ9MLWWKi3",
            "epoch_length": "3"
          },
          "has_ancestor_in_same_checkpoint_window": true,
          "block_stake_winner": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "block_creator": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "coinbase_receiver": "B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo",
          "supercharge_coinbase": true
        },
        "constants": {
          "k": "290",
          "slots_per_epoch": "7140",
          "slots_per_sub_window": "7",
          "delta": "0",
          "genesis_state_timestamp": "1600251300000"
        }
      }
    },
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAABB3qgkt6gpTffkVSfK3I-5Xk-75uvmesJrb8WSS3KzIQDcLZHIyY2X88GsySXlYnJ57rqes-D_N8sf3w9ONKuhM_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAOjxhMkfRBN2MXLSPWcnL5QI32cJLGrzhbeWwuamVTzfyukoCMt_wXVK8rrE2b7q_fg_8LHDGGp_TM01WH1LuDQGRcm3zFOqITIObmcmMDASKyW_ZlWNNo62HMJuHBr0XMgFE_TW806pKZPj7W6ANTt69OqzyXltpeKlzouEjCh-yFgE2YsugvZ6JNdgw_IvY9y4lGs6onyl4Lh2yBCB_Zo_KIgGyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAEOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BgGP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgGmFF42pjZE1HrGzpIXn6NupheimPEIPOiJtMoJr1HGHAHf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAABL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4AAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPADfFIsPJvAfi1Zu3B5RbKkhShEa2pj61ErHDi6kSQlXOwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwcBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAA8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBtRv8EIE_EVG8Rsjo4uOrzQLQMyTtbam_7_JAw2_Qt2Lx-TPYOS9LiZFIb7baLp_6V1mDxvDtwMxdGN4eq69RU1AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBX-1mkCiImxySpfFBYzP5cEPkG3JHlL561JSxCetGMAgBpBtvoIGVFJ3-cGWI02-oTRl2ia73isB0mXR2WWeGgQMBaXlKoIgKPevyE8Q3Is6g9kqXaFp6s5Pa9ImS8BYyrBUBdmdkJeh2NwXEpyxOoMWpHB3uqDZkD0ZyLnIiT-j5RDIBTEWD3qtKdxnqUjtPViZfWRv1RN9jy0gSotXsHxl_HBQBqQo6KIPhdezV26TVKEkCtWuqotEd7mZ3BHUPkF8gViABvIPH4nPEEVtGX6AszQsLm552SN2F5dfInpLzBbCiAS8BngFKmlOUDSIxdudcKwoPfGZTfq9tUsDA9A1dj8Zu5TUB1EsiOTZOB4lB-rhHtowcba9M0zzvJ--ghUBS4RJqhw4BA_s2pG54hVSYXxPwaMdK4ko36E6cBmw8QSkCDAJoAQEBeMt_EQj_Mj7XIQA1qtI54ZYGHx7r80FIwmWEAhM9UAcBEDdmitoyunH7NCrgAZf_-UEnOr6ftLtFR23A66Llzh4B_duZ0AJg1WK-uayaHn7di7Z_q_hI0geY3cRL87PjQzQBy4Bg-tI3rKvBUoUw0cKB2xodcB9SmG_urppHNmVFuAsB2TwlrTTBFZYLae1PZY5eylm0lHeq-X9jF1v364JkGDkBptZkJiOve5lib6jfaoqJsYo_LQ7AUyP1s39p43pgIisBOW0qhQlwxLdlmvnPBQ3UFDk6WiURVgnsVZd4gXy_5gYBX41FSQNwr56cZdku_ZOW17EWJCs5tdFwQAYjD6bj_RwBFj7Z8vbR9xM_jV5N7vlIG2qZ3JenFOR6KD9ESqzp4CcB0zc4EtZU5P32Izpktkrf061GJ83mpdbXG4mD9j9mTCkBTMVLMejFlc_Ym2R8zwv5VCO2FQXJoST5pQG3-FIABTIBzAlqGdXjaCmuXHdv9DgTS2upfQyF6xaaBdt0INYcPRoBhnv-hGcgXzA_JLlMlxQ7tgiPIxqJy3GSw865aEdRfw0Bi8xLg5ERG4_WJ1D02y8FBJotAZF0Z_LIIhrZ9OG4sQABfE_2OwZ6RG13nh-5zgU2eub0HP_m_YlnEwuhZ0jHPAMBafxzT2qv8y7gICuSbmfRA8qI0OgzvgZ49PdSkaaY7zIB4i_MC-fg9HbN7iLECVbnILy6j3uVaZNCuQmHxs_ccTABIeomYvoTflIbEOcNR4BZGPc2vp-h6lDAaSlegJFT0w4BNV8KCkdC7YE0Uab5d2iEDZF6Vvm2ZxcEGTjP2VMK1DcBZW4VBuwhUXqAieE42n7RTbRe2KGx6PDxo65FryquySoAAYSWfDJwdAOoaHPtyzJT2g1C9bJJEhnmmL2_WZPNOhw6ASVTlvxswhYpzvajjZyYblAxa7QuHyij4a-HH3Vp-ssNAUbP63XVP6rb3GBVTJm83WqFJfKm9OewqCPtQN1Q_A0AAWkKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kAW6OhvPbUUo9_az3dQZoC-ow0OhFw8DWV_pMZMlaGyUoARL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMeATvXd2YAh6jWpag_ZAAGvKfBNt_MNZMI68RE_gDmgmsYAXMXa7vEw1pAywL42XIYys2Y8mPdWLWuj8G4FfLJxd0pATxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGAbWUMVDxqsXeU2I7i61f-mNljqu8Y456Yyex_6krMXoeAbJzsLxx_-vxxcTgFIpl6QZbJIiHu-iZYH0C8RcMe0YCAeVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQnAXUz3r-qPXovuFZ9Gb9iVhRsorwSG1I8--QnkuCzUyIsAVf6n7Zxvg2KMRUE8TEiEYahi-BEdxBzDEu6p0yjSN4yAfTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AQGF71eQABy-bk4IlED8UiScebtNMSCK98XYgQjcx4kWAdw-P8ei6BNwYFA1-WDLiFT7gzUZhsyIM_3fev86_LAVAVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEEAecivws4T8FIO6UNiUYE3FVG5DTEyrYAHMK8WfrHmFoqAXpKhKdWXxXytcpMDc3xn5mTcQm5ayHnpUHRQgEkFlE2AegJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMAaZhYz7Ulx7DpQE427Z8fUhCv_7vsQPljZNAGvcE9MwdAfaBPnHxIfuqZh3LgJRe8Rg-w88Qt8Y3GEpQOxqukQgLAVK-m_DwuxGRnVBt8Du4n_a1OpLW-A8Blh3FQCVcmFQgAX5Ysk_SKe-xbhIFpktcu5hlZq-EGuxqTY2lQgBdOXYVAZea-CYLzOknlfQSOM8013tDYOHkFNHHk32sa3nnTeU5AfNyjRaA4QloG0tvgBH-pqdY-Okn3C4W7PPEGb5vlXYWAXhk_zWdaiB7cj8Yf3eGFdLwcys3rxaZd5TPg0lk2Hk5ASemdT48FrmJIdU9GFQC6HTzGKgZ_fLzrGZnJiBFqoomAWZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAAEuU2BbgBrX_qdF6XZq3Y2p7TNYnXWPszn-1AwynFmqJwG3eoeIsH980cnGFhh1XMo9DTA6ewlhJM4MAtxfRRoPAwEuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHgHZbWLlSgpJ06RMkZ60sIkzPWSiNu3NoZISdKxpA7rZNwHM46eN-iQtjFPolGfMmG39My25h9dsZudzWkfvNOkPKAHDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLgHYLThxeEK94xcVft8YalsqWsKgNaBpsYobt5DYobYOJgFplOJw8oSlV8QYr-v6rKJ5TIr2pHbLG5R4wgXoqQEXDwFxcRXllxPIT4i6vi7AKSUYBg0syCtU6anJotKofOkeFQFd2TybLD_O4w-jSWDyRy_NBNnehIb2Ncm5bXdvrjEiHwGoT5Sg1tZL4LlwSbkq4sWKjLk-eSF5-rV_oyxGlavnJAEsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFwEW66Lr2p_qxELinvkpP1xFdpM9UxpuPAdRjjUiQQVfPQHc9bLhJFO4NpxCDnatoPtsbhc_InGqGextuAEBEmEWBQABNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4BN776nYDGKPuLP39TFpEsF1QmoK2ag9t4CEfWNvHMqwkB4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xwBa98jDsB6kVMZxgatkwxB3X8JciKtondqSE51X-stSRwB7oAr6vTduvO2lphonX52tnDKpl3b2SGXInqwyN-6NiQBtcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xABwEQWKAElGddv7wEHQ03Fa7F059FhDN4vyG1qpyt1rRoBzXHIr-GnGfLl6D_OeUH7mjE-K5JiSAr6aGddz6tksgoB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDkBlqEGQhG1K8NNJlh4dQck6NVSrpzo-uVJLH0UqeZudRcAzioSgyJqnNMLk4KXtDxWzAUyzyCAcSQAOd4bI87hZws=",
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
            },
            {
              "data": [
                "Signed_command",
                {
                  "payload": {
                    "common": {
                      "fee": "0",
                      "fee_payer_pk": "B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                  "signer": "B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz",
                  "signature": "7mXFm4iZZkfFYGkMkLb4xSCjjqqDgzhp4JRvhwfbnwH2ahFp5GWiKrUJNfKH9D3nsRqsY1ii11VkAumwfRuom4dsqdCFUaKL"
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
                      "fee_payer_pk": "B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo",
                  "signature": "7mXBd1VgqnbmgSwoUBZd8R9tfTBudtecPJ3GkPj42T8VcpvLtAWXmjgaY6f7VbpXqxK4LuxJcci3sFWSkaYMp6yjsnY6qnnZ"
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
                      "fee_payer_pk": "B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                  "signer": "B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j",
                  "signature": "7mX2gf5CN2e9Tb5jXszQDpmP9L3RjrmVeM6nk3bKRpfzH2QxXNbEY3bZbXJnpHznbBeJtYQJvRGztLMthxFCWjk3szrQNHNK"
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
                      "fee_payer_pk": "B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM",
                  "signature": "7mXT9wAx8PW7QtMsnQuNVrtPcRwrUmDMGKjhBvDQ4jViGTXxQpno8fkS4bJSQNCimEo8GTWgfPdroitYcdbE4iQnwmP4xZcZ"
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
                      "fee_payer_pk": "B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                  "signer": "B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X",
                  "signature": "7mXWRPu5B7ahafcFvqmWkELYTS5PA8pdnU5sWrnbgxfpW9bF7MoUuFRYewwCkF8VS4GPRWpBo7wFrXBR4N7dBiSZ2z57V3ij"
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
                      "fee_payer_pk": "B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm",
                  "signature": "7mXK37iLbH7NEy9xtaY9fVxhsRDzgR2mGmHiDddyciE8XwjLLzFG21dKqiQ35Nco3MdrVvA5K5G52K2skYqDoCjQQXsmuren"
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
                      "fee_payer_pk": "B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY",
                  "signature": "7mWyv8kCUnSYfH3irVJGwV4NqGWUapdyYVzucsuw8gQ59iHyknNKR8mqnuG7u754SSqoBVWE3xgwjiNmAX4DDNRPa3h1PEmA"
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
                      "fee_payer_pk": "B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
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
                  "signer": "B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis",
                  "signature": "7mXJgPVHqSN1y9gxa1KkRxwaqBX4XxmU2NiBfyB8UtkZnTaxDENsQvm11M9CjUgX9bWndM7J9xEMLKVsgXcBf1ERTCZRL8iK"
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
                      "fee_payer_pk": "B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD",
                  "signature": "7mX7PFd8e7E9UoRLiakULwWo2Fj5bEXaxMMxoggkh7TkFongFMRYDRUHTStTKQtLNwMf7oFB6vs1UNzemBJMo2qPEmCsmzPW"
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
                      "fee_payer_pk": "B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2",
                  "signature": "7mXSHquCX3cUhAR1Pr6wX8bB1zbhPLmMvFJBSxAG761htN2hNob9xg2rtBuhBJod1cnfmjCTVjJqiQzdGJcZkT5joBMfVmKw"
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
                      "fee_payer_pk": "B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R",
                      "nonce": "0",
                      "valid_until": [
                        "Since_genesis",
                        "4294967295"
                      ],
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "receiver_pk": "B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM",
                        "amount": "1000000001"
                      }
                    ]
                  },
                  "signer": "B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R",
                  "signature": "7mX1VS7MfGnbJqegqm6fhoSWpQDyfU5PHu54HphjF1XAt1LfL5PVaRmX11n6NMFgPAjq67rxoCP3yqueiYXByVCAqr1ZM3NN"
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
      "jwnRuGwm643VBJekDLftWc8tcgsM7CDJfvQdv7S59hU3iBKjRUp",
      []
    ],
    "protocol_version": {
      "major": 0,
      "minor": 0,
      "patch": 0
    },
    "accounts_accessed": [
      [
        12,
        {
          "public_key": "B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "998999999999",
          "nonce": "1",
          "receipt_chain_hash": "2n1pBGRCbyYMn1m8q4Sn3UP4nkNQArLtcEZB2wumGFfzmN7cY2pD",
          "delegate": "B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm",
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
        10,
        {
          "public_key": "B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2n1uwvchYFE3YEGQkWYmh9qCmc39ijKGyTQCF7bk96752X2oMyvU",
          "delegate": "B62qiTbU1vVqNqNLhahSrvwgghxKvHPCFy7DMGmKmqf6iKBWz98dZAM",
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
        2,
        {
          "public_key": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1002000000002",
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
        16,
        {
          "public_key": "B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "998999999999",
          "nonce": "1",
          "receipt_chain_hash": "2mzYVytdGUwwd6MWmwvbWM8UcArgxmEEyQdRZqu6xahHBSzYjq4e",
          "delegate": "B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2",
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
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2mzXHE88YpomgaY9hMx5hw6Ab75t4FJ3ypoCdkDiLVHyun2c4mqD",
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
        13,
        {
          "public_key": "B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "998999999999",
          "nonce": "1",
          "receipt_chain_hash": "2mzs6bSNMao9VXUo7yWaqGzVhgTVjc5txG8am4b1m8ghdi76poe3",
          "delegate": "B62qnRdiD9yba1waGj84xuV2H88yWvj1NEA897fWLk7Gc3vd2MziEsY",
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
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2n25M2FdeBsx1N22whfvs2hVQ5bPXbsCyq3J6vjK6Ekr2KB1ooFJ",
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
          "balance": "1001000000001",
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
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2n1CFWtMJUmpnVAGgdQd12MJDjPtL6S8a4UxbyBBF9RELQbj2nw4",
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
        9,
        {
          "public_key": "B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1001000000001",
          "nonce": "1",
          "receipt_chain_hash": "2n19M6p2bDc5Eh4wBjrnfaa53gRpTKvFayFbmCxCz52C34kAaMpg",
          "delegate": "B62qr9ei2vBLT5jawoGjbFwkMJb4v3RdxL3HB8PM5Ke3Crrkgyj1G1j",
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
          "balance": "1000000000000",
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
          "balance": "1002000000002",
          "nonce": "1",
          "receipt_chain_hash": "2mzn365J4GYh3ynbVjNvLSiz7wzFGKg2XTyqzY3Y81RUJFrPnN9z",
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
        17,
        {
          "public_key": "B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_symbol": "",
          "balance": "1000000000000",
          "nonce": "1",
          "receipt_chain_hash": "2n2Gj75ayAras3KRVSLfMXwqxDgZPkYVvVtkLfSCmM64E4ANY4Hw",
          "delegate": "B62qoRRDP58UWbfzQQP5jnePeyGQLdy57FHNYX5cHNzcLixHMUaa89R",
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
          "balance": "1718999999999",
          "nonce": "1",
          "receipt_chain_hash": "2n2JMdhwC4Ya26JoeH6FhzU3jQsBo1vF9Xmpyd3wSprQPJoAtUTT",
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
