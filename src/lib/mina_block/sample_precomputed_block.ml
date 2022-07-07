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
           (excess ((magnitude 0) (sgn Pos))) (ledger 0) (success true)
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
 (protocol_state_proof _NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAACdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQCtC9t5svFvTRQn4Nr-cMBjEPpGBrk-tEKCU4-D2ijxP_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6Ro2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAFxI5ougXdG8pcPqt7xrkNRXIrf_CCxbxlGt8LnQLK-MgEhErp_10lnQVY7lIh4YSpf6hH-4X9Iu7ALrs9733jkIwHu3CQpAe6rrMu2XSVx_8Jo__W7ZvdUJaWnt1n_4rMoDwF7DTz4lANzls8z1DLGEf_TNvmGWkqP0h9NuNNHbmBoOwFdyzC-_PLz2ZYuTi5MogrWTHpyxzBwlHIaR1F3n8oiIwHEbrA7kGr-BD0iUMbnHPhQd3bBvCJGInmA_EJ3BP4qBQEKzCtv_aYC-uIHNevghsaQ__iLWwvw3e2xnwM6vm3wJgE3jMlSF-_fiEjkbNvvN-xMoO8jqbkknuJIHbkZU5CCCwHhXODBNtpjzl85oYYtmwUEuH7GswTgiAeZfYZLKuXnAwENViE30_FxaxBbMuOMCBvP-iB4vqKIjSdvNUlKRR2ZMAG7wdpIm816ZRuiURpesbuExUAOd4IrVVru3_BarFqZGAFXzb1Ke2lZRwF_8Qw00e8J5Amy1Wvmx1y8wnSsHygTCwHmfEbSm7zz9JhzAnA_Y4w2DABjmIxM_PL6LQTr-clhAgE2UeOYb14khXPRV7mNhBzZXQm-zOQGSghRK_9pOIFfEQGRF9HtRRuJy7tDdTHSQMC1RmrWUR_NGb4AGrz0YbR-CwFsw2cP7MfLQA1G7MePPyAHoM6iXjrMdjBp3nwxS_e_LAGlY8mV8f-Px-qgGxOywW301TZCoZuobwfO4e3v-zItHgGLn3KkrMs34UEblCpceb73vxW2dKSyuq6hrSM1J3gVFgF5PVHTzv6k90PIbpYsCsMX634CwZIIFGgJln0oBJBeOwH5pqK5yQpGt0OQozIY9TfNYVfubRpsu5t5cm45cp-7OQEADEZptNyvuzC6VEKWLA41KBizlxVqpZwAfh8q-Ym5OAFAX7cR6un8p4h12422YYnFbUJv6gaPKCb-XLCwr-BqDgEOUBnvWVt5b4cu2uh03z5r0elEJK7Xuk16xf5a4iUkFQHOzpJK8SibIm-7bL74CblEIqnZHweCraDYfvyD0Bm5GwFKTunYzvN-cE1Xg24r1CxpZGbicZfhZuWkrIevbxepJAHeflftAjXtExXufHZYL-he8TQQVxp1N7zXvTkZ8mbsHgF-qMD7JX5RGOVI2cfVn1hYyhU7n3hQYjE9JQ4k4gMpFAGdU8hb28i5-JX9PPKFQJreJNB3xrH7iEvo7QOmCSB6FQGZhN5a0wkcUj-Q22eSUms2s9CTa9qKqKqCESdI4ar7LQHSPURVXFaTJAZ9goF2MqS0i-MUJnEBoJhzGXJ10ChPBQABjR744krPNeaPQESAMkNS6SFkW8NUsFZE571Os6gOnRMBrbGvz6_-dWlla1TVzjn3wRpVlY9j9DLvupqpYzTj8BMBDRntusuc8Cu_XBwQU9QiR5UmhVA4wHJ3KgqXDzpU1SUBiaxwUsNvUKibzQYLpn-pRG3-sLbYCnTvYX3Ur2bMIDkBrF0QVebcheaWzeLkzVjkEXVWYi3mFsBLNCfrz055ITkBouBUxluRSy7Mo6m6ozWg1qUBnPuxnOBz6tUuHw-WPzAB3mS_8xYzg68iaHdNKflzgmVpJaOEbgjRudv9gQcJUAgBGnnJIGevOpPjjjt6tVHtMMslmL49Uxr8sxYf9GRSeQwBwxgdh9CrSpnOyIWz1N5RsLyjKzBuvs6NyhqHK8DvxB0BKIjCcWS5CzQal6iCxUVPWGio1oeWs_GO9UKA7j-WKDoBz-b1_MdSOT3L_JQSVsK6hJnTIiiuGt0SDQ--zNk4kjMBF-b82gBjIdJvaOKWiwhIdjYH-DL5rbC6pxoVuS95iCUB_9tOkJ13KWV17xYttzFYFpOorhomKOnXsRT25kgyMAoBQBKK3DI87NJLX03v-DS-lgyQpcl9Fs5tEj7ejJWyvzwAAZL1_NwMTNP23kJ5SLB4MS4LN0S2STK1WvYUHOj-btgsAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3Aa1s8ln_6tGNOv04L0EOdxo9XQ8mFFT6aZaT2BxFzIA8AJXRYizAp_LbipnYFWU01XIHqvO7xqWmoaMVzZJCaIIfAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbBwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsADwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0G2kKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwE8YarsOpthEm-zgZWflXYHlK8dYqU5SCMwvEg7uWlMBgG1lDFQ8arF3lNiO4utX_pjZY6rvGOOemMnsf-pKzF6HgGyc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAgHlSbmjbLnGgXUX59Zt-nH7ttgJlNtTf5tRknzzDXCEJwF1M96_qj16L7hWfRm_YlYUbKK8EhtSPPvkJ5Lgs1MiLAFX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMgH00fCHMH6Wpd0tQf0iAXwJ5JBvViTJqecOhRWDK9RMNQEBhe9XkAAcvm5OCJRA_FIknHm7TTEgivfF2IEI3MeJFgHcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFQFTSa9QkePNGMCS7ZV743HXm8o-GjO_D4OIrBiRJZRBBAHnIr8LOE_BSDulDYlGBNxVRuQ0xMq2ABzCvFn6x5haKgF6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNgHoCT9WxI5UAP7Vwqhq6NszhWP1p-oxpmstCDPitzrWDAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQH2gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEICwFSvpvw8LsRkZ1QbfA7uJ_2tTqS1vgPAZYdxUAlXJhUIAF-WLJP0invsW4SBaZLXLuYZWavhBrsak2NpUIAXTl2FQGXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOQHzco0WgOEJaBtLb4AR_qanWPjpJ9wuFuzzxBm-b5V2FgF4ZP81nWoge3I_GH93hhXS8HMrN68WmXeUz4NJZNh5OQEnpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJgFmTnym_pPxUfBpUIuCatXQbHFUkxjLyRHaa3TQbv4oBgEuU2BbgBrX_qdF6XZq3Y2p7TNYnXWPszn-1AwynFmqJwG3eoeIsH980cnGFhh1XMo9DTA6ewlhJM4MAtxfRRoPAwEuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHgHZbWLlSgpJ06RMkZ60sIkzPWSiNu3NoZISdKxpA7rZNwHM46eN-iQtjFPolGfMmG39My25h9dsZudzWkfvNOkPKAHDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLgHYLThxeEK94xcVft8YalsqWsKgNaBpsYobt5DYobYOJgFplOJw8oSlV8QYr-v6rKJ5TIr2pHbLG5R4wgXoqQEXDwABcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUBNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4BN776nYDGKPuLP39TFpEsF1QmoK2ag9t4CEfWNvHMqwkB4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xwBa98jDsB6kVMZxgatkwxB3X8JciKtondqSE51X-stSRwB7oAr6vTduvO2lphonX52tnDKpl3b2SGXInqwyN-6NiQBtcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xABwEQWKAElGddv7wEHQ03Fa7F059FhDN4vyG1qpyt1rRoAAc1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIKAeWACT0kBAb2aEsxPOQGab1bocjfPtU87S9HPAN68ZoIAZrMlNnD573fZqMj2Cv1RRm7jy9b3Uj-zrRai94Kp6A5AZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXABL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMe)
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
      (coinbase (One ())))
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
      ((edit_state Signature) (send Signature) (receive None)
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
              "ledger": "jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd",
              "success": true,
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
    "protocol_state_proof": "_NXzOpIGeLEB_Ayp3waPKGt3APwMxWnKbTOhCPyLhhJ9-g_wwwD8iQCz_prWi3v8ESi5ao3S87MA_MEHNYZwuM9z_Jzn68Ml7JtyAACdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQCtC9t5svFvTRQn4Nr-cMBjEPpGBrk-tEKCU4-D2ijxP_wlT6tXKLZbCvzygOs6g5ivsQD8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAAIQAAAAAABimVRJFfCb58F5EUQtJUhAU7RZBdufQVYwYf19vDLTD6zXUoX3waJPx7Hm4nw8FjpVprHnNjkDHQTrpV5QBAUW_G-_5qzJs4Iz_GMYdvlYQ5d5APyXh4jpBis63fzHoUQpQOZ63QD8y5-c9DDl6Mb83ZygzWW73QcA_BMaaYeiWSxT_HtvZSqwvCGpAPyLBxCPsXec4vzuDGvfAF9c-AD8h5ywBy2nvR38oCZf6eKXG00A_BFfgFZ8dHWc_OjxzvppY_6hAPxNYOnb34orXPyb9xDyjHGMWgD8SGvgUVyzwCL87W2pQHOLiKYA_G5kdl611weQ_BKOTts5i8bBAPzJKz83XuNFRPzlzYz8FcdAnQD8Tqq8S4SCmEL8vLev0NcnqZcA_Hdu_f9bPcqZ_JRCXBVVaubvAPxUmZchcbJ9S_xAyJNh4KIflQD8s0cHsr7M0Sz8HQJk8jze0VsAAPxvv-asybOCM_xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A_MufnPQw5ejG_N2coM1lu90HAPwTGmmHolksU_x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA_IecsActp70d_KAmX-nilxtNAPwRX4BWfHR1nPzo8c76aWP-oQD8TWDp29-KK1z8m_cQ8oxxjFoA_Ehr4FFcs8Ai_O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs_N17jRUT85c2M_BXHQJ0A_E6qvEuEgphC_Ly3r9DXJ6mXAPx3bv3_Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA_LNHB7K-zNEs_B0CZPI83tFbAAAAAAJItTboRlSlX0_9__31kb2dPKFwS87wXKWdwmRI3t_TEWsaLETdIcfNWVXvGcPzq7hCDht65RcU3teKhE0iB_UFSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BQL8uSqnVrRwc638_J7x1SP5TzYA_AB8L45iHIdZ_IfMJqJz9secAPyv8raeHYJUI_x-9X320Wu51QD89oaQoND3exT8aCokQM5iXmIA_A6tVjJjG8av_PvhH6EQcoAJAPyRQazKvh5Y-fymybc-mdUeVwD8vcNkzaNQTqr8aMX-wQrnFNgA_G3eXoLfrB2y_KUH28UXogj-APx_qubp1g9Ogvwsf7lOmDr2_AD8ygQbcSuIMcP8KSautsesOZEA_O9Rgf1Hjw_c_IeVO8RDeqkAAPy_MobRHtg4YPyrBaqicLyz-QD8Wkev5eDSdZT89tLDrgKny9EA_AR8Lfn2D3i-_FTi-zKRWD3hAPwTdTG4ErdwxvwIPkiaM8x1FgD80bjKsaKwwUj8zrFxwOMEZhsAAPy5KqdWtHBzrfz8nvHVI_lPNgD8AHwvjmIch1n8h8wmonP2x5wA_K_ytp4dglQj_H71ffbRa7nVAPz2hpCg0Pd7FPxoKiRAzmJeYgD8Dq1WMmMbxq_8--EfoRBygAkA_JFBrMq-Hlj5_KbJtz6Z1R5XAPy9w2TNo1BOqvxoxf7BCucU2AD8bd5egt-sHbL8pQfbxReiCP4A_H-q5unWD06C_Cx_uU6YOvb8APzKBBtxK4gxw_wpJq62x6w5kQD871GB_UePD9z8h5U7xEN6qQAA_L8yhtEe2Dhg_KsFqqJwvLP5APxaR6_l4NJ1lPz20sOuAqfL0QD8BHwt-fYPeL78VOL7MpFYPeEA_BN1MbgSt3DG_Ag-SJozzHUWAPzRuMqxorDBSPzOsXHA4wRmGwAAUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6Ro2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAFxI5ougXdG8pcPqt7xrkNRXIrf_CCxbxlGt8LnQLK-MgEhErp_10lnQVY7lIh4YSpf6hH-4X9Iu7ALrs9733jkIwHu3CQpAe6rrMu2XSVx_8Jo__W7ZvdUJaWnt1n_4rMoDwF7DTz4lANzls8z1DLGEf_TNvmGWkqP0h9NuNNHbmBoOwFdyzC-_PLz2ZYuTi5MogrWTHpyxzBwlHIaR1F3n8oiIwHEbrA7kGr-BD0iUMbnHPhQd3bBvCJGInmA_EJ3BP4qBQEKzCtv_aYC-uIHNevghsaQ__iLWwvw3e2xnwM6vm3wJgE3jMlSF-_fiEjkbNvvN-xMoO8jqbkknuJIHbkZU5CCCwHhXODBNtpjzl85oYYtmwUEuH7GswTgiAeZfYZLKuXnAwENViE30_FxaxBbMuOMCBvP-iB4vqKIjSdvNUlKRR2ZMAG7wdpIm816ZRuiURpesbuExUAOd4IrVVru3_BarFqZGAFXzb1Ke2lZRwF_8Qw00e8J5Amy1Wvmx1y8wnSsHygTCwHmfEbSm7zz9JhzAnA_Y4w2DABjmIxM_PL6LQTr-clhAgE2UeOYb14khXPRV7mNhBzZXQm-zOQGSghRK_9pOIFfEQGRF9HtRRuJy7tDdTHSQMC1RmrWUR_NGb4AGrz0YbR-CwFsw2cP7MfLQA1G7MePPyAHoM6iXjrMdjBp3nwxS_e_LAGlY8mV8f-Px-qgGxOywW301TZCoZuobwfO4e3v-zItHgGLn3KkrMs34UEblCpceb73vxW2dKSyuq6hrSM1J3gVFgF5PVHTzv6k90PIbpYsCsMX634CwZIIFGgJln0oBJBeOwH5pqK5yQpGt0OQozIY9TfNYVfubRpsu5t5cm45cp-7OQEADEZptNyvuzC6VEKWLA41KBizlxVqpZwAfh8q-Ym5OAFAX7cR6un8p4h12422YYnFbUJv6gaPKCb-XLCwr-BqDgEOUBnvWVt5b4cu2uh03z5r0elEJK7Xuk16xf5a4iUkFQHOzpJK8SibIm-7bL74CblEIqnZHweCraDYfvyD0Bm5GwFKTunYzvN-cE1Xg24r1CxpZGbicZfhZuWkrIevbxepJAHeflftAjXtExXufHZYL-he8TQQVxp1N7zXvTkZ8mbsHgF-qMD7JX5RGOVI2cfVn1hYyhU7n3hQYjE9JQ4k4gMpFAGdU8hb28i5-JX9PPKFQJreJNB3xrH7iEvo7QOmCSB6FQGZhN5a0wkcUj-Q22eSUms2s9CTa9qKqKqCESdI4ar7LQHSPURVXFaTJAZ9goF2MqS0i-MUJnEBoJhzGXJ10ChPBQABjR744krPNeaPQESAMkNS6SFkW8NUsFZE571Os6gOnRMBrbGvz6_-dWlla1TVzjn3wRpVlY9j9DLvupqpYzTj8BMBDRntusuc8Cu_XBwQU9QiR5UmhVA4wHJ3KgqXDzpU1SUBiaxwUsNvUKibzQYLpn-pRG3-sLbYCnTvYX3Ur2bMIDkBrF0QVebcheaWzeLkzVjkEXVWYi3mFsBLNCfrz055ITkBouBUxluRSy7Mo6m6ozWg1qUBnPuxnOBz6tUuHw-WPzAB3mS_8xYzg68iaHdNKflzgmVpJaOEbgjRudv9gQcJUAgBGnnJIGevOpPjjjt6tVHtMMslmL49Uxr8sxYf9GRSeQwBwxgdh9CrSpnOyIWz1N5RsLyjKzBuvs6NyhqHK8DvxB0BKIjCcWS5CzQal6iCxUVPWGio1oeWs_GO9UKA7j-WKDoBz-b1_MdSOT3L_JQSVsK6hJnTIiiuGt0SDQ--zNk4kjMBF-b82gBjIdJvaOKWiwhIdjYH-DL5rbC6pxoVuS95iCUB_9tOkJ13KWV17xYttzFYFpOorhomKOnXsRT25kgyMAoBQBKK3DI87NJLX03v-DS-lgyQpcl9Fs5tEj7ejJWyvzwAAZL1_NwMTNP23kJ5SLB4MS4LN0S2STK1WvYUHOj-btgsAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3Aa1s8ln_6tGNOv04L0EOdxo9XQ8mFFT6aZaT2BxFzIA8AJXRYizAp_LbipnYFWU01XIHqvO7xqWmoaMVzZJCaIIfAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbBwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsADwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0G2kKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwE8YarsOpthEm-zgZWflXYHlK8dYqU5SCMwvEg7uWlMBgG1lDFQ8arF3lNiO4utX_pjZY6rvGOOemMnsf-pKzF6HgGyc7C8cf_r8cXE4BSKZekGWySIh7vomWB9AvEXDHtGAgHlSbmjbLnGgXUX59Zt-nH7ttgJlNtTf5tRknzzDXCEJwF1M96_qj16L7hWfRm_YlYUbKK8EhtSPPvkJ5Lgs1MiLAFX-p-2cb4NijEVBPExIhGGoYvgRHcQcwxLuqdMo0jeMgH00fCHMH6Wpd0tQf0iAXwJ5JBvViTJqecOhRWDK9RMNQEBhe9XkAAcvm5OCJRA_FIknHm7TTEgivfF2IEI3MeJFgHcPj_HougTcGBQNflgy4hU-4M1GYbMiDP933r_OvywFQFTSa9QkePNGMCS7ZV743HXm8o-GjO_D4OIrBiRJZRBBAHnIr8LOE_BSDulDYlGBNxVRuQ0xMq2ABzCvFn6x5haKgF6SoSnVl8V8rXKTA3N8Z-Zk3EJuWsh56VB0UIBJBZRNgHoCT9WxI5UAP7Vwqhq6NszhWP1p-oxpmstCDPitzrWDAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQH2gT5x8SH7qmYdy4CUXvEYPsPPELfGNxhKUDsarpEICwFSvpvw8LsRkZ1QbfA7uJ_2tTqS1vgPAZYdxUAlXJhUIAF-WLJP0invsW4SBaZLXLuYZWavhBrsak2NpUIAXTl2FQGXmvgmC8zpJ5X0EjjPNNd7Q2Dh5BTRx5N9rGt5503lOQHzco0WgOEJaBtLb4AR_qanWPjpJ9wuFuzzxBm-b5V2FgF4ZP81nWoge3I_GH93hhXS8HMrN68WmXeUz4NJZNh5OQEnpnU-PBa5iSHVPRhUAuh08xioGf3y86xmZyYgRaqKJgFmTnym_pPxUfBpUIuCatXQbHFUkxjLyRHaa3TQbv4oBgEuU2BbgBrX_qdF6XZq3Y2p7TNYnXWPszn-1AwynFmqJwG3eoeIsH980cnGFhh1XMo9DTA6ewlhJM4MAtxfRRoPAwEuHmhzHQC4RyADiCN3fsZSLZoenjZZIMPnzgZK3gwuHgHZbWLlSgpJ06RMkZ60sIkzPWSiNu3NoZISdKxpA7rZNwHM46eN-iQtjFPolGfMmG39My25h9dsZudzWkfvNOkPKAHDfWkshHOqmiRruF5cQyPNDFpp5LnOGuFg-WFEfDGuLgHYLThxeEK94xcVft8YalsqWsKgNaBpsYobt5DYobYOJgFplOJw8oSlV8QYr-v6rKJ5TIr2pHbLG5R4wgXoqQEXDwABcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUBNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4BN776nYDGKPuLP39TFpEsF1QmoK2ag9t4CEfWNvHMqwkB4A02zCtgdsIxhARsCioGIIUhVkT-KVSaYlICUFW9-xwBa98jDsB6kVMZxgatkwxB3X8JciKtondqSE51X-stSRwB7oAr6vTduvO2lphonX52tnDKpl3b2SGXInqwyN-6NiQBtcmNOogeqtVgDYmSDf-DAlB50nvePOrdFEJb_IpA0xABwEQWKAElGddv7wEHQ03Fa7F059FhDN4vyG1qpyt1rRoAAc1xyK_hpxny5eg_znlB-5oxPiuSYkgK-mhnXc-rZLIKAeWACT0kBAb2aEsxPOQGab1bocjfPtU87S9HPAN68ZoIAZrMlNnD573fZqMj2Cv1RRm7jy9b3Uj-zrRai94Kp6A5AZahBkIRtSvDTSZYeHUHJOjVUq6c6PrlSSx9FKnmbnUXABL2qIf5m8UVM-ZRmBDHndf-fNgPjYy0g6T2UmRnynMe",
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
