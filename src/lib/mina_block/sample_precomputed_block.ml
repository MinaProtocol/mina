(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1690219472442)
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
       (timestamp 1690219472442)
       (body_reference
        "\130h\232\132\244\205\245\213\210an\175CO\200v\238\197\218R\031[\232\180Jb\152\223\148/CE")))
     (consensus_state
      ((blockchain_length 2) (epoch_count 0) (min_window_density 6)
       (sub_window_densities (1 0 0))
       (last_vrf_output
        "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000")
       (total_currency 10016120000000000)
       (curr_global_slot
        ((slot_number 6) (slots_per_epoch 576)))
       (global_slot_since_genesis 6)
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
  _AzFacptM6EI_IuGEn36D_DDAPyJALP-mtaLe_wRKLlqjdLzswD8wQc1hnC4z3P8nOfrwyXsm3IA_CVPq1cotlsK_PKA6zqDmK-xAAAAAAAAAAAAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAAhAAAAAAAGKZVEkV8JvnwXkRRC0lSEBTtFkF259BVjBh_X28MtMPrNdShffBok_HsebifDwWOlWmsec2OQMdBOulXlAEBRb8b7_mrMmzgjP8Yxh2-VhDl3kA_JeHiOkGKzrd_MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA_IsHEI-xd5zi_O4Ma98AX1z4APyHnLAHLae9HfygJl_p4pcbTQD8EV-AVnx0dZz86PHO-mlj_qEA_E1g6dvfiitc_Jv3EPKMcYxaAPxIa-BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA_MkrPzde40VE_OXNjPwVx0CdAPxOqrxLhIKYQvy8t6_Q1yeplwD8d279_1s9ypn8lEJcFVVq5u8A_FSZlyFxsn1L_EDIk2Hgoh-VAPyzRweyvszRLPwdAmTyPN7RWwAA_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAAAAAki1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QVItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFAvy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAA_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAA6PGEyR9EE3YxctI9ZycvlAjfZwksavOFt5bC5qZVPN_K6SgIy3_BdUryusTZvur9-D_wscMYan9MzTVYfUu4NAZFybfMU6ohMg5uZyYwMBIrJb9mVY02jrYcwm4cGvRcyAUT9NbzTqkpk-PtboA1O3r06rPJeW2l4qXOi4SMKH7IWATZiy6C9nok12DD8i9j3LiUazqifKXguHbIEIH9mj8oiAbKXgLylZHSdFvnkYWGGjhuw1S9UqCqifTqeahbmA8UYAQ5hecZuoLB8gtts0SMPxhaSut1RZ_qIt2lXmtJv8bgGAY_qMJcltWdvZuLn3kzz0Ofd5oeojuv-gZOm2sWDR8E6AaYUXjamNkTUesbOkhefo26mF6KY8Qg86Im0ygmvUcYcAd_ZeC_e6MMuV6Bh2DMnbL9XzTgkAcTcKX919ukIDPASASmkGJFHwKWqDsHf_kowkf2HW53CH-dCQzTYOfRUgxUjASmQRP-Dv9Mjjkm-oa-BgycS2r5STXExtnEV6Q8EEIQyAYhpJddFLTbQ574zHGl3Hc5L0gGM2A31KzvTmN5ADRc8Abtd8iY33R5xkzi0OfdZQ2cg0BiNXxG_9ZIjMXgQNH80AZgpRK5PEVqA6-eAg4lBWhIj4KpWHaTCOMcaz0aKS_woAY1SjIZXKSTQBUTGZ1AkDAWVDeDYc1FAc78m89OAYMUQARMjnkaifpINMJNbzWollLJGbVZ4t4eFtG8OAlVUlrEXAdIsMwcSIrttuMXHi69UgcoLP7-85gfIZ28tK5XBbb4gATKKvX0ohceTcr_LtpFLUeLLPnvdLU4jc0XYdC6Sv3UnAWZA7oB1BZZmSe32gQ-A0zA2BGrQM4XdH2mAJQyv_XAIAYgoFDGCTKmZM4cKyk9cg2U7tz1E7G-9TYQchXUhnscPARVKU4BojQx-yjve2IP1gIfv949-v96DB3FGgL9-l8YOARmqpJkw6bKiRBto0Z1j1xOgVpfygHMRMzlSlPZku2IRAcUV9RcO3D8JcVj42YlI5rJFwHjeSBTxUXie80n5FAQCAUPBQCz_koAF-2QRQgrQVvZysAJ1VX0s1u1F61VJ_L86AeFVD0JCRca10RW7_010nTo4zrBV0gv_OybE4oEosfstAap9Qy5G7Ag87unSTftDg3E6QoakqfdrTJnY2VyYztgxAUm3AonxovG_2xV1nZ5um1pteu2vhhsl61mRofM70JgPAQjbjCLm7Tn6plqfs9roiHsbc5usddtSM52OTe76vm84AegRmK03P__TnOWemols3AdERSLCXz0UeUrSretqNDQkASRQhAtW8jVeb8al0MstOxegNz1L-Bm0GmMcti2AcQkUAbOINmA9szxWEdW8hv5wQZl7frZbY2eItk_pLmsRENIEAAEvwOjTlWCgsCMWjWpRghNlWQE8N9FewsLuEoPGubd7HQHCYmpoFFNIbqXUE_DqAwz11zHwq9_mMsdKKmmDte4PFwGFWckwTe35TyNm1Niq88nCr1wqszmKWu9My4OaUN68NQGdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQGtC9t5svFvTRQn4Nr-cMBjEPpGBrk-tEKCU4-D2ijxPwGV0WIswKfy24qZ2BVlNNVyB6rzu8alpqGjFc2SQmiCHwFS0reBvhwwDB3LQCBfYCQHWpkLPtZAaF6khi9l6UbpGgE2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAFxI5ougXdG8pcPqt7xrkNRXIrf_CCxbxlGt8LnQLK-MgEhErp_10lnQVY7lIh4YSpf6hH-4X9Iu7ALrs9733jkIwHu3CQpAe6rrMu2XSVx_8Jo__W7ZvdUJaWnt1n_4rMoDwF7DTz4lANzls8z1DLGEf_TNvmGWkqP0h9NuNNHbmBoOwFdyzC-_PLz2ZYuTi5MogrWTHpyxzBwlHIaR1F3n8oiIwHEbrA7kGr-BD0iUMbnHPhQd3bBvCJGInmA_EJ3BP4qBQEKzCtv_aYC-uIHNevghsaQ__iLWwvw3e2xnwM6vm3wJgE3jMlSF-_fiEjkbNvvN-xMoO8jqbkknuJIHbkZU5CCCwHhXODBNtpjzl85oYYtmwUEuH7GswTgiAeZfYZLKuXnAwENViE30_FxaxBbMuOMCBvP-iB4vqKIjSdvNUlKRR2ZMAG7wdpIm816ZRuiURpesbuExUAOd4IrVVru3_BarFqZGAFXzb1Ke2lZRwF_8Qw00e8J5Amy1Wvmx1y8wnSsHygTCwHmfEbSm7zz9JhzAnA_Y4w2DABjmIxM_PL6LQTr-clhAgE2UeOYb14khXPRV7mNhBzZXQm-zOQGSghRK_9pOIFfEQGRF9HtRRuJy7tDdTHSQMC1RmrWUR_NGb4AGrz0YbR-CwFsw2cP7MfLQA1G7MePPyAHoM6iXjrMdjBp3nwxS_e_LAGlY8mV8f-Px-qgGxOywW301TZCoZuobwfO4e3v-zItHgGLn3KkrMs34UEblCpceb73vxW2dKSyuq6hrSM1J3gVFgF5PVHTzv6k90PIbpYsCsMX634CwZIIFGgJln0oBJBeOwH5pqK5yQpGt0OQozIY9TfNYVfubRpsu5t5cm45cp-7OQEADEZptNyvuzC6VEKWLA41KBizlxVqpZwAfh8q-Ym5OAFAX7cR6un8p4h12422YYnFbUJv6gaPKCb-XLCwr-BqDgABDlAZ71lbeW-HLtrodN8-a9HpRCSu17pNesX-WuIlJBUBzs6SSvEomyJvu2y--Am5RCKp2R8Hgq2g2H78g9AZuRsBSk7p2M7zfnBNV4NuK9QsaWRm4nGX4WblpKyHr28XqSQB3n5X7QI17RMV7nx2WC_oXvE0EFcadTe81705GfJm7B4BfqjA-yV-URjlSNnH1Z9YWMoVO594UGIxPSUOJOIDKRQBnVPIW9vIufiV_TzyhUCa3iTQd8ax-4hL6O0DpgkgehUBmYTeWtMJHFI_kNtnklJrNrPQk2vaiqiqghEnSOGq-y0B0j1EVVxWkyQGfYKBdjKktIvjFCZxAaCYcxlyddAoTwUBjR744krPNeaPQESAMkNS6SFkW8NUsFZE571Os6gOnRMBrbGvz6_-dWlla1TVzjn3wRpVlY9j9DLvupqpYzTj8BMBDRntusuc8Cu_XBwQU9QiR5UmhVA4wHJ3KgqXDzpU1SUBiaxwUsNvUKibzQYLpn-pRG3-sLbYCnTvYX3Ur2bMIDkBrF0QVebcheaWzeLkzVjkEXVWYi3mFsBLNCfrz055ITkBouBUxluRSy7Mo6m6ozWg1qUBnPuxnOBz6tUuHw-WPzAAAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAcMYHYfQq0qZzsiFs9TeUbC8oyswbr7OjcoahyvA78QdASiIwnFkuQs0GpeogsVFT1hoqNaHlrPxjvVCgO4_lig6Ac_m9fzHUjk9y_yUElbCuoSZ0yIorhrdEg0PvszZOJIzARfm_NoAYyHSb2jilosISHY2B_gy-a2wuqcaFbkveYglAf_bTpCddyllde8WLbcxWBaTqK4aJijp17EU9uZIMjAKAUASitwyPOzSS19N7_g0vpYMkKXJfRbObRI-3oyVsr88AZL1_NwMTNP23kJ5SLB4MS4LN0S2STK1WvYUHOj-btgsAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3Aa1s8ln_6tGNOv04L0EOdxo9XQ8mFFT6aZaT2BxFzIA8AAAAAAAAAAAAAAAAAAAAAAAAAADfFIsPJvAfi1Zu3B5RbKkhShEa2pj61ErHDi6kSQlXOwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwBf7WaQKIibHJKl8UFjM_lwQ-QbckeUvnrUlLEJ60YwCKQbb6CBlRSd_nBliNNvqE0Zdomu94rAdJl0dllnhoEDaXlKoIgKPevyE8Q3Is6g9kqXaFp6s5Pa9ImS8BYyrBV2Z2Ql6HY3BcSnLE6gxakcHe6oNmQPRnIuciJP6PlEMkxFg96rSncZ6lI7T1YmX1kb9UTfY8tIEqLV7B8ZfxwUqQo6KIPhdezV26TVKEkCtWuqotEd7mZ3BHUPkF8gViC8g8fic8QRW0ZfoCzNCwubnnZI3YXl18iekvMFsKIBL54BSppTlA0iMXbnXCsKD3xmU36vbVLAwPQNXY_GbuU11EsiOTZOB4lB-rhHtowcba9M0zzvJ--ghUBS4RJqhw4D-zakbniFVJhfE_Box0riSjfoTpwGbDxBKQIMAmgBAXjLfxEI_zI-1yEANarSOeGWBh8e6_NBSMJlhAITPVAHEDdmitoyunH7NCrgAZf_-UEnOr6ftLtFR23A66Llzh7925nQAmDVYr65rJoeft2Ltn-r-EjSB5jdxEvzs-NDNMuAYPrSN6yrwVKFMNHCgdsaHXAfUphv7q6aRzZlRbgL2TwlrTTBFZYLae1PZY5eylm0lHeq-X9jF1v364JkGDmm1mQmI697mWJvqN9qiomxij8tDsBTI_Wzf2njemAiKzltKoUJcMS3ZZr5zwUN1BQ5OlolEVYJ7FWXeIF8v-YGX41FSQNwr56cZdku_ZOW17EWJCs5tdFwQAYjD6bj_RwWPtny9tH3Ez-NXk3u-Ugbapncl6cU5HooP0RKrOngJ9M3OBLWVOT99iM6ZLZK39OtRifN5qXW1xuJg_Y_ZkwpTMVLMejFlc_Ym2R8zwv5VCO2FQXJoST5pQG3-FIABTLMCWoZ1eNoKa5cd2_0OBNLa6l9DIXrFpoF23Qg1hw9GoZ7_oRnIF8wPyS5TJcUO7YIjyMaictxksPOuWhHUX8Ni8xLg5ERG4_WJ1D02y8FBJotAZF0Z_LIIhrZ9OG4sQB8T_Y7BnpEbXeeH7nOBTZ65vQc_-b9iWcTC6FnSMc8A2n8c09qr_Mu4CArkm5n0QPKiNDoM74GePT3UpGmmO8y4i_MC-fg9HbN7iLECVbnILy6j3uVaZNCuQmHxs_ccTAh6iZi-hN-UhsQ5w1HgFkY9za-n6HqUMBpKV6AkVPTDjVfCgpHQu2BNFGm-XdohA2Relb5tmcXBBk4z9lTCtQ3ZW4VBuwhUXqAieE42n7RTbRe2KGx6PDxo65FryquySoAhJZ8MnB0A6hoc-3LMlPaDUL1skkSGeaYvb9Zk806HDolU5b8bMIWKc72o42cmG5QMWu0Lh8oo-Gvhx91afrLDUbP63XVP6rb3GBVTJm83WqFJfKm9OewqCPtQN1Q_A0AaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSRujobz21FKPf2s93UGaAvqMNDoRcPA1lf6TGTJWhslKBL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMeO9d3ZgCHqNalqD9kAAa8p8E238w1kwjrxET-AOaCaxhzF2u7xMNaQMsC-NlyGMrNmPJj3Vi1ro_BuBXyycXdKTxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh6yc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAuVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQndTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIixX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMvTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRbcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEE5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWip6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNugJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB32gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEIC1K-m_DwuxGRnVBt8Du4n_a1OpLW-A8Blh3FQCVcmFQgfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhWXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOfNyjRaA4QloG0tvgBH-pqdY-Okn3C4W7PPEGb5vlXYWeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTknpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJmZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAC5TYFuAGtf-p0XpdmrdjantM1iddY-zOf7UDDKcWaont3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHtltYuVKCknTpEyRnrSwiTM9ZKI27c2hkhJ0rGkDutk3zOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDyjDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLtgtOHF4Qr3jFxV-3xhqWypawqA1oGmxihu3kNihtg4maZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw9xcRXllxPIT4i6vi7AKSUYBg0syCtU6anJotKofOkeFV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFxbrouvan-rEQuKe-Sk_XEV2kz1TGm48B1GONSJBBV893PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUANTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjzwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLje--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJ4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xxr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHO6AK-r03brztpaYaJ1-drZwyqZd29khlyJ6sMjfujYktcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xDARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGs1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIK5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmgiazJTZw-e932ajI9gr9UUZu48vW91I_s60WoveCqegOZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXzioSgyJqnNMLk4KXtDxWzAUyzyCAcSQAOd4bI87hZwsPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbUb_BCBPxFRvEbI6OLjq80C0DMk7W2pv-_yQMNv0Ldi8fkz2DkvS4mRSG-22i6f-ldZg8bw7cDMXRjeHquvUVNQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQb)
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
                (nonce 0) (valid_until 4294967295)
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
                (nonce 0) (valid_until 4294967295)
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
                (nonce 0) (valid_until 4294967295)
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
                (nonce 0) (valid_until 4294967295)
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
                (nonce 0) (valid_until 4294967295)
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
                (nonce 0) (valid_until 4294967295)
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
                (nonce 0) (valid_until 4294967295)
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
 (protocol_version ((transaction 1) (network 1)))
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
    "scheduled_time": "1690219472442",
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
          "timestamp": "1690219472442",
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
            "slot_number": "6",
            "slots_per_epoch": "576"
          },
          "global_slot_since_genesis": "6",
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
    "protocol_state_proof": "_AzFacptM6EI_IuGEn36D_DDAPyJALP-mtaLe_wRKLlqjdLzswD8wQc1hnC4z3P8nOfrwyXsm3IA_CVPq1cotlsK_PKA6zqDmK-xAAAAAAAAAAAAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAAhAAAAAAAGKZVEkV8JvnwXkRRC0lSEBTtFkF259BVjBh_X28MtMPrNdShffBok_HsebifDwWOlWmsec2OQMdBOulXlAEBRb8b7_mrMmzgjP8Yxh2-VhDl3kA_JeHiOkGKzrd_MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA_IsHEI-xd5zi_O4Ma98AX1z4APyHnLAHLae9HfygJl_p4pcbTQD8EV-AVnx0dZz86PHO-mlj_qEA_E1g6dvfiitc_Jv3EPKMcYxaAPxIa-BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA_MkrPzde40VE_OXNjPwVx0CdAPxOqrxLhIKYQvy8t6_Q1yeplwD8d279_1s9ypn8lEJcFVVq5u8A_FSZlyFxsn1L_EDIk2Hgoh-VAPyzRweyvszRLPwdAmTyPN7RWwAA_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAAAAAki1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QVItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFAvy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAA_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAA6PGEyR9EE3YxctI9ZycvlAjfZwksavOFt5bC5qZVPN_K6SgIy3_BdUryusTZvur9-D_wscMYan9MzTVYfUu4NAZFybfMU6ohMg5uZyYwMBIrJb9mVY02jrYcwm4cGvRcyAUT9NbzTqkpk-PtboA1O3r06rPJeW2l4qXOi4SMKH7IWATZiy6C9nok12DD8i9j3LiUazqifKXguHbIEIH9mj8oiAbKXgLylZHSdFvnkYWGGjhuw1S9UqCqifTqeahbmA8UYAQ5hecZuoLB8gtts0SMPxhaSut1RZ_qIt2lXmtJv8bgGAY_qMJcltWdvZuLn3kzz0Ofd5oeojuv-gZOm2sWDR8E6AaYUXjamNkTUesbOkhefo26mF6KY8Qg86Im0ygmvUcYcAd_ZeC_e6MMuV6Bh2DMnbL9XzTgkAcTcKX919ukIDPASASmkGJFHwKWqDsHf_kowkf2HW53CH-dCQzTYOfRUgxUjASmQRP-Dv9Mjjkm-oa-BgycS2r5STXExtnEV6Q8EEIQyAYhpJddFLTbQ574zHGl3Hc5L0gGM2A31KzvTmN5ADRc8Abtd8iY33R5xkzi0OfdZQ2cg0BiNXxG_9ZIjMXgQNH80AZgpRK5PEVqA6-eAg4lBWhIj4KpWHaTCOMcaz0aKS_woAY1SjIZXKSTQBUTGZ1AkDAWVDeDYc1FAc78m89OAYMUQARMjnkaifpINMJNbzWollLJGbVZ4t4eFtG8OAlVUlrEXAdIsMwcSIrttuMXHi69UgcoLP7-85gfIZ28tK5XBbb4gATKKvX0ohceTcr_LtpFLUeLLPnvdLU4jc0XYdC6Sv3UnAWZA7oB1BZZmSe32gQ-A0zA2BGrQM4XdH2mAJQyv_XAIAYgoFDGCTKmZM4cKyk9cg2U7tz1E7G-9TYQchXUhnscPARVKU4BojQx-yjve2IP1gIfv949-v96DB3FGgL9-l8YOARmqpJkw6bKiRBto0Z1j1xOgVpfygHMRMzlSlPZku2IRAcUV9RcO3D8JcVj42YlI5rJFwHjeSBTxUXie80n5FAQCAUPBQCz_koAF-2QRQgrQVvZysAJ1VX0s1u1F61VJ_L86AeFVD0JCRca10RW7_010nTo4zrBV0gv_OybE4oEosfstAap9Qy5G7Ag87unSTftDg3E6QoakqfdrTJnY2VyYztgxAUm3AonxovG_2xV1nZ5um1pteu2vhhsl61mRofM70JgPAQjbjCLm7Tn6plqfs9roiHsbc5usddtSM52OTe76vm84AegRmK03P__TnOWemols3AdERSLCXz0UeUrSretqNDQkASRQhAtW8jVeb8al0MstOxegNz1L-Bm0GmMcti2AcQkUAbOINmA9szxWEdW8hv5wQZl7frZbY2eItk_pLmsRENIEAAEvwOjTlWCgsCMWjWpRghNlWQE8N9FewsLuEoPGubd7HQHCYmpoFFNIbqXUE_DqAwz11zHwq9_mMsdKKmmDte4PFwGFWckwTe35TyNm1Niq88nCr1wqszmKWu9My4OaUN68NQGdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQGtC9t5svFvTRQn4Nr-cMBjEPpGBrk-tEKCU4-D2ijxPwGV0WIswKfy24qZ2BVlNNVyB6rzu8alpqGjFc2SQmiCHwFS0reBvhwwDB3LQCBfYCQHWpkLPtZAaF6khi9l6UbpGgE2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAFxI5ougXdG8pcPqt7xrkNRXIrf_CCxbxlGt8LnQLK-MgEhErp_10lnQVY7lIh4YSpf6hH-4X9Iu7ALrs9733jkIwHu3CQpAe6rrMu2XSVx_8Jo__W7ZvdUJaWnt1n_4rMoDwF7DTz4lANzls8z1DLGEf_TNvmGWkqP0h9NuNNHbmBoOwFdyzC-_PLz2ZYuTi5MogrWTHpyxzBwlHIaR1F3n8oiIwHEbrA7kGr-BD0iUMbnHPhQd3bBvCJGInmA_EJ3BP4qBQEKzCtv_aYC-uIHNevghsaQ__iLWwvw3e2xnwM6vm3wJgE3jMlSF-_fiEjkbNvvN-xMoO8jqbkknuJIHbkZU5CCCwHhXODBNtpjzl85oYYtmwUEuH7GswTgiAeZfYZLKuXnAwENViE30_FxaxBbMuOMCBvP-iB4vqKIjSdvNUlKRR2ZMAG7wdpIm816ZRuiURpesbuExUAOd4IrVVru3_BarFqZGAFXzb1Ke2lZRwF_8Qw00e8J5Amy1Wvmx1y8wnSsHygTCwHmfEbSm7zz9JhzAnA_Y4w2DABjmIxM_PL6LQTr-clhAgE2UeOYb14khXPRV7mNhBzZXQm-zOQGSghRK_9pOIFfEQGRF9HtRRuJy7tDdTHSQMC1RmrWUR_NGb4AGrz0YbR-CwFsw2cP7MfLQA1G7MePPyAHoM6iXjrMdjBp3nwxS_e_LAGlY8mV8f-Px-qgGxOywW301TZCoZuobwfO4e3v-zItHgGLn3KkrMs34UEblCpceb73vxW2dKSyuq6hrSM1J3gVFgF5PVHTzv6k90PIbpYsCsMX634CwZIIFGgJln0oBJBeOwH5pqK5yQpGt0OQozIY9TfNYVfubRpsu5t5cm45cp-7OQEADEZptNyvuzC6VEKWLA41KBizlxVqpZwAfh8q-Ym5OAFAX7cR6un8p4h12422YYnFbUJv6gaPKCb-XLCwr-BqDgABDlAZ71lbeW-HLtrodN8-a9HpRCSu17pNesX-WuIlJBUBzs6SSvEomyJvu2y--Am5RCKp2R8Hgq2g2H78g9AZuRsBSk7p2M7zfnBNV4NuK9QsaWRm4nGX4WblpKyHr28XqSQB3n5X7QI17RMV7nx2WC_oXvE0EFcadTe81705GfJm7B4BfqjA-yV-URjlSNnH1Z9YWMoVO594UGIxPSUOJOIDKRQBnVPIW9vIufiV_TzyhUCa3iTQd8ax-4hL6O0DpgkgehUBmYTeWtMJHFI_kNtnklJrNrPQk2vaiqiqghEnSOGq-y0B0j1EVVxWkyQGfYKBdjKktIvjFCZxAaCYcxlyddAoTwUBjR744krPNeaPQESAMkNS6SFkW8NUsFZE571Os6gOnRMBrbGvz6_-dWlla1TVzjn3wRpVlY9j9DLvupqpYzTj8BMBDRntusuc8Cu_XBwQU9QiR5UmhVA4wHJ3KgqXDzpU1SUBiaxwUsNvUKibzQYLpn-pRG3-sLbYCnTvYX3Ur2bMIDkBrF0QVebcheaWzeLkzVjkEXVWYi3mFsBLNCfrz055ITkBouBUxluRSy7Mo6m6ozWg1qUBnPuxnOBz6tUuHw-WPzAAAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAcMYHYfQq0qZzsiFs9TeUbC8oyswbr7OjcoahyvA78QdASiIwnFkuQs0GpeogsVFT1hoqNaHlrPxjvVCgO4_lig6Ac_m9fzHUjk9y_yUElbCuoSZ0yIorhrdEg0PvszZOJIzARfm_NoAYyHSb2jilosISHY2B_gy-a2wuqcaFbkveYglAf_bTpCddyllde8WLbcxWBaTqK4aJijp17EU9uZIMjAKAUASitwyPOzSS19N7_g0vpYMkKXJfRbObRI-3oyVsr88AZL1_NwMTNP23kJ5SLB4MS4LN0S2STK1WvYUHOj-btgsAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3Aa1s8ln_6tGNOv04L0EOdxo9XQ8mFFT6aZaT2BxFzIA8AAAAAAAAAAAAAAAAAAAAAAAAAADfFIsPJvAfi1Zu3B5RbKkhShEa2pj61ErHDi6kSQlXOwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwBf7WaQKIibHJKl8UFjM_lwQ-QbckeUvnrUlLEJ60YwCKQbb6CBlRSd_nBliNNvqE0Zdomu94rAdJl0dllnhoEDaXlKoIgKPevyE8Q3Is6g9kqXaFp6s5Pa9ImS8BYyrBV2Z2Ql6HY3BcSnLE6gxakcHe6oNmQPRnIuciJP6PlEMkxFg96rSncZ6lI7T1YmX1kb9UTfY8tIEqLV7B8ZfxwUqQo6KIPhdezV26TVKEkCtWuqotEd7mZ3BHUPkF8gViC8g8fic8QRW0ZfoCzNCwubnnZI3YXl18iekvMFsKIBL54BSppTlA0iMXbnXCsKD3xmU36vbVLAwPQNXY_GbuU11EsiOTZOB4lB-rhHtowcba9M0zzvJ--ghUBS4RJqhw4D-zakbniFVJhfE_Box0riSjfoTpwGbDxBKQIMAmgBAXjLfxEI_zI-1yEANarSOeGWBh8e6_NBSMJlhAITPVAHEDdmitoyunH7NCrgAZf_-UEnOr6ftLtFR23A66Llzh7925nQAmDVYr65rJoeft2Ltn-r-EjSB5jdxEvzs-NDNMuAYPrSN6yrwVKFMNHCgdsaHXAfUphv7q6aRzZlRbgL2TwlrTTBFZYLae1PZY5eylm0lHeq-X9jF1v364JkGDmm1mQmI697mWJvqN9qiomxij8tDsBTI_Wzf2njemAiKzltKoUJcMS3ZZr5zwUN1BQ5OlolEVYJ7FWXeIF8v-YGX41FSQNwr56cZdku_ZOW17EWJCs5tdFwQAYjD6bj_RwWPtny9tH3Ez-NXk3u-Ugbapncl6cU5HooP0RKrOngJ9M3OBLWVOT99iM6ZLZK39OtRifN5qXW1xuJg_Y_ZkwpTMVLMejFlc_Ym2R8zwv5VCO2FQXJoST5pQG3-FIABTLMCWoZ1eNoKa5cd2_0OBNLa6l9DIXrFpoF23Qg1hw9GoZ7_oRnIF8wPyS5TJcUO7YIjyMaictxksPOuWhHUX8Ni8xLg5ERG4_WJ1D02y8FBJotAZF0Z_LIIhrZ9OG4sQB8T_Y7BnpEbXeeH7nOBTZ65vQc_-b9iWcTC6FnSMc8A2n8c09qr_Mu4CArkm5n0QPKiNDoM74GePT3UpGmmO8y4i_MC-fg9HbN7iLECVbnILy6j3uVaZNCuQmHxs_ccTAh6iZi-hN-UhsQ5w1HgFkY9za-n6HqUMBpKV6AkVPTDjVfCgpHQu2BNFGm-XdohA2Relb5tmcXBBk4z9lTCtQ3ZW4VBuwhUXqAieE42n7RTbRe2KGx6PDxo65FryquySoAhJZ8MnB0A6hoc-3LMlPaDUL1skkSGeaYvb9Zk806HDolU5b8bMIWKc72o42cmG5QMWu0Lh8oo-Gvhx91afrLDUbP63XVP6rb3GBVTJm83WqFJfKm9OewqCPtQN1Q_A0AaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSRujobz21FKPf2s93UGaAvqMNDoRcPA1lf6TGTJWhslKBL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMeO9d3ZgCHqNalqD9kAAa8p8E238w1kwjrxET-AOaCaxhzF2u7xMNaQMsC-NlyGMrNmPJj3Vi1ro_BuBXyycXdKTxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh6yc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAuVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQndTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIixX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMvTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRbcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEE5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWip6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNugJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB32gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEIC1K-m_DwuxGRnVBt8Du4n_a1OpLW-A8Blh3FQCVcmFQgfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhWXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOfNyjRaA4QloG0tvgBH-pqdY-Okn3C4W7PPEGb5vlXYWeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTknpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJmZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAC5TYFuAGtf-p0XpdmrdjantM1iddY-zOf7UDDKcWaont3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHtltYuVKCknTpEyRnrSwiTM9ZKI27c2hkhJ0rGkDutk3zOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDyjDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLtgtOHF4Qr3jFxV-3xhqWypawqA1oGmxihu3kNihtg4maZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw9xcRXllxPIT4i6vi7AKSUYBg0syCtU6anJotKofOkeFV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFxbrouvan-rEQuKe-Sk_XEV2kz1TGm48B1GONSJBBV893PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUANTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjzwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLje--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJ4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xxr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHO6AK-r03brztpaYaJ1-drZwyqZd29khlyJ6sMjfujYktcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xDARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGs1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIK5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmgiazJTZw-e932ajI9gr9UUZu48vW91I_s60WoveCqegOZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXzioSgyJqnNMLk4KXtDxWzAUyzyCAcSQAOd4bI87hZwsPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbUb_BCBPxFRvEbI6OLjq80C0DMk7W2pv-_yQMNv0Ldi8fkz2DkvS4mRSG-22i6f-ldZg8bw7cDMXRjeHquvUVNQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQb",
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
                      "valid_until": "4294967295",
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
                      "valid_until": "4294967295",
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
                      "valid_until": "4294967295",
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
                      "valid_until": "4294967295",
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
                      "valid_until": "4294967295",
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
                      "valid_until": "4294967295",
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
                      "valid_until": "294967295",
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
      "transaction": 1,
      "network": 1
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
