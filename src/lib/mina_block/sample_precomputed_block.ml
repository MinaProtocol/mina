(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
   ((scheduled_time 1690218710599)
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
       (timestamp 1690218710599)
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
  _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAABB3qgkt6gpTffkVSfK3I-5Xk-75uvmesJrb8WSS3KzIQDcLZHIyY2X88GsySXlYnJ57rqes-D_N8sf3w9ONKuhM_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAOjxhMkfRBN2MXLSPWcnL5QI32cJLGrzhbeWwuamVTzfyukoCMt_wXVK8rrE2b7q_fg_8LHDGGp_TM01WH1LuDQGRcm3zFOqITIObmcmMDASKyW_ZlWNNo62HMJuHBr0XMgFE_TW806pKZPj7W6ANTt69OqzyXltpeKlzouEjCh-yFgE2YsugvZ6JNdgw_IvY9y4lGs6onyl4Lh2yBCB_Zo_KIgGyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAEOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BgGP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgGmFF42pjZE1HrGzpIXn6NupheimPEIPOiJtMoJr1HGHAHf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAABL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4AAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPAAAAAAAAAAABQAAAAAAAAAAAAAA3xSLDybwH4tWbtweUWypIUoRGtqY-tRKxw4upEkJVzsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsHAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwAPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbUb_BCBPxFRvEbI6OLjq80C0DMk7W2pv-_yQMNv0Ldi8fkz2DkvS4mRSG-22i6f-ldZg8bw7cDMXRjeHquvUVNQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAV_tZpAoiJsckqXxQWMz-XBD5BtyR5S-etSUsQnrRjAIAaQbb6CBlRSd_nBliNNvqE0Zdomu94rAdJl0dllnhoEDAWl5SqCICj3r8hPENyLOoPZKl2haerOT2vSJkvAWMqwVAXZnZCXodjcFxKcsTqDFqRwd7qg2ZA9Gci5yIk_o-UQyAUxFg96rSncZ6lI7T1YmX1kb9UTfY8tIEqLV7B8ZfxwUAakKOiiD4XXs1duk1ShJArVrqqLRHe5mdwR1D5BfIFYgAbyDx-JzxBFbRl-gLM0LC5uedkjdheXXyJ6S8wWwogEvAZ4BSppTlA0iMXbnXCsKD3xmU36vbVLAwPQNXY_GbuU1AdRLIjk2TgeJQfq4R7aMHG2vTNM87yfvoIVAUuESaocOAQP7NqRueIVUmF8T8GjHSuJKN-hOnAZsPEEpAgwCaAEBAXjLfxEI_zI-1yEANarSOeGWBh8e6_NBSMJlhAITPVAHARA3ZoraMrpx-zQq4AGX__lBJzq-n7S7RUdtwOui5c4eAf3bmdACYNVivrmsmh5-3Yu2f6v4SNIHmN3ES_Oz40M0AcuAYPrSN6yrwVKFMNHCgdsaHXAfUphv7q6aRzZlRbgLAdk8Ja00wRWWC2ntT2WOXspZtJR3qvl_Yxdb9-uCZBg5AabWZCYjr3uZYm-o32qKibGKPy0OwFMj9bN_aeN6YCIrATltKoUJcMS3ZZr5zwUN1BQ5OlolEVYJ7FWXeIF8v-YGAV-NRUkDcK-enGXZLv2TltexFiQrObXRcEAGIw-m4_0cARY-2fL20fcTP41eTe75SBtqmdyXpxTkeig_REqs6eAnAdM3OBLWVOT99iM6ZLZK39OtRifN5qXW1xuJg_Y_ZkwpAUzFSzHoxZXP2JtkfM8L-VQjthUFyaEk-aUBt_hSAAUyAcwJahnV42gprlx3b_Q4E0trqX0MhesWmgXbdCDWHD0aAYZ7_oRnIF8wPyS5TJcUO7YIjyMaictxksPOuWhHUX8NAYvMS4ORERuP1idQ9NsvBQSaLQGRdGfyyCIa2fThuLEAAXxP9jsGekRtd54fuc4FNnrm9Bz_5v2JZxMLoWdIxzwDAWn8c09qr_Mu4CArkm5n0QPKiNDoM74GePT3UpGmmO8yAeIvzAvn4PR2ze4ixAlW5yC8uo97lWmTQrkJh8bP3HEwASHqJmL6E35SGxDnDUeAWRj3Nr6foepQwGkpXoCRU9MOATVfCgpHQu2BNFGm-XdohA2Relb5tmcXBBk4z9lTCtQ3AWVuFQbsIVF6gInhONp-0U20Xtihsejw8aOuRa8qrskqAAGElnwycHQDqGhz7csyU9oNQvWySRIZ5pi9v1mTzTocOgElU5b8bMIWKc72o42cmG5QMWu0Lh8oo-Gvhx91afrLDQFGz-t11T-q29xgVUyZvN1qhSXypvTnsKgj7UDdUPwNAAFpCpjZSyFw7fs_VpvW3u-pzKE7CT2VmxNu4B0vmGsNJAFujobz21FKPf2s93UGaAvqMNDoRcPA1lf6TGTJWhslKAES9qiH-ZvFFTPmUZgQx53X_nzYD42MtIOk9lJkZ8pzHgE713dmAIeo1qWoP2QABrynwTbfzDWTCOvERP4A5oJrGAFzF2u7xMNaQMsC-NlyGMrNmPJj3Vi1ro_BuBXyycXdKQE8YarsOpthEm-zgZWflXYHlK8dYqU5SCMwvEg7uWlMBgG1lDFQ8arF3lNiO4utX_pjZY6rvGOOemMnsf-pKzF6HgGyc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAgHlSbmjbLnGgXUX59Zt-nH7ttgJlNtTf5tRknzzDXCEJwF1M96_qj16L7hWfRm_YlYUbKK8EhtSPPvkJ5Lgs1MiLAFX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMgH00fCHMH6Wpd0tQf0iAXwJ5JBvViTJqecOhRWDK9RMNQEBhe9XkAAcvm5OCJRA_FIknHm7TTEgivfF2IEI3MeJFgHcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFQFTSa9QkePNGMCS7ZV743HXm8o-GjO_D4OIrBiRJZRBBAHnIr8LOE_BSDulDYlGBNxVRuQ0xMq2ABzCvFn6x5haKgF6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNgHoCT9WxI5UAP7Vwqhq6NszhWP1p-oxpmstCDPitzrWDAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQH2gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEICwFSvpvw8LsRkZ1QbfA7uJ_2tTqS1vgPAZYdxUAlXJhUIAF-WLJP0invsW4SBaZLXLuYZWavhBrsak2NpUIAXTl2FQGXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOQHzco0WgOEJaBtLb4AR_qanWPjpJ9wuFuzzxBm-b5V2FgF4ZP81nWoge3I_GH93hhXS8HMrN68WmXeUz4NJZNh5OQEnpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJgFmTnym_pPxUfBpUIuCatXQbHFUkxjLyRHaa3TQbv4oBgABLlNgW4Aa1_6nRel2at2Nqe0zWJ11j7M5_tQMMpxZqicBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8BcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUAATU2LZhvIMWY5Tw94Lj8QTAEhCQxcq-JPMmcoZmqFhY8AfCVHmo4X7Tqi14s8OieVIB6mZOLCracd_G5shCgXRUuATe--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJAeANNswrYHbCMYQEbAoqBiCFIVZE_ilUmmJSAlBVvfscAWvfIw7AepFTGcYGrZMMQd1_CXIiraJ3akhOdV_rLUkcAe6AK-r03brztpaYaJ1-drZwyqZd29khlyJ6sMjfujYkAbXJjTqIHqrVYA2Jkg3_gwJQedJ73jzq3RRCW_yKQNMQAcBEFigBJRnXb-8BB0NNxWuxdOfRYQzeL8htaqcrda0aAc1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIKAeWACT0kBAb2aEsxPOQGab1bocjfPtU87S9HPAN68ZoIAZrMlNnD573fZqMj2Cv1RRm7jy9b3Uj-zrRai94Kp6A5AZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXAAAAAAAAAAAFAAAAAAAAAAAAAADOKhKDImqc0wuTgpe0PFbMBTLPIIBxJAA53hsjzuFnCw==)
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
    "scheduled_time": "1690218710599",
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
          "timestamp": "1690218710599",
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
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAAAAAAAAAAABB3qgkt6gpTffkVSfK3I-5Xk-75uvmesJrb8WSS3KzIQDcLZHIyY2X88GsySXlYnJ57rqes-D_N8sf3w9ONKuhM_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAOjxhMkfRBN2MXLSPWcnL5QI32cJLGrzhbeWwuamVTzfyukoCMt_wXVK8rrE2b7q_fg_8LHDGGp_TM01WH1LuDQGRcm3zFOqITIObmcmMDASKyW_ZlWNNo62HMJuHBr0XMgFE_TW806pKZPj7W6ANTt69OqzyXltpeKlzouEjCh-yFgE2YsugvZ6JNdgw_IvY9y4lGs6onyl4Lh2yBCB_Zo_KIgGyl4C8pWR0nRb55GFhho4bsNUvVKgqon06nmoW5gPFGAEOYXnGbqCwfILbbNEjD8YWkrrdUWf6iLdpV5rSb_G4BgGP6jCXJbVnb2bi595M89Dn3eaHqI7r_oGTptrFg0fBOgGmFF42pjZE1HrGzpIXn6NupheimPEIPOiJtMoJr1HGHAHf2Xgv3ujDLlegYdgzJ2y_V804JAHE3Cl_dfbpCAzwEgEppBiRR8Clqg7B3_5KMJH9h1udwh_nQkM02Dn0VIMVIwEpkET_g7_TI45JvqGvgYMnEtq-Uk1xMbZxFekPBBCEMgGIaSXXRS020Oe-Mxxpdx3OS9IBjNgN9Ss705jeQA0XPAG7XfImN90ecZM4tDn3WUNnINAYjV8Rv_WSIzF4EDR_NAGYKUSuTxFagOvngIOJQVoSI-CqVh2kwjjHGs9Gikv8KAGNUoyGVykk0AVExmdQJAwFlQ3g2HNRQHO_JvPTgGDFEAETI55Gon6SDTCTW81qJZSyRm1WeLeHhbRvDgJVVJaxFwHSLDMHEiK7bbjFx4uvVIHKCz-_vOYHyGdvLSuVwW2-IAEyir19KIXHk3K_y7aRS1Hiyz573S1OI3NF2HQukr91JwFmQO6AdQWWZknt9oEPgNMwNgRq0DOF3R9pgCUMr_1wCAGIKBQxgkypmTOHCspPXINlO7c9ROxvvU2EHIV1IZ7HDwEVSlOAaI0Mfso73tiD9YCH7_ePfr_egwdxRoC_fpfGDgEZqqSZMOmyokQbaNGdY9cToFaX8oBzETM5UpT2ZLtiEQHFFfUXDtw_CXFY-NmJSOayRcB43kgU8VF4nvNJ-RQEAgFDwUAs_5KABftkEUIK0Fb2crACdVV9LNbtRetVSfy_OgHhVQ9CQkXGtdEVu_9NdJ06OM6wVdIL_zsmxOKBKLH7LQGqfUMuRuwIPO7p0k37Q4NxOkKGpKn3a0yZ2NlcmM7YMQFJtwKJ8aLxv9sVdZ2ebptabXrtr4YbJetZkaHzO9CYDwEI24wi5u05-qZan7Pa6Ih7G3ObrHXbUjOdjk3u-r5vOAHoEZitNz__05zlnpqJbNwHREUiwl89FHlK0q3rajQ0JAEkUIQLVvI1Xm_GpdDLLTsXoDc9S_gZtBpjHLYtgHEJFAGziDZgPbM8VhHVvIb-cEGZe362W2NniLZP6S5rERDSBAABL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4AAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPAAAAAAAAAAABQAAAAAAAAAAAAAA3xSLDybwH4tWbtweUWypIUoRGtqY-tRKxw4upEkJVzsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsHAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwAPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbUb_BCBPxFRvEbI6OLjq80C0DMk7W2pv-_yQMNv0Ldi8fkz2DkvS4mRSG-22i6f-ldZg8bw7cDMXRjeHquvUVNQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAV_tZpAoiJsckqXxQWMz-XBD5BtyR5S-etSUsQnrRjAIAaQbb6CBlRSd_nBliNNvqE0Zdomu94rAdJl0dllnhoEDAWl5SqCICj3r8hPENyLOoPZKl2haerOT2vSJkvAWMqwVAXZnZCXodjcFxKcsTqDFqRwd7qg2ZA9Gci5yIk_o-UQyAUxFg96rSncZ6lI7T1YmX1kb9UTfY8tIEqLV7B8ZfxwUAakKOiiD4XXs1duk1ShJArVrqqLRHe5mdwR1D5BfIFYgAbyDx-JzxBFbRl-gLM0LC5uedkjdheXXyJ6S8wWwogEvAZ4BSppTlA0iMXbnXCsKD3xmU36vbVLAwPQNXY_GbuU1AdRLIjk2TgeJQfq4R7aMHG2vTNM87yfvoIVAUuESaocOAQP7NqRueIVUmF8T8GjHSuJKN-hOnAZsPEEpAgwCaAEBAXjLfxEI_zI-1yEANarSOeGWBh8e6_NBSMJlhAITPVAHARA3ZoraMrpx-zQq4AGX__lBJzq-n7S7RUdtwOui5c4eAf3bmdACYNVivrmsmh5-3Yu2f6v4SNIHmN3ES_Oz40M0AcuAYPrSN6yrwVKFMNHCgdsaHXAfUphv7q6aRzZlRbgLAdk8Ja00wRWWC2ntT2WOXspZtJR3qvl_Yxdb9-uCZBg5AabWZCYjr3uZYm-o32qKibGKPy0OwFMj9bN_aeN6YCIrATltKoUJcMS3ZZr5zwUN1BQ5OlolEVYJ7FWXeIF8v-YGAV-NRUkDcK-enGXZLv2TltexFiQrObXRcEAGIw-m4_0cARY-2fL20fcTP41eTe75SBtqmdyXpxTkeig_REqs6eAnAdM3OBLWVOT99iM6ZLZK39OtRifN5qXW1xuJg_Y_ZkwpAUzFSzHoxZXP2JtkfM8L-VQjthUFyaEk-aUBt_hSAAUyAcwJahnV42gprlx3b_Q4E0trqX0MhesWmgXbdCDWHD0aAYZ7_oRnIF8wPyS5TJcUO7YIjyMaictxksPOuWhHUX8NAYvMS4ORERuP1idQ9NsvBQSaLQGRdGfyyCIa2fThuLEAAXxP9jsGekRtd54fuc4FNnrm9Bz_5v2JZxMLoWdIxzwDAWn8c09qr_Mu4CArkm5n0QPKiNDoM74GePT3UpGmmO8yAeIvzAvn4PR2ze4ixAlW5yC8uo97lWmTQrkJh8bP3HEwASHqJmL6E35SGxDnDUeAWRj3Nr6foepQwGkpXoCRU9MOATVfCgpHQu2BNFGm-XdohA2Relb5tmcXBBk4z9lTCtQ3AWVuFQbsIVF6gInhONp-0U20Xtihsejw8aOuRa8qrskqAAGElnwycHQDqGhz7csyU9oNQvWySRIZ5pi9v1mTzTocOgElU5b8bMIWKc72o42cmG5QMWu0Lh8oo-Gvhx91afrLDQFGz-t11T-q29xgVUyZvN1qhSXypvTnsKgj7UDdUPwNAAFpCpjZSyFw7fs_VpvW3u-pzKE7CT2VmxNu4B0vmGsNJAFujobz21FKPf2s93UGaAvqMNDoRcPA1lf6TGTJWhslKAES9qiH-ZvFFTPmUZgQx53X_nzYD42MtIOk9lJkZ8pzHgE713dmAIeo1qWoP2QABrynwTbfzDWTCOvERP4A5oJrGAFzF2u7xMNaQMsC-NlyGMrNmPJj3Vi1ro_BuBXyycXdKQE8YarsOpthEm-zgZWflXYHlK8dYqU5SCMwvEg7uWlMBgG1lDFQ8arF3lNiO4utX_pjZY6rvGOOemMnsf-pKzF6HgGyc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAgHlSbmjbLnGgXUX59Zt-nH7ttgJlNtTf5tRknzzDXCEJwF1M96_qj16L7hWfRm_YlYUbKK8EhtSPPvkJ5Lgs1MiLAFX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMgH00fCHMH6Wpd0tQf0iAXwJ5JBvViTJqecOhRWDK9RMNQEBhe9XkAAcvm5OCJRA_FIknHm7TTEgivfF2IEI3MeJFgHcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFQFTSa9QkePNGMCS7ZV743HXm8o-GjO_D4OIrBiRJZRBBAHnIr8LOE_BSDulDYlGBNxVRuQ0xMq2ABzCvFn6x5haKgF6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNgHoCT9WxI5UAP7Vwqhq6NszhWP1p-oxpmstCDPitzrWDAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQH2gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEICwFSvpvw8LsRkZ1QbfA7uJ_2tTqS1vgPAZYdxUAlXJhUIAF-WLJP0invsW4SBaZLXLuYZWavhBrsak2NpUIAXTl2FQGXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOQHzco0WgOEJaBtLb4AR_qanWPjpJ9wuFuzzxBm-b5V2FgF4ZP81nWoge3I_GH93hhXS8HMrN68WmXeUz4NJZNh5OQEnpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJgFmTnym_pPxUfBpUIuCatXQbHFUkxjLyRHaa3TQbv4oBgABLlNgW4Aa1_6nRel2at2Nqe0zWJ11j7M5_tQMMpxZqicBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8BcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUAATU2LZhvIMWY5Tw94Lj8QTAEhCQxcq-JPMmcoZmqFhY8AfCVHmo4X7Tqi14s8OieVIB6mZOLCracd_G5shCgXRUuATe--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJAeANNswrYHbCMYQEbAoqBiCFIVZE_ilUmmJSAlBVvfscAWvfIw7AepFTGcYGrZMMQd1_CXIiraJ3akhOdV_rLUkcAe6AK-r03brztpaYaJ1-drZwyqZd29khlyJ6sMjfujYkAbXJjTqIHqrVYA2Jkg3_gwJQedJ73jzq3RRCW_yKQNMQAcBEFigBJRnXb-8BB0NNxWuxdOfRYQzeL8htaqcrda0aAc1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIKAeWACT0kBAb2aEsxPOQGab1bocjfPtU87S9HPAN68ZoIAZrMlNnD573fZqMj2Cv1RRm7jy9b3Uj-zrRai94Kp6A5AZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXAAAAAAAAAAAFAAAAAAAAAAAAAADOKhKDImqc0wuTgpe0PFbMBTLPIIBxJAA53hsjzuFnCw==",
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
