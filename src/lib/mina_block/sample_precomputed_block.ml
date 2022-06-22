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
 (protocol_state_proof
  AgICAgEBAQEBAgEB_NXzOpIGeLEBAfwMqd8GjyhrdwABAfwMxWnKbTOhCAH8i4YSffoP8MMAAQH8iQCz_prWi3sB_BEouWqN0vOzAAIBAfzBBzWGcLjPcwH8nOfrwyXsm3IAAQCdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQEArQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8CAQH8JU-rVyi2WwoB_PKA6zqDmK-xAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBAgEQAQEBAAEAAQABAAABYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFgECAQEBAgEB_G-_5qzJs4IzAfxjGHb5WEOXeQABAgEB_JeHiOkGKzrdAfzHoUQpQOZ63QABAgEB_MufnPQw5ejGAfzdnKDNZbvdBwABAgEB_BMaaYeiWSxTAfx7b2UqsLwhqQABAgEB_IsHEI-xd5ziAfzuDGvfAF9c-AABAgEB_IecsActp70dAfygJl_p4pcbTQABAgEB_BFfgFZ8dHWcAfzo8c76aWP-oQABAgEB_E1g6dvfiitcAfyb9xDyjHGMWgABAgEB_Ehr4FFcs8AiAfztbalAc4uIpgABAgEB_G5kdl611weQAfwSjk7bOYvGwQABAgEB_MkrPzde40VEAfzlzYz8FcdAnQABAgEB_E6qvEuEgphCAfy8t6_Q1yeplwABAgEB_Hdu_f9bPcqZAfyUQlwVVWrm7wABAgEB_FSZlyFxsn1LAfxAyJNh4KIflQABAgEB_LNHB7K-zNEsAfwdAmTyPN7RWwAAAgEBAQIBAfxvv-asybOCMwH8Yxh2-VhDl3kAAQIBAfyXh4jpBis63QH8x6FEKUDmet0AAQIBAfzLn5z0MOXoxgH83ZygzWW73QcAAQIBAfwTGmmHolksUwH8e29lKrC8IakAAQIBAfyLBxCPsXec4gH87gxr3wBfXPgAAQIBAfyHnLAHLae9HQH8oCZf6eKXG00AAQIBAfwRX4BWfHR1nAH86PHO-mlj_qEAAQIBAfxNYOnb34orXAH8m_cQ8oxxjFoAAQIBAfxIa-BRXLPAIgH87W2pQHOLiKYAAQIBAfxuZHZetdcHkAH8Eo5O2zmLxsEAAQIBAfzJKz83XuNFRAH85c2M_BXHQJ0AAQIBAfxOqrxLhIKYQgH8vLev0NcnqZcAAQIBAfx3bv3_Wz3KmQH8lEJcFVVq5u8AAQIBAfxUmZchcbJ9SwH8QMiTYeCiH5UAAQIBAfyzRweyvszRLAH8HQJk8jze0VsAAAABAAECSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUBAgEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6Ro2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAIBAXEjmi6Bd0bylw-q3vGuQ1Fcit_8ILFvGUa3wudAsr4yASESun_XSWdBVjuUiHhhKl_qEf7hf0i7sAuuz3vfeOQjAe7cJCkB7qusy7ZdJXH_wmj_9btm91Qlpae3Wf_isygPAXsNPPiUA3OWzzPUMsYR_9M2-YZaSo_SH02400duYGg7AV3LML788vPZli5OLkyiCtZMenLHMHCUchpHUXefyiIjAcRusDuQav4EPSJQxucc-FB3dsG8IkYieYD8QncE_ioFAQrMK2_9pgL64gc16-CGxpD_-ItbC_Dd7bGfAzq-bfAmATeMyVIX79-ISORs2-837Eyg7yOpuSSe4kgduRlTkIILAeFc4ME22mPOXzmhhi2bBQS4fsazBOCIB5l9hksq5ecDAQ1WITfT8XFrEFsy44wIG8_6IHi-ooiNJ281SUpFHZkwAbvB2kibzXplG6JRGl6xu4TFQA53gitVWu7f8FqsWpkYAVfNvUp7aVlHAX_xDDTR7wnkCbLVa-bHXLzCdKwfKBMLAeZ8RtKbvPP0mHMCcD9jjDYMAGOYjEz88votBOv5yWECATZR45hvXiSFc9FXuY2EHNldCb7M5AZKCFEr_2k4gV8RAZEX0e1FG4nLu0N1MdJAwLVGatZRH80ZvgAavPRhtH4LAWzDZw_sx8tADUbsx48_IAegzqJeOsx2MGnefDFL978sAaVjyZXx_4_H6qAbE7LBbfTVNkKhm6hvB87h7e_7Mi0eAYufcqSsyzfhQRuUKlx5vve_FbZ0pLK6rqGtIzUneBUWAXk9UdPO_qT3Q8huliwKwxfrfgLBkggUaAmWfSgEkF47AfmmornJCka3Q5CjMhj1N81hV-5tGmy7m3lybjlyn7s5AQAMRmm03K-7MLpUQpYsDjUoGLOXFWqlnAB-Hyr5ibk4AUBftxHq6fyniHXbjbZhicVtQm_qBo8oJv5csLCv4GoOAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAAGNHvjiSs815o9ARIAyQ1LpIWRbw1SwVkTnvU6zqA6dEwGtsa_Pr_51aWVrVNXOOffBGlWVj2P0Mu-6mqljNOPwEwEBDRntusuc8Cu_XBwQU9QiR5UmhVA4wHJ3KgqXDzpU1SUBiaxwUsNvUKibzQYLpn-pRG3-sLbYCnTvYX3Ur2bMIDkBrF0QVebcheaWzeLkzVjkEXVWYi3mFsBLNCfrz055ITkBouBUxluRSy7Mo6m6ozWg1qUBnPuxnOBz6tUuHw-WPzAB3mS_8xYzg68iaHdNKflzgmVpJaOEbgjRudv9gQcJUAgBGnnJIGevOpPjjjt6tVHtMMslmL49Uxr8sxYf9GRSeQwBwxgdh9CrSpnOyIWz1N5RsLyjKzBuvs6NyhqHK8DvxB0BKIjCcWS5CzQal6iCxUVPWGio1oeWs_GO9UKA7j-WKDoBz-b1_MdSOT3L_JQSVsK6hJnTIiiuGt0SDQ--zNk4kjMBF-b82gBjIdJvaOKWiwhIdjYH-DL5rbC6pxoVuS95iCUB_9tOkJ13KWV17xYttzFYFpOorhomKOnXsRT25kgyMAoBQBKK3DI87NJLX03v-DS-lgyQpcl9Fs5tEj7ejJWyvzwAAZL1_NwMTNP23kJ5SLB4MS4LN0S2STK1WvYUHOj-btgsAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3Aa1s8ln_6tGNOv04L0EOdxo9XQ8mFFT6aZaT2BxFzIA8AJXRYizAp_LbipnYFWU01XIHqvO7xqWmoaMVzZJCaIIfAgICAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBBwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsAAgEPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSRujobz21FKPf2s93UGaAvqMNDoRcPA1lf6TGTJWhslKAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAgEBPGGq7DqbYRJvs4GVn5V2B5SvHWKlOUgjMLxIO7lpTAYBtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh4BsnOwvHH_6_HFxOAUimXpBlskiIe76JlgfQLxFwx7RgIB5Um5o2y5xoF1F-fWbfpx-7bYCZTbU3-bUZJ88w1whCcBdTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIiwBV_qftnG-DYoxFQTxMSIRhqGL4ER3EHMMS7qnTKNI3jIB9NHwhzB-lqXdLUH9IgF8CeSQb1YkyannDoUVgyvUTDUBAYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRYB3D4_x6LoE3BgUDX5YMuIVPuDNRmGzIgz_d96_zr8sBUBU0mvUJHjzRjAku2Ve-Nx15vKPhozvw-DiKwYkSWUQQQB5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWioBekqEp1ZfFfK1ykwNzfGfmZNxCblrIeelQdFCASQWUTYB6Ak_VsSOVAD-1cKoaujbM4Vj9afqMaZrLQgz4rc61gwBpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB0B9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkBJ6Z1PjwWuYkh1T0YVALodPMYqBn98vOsZmcmIEWqiiYBZk58pv6T8VHwaVCLgmrV0GxxVJMYy8kR2mt00G7-KAYBLlNgW4Aa1_6nRel2at2Nqe0zWJ11j7M5_tQMMpxZqicBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8AAXFxFeWXE8hPiLq-LsApJRgGDSzIK1Tpqcmi0qh86R4VAV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfAQGoT5Sg1tZL4LlwSbkq4sWKjLk-eSF5-rV_oyxGlavnJAEsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFwEW66Lr2p_qxELinvkpP1xFdpM9UxpuPAdRjjUiQQVfPQHc9bLhJFO4NpxCDnatoPtsbhc_InGqGextuAEBEmEWBQE1Ni2YbyDFmOU8PeC4_EEwBIQkMXKviTzJnKGZqhYWPAHwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLgE3vvqdgMYo-4s_f1MWkSwXVCagrZqD23gIR9Y28cyrCQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgABzXHIr-GnGfLl6D_OeUH7mjE-K5JiSAr6aGddz6tksgoB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDkBlqEGQhG1K8NNJlh4dQck6NVSrpzo-uVJLH0UqeZudRcAEvaoh_mbxRUz5lGYEMed1_582A-NjLSDpPZSZGfKcx4=)
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
  "protocol_state_proof": "AgICAgEBAQEBAgEB_NXzOpIGeLEBAfwMqd8GjyhrdwABAfwMxWnKbTOhCAH8i4YSffoP8MMAAQH8iQCz_prWi3sB_BEouWqN0vOzAAIBAfzBBzWGcLjPcwH8nOfrwyXsm3IAAQCdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQEArQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8CAQH8JU-rVyi2WwoB_PKA6zqDmK-xAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBAgEQAQEBAAEAAQABAAABYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFgECAQEBAgEB_G-_5qzJs4IzAfxjGHb5WEOXeQABAgEB_JeHiOkGKzrdAfzHoUQpQOZ63QABAgEB_MufnPQw5ejGAfzdnKDNZbvdBwABAgEB_BMaaYeiWSxTAfx7b2UqsLwhqQABAgEB_IsHEI-xd5ziAfzuDGvfAF9c-AABAgEB_IecsActp70dAfygJl_p4pcbTQABAgEB_BFfgFZ8dHWcAfzo8c76aWP-oQABAgEB_E1g6dvfiitcAfyb9xDyjHGMWgABAgEB_Ehr4FFcs8AiAfztbalAc4uIpgABAgEB_G5kdl611weQAfwSjk7bOYvGwQABAgEB_MkrPzde40VEAfzlzYz8FcdAnQABAgEB_E6qvEuEgphCAfy8t6_Q1yeplwABAgEB_Hdu_f9bPcqZAfyUQlwVVWrm7wABAgEB_FSZlyFxsn1LAfxAyJNh4KIflQABAgEB_LNHB7K-zNEsAfwdAmTyPN7RWwAAAgEBAQIBAfxvv-asybOCMwH8Yxh2-VhDl3kAAQIBAfyXh4jpBis63QH8x6FEKUDmet0AAQIBAfzLn5z0MOXoxgH83ZygzWW73QcAAQIBAfwTGmmHolksUwH8e29lKrC8IakAAQIBAfyLBxCPsXec4gH87gxr3wBfXPgAAQIBAfyHnLAHLae9HQH8oCZf6eKXG00AAQIBAfwRX4BWfHR1nAH86PHO-mlj_qEAAQIBAfxNYOnb34orXAH8m_cQ8oxxjFoAAQIBAfxIa-BRXLPAIgH87W2pQHOLiKYAAQIBAfxuZHZetdcHkAH8Eo5O2zmLxsEAAQIBAfzJKz83XuNFRAH85c2M_BXHQJ0AAQIBAfxOqrxLhIKYQgH8vLev0NcnqZcAAQIBAfx3bv3_Wz3KmQH8lEJcFVVq5u8AAQIBAfxUmZchcbJ9SwH8QMiTYeCiH5UAAQIBAfyzRweyvszRLAH8HQJk8jze0VsAAAABAAECSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUBAgEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBUtK3gb4cMAwdy0AgX2AkB1qZCz7WQGhepIYvZelG6Ro2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAIBAXEjmi6Bd0bylw-q3vGuQ1Fcit_8ILFvGUa3wudAsr4yASESun_XSWdBVjuUiHhhKl_qEf7hf0i7sAuuz3vfeOQjAe7cJCkB7qusy7ZdJXH_wmj_9btm91Qlpae3Wf_isygPAXsNPPiUA3OWzzPUMsYR_9M2-YZaSo_SH02400duYGg7AV3LML788vPZli5OLkyiCtZMenLHMHCUchpHUXefyiIjAcRusDuQav4EPSJQxucc-FB3dsG8IkYieYD8QncE_ioFAQrMK2_9pgL64gc16-CGxpD_-ItbC_Dd7bGfAzq-bfAmATeMyVIX79-ISORs2-837Eyg7yOpuSSe4kgduRlTkIILAeFc4ME22mPOXzmhhi2bBQS4fsazBOCIB5l9hksq5ecDAQ1WITfT8XFrEFsy44wIG8_6IHi-ooiNJ281SUpFHZkwAbvB2kibzXplG6JRGl6xu4TFQA53gitVWu7f8FqsWpkYAVfNvUp7aVlHAX_xDDTR7wnkCbLVa-bHXLzCdKwfKBMLAeZ8RtKbvPP0mHMCcD9jjDYMAGOYjEz88votBOv5yWECATZR45hvXiSFc9FXuY2EHNldCb7M5AZKCFEr_2k4gV8RAZEX0e1FG4nLu0N1MdJAwLVGatZRH80ZvgAavPRhtH4LAWzDZw_sx8tADUbsx48_IAegzqJeOsx2MGnefDFL978sAaVjyZXx_4_H6qAbE7LBbfTVNkKhm6hvB87h7e_7Mi0eAYufcqSsyzfhQRuUKlx5vve_FbZ0pLK6rqGtIzUneBUWAXk9UdPO_qT3Q8huliwKwxfrfgLBkggUaAmWfSgEkF47AfmmornJCka3Q5CjMhj1N81hV-5tGmy7m3lybjlyn7s5AQAMRmm03K-7MLpUQpYsDjUoGLOXFWqlnAB-Hyr5ibk4AUBftxHq6fyniHXbjbZhicVtQm_qBo8oJv5csLCv4GoOAQ5QGe9ZW3lvhy7a6HTfPmvR6UQkrte6TXrF_lriJSQVAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAAGNHvjiSs815o9ARIAyQ1LpIWRbw1SwVkTnvU6zqA6dEwGtsa_Pr_51aWVrVNXOOffBGlWVj2P0Mu-6mqljNOPwEwEBDRntusuc8Cu_XBwQU9QiR5UmhVA4wHJ3KgqXDzpU1SUBiaxwUsNvUKibzQYLpn-pRG3-sLbYCnTvYX3Ur2bMIDkBrF0QVebcheaWzeLkzVjkEXVWYi3mFsBLNCfrz055ITkBouBUxluRSy7Mo6m6ozWg1qUBnPuxnOBz6tUuHw-WPzAB3mS_8xYzg68iaHdNKflzgmVpJaOEbgjRudv9gQcJUAgBGnnJIGevOpPjjjt6tVHtMMslmL49Uxr8sxYf9GRSeQwBwxgdh9CrSpnOyIWz1N5RsLyjKzBuvs6NyhqHK8DvxB0BKIjCcWS5CzQal6iCxUVPWGio1oeWs_GO9UKA7j-WKDoBz-b1_MdSOT3L_JQSVsK6hJnTIiiuGt0SDQ--zNk4kjMBF-b82gBjIdJvaOKWiwhIdjYH-DL5rbC6pxoVuS95iCUB_9tOkJ13KWV17xYttzFYFpOorhomKOnXsRT25kgyMAoBQBKK3DI87NJLX03v-DS-lgyQpcl9Fs5tEj7ejJWyvzwAAZL1_NwMTNP23kJ5SLB4MS4LN0S2STK1WvYUHOj-btgsAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3Aa1s8ln_6tGNOv04L0EOdxo9XQ8mFFT6aZaT2BxFzIA8AJXRYizAp_LbipnYFWU01XIHqvO7xqWmoaMVzZJCaIIfAgICAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwABAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBBwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsAAgEPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbaQqY2UshcO37P1ab1t7vqcyhOwk9lZsTbuAdL5hrDSRujobz21FKPf2s93UGaAvqMNDoRcPA1lf6TGTJWhslKAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAgEBPGGq7DqbYRJvs4GVn5V2B5SvHWKlOUgjMLxIO7lpTAYBtZQxUPGqxd5TYjuLrV_6Y2WOq7xjjnpjJ7H_qSsxeh4BsnOwvHH_6_HFxOAUimXpBlskiIe76JlgfQLxFwx7RgIB5Um5o2y5xoF1F-fWbfpx-7bYCZTbU3-bUZJ88w1whCcBdTPev6o9ei-4Vn0Zv2JWFGyivBIbUjz75CeS4LNTIiwBV_qftnG-DYoxFQTxMSIRhqGL4ER3EHMMS7qnTKNI3jIB9NHwhzB-lqXdLUH9IgF8CeSQb1YkyannDoUVgyvUTDUBAYXvV5AAHL5uTgiUQPxSJJx5u00xIIr3xdiBCNzHiRYB3D4_x6LoE3BgUDX5YMuIVPuDNRmGzIgz_d96_zr8sBUBU0mvUJHjzRjAku2Ve-Nx15vKPhozvw-DiKwYkSWUQQQB5yK_CzhPwUg7pQ2JRgTcVUbkNMTKtgAcwrxZ-seYWioBekqEp1ZfFfK1ykwNzfGfmZNxCblrIeelQdFCASQWUTYB6Ak_VsSOVAD-1cKoaujbM4Vj9afqMaZrLQgz4rc61gwBpmFjPtSXHsOlATjbtnx9SEK__u-xA-WNk0Aa9wT0zB0B9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkBJ6Z1PjwWuYkh1T0YVALodPMYqBn98vOsZmcmIEWqiiYBZk58pv6T8VHwaVCLgmrV0GxxVJMYy8kR2mt00G7-KAYBLlNgW4Aa1_6nRel2at2Nqe0zWJ11j7M5_tQMMpxZqicBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8AAXFxFeWXE8hPiLq-LsApJRgGDSzIK1Tpqcmi0qh86R4VAV3ZPJssP87jD6NJYPJHL80E2d6EhvY1ybltd2-uMSIfAQGoT5Sg1tZL4LlwSbkq4sWKjLk-eSF5-rV_oyxGlavnJAEsfGqlEjtBqo6s6Fp-7rjrsiIZyTU7knZxEZmqqAGCFwEW66Lr2p_qxELinvkpP1xFdpM9UxpuPAdRjjUiQQVfPQHc9bLhJFO4NpxCDnatoPtsbhc_InGqGextuAEBEmEWBQE1Ni2YbyDFmOU8PeC4_EEwBIQkMXKviTzJnKGZqhYWPAHwlR5qOF-06oteLPDonlSAepmTiwq2nHfxubIQoF0VLgE3vvqdgMYo-4s_f1MWkSwXVCagrZqD23gIR9Y28cyrCQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgABzXHIr-GnGfLl6D_OeUH7mjE-K5JiSAr6aGddz6tksgoB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDkBlqEGQhG1K8NNJlh4dQck6NVSrpzo-uVJLH0UqeZudRcAEvaoh_mbxRUz5lGYEMed1_582A-NjLSDpPZSZGfKcx4=",
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
|json}
