(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1690134838591)
 (protocol_state
  ((previous_state_hash
    16014239194902465465595109881398070442140660435305474755749637269252225632503)
   (body
    ((genesis_state_hash
      16014239194902465465595109881398070442140660435305474755749637269252225632503)
     (blockchain_state
      ((staged_ledger_hash
        ((non_snark
          ((ledger_hash
            10297043144660004309489759582880215541987388636599529407662487573918152643431)
           (aux_hash
             "\140\134\163\169\168\189\198\251\199\017\029\149\027\201\171\196\236\214Ko3g>\221\169E\
            \n\184bF\206#")
           (pending_coinbase_aux
            "\147\141\184\201\248,\140\181\141?>\244\253%\0006\164\141&\167\018u=/\222Z\189\003\168\\\171\244")))
         (pending_coinbase_hash
          5047055522714573962451932445720607459327212603444463294362216371066600674316)))
       (genesis_ledger_hash
        4958998934359971061501155897206360741418847934692582646141869034661458403276)
       (ledger_proof_statement
        ((source
          ((first_pass_ledger
            4958998934359971061501155897206360741418847934692582646141869034661458403276)
           (second_pass_ledger
            4958998934359971061501155897206360741418847934692582646141869034661458403276)
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
            4958998934359971061501155897206360741418847934692582646141869034661458403276)
           (second_pass_ledger
            4958998934359971061501155897206360741418847934692582646141869034661458403276)
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
          4958998934359971061501155897206360741418847934692582646141869034661458403276)
         (connecting_ledger_right
          4958998934359971061501155897206360741418847934692582646141869034661458403276)
         (supply_increase ((magnitude 0) (sgn Pos)))
         (fee_excess
          ((fee_token_l
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (fee_excess_l ((magnitude 0) (sgn Pos)))
           (fee_token_r
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (fee_excess_r ((magnitude 0) (sgn Pos)))))
         (sok_digest ())))
       (timestamp 1690134838591)
       (body_reference
        "\130h\232\132\244\205\245\213\210an\175CO\200v\238\197\218R\031[\232\180Jb\152\223\148/CE")))
     (consensus_state
      ((blockchain_length 2) (epoch_count 0) (min_window_density 6)
       (sub_window_densities (1 0 0))
       (last_vrf_output
        "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000")
       (total_currency 10016120000000000)
       (curr_global_slot
        ((slot_number (Since_hard_fork 6)) (slots_per_epoch 576)))
       (global_slot_since_genesis (Since_genesis 6))
       (staking_epoch_data
        ((ledger
          ((hash
            4958998934359971061501155897206360741418847934692582646141869034661458403276)
           (total_currency 10016100000000000)))
         (seed 0) (start_checkpoint 0) (lock_checkpoint 0) (epoch_length 1)))
       (next_epoch_data
        ((ledger
          ((hash
            4958998934359971061501155897206360741418847934692582646141869034661458403276)
           (total_currency 10016100000000000)))
         (seed
          11097254031198438328229081175959322858342266757425965220770466547940953006797)
         (start_checkpoint 0)
         (lock_checkpoint
          16014239194902465465595109881398070442140660435305474755749637269252225632503)
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
  _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAABB3qgkt6gpTffkVSfK3I-5Xk-75uvmesJrb8WSS3KzIQDcLZHIyY2X88GsySXlYnJ57rqes-D_N8sf3w9ONKuhM_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAOjxhMkfRBN2MXLSPWcnL5QI32cJLGrzhbeWwuamVTzfyukoCMt_wXVK8rrE2b7q_fg_8LHDGGp_TM01WH1LuDQGRcm3zFOqITIObmcmMDASKyW_ZlWNNo62HMJuHBr0XMgFE_TW806pKZPj7W6ANTt69OqzyXltpeKlzouEjCh-yFgE2YsugvZ6JNdgw_IvY9y4lGs6onyl4Lh2yBCB_Zo_KIgGyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAEOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BgGP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgGmFF42pjZE1HrGzpIXn6NupheimPEIPOiJtMoJr1HGHAHf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAABL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4AAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPAAAAAAAAAAABQAAAAAAAN8Uiw8m8B-LVm7cHlFsqSFKERramPrUSscOLqRJCVc7AQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbBwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsADwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0G1G_wQgT8RUbxGyOji46vNAtAzJO1tqb_v8kDDb9C3YvH5M9g5L0uJkUhvttoun_pXWYPG8O3AzF0Y3h6rr1FTUBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwFf7WaQKIibHJKl8UFjM_lwQ-QbckeUvnrUlLEJ60YwCAGkG2-ggZUUnf5wZYjTb6hNGXaJrveKwHSZdHZZZ4aBAwFpeUqgiAo96_ITxDcizqD2SpdoWnqzk9r0iZLwFjKsFQF2Z2Ql6HY3BcSnLE6gxakcHe6oNmQPRnIuciJP6PlEMgFMRYPeq0p3GepSO09WJl9ZG_VE32PLSBKi1ewfGX8cFAGpCjoog-F17NXbpNUoSQK1a6qi0R3uZncEdQ-QXyBWIAG8g8fic8QRW0ZfoCzNCwubnnZI3YXl18iekvMFsKIBLwGeAUqaU5QNIjF251wrCg98ZlN-r21SwMD0DV2Pxm7lNQHUSyI5Nk4HiUH6uEe2jBxtr0zTPO8n76CFQFLhEmqHDgED-zakbniFVJhfE_Box0riSjfoTpwGbDxBKQIMAmgBAQF4y38RCP8yPtchADWq0jnhlgYfHuvzQUjCZYQCEz1QBwEQN2aK2jK6cfs0KuABl__5QSc6vp-0u0VHbcDrouXOHgH925nQAmDVYr65rJoeft2Ltn-r-EjSB5jdxEvzs-NDNAHLgGD60jesq8FShTDRwoHbGh1wH1KYb-6umkc2ZUW4CwHZPCWtNMEVlgtp7U9ljl7KWbSUd6r5f2MXW_frgmQYOQGm1mQmI697mWJvqN9qiomxij8tDsBTI_Wzf2njemAiKwE5bSqFCXDEt2Wa-c8FDdQUOTpaJRFWCexVl3iBfL_mBgFfjUVJA3Cvnpxl2S79k5bXsRYkKzm10XBABiMPpuP9HAEWPtny9tH3Ez-NXk3u-Ugbapncl6cU5HooP0RKrOngJwHTNzgS1lTk_fYjOmS2St_TrUYnzeal1tcbiYP2P2ZMKQFMxUsx6MWVz9ibZHzPC_lUI7YVBcmhJPmlAbf4UgAFMgHMCWoZ1eNoKa5cd2_0OBNLa6l9DIXrFpoF23Qg1hw9GgGGe_6EZyBfMD8kuUyXFDu2CI8jGonLcZLDzrloR1F_DQGLzEuDkREbj9YnUPTbLwUEmi0BkXRn8sgiGtn04bixAAF8T_Y7BnpEbXeeH7nOBTZ65vQc_-b9iWcTC6FnSMc8AwFp_HNPaq_zLuAgK5JuZ9EDyojQ6DO-Bnj091KRppjvMgHiL8wL5-D0ds3uIsQJVucgvLqPe5Vpk0K5CYfGz9xxMAEh6iZi-hN-UhsQ5w1HgFkY9za-n6HqUMBpKV6AkVPTDgE1XwoKR0LtgTRRpvl3aIQNkXpW-bZnFwQZOM_ZUwrUNwFlbhUG7CFReoCJ4TjaftFNtF7YobHo8PGjrkWvKq7JKgABhJZ8MnB0A6hoc-3LMlPaDUL1skkSGeaYvb9Zk806HDoBJVOW_GzCFinO9qONnJhuUDFrtC4fKKPhr4cfdWn6yw0BRs_rddU_qtvcYFVMmbzdaoUl8qb057CoI-1A3VD8DQABaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSQBbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBEvaoh_mbxRUz5lGYEMed1_582A-NjLSDpPZSZGfKcx4BO9d3ZgCHqNalqD9kAAa8p8E238w1kwjrxET-AOaCaxgBcxdru8TDWkDLAvjZchjKzZjyY91Yta6PwbgV8snF3SkBPGGq7DqbYRJvs4GVn5V2B5SvHWKlOUgjMLxIO7lpTAYBtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh4BsnOwvHH_6_HFxOAUimXpBlskiIe76JlgfQLxFwx7RgIB5Um5o2y5xoF1F-fWbfpx-7bYCZTbU3-bUZJ88w1whCcBdTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIiwBV_qftnG-DYoxFQTxMSIRhqGL4ER3EHMMS7qnTKNI3jIB9NHwhzB-lqXdLUH9IgF8CeSQb1YkyannDoUVgyvUTDUBAYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRYB3D4_x6LoE3BgUDX5YMuIVPuDNRmGzIgz_d96_zr8sBUBU0mvUJHjzRjAku2Ve-Nx15vKPhozvw-DiKwYkSWUQQQB5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWioBekqEp1ZfFfK1ykwNzfGfmZNxCblrIeelQdFCASQWUTYB6Ak_VsSOVAD-1cKoaujbM4Vj9afqMaZrLQgz4rc61gwBpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB0B9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkBJ6Z1PjwWuYkh1T0YVALodPMYqBn98vOsZmcmIEWqiiYBZk58pv6T8VHwaVCLgmrV0GxxVJMYy8kR2mt00G7-KAYAAS5TYFuAGtf-p0XpdmrdjantM1iddY-zOf7UDDKcWaonAbd6h4iwf3zRycYWGHVcyj0NMDp7CWEkzgwC3F9FGg8DAS4eaHMdALhHIAOII3d-xlItmh6eNlkgw-fOBkreDC4eAdltYuVKCknTpEyRnrSwiTM9ZKI27c2hkhJ0rGkDutk3Aczjp436JC2MU-iUZ8yYbf0zLbmH12xm53NaR-806Q8oAcN9aSyEc6qaJGu4XlxDI80MWmnkuc4a4WD5YUR8Ma4uAdgtOHF4Qr3jFxV-3xhqWypawqA1oGmxihu3kNihtg4mAWmU4nDyhKVXxBiv6_qsonlMivakdssblHjCBeipARcPAXFxFeWXE8hPiLq-LsApJRgGDSzIK1Tpqcmi0qh86R4VAV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfAahPlKDW1kvguXBJuSrixYqMuT55IXn6tX-jLEaVq-ckASx8aqUSO0GqjqzoWn7uuOuyIhnJNTuSdnERmaqoAYIXARbrouvan-rEQuKe-Sk_XEV2kz1TGm48B1GONSJBBV89Adz1suEkU7g2nEIOdq2g-2xuFz8icaoZ7G24AQESYRYFAAE1Ni2YbyDFmOU8PeC4_EEwBIQkMXKviTzJnKGZqhYWPAHwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLgE3vvqdgMYo-4s_f1MWkSwXVCagrZqD23gIR9Y28cyrCQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgHNcciv4acZ8uXoP855QfuaMT4rkmJICvpoZ13Pq2SyCgHlgAk9JAQG9mhLMTzkBmm9W6HI3z7VPO0vRzwDevGaCAGazJTZw-e932ajI9gr9UUZu48vW91I_s60WoveCqegOQGWoQZCEbUrw00mWHh1ByTo1VKunOj65UksfRSp5m51FwAAAAAAAAAABQAAAAAAAM4qEoMiapzTC5OCl7Q8VswFMs8ggHEkADneGyPO4WcL)
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
  (16014239194902465465595109881398070442140660435305474755749637269252225632503
   ()))
 (protocol_version ((major 0) (minor 0) (patch 0)))
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
    "scheduled_time": "1690134838591",
    "protocol_state": {
      "previous_state_hash": "3NLuguToNNw82AmRQs5wEQV7d33cPoiDeBWttMybzcoZAU2YP1Yz",
      "body": {
        "genesis_state_hash": "3NLuguToNNw82AmRQs5wEQV7d33cPoiDeBWttMybzcoZAU2YP1Yz",
        "blockchain_state": {
          "staged_ledger_hash": {
            "non_snark": {
              "ledger_hash": "jwtL47nyjgCexDufj4YvsvG3CnQTUoFx3DWqw9agMYbABy4mGyf",
              "aux_hash": "VHK1wNNNStDStffTw4WUKsA7XpWHUAgZqqE6hwyE5jPejatdqy",
              "pending_coinbase_aux": "XH9htC21tQMDKM6hhATkQjecZPRUGpofWATXPkjB5QKxpTBv7H"
            },
            "pending_coinbase_hash": "2mzcFr5TxgWNmHe2dBbvGZRqSGLjx8vRxAZJL3nDdM1gHEBD3YYo"
          },
          "genesis_ledger_hash": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
          "ledger_proof_statement": {
            "source": {
              "first_pass_ledger": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
              "second_pass_ledger": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
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
              "first_pass_ledger": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
              "second_pass_ledger": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
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
            "connecting_ledger_left": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
            "connecting_ledger_right": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
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
          "timestamp": "1690134838591",
          "body_reference": "8268e884f4cdf5d5d2616eaf434fc876eec5da521f5be8b44a6298df942f4345"
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
            "slot_number": [
              "Since_hard_fork",
              "6"
            ],
            "slots_per_epoch": "576"
          },
          "global_slot_since_genesis": [
            "Since_genesis",
            "6"
          ],
          "staking_epoch_data": {
            "ledger": {
              "hash": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
              "total_currency": "10016100000000000"
            },
            "seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "epoch_length": "1"
          },
          "next_epoch_data": {
            "ledger": {
              "hash": "jxeqCMyTEzGxMEgbKQCQo7YDfaXujF2LNaD7UQTpBt5oDPf3pTj",
              "total_currency": "10016100000000000"
            },
            "seed": "2vbhjwHdFZqQaG1zZVkrnHacQba792hNoPuBd4KLTnMgwCSP5f4d",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NLuguToNNw82AmRQs5wEQV7d33cPoiDeBWttMybzcoZAU2YP1Yz",
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
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAABB3qgkt6gpTffkVSfK3I-5Xk-75uvmesJrb8WSS3KzIQDcLZHIyY2X88GsySXlYnJ57rqes-D_N8sf3w9ONKuhM_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAOjxhMkfRBN2MXLSPWcnL5QI32cJLGrzhbeWwuamVTzfyukoCMt_wXVK8rrE2b7q_fg_8LHDGGp_TM01WH1LuDQGRcm3zFOqITIObmcmMDASKyW_ZlWNNo62HMJuHBr0XMgFE_TW806pKZPj7W6ANTt69OqzyXltpeKlzouEjCh-yFgE2YsugvZ6JNdgw_IvY9y4lGs6onyl4Lh2yBCB_Zo_KIgGyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAEOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BgGP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgGmFF42pjZE1HrGzpIXn6NupheimPEIPOiJtMoJr1HGHAHf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAABL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4AAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPAAAAAAAAAAABQAAAAAAAN8Uiw8m8B-LVm7cHlFsqSFKERramPrUSscOLqRJCVc7AQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbBwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsADwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0G1G_wQgT8RUbxGyOji46vNAtAzJO1tqb_v8kDDb9C3YvH5M9g5L0uJkUhvttoun_pXWYPG8O3AzF0Y3h6rr1FTUBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwFf7WaQKIibHJKl8UFjM_lwQ-QbckeUvnrUlLEJ60YwCAGkG2-ggZUUnf5wZYjTb6hNGXaJrveKwHSZdHZZZ4aBAwFpeUqgiAo96_ITxDcizqD2SpdoWnqzk9r0iZLwFjKsFQF2Z2Ql6HY3BcSnLE6gxakcHe6oNmQPRnIuciJP6PlEMgFMRYPeq0p3GepSO09WJl9ZG_VE32PLSBKi1ewfGX8cFAGpCjoog-F17NXbpNUoSQK1a6qi0R3uZncEdQ-QXyBWIAG8g8fic8QRW0ZfoCzNCwubnnZI3YXl18iekvMFsKIBLwGeAUqaU5QNIjF251wrCg98ZlN-r21SwMD0DV2Pxm7lNQHUSyI5Nk4HiUH6uEe2jBxtr0zTPO8n76CFQFLhEmqHDgED-zakbniFVJhfE_Box0riSjfoTpwGbDxBKQIMAmgBAQF4y38RCP8yPtchADWq0jnhlgYfHuvzQUjCZYQCEz1QBwEQN2aK2jK6cfs0KuABl__5QSc6vp-0u0VHbcDrouXOHgH925nQAmDVYr65rJoeft2Ltn-r-EjSB5jdxEvzs-NDNAHLgGD60jesq8FShTDRwoHbGh1wH1KYb-6umkc2ZUW4CwHZPCWtNMEVlgtp7U9ljl7KWbSUd6r5f2MXW_frgmQYOQGm1mQmI697mWJvqN9qiomxij8tDsBTI_Wzf2njemAiKwE5bSqFCXDEt2Wa-c8FDdQUOTpaJRFWCexVl3iBfL_mBgFfjUVJA3Cvnpxl2S79k5bXsRYkKzm10XBABiMPpuP9HAEWPtny9tH3Ez-NXk3u-Ugbapncl6cU5HooP0RKrOngJwHTNzgS1lTk_fYjOmS2St_TrUYnzeal1tcbiYP2P2ZMKQFMxUsx6MWVz9ibZHzPC_lUI7YVBcmhJPmlAbf4UgAFMgHMCWoZ1eNoKa5cd2_0OBNLa6l9DIXrFpoF23Qg1hw9GgGGe_6EZyBfMD8kuUyXFDu2CI8jGonLcZLDzrloR1F_DQGLzEuDkREbj9YnUPTbLwUEmi0BkXRn8sgiGtn04bixAAF8T_Y7BnpEbXeeH7nOBTZ65vQc_-b9iWcTC6FnSMc8AwFp_HNPaq_zLuAgK5JuZ9EDyojQ6DO-Bnj091KRppjvMgHiL8wL5-D0ds3uIsQJVucgvLqPe5Vpk0K5CYfGz9xxMAEh6iZi-hN-UhsQ5w1HgFkY9za-n6HqUMBpKV6AkVPTDgE1XwoKR0LtgTRRpvl3aIQNkXpW-bZnFwQZOM_ZUwrUNwFlbhUG7CFReoCJ4TjaftFNtF7YobHo8PGjrkWvKq7JKgABhJZ8MnB0A6hoc-3LMlPaDUL1skkSGeaYvb9Zk806HDoBJVOW_GzCFinO9qONnJhuUDFrtC4fKKPhr4cfdWn6yw0BRs_rddU_qtvcYFVMmbzdaoUl8qb057CoI-1A3VD8DQABaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSQBbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBEvaoh_mbxRUz5lGYEMed1_582A-NjLSDpPZSZGfKcx4BO9d3ZgCHqNalqD9kAAa8p8E238w1kwjrxET-AOaCaxgBcxdru8TDWkDLAvjZchjKzZjyY91Yta6PwbgV8snF3SkBPGGq7DqbYRJvs4GVn5V2B5SvHWKlOUgjMLxIO7lpTAYBtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh4BsnOwvHH_6_HFxOAUimXpBlskiIe76JlgfQLxFwx7RgIB5Um5o2y5xoF1F-fWbfpx-7bYCZTbU3-bUZJ88w1whCcBdTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIiwBV_qftnG-DYoxFQTxMSIRhqGL4ER3EHMMS7qnTKNI3jIB9NHwhzB-lqXdLUH9IgF8CeSQb1YkyannDoUVgyvUTDUBAYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRYB3D4_x6LoE3BgUDX5YMuIVPuDNRmGzIgz_d96_zr8sBUBU0mvUJHjzRjAku2Ve-Nx15vKPhozvw-DiKwYkSWUQQQB5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWioBekqEp1ZfFfK1ykwNzfGfmZNxCblrIeelQdFCASQWUTYB6Ak_VsSOVAD-1cKoaujbM4Vj9afqMaZrLQgz4rc61gwBpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB0B9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkBJ6Z1PjwWuYkh1T0YVALodPMYqBn98vOsZmcmIEWqiiYBZk58pv6T8VHwaVCLgmrV0GxxVJMYy8kR2mt00G7-KAYAAS5TYFuAGtf-p0XpdmrdjantM1iddY-zOf7UDDKcWaonAbd6h4iwf3zRycYWGHVcyj0NMDp7CWEkzgwC3F9FGg8DAS4eaHMdALhHIAOII3d-xlItmh6eNlkgw-fOBkreDC4eAdltYuVKCknTpEyRnrSwiTM9ZKI27c2hkhJ0rGkDutk3Aczjp436JC2MU-iUZ8yYbf0zLbmH12xm53NaR-806Q8oAcN9aSyEc6qaJGu4XlxDI80MWmnkuc4a4WD5YUR8Ma4uAdgtOHF4Qr3jFxV-3xhqWypawqA1oGmxihu3kNihtg4mAWmU4nDyhKVXxBiv6_qsonlMivakdssblHjCBeipARcPAXFxFeWXE8hPiLq-LsApJRgGDSzIK1Tpqcmi0qh86R4VAV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfAahPlKDW1kvguXBJuSrixYqMuT55IXn6tX-jLEaVq-ckASx8aqUSO0GqjqzoWn7uuOuyIhnJNTuSdnERmaqoAYIXARbrouvan-rEQuKe-Sk_XEV2kz1TGm48B1GONSJBBV89Adz1suEkU7g2nEIOdq2g-2xuFz8icaoZ7G24AQESYRYFAAE1Ni2YbyDFmOU8PeC4_EEwBIQkMXKviTzJnKGZqhYWPAHwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLgE3vvqdgMYo-4s_f1MWkSwXVCagrZqD23gIR9Y28cyrCQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgHNcciv4acZ8uXoP855QfuaMT4rkmJICvpoZ13Pq2SyCgHlgAk9JAQG9mhLMTzkBmm9W6HI3z7VPO0vRzwDevGaCAGazJTZw-e932ajI9gr9UUZu48vW91I_s60WoveCqegOQGWoQZCEbUrw00mWHh1ByTo1VKunOj65UksfRSp5m51FwAAAAAAAAAABQAAAAAAAM4qEoMiapzTC5OCl7Q8VswFMs8ggHEkADneGyPO4WcL",
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
      "jxyQ8VuSgrcJUcyL2k7UVSktFqSDCjDrKfTjNAZbMWj4ptPv4Cf",
      []
    ],
    "protocol_version": {
      "major": 0,
      "minor": 0,
      "patch": 0
    },
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
