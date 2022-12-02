(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1668291220375)
 (protocol_state
  ((previous_state_hash
    21354980353151189422399682646222993743985711850484615412360382988223153878921)
   (body
    ((genesis_state_hash
      21354980353151189422399682646222993743985711850484615412360382988223153878921)
     (blockchain_state
      ((staged_ledger_hash
        ((non_snark
          ((ledger_hash
            8237146277932330249654065688686921375424120725278996540638677687495951864518)
           (aux_hash
            "C\218\138 (.x\014\172\014\165\255\205\131Z\168\183\148\239LZT\174,\021;t\170\251\127\244q")
           (pending_coinbase_aux
            "\147\141\184\201\248,\140\181\141?>\244\253%\0006\164\141&\167\018u=/\222Z\189\003\168\\\171\244")))
         (pending_coinbase_hash
          11986604660264413220488134474502773536407841248153857093789092441218881319786)))
       (genesis_ledger_hash
        4816407238806199519904806484759825294535379744277661893639373343262974140371)
       (registers
        ((ledger
          4816407238806199519904806484759825294535379744277661893639373343262974140371)
         (pending_coinbase_stack ())
         (local_state
          ((stack_frame
            0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C)
           (call_stack
            0x0000000000000000000000000000000000000000000000000000000000000000)
           (transaction_commitment
            0x0000000000000000000000000000000000000000000000000000000000000000)
           (full_transaction_commitment
            0x0000000000000000000000000000000000000000000000000000000000000000)
           (token_id
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (excess ((magnitude 0) (sgn Pos)))
           (supply_increase ((magnitude 0) (sgn Pos))) (ledger 0)
           (success true) (account_update_index 0) (failure_status_tbl ())))))
       (timestamp 1668291220375)
       (body_reference
        "\255\242\2436c:`\178\"\194:/\242\132g\199\205r\251\197%\133\\\028\190\163#\236\221\247\178\157")))
     (consensus_state
      ((blockchain_length 2) (epoch_count 0) (min_window_density 6)
       (sub_window_densities (1 0 0))
       (last_vrf_output
        "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000")
       (total_currency 10016120000000000)
       (curr_global_slot ((slot_number 6) (slots_per_epoch 576)))
       (global_slot_since_genesis 6)
       (staking_epoch_data
        ((ledger
          ((hash
            4816407238806199519904806484759825294535379744277661893639373343262974140371)
           (total_currency 10016100000000000)))
         (seed 0) (start_checkpoint 0) (lock_checkpoint 0) (epoch_length 1)))
       (next_epoch_data
        ((ledger
          ((hash
            4816407238806199519904806484759825294535379744277661893639373343262974140371)
           (total_currency 10016100000000000)))
         (seed
          11097254031198438328229081175959322858342266757425965220770466547940953006797)
         (start_checkpoint 0)
         (lock_checkpoint
          21354980353151189422399682646222993743985711850484615412360382988223153878921)
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
  _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAspeAvKVkdJ0W-eRhYYaOG7DVL1SoKqJ9Op5qFuYDxRgADmF5xm6gsHyC22zRIw_GFpK63VFn-oi3aVea0m_xuAb8JU-rVyi2Wwr88oDrOoOYr7EA_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAACEAAAAAAAYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFvxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAD8b7_mrMmzgjP8Yxh2-VhDl3kA_JeHiOkGKzrd_MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA_IsHEI-xd5zi_O4Ma98AX1z4APyHnLAHLae9HfygJl_p4pcbTQD8EV-AVnx0dZz86PHO-mlj_qEA_E1g6dvfiitc_Jv3EPKMcYxaAPxIa-BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA_MkrPzde40VE_OXNjPwVx0CdAPxOqrxLhIKYQvy8t6_Q1yeplwD8d279_1s9ypn8lEJcFVVq5u8A_FSZlyFxsn1L_EDIk2Hgoh-VAPyzRweyvszRLPwdAmTyPN7RWwAAAAACSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUC_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAKYUXjamNkTUesbOkhefo26mF6KY8Qg86Im0ygmvUcYc39l4L97owy5XoGHYMydsv1fNOCQBxNwpf3X26QgM8BIBKaQYkUfApaoOwd_-SjCR_YdbncIf50JDNNg59FSDFSMBKZBE_4O_0yOOSb6hr4GDJxLavlJNcTG2cRXpDwQQhDIBiGkl10UtNtDnvjMcaXcdzkvSAYzYDfUrO9OY3kANFzwBu13yJjfdHnGTOLQ591lDZyDQGI1fEb_1kiMxeBA0fzQBmClErk8RWoDr54CDiUFaEiPgqlYdpMI4xxrPRopL_CgBjVKMhlcpJNAFRMZnUCQMBZUN4NhzUUBzvybz04BgxRABEyOeRqJ-kg0wk1vNaiWUskZtVni3h4W0bw4CVVSWsRcB0iwzBxIiu224xceLr1SBygs_v7zmB8hnby0rlcFtviABMoq9fSiFx5Nyv8u2kUtR4ss-e90tTiNzRdh0LpK_dScBZkDugHUFlmZJ7faBD4DTMDYEatAzhd0faYAlDK_9cAgBiCgUMYJMqZkzhwrKT1yDZTu3PUTsb71NhByFdSGexw8BFUpTgGiNDH7KO97Yg_WAh-_3j36_3oMHcUaAv36Xxg4BGaqkmTDpsqJEG2jRnWPXE6BWl_KAcxEzOVKU9mS7YhEBxRX1Fw7cPwlxWPjZiUjmskXAeN5IFPFReJ7zSfkUBAIBQ8FALP-SgAX7ZBFCCtBW9nKwAnVVfSzW7UXrVUn8vzoB4VUPQkJFxrXRFbv_TXSdOjjOsFXSC_87JsTigSix-y0Bqn1DLkbsCDzu6dJN-0ODcTpChqSp92tMmdjZXJjO2DEBSbcCifGi8b_bFXWdnm6bWm167a-GGyXrWZGh8zvQmA8BCNuMIubtOfqmWp-z2uiIextzm6x121IznY5N7vq-bzgB6BGYrTc__9Oc5Z6aiWzcB0RFIsJfPRR5StKt62o0NCQBJFCEC1byNV5vxqXQyy07F6A3PUv4GbQaYxy2LYBxCRQBs4g2YD2zPFYR1byG_nBBmXt-tltjZ4i2T-kuaxEQ0gQBL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwAAXEjmi6Bd0bylw-q3vGuQ1Fcit_8ILFvGUa3wudAsr4yASESun_XSWdBVjuUiHhhKl_qEf7hf0i7sAuuz3vfeOQjAe7cJCkB7qusy7ZdJXH_wmj_9btm91Qlpae3Wf_isygPAXsNPPiUA3OWzzPUMsYR_9M2-YZaSo_SH02400duYGg7AV3LML788vPZli5OLkyiCtZMenLHMHCUchpHUXefyiIjAcRusDuQav4EPSJQxucc-FB3dsG8IkYieYD8QncE_ioFAQrMK2_9pgL64gc16-CGxpD_-ItbC_Dd7bGfAzq-bfAmATeMyVIX79-ISORs2-837Eyg7yOpuSSe4kgduRlTkIILAeFc4ME22mPOXzmhhi2bBQS4fsazBOCIB5l9hksq5ecDAQ1WITfT8XFrEFsy44wIG8_6IHi-ooiNJ281SUpFHZkwAbvB2kibzXplG6JRGl6xu4TFQA53gitVWu7f8FqsWpkYAVfNvUp7aVlHAX_xDDTR7wnkCbLVa-bHXLzCdKwfKBMLAeZ8RtKbvPP0mHMCcD9jjDYMAGOYjEz88votBOv5yWECATZR45hvXiSFc9FXuY2EHNldCb7M5AZKCFEr_2k4gV8RAZEX0e1FG4nLu0N1MdJAwLVGatZRH80ZvgAavPRhtH4LAWzDZw_sx8tADUbsx48_IAegzqJeOsx2MGnefDFL978sAaVjyZXx_4_H6qAbE7LBbfTVNkKhm6hvB87h7e_7Mi0eAYufcqSsyzfhQRuUKlx5vve_FbZ0pLK6rqGtIzUneBUWAXk9UdPO_qT3Q8huliwKwxfrfgLBkggUaAmWfSgEkF47AfmmornJCka3Q5CjMhj1N81hV-5tGmy7m3lybjlyn7s5AQAMRmm03K-7MLpUQpYsDjUoGLOXFWqlnAB-Hyr5ibk4AUBftxHq6fyniHXbjbZhicVtQm_qBo8oJv5csLCv4GoOAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAAGNHvjiSs815o9ARIAyQ1LpIWRbw1SwVkTnvU6zqA6dEwGtsa_Pr_51aWVrVNXOOffBGlWVj2P0Mu-6mqljNOPwEwENGe26y5zwK79cHBBT1CJHlSaFUDjAcncqCpcPOlTVJQGJrHBSw29QqJvNBgumf6lEbf6wttgKdO9hfdSvZswgOQGsXRBV5tyF5pbN4uTNWOQRdVZiLeYWwEs0J-vPTnkhOQGi4FTGW5FLLsyjqbqjNaDWpQGc-7Gc4HPq1S4fD5Y_MAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAABkvX83AxM0_beQnlIsHgxLgs3RLZJMrVa9hQc6P5u2CwBTLHhvOyEP6t-N3gPRIgNWOv6PCi0wMkTrkFJWlvPWxkBwMhN_qFTBruWJxW5IcARf96fP53_qXNPypd8roZUkDcBrWzyWf_q0Y06_TgvQQ53Gj1dDyYUVPpplpPYHEXMgDwAj-owlyW1Z29m4ufeTPPQ593mh6iO6_6Bk6baxYNHwToBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsHAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwAPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbdmdkJeh2NwXEpyxOoMWpHB3uqDZkD0ZyLnIiT-j5RDJMRYPeq0p3GepSO09WJl9ZG_VE32PLSBKi1ewfGX8cFAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAdRLIjk2TgeJQfq4R7aMHG2vTNM87yfvoIVAUuESaocOAQP7NqRueIVUmF8T8GjHSuJKN-hOnAZsPEEpAgwCaAEBAXjLfxEI_zI-1yEANarSOeGWBh8e6_NBSMJlhAITPVAHARA3ZoraMrpx-zQq4AGX__lBJzq-n7S7RUdtwOui5c4eAf3bmdACYNVivrmsmh5-3Yu2f6v4SNIHmN3ES_Oz40M0AcuAYPrSN6yrwVKFMNHCgdsaHXAfUphv7q6aRzZlRbgLAdk8Ja00wRWWC2ntT2WOXspZtJR3qvl_Yxdb9-uCZBg5AabWZCYjr3uZYm-o32qKibGKPy0OwFMj9bN_aeN6YCIrATltKoUJcMS3ZZr5zwUN1BQ5OlolEVYJ7FWXeIF8v-YGAV-NRUkDcK-enGXZLv2TltexFiQrObXRcEAGIw-m4_0cARY-2fL20fcTP41eTe75SBtqmdyXpxTkeig_REqs6eAnAdM3OBLWVOT99iM6ZLZK39OtRifN5qXW1xuJg_Y_ZkwpAUzFSzHoxZXP2JtkfM8L-VQjthUFyaEk-aUBt_hSAAUyAcwJahnV42gprlx3b_Q4E0trqX0MhesWmgXbdCDWHD0aAYZ7_oRnIF8wPyS5TJcUO7YIjyMaictxksPOuWhHUX8NAYvMS4ORERuP1idQ9NsvBQSaLQGRdGfyyCIa2fThuLEAAXxP9jsGekRtd54fuc4FNnrm9Bz_5v2JZxMLoWdIxzwDAWn8c09qr_Mu4CArkm5n0QPKiNDoM74GePT3UpGmmO8yAeIvzAvn4PR2ze4ixAlW5yC8uo97lWmTQrkJh8bP3HEwASHqJmL6E35SGxDnDUeAWRj3Nr6foepQwGkpXoCRU9MOATVfCgpHQu2BNFGm-XdohA2Relb5tmcXBBk4z9lTCtQ3AWVuFQbsIVF6gInhONp-0U20Xtihsejw8aOuRa8qrskqAYSWfDJwdAOoaHPtyzJT2g1C9bJJEhnmmL2_WZPNOhw6ASVTlvxswhYpzvajjZyYblAxa7QuHyij4a-HH3Vp-ssNAUbP63XVP6rb3GBVTJm83WqFJfKm9OewqCPtQN1Q_A0AAWkKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kAW6OhvPbUUo9_az3dQZoC-ow0OhFw8DWV_pMZMlaGyUoARL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMeATvXd2YAh6jWpag_ZAAGvKfBNt_MNZMI68RE_gDmgmsYAXMXa7vEw1pAywL42XIYys2Y8mPdWLWuj8G4FfLJxd0pAAE8YarsOpthEm-zgZWflXYHlK8dYqU5SCMwvEg7uWlMBgG1lDFQ8arF3lNiO4utX_pjZY6rvGOOemMnsf-pKzF6HgGyc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAgHlSbmjbLnGgXUX59Zt-nH7ttgJlNtTf5tRknzzDXCEJwF1M96_qj16L7hWfRm_YlYUbKK8EhtSPPvkJ5Lgs1MiLAFX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMgH00fCHMH6Wpd0tQf0iAXwJ5JBvViTJqecOhRWDK9RMNQEBhe9XkAAcvm5OCJRA_FIknHm7TTEgivfF2IEI3MeJFgHcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFQFTSa9QkePNGMCS7ZV743HXm8o-GjO_D4OIrBiRJZRBBAHnIr8LOE_BSDulDYlGBNxVRuQ0xMq2ABzCvFn6x5haKgF6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNgHoCT9WxI5UAP7Vwqhq6NszhWP1p-oxpmstCDPitzrWDAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQH2gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEICwFSvpvw8LsRkZ1QbfA7uJ_2tTqS1vgPAZYdxUAlXJhUIAF-WLJP0invsW4SBaZLXLuYZWavhBrsak2NpUIAXTl2FQGXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOQHzco0WgOEJaBtLb4AR_qanWPjpJ9wuFuzzxBm-b5V2FgF4ZP81nWoge3I_GH93hhXS8HMrN68WmXeUz4NJZNh5OQEnpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJgFmTnym_pPxUfBpUIuCatXQbHFUkxjLyRHaa3TQbv4oBgEuU2BbgBrX_qdF6XZq3Y2p7TNYnXWPszn-1AwynFmqJwG3eoeIsH980cnGFhh1XMo9DTA6ewlhJM4MAtxfRRoPAwEuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHgHZbWLlSgpJ06RMkZ60sIkzPWSiNu3NoZISdKxpA7rZNwHM46eN-iQtjFPolGfMmG39My25h9dsZudzWkfvNOkPKAHDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLgHYLThxeEK94xcVft8YalsqWsKgNaBpsYobt5DYobYOJgFplOJw8oSlV8QYr-v6rKJ5TIr2pHbLG5R4wgXoqQEXDwABcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUBNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4BN776nYDGKPuLP39TFpEsF1QmoK2ag9t4CEfWNvHMqwkB4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xwBa98jDsB6kVMZxgatkwxB3X8JciKtondqSE51X-stSRwB7oAr6vTduvO2lphonX52tnDKpl3b2SGXInqwyN-6NiQBtcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xABwEQWKAElGddv7wEHQ03Fa7F059FhDN4vyG1qpyt1rRoAAc1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIKAeWACT0kBAb2aEsxPOQGab1bocjfPtU87S9HPAN68ZoIAZrMlNnD573fZqMj2Cv1RRm7jy9b3Uj-zrRai94Kp6A5AZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXAKkKOiiD4XXs1duk1ShJArVrqqLRHe5mdwR1D5BfIFYg)
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
                ((source_pk
                  B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
                 (receiver_pk
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
                ((source_pk
                  B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
                 (receiver_pk
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
                ((source_pk
                  B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
                 (receiver_pk
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
                ((source_pk
                  B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
                 (receiver_pk
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
                ((source_pk
                  B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
                 (receiver_pk
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
                ((source_pk
                  B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
                 (receiver_pk
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
                ((source_pk
                  B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
                 (receiver_pk
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
  (21354980353151189422399682646222993743985711850484615412360382988223153878921
   ()))
 (accounts_accessed
  ((2
    ((public_key B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      1756052024613657634730554264564165361515062420964192359191855470145283983189)
     (delegate (B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (1
    ((public_key B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 98999999999) (nonce 1)
     (receipt_chain_hash
      14724034866503804719874943167124323851595977937051716261242157735099618131240)
     (delegate (B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (14
    ((public_key B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qpaA93gHfmvNoH9DLGgxreGnijhh5aui4duxiV3foX4p5ay5RNis))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (3
    ((public_key B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      16097722112531256871937176655429045871577436884363597261289761147678877237138)
     (delegate (B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (15
    ((public_key B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qqMGFkBEtgGs2Gi6AWd1Abn9yzXdj5HRMzm95uwbJ8Wa88C7urCD))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (6
    ((public_key B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      3789829474818306949906721224783620372752646928473927977428294954344374533872)
     (delegate (B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (7
    ((public_key B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qkYgXYkzT5fuPNhMEHk8ouiThjNNDSTMnpBAuaf6q7pNnCFkUqtz))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (5
    ((public_key B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      8533797999234991471367202436629983958250732378960523831599964589517571228325)
     (delegate (B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (11
    ((public_key B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qji8zLZEuMUpZnRN3FHgsgnybYhhMFBBMcLAwGGLR3hTdfkhmM4X))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (0
    ((public_key B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 10000000000000000) (nonce 1)
     (receipt_chain_hash
      23293976437428080852645890265900229412344252883925841424431974907470362218153)
     (delegate (B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (4
    ((public_key B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      11341467036951506593129937196842083980413513803534502611689999876031423969561)
     (delegate (B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ())))
   (8
    ((public_key B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1040000000000) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
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
    "scheduled_time": "1668291220375",
    "protocol_state": {
      "previous_state_hash": "3NL5YY6SBChV9bDTFwMegztXPQkT5kKKfKhY61DyYWpFV2fxtNLD",
      "body": {
        "genesis_state_hash": "3NL5YY6SBChV9bDTFwMegztXPQkT5kKKfKhY61DyYWpFV2fxtNLD",
        "blockchain_state": {
          "staged_ledger_hash": {
            "non_snark": {
              "ledger_hash": "jxbwsja7766oVsNcZrMetaWSTqK7XBqgrSttaH5H74E5aN9nwsP",
              "aux_hash": "UjJhe9UvGSgmN4Ckyu83JGeL8dayusEoXquzNqWDAjiubWg8p1",
              "pending_coinbase_aux": "XH9htC21tQMDKM6hhATkQjecZPRUGpofWATXPkjB5QKxpTBv7H"
            },
            "pending_coinbase_hash": "2n1KVFYysZUDR1HDZuyq4YeXPGRY1gpPan8TQGFCxVSPfChDgAJn"
          },
          "genesis_ledger_hash": "jxhv1J2fQRtRiv5cQZJBnS2ncRQznQ4pUfL5MMVBwi3uRAMh34t",
          "registers": {
            "ledger": "jxhv1J2fQRtRiv5cQZJBnS2ncRQznQ4pUfL5MMVBwi3uRAMh34t",
            "pending_coinbase_stack": null,
            "local_state": {
              "stack_frame": "0x0641662E94D68EC970D0AFC059D02729BBF4A2CD88C548CCD9FB1E26E570C66C",
              "call_stack": "0x0000000000000000000000000000000000000000000000000000000000000000",
              "transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
              "full_transaction_commitment": "0x0000000000000000000000000000000000000000000000000000000000000000",
              "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
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
              "failure_status_tbl": []
            }
          },
          "timestamp": "1668291220375",
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
            "slot_number": "6",
            "slots_per_epoch": "576"
          },
          "global_slot_since_genesis": "6",
          "staking_epoch_data": {
            "ledger": {
              "hash": "jxhv1J2fQRtRiv5cQZJBnS2ncRQznQ4pUfL5MMVBwi3uRAMh34t",
              "total_currency": "10016100000000000"
            },
            "seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "epoch_length": "1"
          },
          "next_epoch_data": {
            "ledger": {
              "hash": "jxhv1J2fQRtRiv5cQZJBnS2ncRQznQ4pUfL5MMVBwi3uRAMh34t",
              "total_currency": "10016100000000000"
            },
            "seed": "2vbhjwHdFZqQaG1zZVkrnHacQba792hNoPuBd4KLTnMgwCSP5f4d",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NL5YY6SBChV9bDTFwMegztXPQkT5kKKfKhY61DyYWpFV2fxtNLD",
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
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAspeAvKVkdJ0W-eRhYYaOG7DVL1SoKqJ9Op5qFuYDxRgADmF5xm6gsHyC22zRIw_GFpK63VFn-oi3aVea0m_xuAb8JU-rVyi2Wwr88oDrOoOYr7EA_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAACEAAAAAAAYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFvxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAD8b7_mrMmzgjP8Yxh2-VhDl3kA_JeHiOkGKzrd_MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA_IsHEI-xd5zi_O4Ma98AX1z4APyHnLAHLae9HfygJl_p4pcbTQD8EV-AVnx0dZz86PHO-mlj_qEA_E1g6dvfiitc_Jv3EPKMcYxaAPxIa-BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA_MkrPzde40VE_OXNjPwVx0CdAPxOqrxLhIKYQvy8t6_Q1yeplwD8d279_1s9ypn8lEJcFVVq5u8A_FSZlyFxsn1L_EDIk2Hgoh-VAPyzRweyvszRLPwdAmTyPN7RWwAAAAACSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUC_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAKYUXjamNkTUesbOkhefo26mF6KY8Qg86Im0ygmvUcYc39l4L97owy5XoGHYMydsv1fNOCQBxNwpf3X26QgM8BIBKaQYkUfApaoOwd_-SjCR_YdbncIf50JDNNg59FSDFSMBKZBE_4O_0yOOSb6hr4GDJxLavlJNcTG2cRXpDwQQhDIBiGkl10UtNtDnvjMcaXcdzkvSAYzYDfUrO9OY3kANFzwBu13yJjfdHnGTOLQ591lDZyDQGI1fEb_1kiMxeBA0fzQBmClErk8RWoDr54CDiUFaEiPgqlYdpMI4xxrPRopL_CgBjVKMhlcpJNAFRMZnUCQMBZUN4NhzUUBzvybz04BgxRABEyOeRqJ-kg0wk1vNaiWUskZtVni3h4W0bw4CVVSWsRcB0iwzBxIiu224xceLr1SBygs_v7zmB8hnby0rlcFtviABMoq9fSiFx5Nyv8u2kUtR4ss-e90tTiNzRdh0LpK_dScBZkDugHUFlmZJ7faBD4DTMDYEatAzhd0faYAlDK_9cAgBiCgUMYJMqZkzhwrKT1yDZTu3PUTsb71NhByFdSGexw8BFUpTgGiNDH7KO97Yg_WAh-_3j36_3oMHcUaAv36Xxg4BGaqkmTDpsqJEG2jRnWPXE6BWl_KAcxEzOVKU9mS7YhEBxRX1Fw7cPwlxWPjZiUjmskXAeN5IFPFReJ7zSfkUBAIBQ8FALP-SgAX7ZBFCCtBW9nKwAnVVfSzW7UXrVUn8vzoB4VUPQkJFxrXRFbv_TXSdOjjOsFXSC_87JsTigSix-y0Bqn1DLkbsCDzu6dJN-0ODcTpChqSp92tMmdjZXJjO2DEBSbcCifGi8b_bFXWdnm6bWm167a-GGyXrWZGh8zvQmA8BCNuMIubtOfqmWp-z2uiIextzm6x121IznY5N7vq-bzgB6BGYrTc__9Oc5Z6aiWzcB0RFIsJfPRR5StKt62o0NCQBJFCEC1byNV5vxqXQyy07F6A3PUv4GbQaYxy2LYBxCRQBs4g2YD2zPFYR1byG_nBBmXt-tltjZ4i2T-kuaxEQ0gQBL8Do05VgoLAjFo1qUYITZVkBPDfRXsLC7hKDxrm3ex0BwmJqaBRTSG6l1BPw6gMM9dcx8Kvf5jLHSippg7XuDxcBhVnJME3t-U8jZtTYqvPJwq9cKrM5ilrvTMuDmlDevDUBnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEBrQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8BldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8BUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6RoBNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwAAXEjmi6Bd0bylw-q3vGuQ1Fcit_8ILFvGUa3wudAsr4yASESun_XSWdBVjuUiHhhKl_qEf7hf0i7sAuuz3vfeOQjAe7cJCkB7qusy7ZdJXH_wmj_9btm91Qlpae3Wf_isygPAXsNPPiUA3OWzzPUMsYR_9M2-YZaSo_SH02400duYGg7AV3LML788vPZli5OLkyiCtZMenLHMHCUchpHUXefyiIjAcRusDuQav4EPSJQxucc-FB3dsG8IkYieYD8QncE_ioFAQrMK2_9pgL64gc16-CGxpD_-ItbC_Dd7bGfAzq-bfAmATeMyVIX79-ISORs2-837Eyg7yOpuSSe4kgduRlTkIILAeFc4ME22mPOXzmhhi2bBQS4fsazBOCIB5l9hksq5ecDAQ1WITfT8XFrEFsy44wIG8_6IHi-ooiNJ281SUpFHZkwAbvB2kibzXplG6JRGl6xu4TFQA53gitVWu7f8FqsWpkYAVfNvUp7aVlHAX_xDDTR7wnkCbLVa-bHXLzCdKwfKBMLAeZ8RtKbvPP0mHMCcD9jjDYMAGOYjEz88votBOv5yWECATZR45hvXiSFc9FXuY2EHNldCb7M5AZKCFEr_2k4gV8RAZEX0e1FG4nLu0N1MdJAwLVGatZRH80ZvgAavPRhtH4LAWzDZw_sx8tADUbsx48_IAegzqJeOsx2MGnefDFL978sAaVjyZXx_4_H6qAbE7LBbfTVNkKhm6hvB87h7e_7Mi0eAYufcqSsyzfhQRuUKlx5vve_FbZ0pLK6rqGtIzUneBUWAXk9UdPO_qT3Q8huliwKwxfrfgLBkggUaAmWfSgEkF47AfmmornJCka3Q5CjMhj1N81hV-5tGmy7m3lybjlyn7s5AQAMRmm03K-7MLpUQpYsDjUoGLOXFWqlnAB-Hyr5ibk4AUBftxHq6fyniHXbjbZhicVtQm_qBo8oJv5csLCv4GoOAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAAGNHvjiSs815o9ARIAyQ1LpIWRbw1SwVkTnvU6zqA6dEwGtsa_Pr_51aWVrVNXOOffBGlWVj2P0Mu-6mqljNOPwEwENGe26y5zwK79cHBBT1CJHlSaFUDjAcncqCpcPOlTVJQGJrHBSw29QqJvNBgumf6lEbf6wttgKdO9hfdSvZswgOQGsXRBV5tyF5pbN4uTNWOQRdVZiLeYWwEs0J-vPTnkhOQGi4FTGW5FLLsyjqbqjNaDWpQGc-7Gc4HPq1S4fD5Y_MAHeZL_zFjODryJod00p-XOCZWklo4RuCNG52_2BBwlQCAEaeckgZ686k-OOO3q1Ue0wyyWYvj1TGvyzFh_0ZFJ5DAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEoiMJxZLkLNBqXqILFRU9YaKjWh5az8Y71QoDuP5YoOgHP5vX8x1I5Pcv8lBJWwrqEmdMiKK4a3RIND77M2TiSMwEX5vzaAGMh0m9o4paLCEh2Ngf4MvmtsLqnGhW5L3mIJQH_206QnXcpZXXvFi23MVgWk6iuGiYo6dexFPbmSDIwCgFAEorcMjzs0ktfTe_4NL6WDJClyX0Wzm0SPt6MlbK_PAABkvX83AxM0_beQnlIsHgxLgs3RLZJMrVa9hQc6P5u2CwBTLHhvOyEP6t-N3gPRIgNWOv6PCi0wMkTrkFJWlvPWxkBwMhN_qFTBruWJxW5IcARf96fP53_qXNPypd8roZUkDcBrWzyWf_q0Y06_TgvQQ53Gj1dDyYUVPpplpPYHEXMgDwAj-owlyW1Z29m4ufeTPPQ593mh6iO6_6Bk6baxYNHwToBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsHAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwAPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbdmdkJeh2NwXEpyxOoMWpHB3uqDZkD0ZyLnIiT-j5RDJMRYPeq0p3GepSO09WJl9ZG_VE32PLSBKi1ewfGX8cFAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAdRLIjk2TgeJQfq4R7aMHG2vTNM87yfvoIVAUuESaocOAQP7NqRueIVUmF8T8GjHSuJKN-hOnAZsPEEpAgwCaAEBAXjLfxEI_zI-1yEANarSOeGWBh8e6_NBSMJlhAITPVAHARA3ZoraMrpx-zQq4AGX__lBJzq-n7S7RUdtwOui5c4eAf3bmdACYNVivrmsmh5-3Yu2f6v4SNIHmN3ES_Oz40M0AcuAYPrSN6yrwVKFMNHCgdsaHXAfUphv7q6aRzZlRbgLAdk8Ja00wRWWC2ntT2WOXspZtJR3qvl_Yxdb9-uCZBg5AabWZCYjr3uZYm-o32qKibGKPy0OwFMj9bN_aeN6YCIrATltKoUJcMS3ZZr5zwUN1BQ5OlolEVYJ7FWXeIF8v-YGAV-NRUkDcK-enGXZLv2TltexFiQrObXRcEAGIw-m4_0cARY-2fL20fcTP41eTe75SBtqmdyXpxTkeig_REqs6eAnAdM3OBLWVOT99iM6ZLZK39OtRifN5qXW1xuJg_Y_ZkwpAUzFSzHoxZXP2JtkfM8L-VQjthUFyaEk-aUBt_hSAAUyAcwJahnV42gprlx3b_Q4E0trqX0MhesWmgXbdCDWHD0aAYZ7_oRnIF8wPyS5TJcUO7YIjyMaictxksPOuWhHUX8NAYvMS4ORERuP1idQ9NsvBQSaLQGRdGfyyCIa2fThuLEAAXxP9jsGekRtd54fuc4FNnrm9Bz_5v2JZxMLoWdIxzwDAWn8c09qr_Mu4CArkm5n0QPKiNDoM74GePT3UpGmmO8yAeIvzAvn4PR2ze4ixAlW5yC8uo97lWmTQrkJh8bP3HEwASHqJmL6E35SGxDnDUeAWRj3Nr6foepQwGkpXoCRU9MOATVfCgpHQu2BNFGm-XdohA2Relb5tmcXBBk4z9lTCtQ3AWVuFQbsIVF6gInhONp-0U20Xtihsejw8aOuRa8qrskqAYSWfDJwdAOoaHPtyzJT2g1C9bJJEhnmmL2_WZPNOhw6ASVTlvxswhYpzvajjZyYblAxa7QuHyij4a-HH3Vp-ssNAUbP63XVP6rb3GBVTJm83WqFJfKm9OewqCPtQN1Q_A0AAWkKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kAW6OhvPbUUo9_az3dQZoC-ow0OhFw8DWV_pMZMlaGyUoARL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMeATvXd2YAh6jWpag_ZAAGvKfBNt_MNZMI68RE_gDmgmsYAXMXa7vEw1pAywL42XIYys2Y8mPdWLWuj8G4FfLJxd0pAAE8YarsOpthEm-zgZWflXYHlK8dYqU5SCMwvEg7uWlMBgG1lDFQ8arF3lNiO4utX_pjZY6rvGOOemMnsf-pKzF6HgGyc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAgHlSbmjbLnGgXUX59Zt-nH7ttgJlNtTf5tRknzzDXCEJwF1M96_qj16L7hWfRm_YlYUbKK8EhtSPPvkJ5Lgs1MiLAFX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMgH00fCHMH6Wpd0tQf0iAXwJ5JBvViTJqecOhRWDK9RMNQEBhe9XkAAcvm5OCJRA_FIknHm7TTEgivfF2IEI3MeJFgHcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFQFTSa9QkePNGMCS7ZV743HXm8o-GjO_D4OIrBiRJZRBBAHnIr8LOE_BSDulDYlGBNxVRuQ0xMq2ABzCvFn6x5haKgF6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNgHoCT9WxI5UAP7Vwqhq6NszhWP1p-oxpmstCDPitzrWDAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQH2gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEICwFSvpvw8LsRkZ1QbfA7uJ_2tTqS1vgPAZYdxUAlXJhUIAF-WLJP0invsW4SBaZLXLuYZWavhBrsak2NpUIAXTl2FQGXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOQHzco0WgOEJaBtLb4AR_qanWPjpJ9wuFuzzxBm-b5V2FgF4ZP81nWoge3I_GH93hhXS8HMrN68WmXeUz4NJZNh5OQEnpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJgFmTnym_pPxUfBpUIuCatXQbHFUkxjLyRHaa3TQbv4oBgEuU2BbgBrX_qdF6XZq3Y2p7TNYnXWPszn-1AwynFmqJwG3eoeIsH980cnGFhh1XMo9DTA6ewlhJM4MAtxfRRoPAwEuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHgHZbWLlSgpJ06RMkZ60sIkzPWSiNu3NoZISdKxpA7rZNwHM46eN-iQtjFPolGfMmG39My25h9dsZudzWkfvNOkPKAHDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLgHYLThxeEK94xcVft8YalsqWsKgNaBpsYobt5DYobYOJgFplOJw8oSlV8QYr-v6rKJ5TIr2pHbLG5R4wgXoqQEXDwABcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUBNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4BN776nYDGKPuLP39TFpEsF1QmoK2ag9t4CEfWNvHMqwkB4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xwBa98jDsB6kVMZxgatkwxB3X8JciKtondqSE51X-stSRwB7oAr6vTduvO2lphonX52tnDKpl3b2SGXInqwyN-6NiQBtcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xABwEQWKAElGddv7wEHQ03Fa7F059FhDN4vyG1qpyt1rRoAAc1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIKAeWACT0kBAb2aEsxPOQGab1bocjfPtU87S9HPAN68ZoIAZrMlNnD573fZqMj2Cv1RRm7jy9b3Uj-zrRai94Kp6A5AZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXAKkKOiiD4XXs1duk1ShJArVrqqLRHe5mdwR1D5BfIFYg",
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
                        "source_pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
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
                        "source_pk": "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX",
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
                        "source_pk": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
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
                        "source_pk": "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF",
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
                        "source_pk": "B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7",
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
                        "source_pk": "B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq",
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
                      "valid_until": "4294967295",
                      "memo": "E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"
                    },
                    "body": [
                      "Payment",
                      {
                        "source_pk": "B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA",
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
      "jx9Fm8YFWcyRu51B71pw5rAedYGu9LKsTr6w1Qw9FXRPPTLv6VD",
      []
    ],
    "accounts_accessed": [
      [
        2,
        {
          "public_key": "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93",
          "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "send": [
              "Signature"
            ],
            "receive": [
              "None"
            ],
            "access": [
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
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
            "edit_sequence_state": [
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
          "token_permissions": [
            "Not_owned",
            {
              "account_disabled": false
            }
          ],
          "token_symbol": "",
          "balance": "1040000000000",
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
            "edit_sequence_state": [
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
