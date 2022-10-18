(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1655382227041)
 (protocol_state
  ((previous_state_hash
    5582850020617837418082100114371302095819386849215536975366590036056158060076)
   (body
    ((genesis_state_hash
      5582850020617837418082100114371302095819386849215536975366590036056158060076)
     (blockchain_state
      ((staged_ledger_hash
        ((non_snark
          ((ledger_hash
            5396542681852645656338653836780764771230427775935376452839671839888494885666)
           (aux_hash
            "j\017N\172\139\146\2207U)x\243\019\191D\127y!\218\182\142\236\005\151\\\200\172A\159\131\002^")
           (pending_coinbase_aux
            "\147\141\184\201\248,\140\181\141?>\244\253%\0006\164\141&\167\018u=/\222Z\189\003\168\\\171\244")))
         (pending_coinbase_hash
          11089533555756432329108253137278634012473051208843078056166823375138421684681)))
       (genesis_ledger_hash
        13910975332034754558398291674843021523138027077932710089396878442879931078992)
       (registers
        ((ledger
          13910975332034754558398291674843021523138027077932710089396878442879931078992)
         (pending_coinbase_stack ())
         (local_state
          ((stack_frame
            0x02F99BCFB0AA7F48C1888DA5A67196A2410FB084CD2DB1AF5216C5122AEBC054)
           (call_stack
            0x0000000000000000000000000000000000000000000000000000000000000000)
           (transaction_commitment
            0x0000000000000000000000000000000000000000000000000000000000000000)
           (full_transaction_commitment
            0x0000000000000000000000000000000000000000000000000000000000000000)
           (token_id
            0x0000000000000000000000000000000000000000000000000000000000000001)
           (excess ((magnitude 0) (sgn Pos)))
           (supply_increase ((magnitude 0) (sgn Pos)))
           (ledger 0) (success true)
           (account_update_index 0)
           (failure_status_tbl ())))))
       (timestamp 1655382227041)
       (body_reference
        "\021\140i\206o\231\153\191\212i\0118O&\230\190\177\2176\016h8\238T8{\021\194#\223\158\137")))
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
            13910975332034754558398291674843021523138027077932710089396878442879931078992)
           (total_currency 10016100000000000)))
         (seed 0) (start_checkpoint 0) (lock_checkpoint 0) (epoch_length 1)))
       (next_epoch_data
        ((ledger
          ((hash
            13910975332034754558398291674843021523138027077932710089396878442879931078992)
           (total_currency 10016100000000000)))
         (seed
          6361847198485054175200272537302982739133979173179386423380077201169092291378)
         (start_checkpoint 0)
         (lock_checkpoint
          5582850020617837418082100114371302095819386849215536975366590036056158060076)
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
 _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEArQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T_8JU-rVyi2Wwr88oDrOoOYr7EA_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAACEAAAAAAAYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFvxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAD8b7_mrMmzgjP8Yxh2-VhDl3kA_JeHiOkGKzrd_MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA_IsHEI-xd5zi_O4Ma98AX1z4APyHnLAHLae9HfygJl_p4pcbTQD8EV-AVnx0dZz86PHO-mlj_qEA_E1g6dvfiitc_Jv3EPKMcYxaAPxIa-BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA_MkrPzde40VE_OXNjPwVx0CdAPxOqrxLhIKYQvy8t6_Q1yeplwD8d279_1s9ypn8lEJcFVVq5u8A_FSZlyFxsn1L_EDIk2Hgoh-VAPyzRweyvszRLPwdAmTyPN7RWwAAAAACSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUC_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAFLSt4G-HDAMHctAIF9gJAdamQs-1kBoXqSGL2XpRukaNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4BDlAZ71lbeW-HLtrodN8-a9HpRCSu17pNesX-WuIlJBUBzs6SSvEomyJvu2y--Am5RCKp2R8Hgq2g2H78g9AZuRsBSk7p2M7zfnBNV4NuK9QsaWRm4nGX4WblpKyHr28XqSQB3n5X7QI17RMV7nx2WC_oXvE0EFcadTe81705GfJm7B4BfqjA-yV-URjlSNnH1Z9YWMoVO594UGIxPSUOJOIDKRQBnVPIW9vIufiV_TzyhUCa3iTQd8ax-4hL6O0DpgkgehUBmYTeWtMJHFI_kNtnklJrNrPQk2vaiqiqghEnSOGq-y0B0j1EVVxWkyQGfYKBdjKktIvjFCZxAaCYcxlyddAoTwUAAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAcMYHYfQq0qZzsiFs9TeUbC8oyswbr7OjcoahyvA78QdASiIwnFkuQs0GpeogsVFT1hoqNaHlrPxjvVCgO4_lig6Ac_m9fzHUjk9y_yUElbCuoSZ0yIorhrdEg0PvszZOJIzARfm_NoAYyHSb2jilosISHY2B_gy-a2wuqcaFbkveYglAf_bTpCddyllde8WLbcxWBaTqK4aJijp17EU9uZIMjAKAUASitwyPOzSS19N7_g0vpYMkKXJfRbObRI-3oyVsr88AAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPACV0WIswKfy24qZ2BVlNNVyB6rzu8alpqGjFc2SQmiCHwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwcBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAA8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBtpCpjZSyFw7fs_VpvW3u-pzKE7CT2VmxNu4B0vmGsNJG6OhvPbUUo9_az3dQZoC-ow0OhFw8DWV_pMZMlaGyUoAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBPGGq7DqbYRJvs4GVn5V2B5SvHWKlOUgjMLxIO7lpTAYBtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh4BsnOwvHH_6_HFxOAUimXpBlskiIe76JlgfQLxFwx7RgIB5Um5o2y5xoF1F-fWbfpx-7bYCZTbU3-bUZJ88w1whCcBdTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIiwBV_qftnG-DYoxFQTxMSIRhqGL4ER3EHMMS7qnTKNI3jIB9NHwhzB-lqXdLUH9IgF8CeSQb1YkyannDoUVgyvUTDUBAYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRYB3D4_x6LoE3BgUDX5YMuIVPuDNRmGzIgz_d96_zr8sBUBU0mvUJHjzRjAku2Ve-Nx15vKPhozvw-DiKwYkSWUQQQB5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWioBekqEp1ZfFfK1ykwNzfGfmZNxCblrIeelQdFCASQWUTYB6Ak_VsSOVAD-1cKoaujbM4Vj9afqMaZrLQgz4rc61gwBpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB0B9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkBJ6Z1PjwWuYkh1T0YVALodPMYqBn98vOsZmcmIEWqiiYBZk58pv6T8VHwaVCLgmrV0GxxVJMYy8kR2mt00G7-KAYBLlNgW4Aa1_6nRel2at2Nqe0zWJ11j7M5_tQMMpxZqicBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8AAXFxFeWXE8hPiLq-LsApJRgGDSzIK1Tpqcmi0qh86R4VAV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfAahPlKDW1kvguXBJuSrixYqMuT55IXn6tX-jLEaVq-ckASx8aqUSO0GqjqzoWn7uuOuyIhnJNTuSdnERmaqoAYIXARbrouvan-rEQuKe-Sk_XEV2kz1TGm48B1GONSJBBV89Adz1suEkU7g2nEIOdq2g-2xuFz8icaoZ7G24AQESYRYFATU2LZhvIMWY5Tw94Lj8QTAEhCQxcq-JPMmcoZmqFhY8AfCVHmo4X7Tqi14s8OieVIB6mZOLCracd_G5shCgXRUuATe--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJAeANNswrYHbCMYQEbAoqBiCFIVZE_ilUmmJSAlBVvfscAWvfIw7AepFTGcYGrZMMQd1_CXIiraJ3akhOdV_rLUkcAe6AK-r03brztpaYaJ1-drZwyqZd29khlyJ6sMjfujYkAbXJjTqIHqrVYA2Jkg3_gwJQedJ73jzq3RRCW_yKQNMQAcBEFigBJRnXb-8BB0NNxWuxdOfRYQzeL8htaqcrda0aAAHNcciv4acZ8uXoP855QfuaMT4rkmJICvpoZ13Pq2SyCgHlgAk9JAQG9mhLMTzkBmm9W6HI3z7VPO0vRzwDevGaCAGazJTZw-e932ajI9gr9UUZu48vW91I_s60WoveCqegOQGWoQZCEbUrw00mWHh1ByTo1VKunOj65UksfRSp5m51FwAS9qiH-ZvFFTPmUZgQx53X_nzYD42MtIOk9lJkZ8pzHg==
 )
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
      (coinbase (One ()))
      (internal_command_statuses (Applied (Failed ((Update_not_permitted_balance) (Update_not_permitted_balance))))))
     ()))))
 (delta_transition_chain_proof
  (5582850020617837418082100114371302095819386849215536975366590036056158060076
   ()))
 (accounts_accessed
  ((2
    ((public_key B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      18124910813427913474485731096644147792660148121469641970505748589829665835213)
     (delegate (B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
   (1
    ((public_key B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 98999999999) (nonce 1)
     (receipt_chain_hash
      8322800007689540094975992745311146902549703840817525230946363597440830233832)
     (delegate (B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
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
     (zkapp ()) (zkapp_uri "")))
   (3
    ((public_key B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      14992176166039464194487240143773842625359853606895601261669850329296348731564)
     (delegate (B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
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
     (zkapp ()) (zkapp_uri "")))
   (6
    ((public_key B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      10382489361139595264833372177371696572277438071630586534029875247289501444643)
     (delegate (B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
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
     (zkapp ()) (zkapp_uri "")))
   (5
    ((public_key B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      11180984077588740860304946423169271437093932861814047232453099847002416687558)
     (delegate (B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
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
     (zkapp ()) (zkapp_uri "")))
   (0
    ((public_key B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 10000000000000000) (nonce 1)
     (receipt_chain_hash
      7150073137081284221786979852002819999869539458452908703501226782052843046282)
     (delegate (B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
   (4
    ((public_key B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      11846198824303028541668726573931966719396363988406909701093877242608118205147)
     (delegate (B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (access None) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
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
     (zkapp ()) (zkapp_uri "")))))
 (accounts_created ())
 (tokens_used
  ((0x0000000000000000000000000000000000000000000000000000000000000001 ()))))
|sexp}

let sample_block_json =
  {json|
{
  "version": 3,
  "data": {
    "scheduled_time": "1655382227041",
    "protocol_state": {
      "previous_state_hash": "3NKNNu4AwgzyTcmjZAeak516KdwtkFtL39YumhbKrvzVBcX4sr1G",
      "body": {
        "genesis_state_hash": "3NKNNu4AwgzyTcmjZAeak516KdwtkFtL39YumhbKrvzVBcX4sr1G",
        "blockchain_state": {
          "staged_ledger_hash": {
            "non_snark": {
              "ledger_hash": "jwN1bzJ7UPe39bSLW37ik6HNqtoCfvsjdb7NAg6JDQLTFZhj5jd",
              "aux_hash": "V28ppM4mPwb4wEHafihEdCxSGYfqwYaPUy2CyvNBHLNhtsWpu2",
              "pending_coinbase_aux": "XH9htC21tQMDKM6hhATkQjecZPRUGpofWATXPkjB5QKxpTBv7H"
            },
            "pending_coinbase_hash": "2n23E7Ty9K2efaVgAzBaYmwH97NsX63ciF2SSLniJBh9pJM2AsBL"
          },
          "genesis_ledger_hash": "jwhzN7vCf9ykq6SmNe1EuGQYTAjLDTA8D4bQm5K57ZHVKSi5rUR",
          "registers": {
            "ledger": "jwhzN7vCf9ykq6SmNe1EuGQYTAjLDTA8D4bQm5K57ZHVKSi5rUR",
            "pending_coinbase_stack": null,
            "local_state": {
              "stack_frame": "0x02F99BCFB0AA7F48C1888DA5A67196A2410FB084CD2DB1AF5216C5122AEBC054",
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
          "timestamp": "1655382227041",
          "body_reference": "158c69ce6fe799bfd4690b384f26e6beb1d936106838ee54387b15c223df9e89"
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
              "hash": "jwhzN7vCf9ykq6SmNe1EuGQYTAjLDTA8D4bQm5K57ZHVKSi5rUR",
              "total_currency": "10016100000000000"
            },
            "seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "epoch_length": "1"
          },
          "next_epoch_data": {
            "ledger": {
              "hash": "jwhzN7vCf9ykq6SmNe1EuGQYTAjLDTA8D4bQm5K57ZHVKSi5rUR",
              "total_currency": "10016100000000000"
            },
            "seed": "2vaXVbnZUEmF2jd8TSWu59Y1pjnh97PmC9jRq5x1UHF5zBs83ygF",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NKNNu4AwgzyTcmjZAeak516KdwtkFtL39YumhbKrvzVBcX4sr1G",
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
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAAAAnQn3zlVGVuICPyKcBIWXPldv9xKNRZBolsOtVvsZIAEArQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T_8JU-rVyi2Wwr88oDrOoOYr7EA_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAACEAAAAAAAYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFvxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAD8b7_mrMmzgjP8Yxh2-VhDl3kA_JeHiOkGKzrd_MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA_IsHEI-xd5zi_O4Ma98AX1z4APyHnLAHLae9HfygJl_p4pcbTQD8EV-AVnx0dZz86PHO-mlj_qEA_E1g6dvfiitc_Jv3EPKMcYxaAPxIa-BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA_MkrPzde40VE_OXNjPwVx0CdAPxOqrxLhIKYQvy8t6_Q1yeplwD8d279_1s9ypn8lEJcFVVq5u8A_FSZlyFxsn1L_EDIk2Hgoh-VAPyzRweyvszRLPwdAmTyPN7RWwAAAAACSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUC_Lkqp1a0cHOt_Pye8dUj-U82APwAfC-OYhyHWfyHzCaic_bHnAD8r_K2nh2CVCP8fvV99tFrudUA_PaGkKDQ93sU_GgqJEDOYl5iAPwOrVYyYxvGr_z74R-hEHKACQD8kUGsyr4eWPn8psm3PpnVHlcA_L3DZM2jUE6q_GjF_sEK5xTYAPxt3l6C36wdsvylB9vFF6II_gD8f6rm6dYPToL8LH-5Tpg69vwA_MoEG3EriDHD_CkmrrbHrDmRAPzvUYH9R48P3PyHlTvEQ3qpAAD8vzKG0R7YOGD8qwWqonC8s_kA_FpHr-Xg0nWU_PbSw64Cp8vRAPwEfC359g94vvxU4vsykVg94QD8E3UxuBK3cMb8CD5ImjPMdRYA_NG4yrGisMFI_M6xccDjBGYbAAD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAFLSt4G-HDAMHctAIF9gJAdamQs-1kBoXqSGL2XpRukaNomOADX-vhbuldiQMd9aENVh2Ziu0GYvXXi7DBfL2AwBcSOaLoF3RvKXD6re8a5DUVyK3_wgsW8ZRrfC50CyvjIBIRK6f9dJZ0FWO5SIeGEqX-oR_uF_SLuwC67Pe9945CMB7twkKQHuq6zLtl0lcf_CaP_1u2b3VCWlp7dZ_-KzKA8Bew08-JQDc5bPM9QyxhH_0zb5hlpKj9IfTbjTR25gaDsBXcswvvzy89mWLk4uTKIK1kx6cscwcJRyGkdRd5_KIiMBxG6wO5Bq_gQ9IlDG5xz4UHd2wbwiRiJ5gPxCdwT-KgUBCswrb_2mAvriBzXr4IbGkP_4i1sL8N3tsZ8DOr5t8CYBN4zJUhfv34hI5Gzb7zfsTKDvI6m5JJ7iSB25GVOQggsB4VzgwTbaY85fOaGGLZsFBLh-xrME4IgHmX2GSyrl5wMBDVYhN9PxcWsQWzLjjAgbz_ogeL6iiI0nbzVJSkUdmTABu8HaSJvNemUbolEaXrG7hMVADneCK1Va7t_wWqxamRgBV829SntpWUcBf_EMNNHvCeQJstVr5sdcvMJ0rB8oEwsB5nxG0pu88_SYcwJwP2OMNgwAY5iMTPzy-i0E6_nJYQIBNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBkRfR7UUbicu7Q3Ux0kDAtUZq1lEfzRm-ABq89GG0fgsBbMNnD-zHy0ANRuzHjz8gB6DOol46zHYwad58MUv3vywBpWPJlfH_j8fqoBsTssFt9NU2QqGbqG8HzuHt7_syLR4Bi59ypKzLN-FBG5QqXHm-978VtnSksrquoa0jNSd4FRYBeT1R087-pPdDyG6WLArDF-t-AsGSCBRoCZZ9KASQXjsB-aaiuckKRrdDkKMyGPU3zWFX7m0abLubeXJuOXKfuzkBAAxGabTcr7swulRCliwONSgYs5cVaqWcAH4fKvmJuTgBQF-3Eerp_KeIdduNtmGJxW1Cb-oGjygm_lywsK_gag4BDlAZ71lbeW-HLtrodN8-a9HpRCSu17pNesX-WuIlJBUBzs6SSvEomyJvu2y--Am5RCKp2R8Hgq2g2H78g9AZuRsBSk7p2M7zfnBNV4NuK9QsaWRm4nGX4WblpKyHr28XqSQB3n5X7QI17RMV7nx2WC_oXvE0EFcadTe81705GfJm7B4BfqjA-yV-URjlSNnH1Z9YWMoVO594UGIxPSUOJOIDKRQBnVPIW9vIufiV_TzyhUCa3iTQd8ax-4hL6O0DpgkgehUBmYTeWtMJHFI_kNtnklJrNrPQk2vaiqiqghEnSOGq-y0B0j1EVVxWkyQGfYKBdjKktIvjFCZxAaCYcxlyddAoTwUAAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAcMYHYfQq0qZzsiFs9TeUbC8oyswbr7OjcoahyvA78QdASiIwnFkuQs0GpeogsVFT1hoqNaHlrPxjvVCgO4_lig6Ac_m9fzHUjk9y_yUElbCuoSZ0yIorhrdEg0PvszZOJIzARfm_NoAYyHSb2jilosISHY2B_gy-a2wuqcaFbkveYglAf_bTpCddyllde8WLbcxWBaTqK4aJijp17EU9uZIMjAKAUASitwyPOzSS19N7_g0vpYMkKXJfRbObRI-3oyVsr88AAGS9fzcDEzT9t5CeUiweDEuCzdEtkkytVr2FBzo_m7YLAFMseG87IQ_q343eA9EiA1Y6_o8KLTAyROuQUlaW89bGQHAyE3-oVMGu5YnFbkhwBF_3p8_nf-pc0_Kl3yuhlSQNwGtbPJZ_-rRjTr9OC9BDncaPV0PJhRU-mmWk9gcRcyAPACV0WIswKfy24qZ2BVlNNVyB6rzu8alpqGjFc2SQmiCHwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwcBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAA8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBtpCpjZSyFw7fs_VpvW3u-pzKE7CT2VmxNu4B0vmGsNJG6OhvPbUUo9_az3dQZoC-ow0OhFw8DWV_pMZMlaGyUoAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBPGGq7DqbYRJvs4GVn5V2B5SvHWKlOUgjMLxIO7lpTAYBtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh4BsnOwvHH_6_HFxOAUimXpBlskiIe76JlgfQLxFwx7RgIB5Um5o2y5xoF1F-fWbfpx-7bYCZTbU3-bUZJ88w1whCcBdTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIiwBV_qftnG-DYoxFQTxMSIRhqGL4ER3EHMMS7qnTKNI3jIB9NHwhzB-lqXdLUH9IgF8CeSQb1YkyannDoUVgyvUTDUBAYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRYB3D4_x6LoE3BgUDX5YMuIVPuDNRmGzIgz_d96_zr8sBUBU0mvUJHjzRjAku2Ve-Nx15vKPhozvw-DiKwYkSWUQQQB5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWioBekqEp1ZfFfK1ykwNzfGfmZNxCblrIeelQdFCASQWUTYB6Ak_VsSOVAD-1cKoaujbM4Vj9afqMaZrLQgz4rc61gwBpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB0B9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkBJ6Z1PjwWuYkh1T0YVALodPMYqBn98vOsZmcmIEWqiiYBZk58pv6T8VHwaVCLgmrV0GxxVJMYy8kR2mt00G7-KAYBLlNgW4Aa1_6nRel2at2Nqe0zWJ11j7M5_tQMMpxZqicBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8AAXFxFeWXE8hPiLq-LsApJRgGDSzIK1Tpqcmi0qh86R4VAV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfAahPlKDW1kvguXBJuSrixYqMuT55IXn6tX-jLEaVq-ckASx8aqUSO0GqjqzoWn7uuOuyIhnJNTuSdnERmaqoAYIXARbrouvan-rEQuKe-Sk_XEV2kz1TGm48B1GONSJBBV89Adz1suEkU7g2nEIOdq2g-2xuFz8icaoZ7G24AQESYRYFATU2LZhvIMWY5Tw94Lj8QTAEhCQxcq-JPMmcoZmqFhY8AfCVHmo4X7Tqi14s8OieVIB6mZOLCracd_G5shCgXRUuATe--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJAeANNswrYHbCMYQEbAoqBiCFIVZE_ilUmmJSAlBVvfscAWvfIw7AepFTGcYGrZMMQd1_CXIiraJ3akhOdV_rLUkcAe6AK-r03brztpaYaJ1-drZwyqZd29khlyJ6sMjfujYkAbXJjTqIHqrVYA2Jkg3_gwJQedJ73jzq3RRCW_yKQNMQAcBEFigBJRnXb-8BB0NNxWuxdOfRYQzeL8htaqcrda0aAAHNcciv4acZ8uXoP855QfuaMT4rkmJICvpoZ13Pq2SyCgHlgAk9JAQG9mhLMTzkBmm9W6HI3z7VPO0vRzwDevGaCAGazJTZw-e932ajI9gr9UUZu48vW91I_s60WoveCqegOQGWoQZCEbUrw00mWHh1ByTo1VKunOj65UksfRSp5m51FwAS9qiH-ZvFFTPmUZgQx53X_nzYD42MtIOk9lJkZ8pzHg==",
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
                  "signature": "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt"
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
          "internal_command_statuses":[
            ["Applied"],
            ["Failed",[[["Update_not_permitted_balance"]],[["Update_not_permitted_balance"]]]]
          ]
        },
        null
      ]
    },
    "delta_transition_chain_proof": [
      "jwS686H1zvTjvdHULJkz9xjarjiZeuLFHhUchnHTfhf5yJmouon",
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
          "receipt_chain_hash": "2n25EYLf61vHTACzFgXp64JB2oH79s8TD8pp7YWEBMeoCPWSDZnZ",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "receipt_chain_hash": "2n2GwSeZ7VPL6WxCddqAU9BCe8cCypKU7PQ5MVrmTm8P6M3QhHVc",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "receipt_chain_hash": "2n1pWSqUYXzdxVYo2eTfUroAUyTgRLnUwWsrxKfTDFr46aN8mfqi",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "receipt_chain_hash": "2mznCm9RjqfzRwnrvhNanSEG5haCvtaBsktfXPV7K27RXQFmwEUV",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "receipt_chain_hash": "2n21swLakzABLQTJ1WBuMJDXW7wy8YhFJVZQuSEiZVX9Npr44iuL",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "receipt_chain_hash": "2n1ZipMa9aDQbCZ3KNxn6Na2UQAxKR9e8amsKaBBBtKYnFcksQrN",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "receipt_chain_hash": "2n2B5BzSt5qoZAmZ3znSb9z3QtXbtJD4kMzcioMkZX3YfmfSdquy",
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
          "zkapp": null,
          "zkapp_uri": ""
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
          "zkapp": null,
          "zkapp_uri": ""
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
