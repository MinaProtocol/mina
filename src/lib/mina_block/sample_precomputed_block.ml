(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)
let sample_block_sexp =
  {sexp|
((scheduled_time 1653989603207)
 (protocol_state
  ((previous_state_hash
    17473258905665237284832573461818847361684453159583220075766099558740479185450)
   (body
    ((genesis_state_hash
      17473258905665237284832573461818847361684453159583220075766099558740479185450)
     (blockchain_state
      ((staged_ledger_hash
        ((non_snark
          ((ledger_hash
            6909144823035311680342700490444104620140714101660929546660204184691054283936)
           (aux_hash
            "\189\216\213\138j\176%\214e\159\222#\145\011G\181=w@zx\196i\230\191\021\212V\003\241\139\n")
           (pending_coinbase_aux
            "\147\141\184\201\248,\140\181\141?>\244\253%\0006\164\141&\167\018u=/\222Z\189\003\168\\\171\244")))
         (pending_coinbase_hash
          3271908291937070024579456660832089271815626624080948511730537255376510579236)))
       (genesis_ledger_hash
        16041053542394242154725113468404579468710303098516635504517095323755599162781)
       (registers
        ((ledger
          16041053542394242154725113468404579468710303098516635504517095323755599162781)
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
       (timestamp 1653989603207)
       (body_reference
        "\172.\017\194\246}t\169\189O7\172\147\171B\230\016s\195\173wN\169\140\237Z\141UvGR\250")))
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
            16041053542394242154725113468404579468710303098516635504517095323755599162781)
           (total_currency 10016100000000000)))
         (seed 0) (start_checkpoint 0) (lock_checkpoint 0) (epoch_length 1)))
       (next_epoch_data
        ((ledger
          ((hash
            16041053542394242154725113468404579468710303098516635504517095323755599162781)
           (total_currency 10016100000000000)))
         (seed
          6361847198485054175200272537302982739133979173179386423380077201169092291378)
         (start_checkpoint 0)
         (lock_checkpoint
          17473258905665237284832573461818847361684453159583220075766099558740479185450)
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
  AgICAgEBAQEBAgEB_NXzOpIGeLEBAfwMqd8GjyhrdwABAfwMxWnKbTOhCAH8i4YSffoP8MMAAQH8iQCz_prWi3sB_BEouWqN0vOzAAIBAfzBBzWGcLjPcwH8nOfrwyXsm3IAAQCdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQEArQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8CAQH8JU-rVyi2WwoB_PKA6zqDmK-xAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEAAQEBAAEAAQABAAABYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFgECAQEBAgEB_G-_5qzJs4IzAfxjGHb5WEOXeQABAgEB_JeHiOkGKzrdAfzHoUQpQOZ63QABAgEB_MufnPQw5ejGAfzdnKDNZbvdBwABAgEB_BMaaYeiWSxTAfx7b2UqsLwhqQABAgEB_IsHEI-xd5ziAfzuDGvfAF9c-AABAgEB_IecsActp70dAfygJl_p4pcbTQABAgEB_BFfgFZ8dHWcAfzo8c76aWP-oQABAgEB_E1g6dvfiitcAfyb9xDyjHGMWgABAgEB_Ehr4FFcs8AiAfztbalAc4uIpgABAgEB_G5kdl611weQAfwSjk7bOYvGwQABAgEB_MkrPzde40VEAfzlzYz8FcdAnQABAgEB_E6qvEuEgphCAfy8t6_Q1yeplwABAgEB_Hdu_f9bPcqZAfyUQlwVVWrm7wABAgEB_FSZlyFxsn1LAfxAyJNh4KIflQABAgEB_LNHB7K-zNEsAfwdAmTyPN7RWwAAAgEBAQIBAfxvv-asybOCMwH8Yxh2-VhDl3kAAQIBAfyXh4jpBis63QH8x6FEKUDmet0AAQIBAfzLn5z0MOXoxgH83ZygzWW73QcAAQIBAfwTGmmHolksUwH8e29lKrC8IakAAQIBAfyLBxCPsXec4gH87gxr3wBfXPgAAQIBAfyHnLAHLae9HQH8oCZf6eKXG00AAQIBAfwRX4BWfHR1nAH86PHO-mlj_qEAAQIBAfxNYOnb34orXAH8m_cQ8oxxjFoAAQIBAfxIa-BRXLPAIgH87W2pQHOLiKYAAQIBAfxuZHZetdcHkAH8Eo5O2zmLxsEAAQIBAfzJKz83XuNFRAH85c2M_BXHQJ0AAQIBAfxOqrxLhIKYQgH8vLev0NcnqZcAAQIBAfx3bv3_Wz3KmQH8lEJcFVVq5u8AAQIBAfxUmZchcbJ9SwH8QMiTYeCiH5UAAQIBAfyzRweyvszRLAH8HQJk8jze0VsAAAABAAECSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUBAgEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8CAQFS0reBvhwwDB3LQCBfYCQHWpkLPtZAaF6khi9l6UbpGgE2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAFxI5ougXdG8pcPqt7xrkNRXIrf_CCxbxlGt8LnQLK-MgEhErp_10lnQVY7lIh4YSpf6hH-4X9Iu7ALrs9733jkIwHu3CQpAe6rrMu2XSVx_8Jo__W7ZvdUJaWnt1n_4rMoDwF7DTz4lANzls8z1DLGEf_TNvmGWkqP0h9NuNNHbmBoOwFdyzC-_PLz2ZYuTi5MogrWTHpyxzBwlHIaR1F3n8oiIwHEbrA7kGr-BD0iUMbnHPhQd3bBvCJGInmA_EJ3BP4qBQEKzCtv_aYC-uIHNevghsaQ__iLWwvw3e2xnwM6vm3wJgE3jMlSF-_fiEjkbNvvN-xMoO8jqbkknuJIHbkZU5CCCwHhXODBNtpjzl85oYYtmwUEuH7GswTgiAeZfYZLKuXnAwENViE30_FxaxBbMuOMCBvP-iB4vqKIjSdvNUlKRR2ZMAG7wdpIm816ZRuiURpesbuExUAOd4IrVVru3_BarFqZGAFXzb1Ke2lZRwF_8Qw00e8J5Amy1Wvmx1y8wnSsHygTCwHmfEbSm7zz9JhzAnA_Y4w2DABjmIxM_PL6LQTr-clhAgABNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBAZEX0e1FG4nLu0N1MdJAwLVGatZRH80ZvgAavPRhtH4LAWzDZw_sx8tADUbsx48_IAegzqJeOsx2MGnefDFL978sAaVjyZXx_4_H6qAbE7LBbfTVNkKhm6hvB87h7e_7Mi0eAYufcqSsyzfhQRuUKlx5vve_FbZ0pLK6rqGtIzUneBUWAXk9UdPO_qT3Q8huliwKwxfrfgLBkggUaAmWfSgEkF47AfmmornJCka3Q5CjMhj1N81hV-5tGmy7m3lybjlyn7s5AAEADEZptNyvuzC6VEKWLA41KBizlxVqpZwAfh8q-Ym5OAFAX7cR6un8p4h12422YYnFbUJv6gaPKCb-XLCwr-BqDgEOUBnvWVt5b4cu2uh03z5r0elEJK7Xuk16xf5a4iUkFQIBAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEBKIjCcWS5CzQal6iCxUVPWGio1oeWs_GO9UKA7j-WKDoBz-b1_MdSOT3L_JQSVsK6hJnTIiiuGt0SDQ--zNk4kjMBF-b82gBjIdJvaOKWiwhIdjYH-DL5rbC6pxoVuS95iCUB_9tOkJ13KWV17xYttzFYFpOorhomKOnXsRT25kgyMAoBQBKK3DI87NJLX03v-DS-lgyQpcl9Fs5tEj7ejJWyvzwBkvX83AxM0_beQnlIsHgxLgs3RLZJMrVa9hQc6P5u2CwAAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3rWzyWf_q0Y06_TgvQQ53Gj1dDyYUVPpplpPYHEXMgDwCAgIBAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAAEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEHAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwIBDwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0G2kKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwIBATvXd2YAh6jWpag_ZAAGvKfBNt_MNZMI68RE_gDmgmsYAXMXa7vEw1pAywL42XIYys2Y8mPdWLWuj8G4FfLJxd0pATxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGAbWUMVDxqsXeU2I7i61f-mNljqu8Y456Yyex_6krMXoeAbJzsLxx_-vxxcTgFIpl6QZbJIiHu-iZYH0C8RcMe0YCAeVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQnAXUz3r-qPXovuFZ9Gb9iVhRsorwSG1I8--QnkuCzUyIsAVf6n7Zxvg2KMRUE8TEiEYahi-BEdxBzDEu6p0yjSN4yAfTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AQGF71eQABy-bk4IlED8UiScebtNMSCK98XYgQjcx4kWAdw-P8ei6BNwYFA1-WDLiFT7gzUZhsyIM_3fev86_LAVAVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEEAecivws4T8FIO6UNiUYE3FVG5DTEyrYAHMK8WfrHmFoqAXpKhKdWXxXytcpMDc3xn5mTcQm5ayHnpUHRQgEkFlE2AegJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMAAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQEB9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkAASemdT48FrmJIdU9GFQC6HTzGKgZ_fLzrGZnJiBFqoomAWZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAgEBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8BcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUBNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4AATe--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJAQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgHNcciv4acZ8uXoP855QfuaMT4rkmJICvpoZ13Pq2SyCgAB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDmWoQZCEbUrw00mWHh1ByTo1VKunOj65UksfRSp5m51Fw==)
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
                  B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz)
                 (amount 1000000001))))))
            (signer B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
            (signature
             (2624790110040619097322442003505841435141972686132514625595757782273798773194
              26865973790257767413057212348205130141300744192599555345968688676353275000209)))))
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
                  B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm)
                 (amount 1000000001))))))
            (signer B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX)
            (signature
             (1629755357275865931605727979180251841514241020432365993932795229438925365379
              11102386492057132662139020545389849553391951512692930847842676297300704882247)))))
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
                  B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2)
                 (amount 1000000001))))))
            (signer B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
            (signature
             (17635734646647920690169694764446281534378027408005666156101007982257800187298
              3295142109416422422341202799936619326665800469150584625476368412811468311760)))))
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
                  B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)
                 (amount 1000000001))))))
            (signer B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
            (signature
             (317486600753054183279213916820847978325972946655967920306850783796286881766
              17457350400788927539043513735553177502363195580057576324486615363043559382648)))))
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
                  B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
                 (amount 1000000001))))))
            (signer B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7)
            (signature
             (11576214069076631449973766089967317010892921008349408021239215299640168385269
              10893997420520561323519477932174511919937861860189824964411604919453040624475)))))
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
                  B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF)
                 (amount 1000000001))))))
            (signer B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq)
            (signature
             (9031776815217295499367944223955219280115942046123064022068379751254154557175
              5381365211449878565465750054973499984808538694265643093445707357587602148375)))))
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
                  B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
                 (amount 1000000001))))))
            (signer B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA)
            (signature
             (12309899091643738004638224987754963758052820749542392052832381481826311744718
              452635837932404430708440230707559489723217212944764269627376232213447393162)))))
         (status Applied))))
      (coinbase (One ())))
     ()))))
 (delta_transition_chain_proof
  (17473258905665237284832573461818847361684453159583220075766099558740479185450
   ()))
 (accounts_accessed
  ((12
    ((public_key B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
   (2
    ((public_key B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      15018126736114034971379027508106823645323618085925642640378503671468586157006)
     (delegate (B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
   (16
    ((public_key B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 1001000000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2))
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
      5558329214275537272848768839165680150629827154945511206874707541771891199014)
     (delegate (B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX))
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
     (token_symbol "") (balance 1001000000001) (nonce 1)
     (receipt_chain_hash
      12226988832353384659756570818437506293404396190454015060541063554138592983857)
     (delegate (B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF))
     (voting_for 0) (timing Untimed)
     (permissions
      ((edit_state Signature) (send Signature) (receive None)
       (set_delegate Signature) (set_permissions Signature)
       (set_verification_key Signature) (set_zkapp_uri Signature)
       (edit_sequence_state Signature) (set_token_symbol Signature)
       (increment_nonce Signature) (set_voting_for Signature)))
     (zkapp ()) (zkapp_uri "")))
   (18
    ((public_key B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz)
     (token_id
      0x0000000000000000000000000000000000000000000000000000000000000001)
     (token_permissions (Not_owned (account_disabled false)))
     (token_symbol "") (balance 999000001) (nonce 0)
     (receipt_chain_hash
      14564582992068613478915821183083107733064540968050799295374021047658500056219)
     (delegate (B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz))
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
     (token_symbol "") (balance 1000000000000) (nonce 1)
     (receipt_chain_hash
      205955712724237573746663312079467834945262380282042798778435155338576926579)
     (delegate (B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA))
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
      16034039772558450007242235603884780068752076379242636801160785815975088471465)
     (delegate (B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq))
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
      27885513822288937255009244595396542456692891087932980761093146914834537342045)
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
     (token_symbol "") (balance 998999999999) (nonce 1)
     (receipt_chain_hash
      10547268328341193750819522595065511330985480096143091391268478228824314181645)
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
 (accounts_created
  (((B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz
     0x0000000000000000000000000000000000000000000000000000000000000001)
    1000000)))
 (tokens_used
  ((0x0000000000000000000000000000000000000000000000000000000000000001 ()))))
|sexp}

let sample_block_json =
  {json|
{"scheduled_time":"1653989603207","protocol_state":{"previous_state_hash":"3NKMRTEJ3pEaCbfNY68XWgTjLH1bGyXPgq3EYbfcM3rzi7b9N9Sc","body":{"genesis_state_hash":"3NKMRTEJ3pEaCbfNY68XWgTjLH1bGyXPgq3EYbfcM3rzi7b9N9Sc","blockchain_state":{"staged_ledger_hash":{"non_snark":{"ledger_hash":"jxK6Fz4zsEtQY3R7bq2rUoxQeBG66Vi2SzwR49hqZi7LMJwrZKb","aux_hash":"Vf2rhF77kcX4Z4t8GLe4DUzujuPckNXw6Wa8dBW5jU3Ptp2w25","pending_coinbase_aux":"XH9htC21tQMDKM6hhATkQjecZPRUGpofWATXPkjB5QKxpTBv7H"},"pending_coinbase_hash":"2mznsqsRLeACsmrLwKENVwoFgQJZiYaXBkb9J8BRaDCf9Gzqubuy"},"genesis_ledger_hash":"jxJ9zhpSiTk5wdAtCBjLVDRUhnpw5vNdaNGsEagdB1uvGVk4qdf","registers":{"ledger":"jxJ9zhpSiTk5wdAtCBjLVDRUhnpw5vNdaNGsEagdB1uvGVk4qdf","pending_coinbase_stack":null,"local_state":{"stack_frame":"0x02F99BCFB0AA7F48C1888DA5A67196A2410FB084CD2DB1AF5216C5122AEBC054","call_stack":"0x0000000000000000000000000000000000000000000000000000000000000000","transaction_commitment":"0x0000000000000000000000000000000000000000000000000000000000000000","full_transaction_commitment":"0x0000000000000000000000000000000000000000000000000000000000000000","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","excess":{"magnitude":"0","sgn":["Pos"]},"ledger":"jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd","success":true,"failure_status_tbl":[]}},"timestamp":"1653989603207","body_reference":"ac2e11c2f67d74a9bd4f37ac93ab42e61073c3ad774ea98ced5a8d55764752fa"},"consensus_state":{"blockchain_length":"2","epoch_count":"0","min_window_density":"6","sub_window_densities":["1","0","0"],"last_vrf_output":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","total_currency":"10016120000000000","curr_global_slot":{"slot_number":"6","slots_per_epoch":"576"},"global_slot_since_genesis":"6","staking_epoch_data":{"ledger":{"hash":"jxJ9zhpSiTk5wdAtCBjLVDRUhnpw5vNdaNGsEagdB1uvGVk4qdf","total_currency":"10016100000000000"},"seed":"2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA","start_checkpoint":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","lock_checkpoint":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","epoch_length":"1"},"next_epoch_data":{"ledger":{"hash":"jxJ9zhpSiTk5wdAtCBjLVDRUhnpw5vNdaNGsEagdB1uvGVk4qdf","total_currency":"10016100000000000"},"seed":"2vaXVbnZUEmF2jd8TSWu59Y1pjnh97PmC9jRq5x1UHF5zBs83ygF","start_checkpoint":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","lock_checkpoint":"3NKMRTEJ3pEaCbfNY68XWgTjLH1bGyXPgq3EYbfcM3rzi7b9N9Sc","epoch_length":"3"},"has_ancestor_in_same_checkpoint_window":true,"block_stake_winner":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","block_creator":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","coinbase_receiver":"B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo","supercharge_coinbase":true},"constants":{"k":"24","slots_per_epoch":"576","slots_per_sub_window":"2","delta":"0","genesis_state_timestamp":"1548878400000"}}},"protocol_state_proof":"AgICAgEBAQEBAgEB_NXzOpIGeLEBAfwMqd8GjyhrdwABAfwMxWnKbTOhCAH8i4YSffoP8MMAAQH8iQCz_prWi3sB_BEouWqN0vOzAAIBAfzBBzWGcLjPcwH8nOfrwyXsm3IAAQCdCffOVUZW4gI_IpwEhZc-V2_3Eo1FkGiWw61W-xkgAQEArQvbebLxb00UJ-Da_nDAYxD6Rga5PrRCglOPg9oo8T8CAQH8JU-rVyi2WwoB_PKA6zqDmK-xAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEAAQEBAAEAAQABAAABYplUSRXwm-fBeRFELSVIQFO0WQXbn0FWMGH9fbwy0w-s11KF98GiT8ex5uJ8PBY6Vaax5zY5Ax0E66VeUAQFFgECAQEBAgEB_G-_5qzJs4IzAfxjGHb5WEOXeQABAgEB_JeHiOkGKzrdAfzHoUQpQOZ63QABAgEB_MufnPQw5ejGAfzdnKDNZbvdBwABAgEB_BMaaYeiWSxTAfx7b2UqsLwhqQABAgEB_IsHEI-xd5ziAfzuDGvfAF9c-AABAgEB_IecsActp70dAfygJl_p4pcbTQABAgEB_BFfgFZ8dHWcAfzo8c76aWP-oQABAgEB_E1g6dvfiitcAfyb9xDyjHGMWgABAgEB_Ehr4FFcs8AiAfztbalAc4uIpgABAgEB_G5kdl611weQAfwSjk7bOYvGwQABAgEB_MkrPzde40VEAfzlzYz8FcdAnQABAgEB_E6qvEuEgphCAfy8t6_Q1yeplwABAgEB_Hdu_f9bPcqZAfyUQlwVVWrm7wABAgEB_FSZlyFxsn1LAfxAyJNh4KIflQABAgEB_LNHB7K-zNEsAfwdAmTyPN7RWwAAAgEBAQIBAfxvv-asybOCMwH8Yxh2-VhDl3kAAQIBAfyXh4jpBis63QH8x6FEKUDmet0AAQIBAfzLn5z0MOXoxgH83ZygzWW73QcAAQIBAfwTGmmHolksUwH8e29lKrC8IakAAQIBAfyLBxCPsXec4gH87gxr3wBfXPgAAQIBAfyHnLAHLae9HQH8oCZf6eKXG00AAQIBAfwRX4BWfHR1nAH86PHO-mlj_qEAAQIBAfxNYOnb34orXAH8m_cQ8oxxjFoAAQIBAfxIa-BRXLPAIgH87W2pQHOLiKYAAQIBAfxuZHZetdcHkAH8Eo5O2zmLxsEAAQIBAfzJKz83XuNFRAH85c2M_BXHQJ0AAQIBAfxOqrxLhIKYQgH8vLev0NcnqZcAAQIBAfx3bv3_Wz3KmQH8lEJcFVVq5u8AAQIBAfxUmZchcbJ9SwH8QMiTYeCiH5UAAQIBAfyzRweyvszRLAH8HQJk8jze0VsAAAABAAECSLU26EZUpV9P_f_99ZG9nTyhcEvO8FylncJkSN7f0xFrGixE3SHHzVlV7xnD86u4Qg4beuUXFN7XioRNIgf1BUi1NuhGVKVfT_3__fWRvZ08oXBLzvBcpZ3CZEje39MRaxosRN0hx81ZVe8Zw_OruEIOG3rlFxTe14qETSIH9QUBAgEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBAQIBAfy5KqdWtHBzrQH8_J7x1SP5TzYAAQIBAfwAfC-OYhyHWQH8h8wmonP2x5wAAQIBAfyv8raeHYJUIwH8fvV99tFrudUAAQIBAfz2hpCg0Pd7FAH8aCokQM5iXmIAAQIBAfwOrVYyYxvGrwH8--EfoRBygAkAAQIBAfyRQazKvh5Y-QH8psm3PpnVHlcAAQIBAfy9w2TNo1BOqgH8aMX-wQrnFNgAAQIBAfxt3l6C36wdsgH8pQfbxReiCP4AAQIBAfx_qubp1g9OggH8LH-5Tpg69vwAAQIBAfzKBBtxK4gxwwH8KSautsesOZEAAQIBAfzvUYH9R48P3AH8h5U7xEN6qQAAAQIBAfy_MobRHtg4YAH8qwWqonC8s_kAAQIBAfxaR6_l4NJ1lAH89tLDrgKny9EAAQIBAfwEfC359g94vgH8VOL7MpFYPeEAAQIBAfwTdTG4ErdwxgH8CD5ImjPMdRYAAQIBAfzRuMqxorDBSAH8zrFxwOMEZhsAAAEBldFiLMCn8tuKmdgVZTTVcgeq87vGpaahoxXNkkJogh8CAQFS0reBvhwwDB3LQCBfYCQHWpkLPtZAaF6khi9l6UbpGgE2iY4ANf6-Fu6V2JAx31oQ1WHZmK7QZi9deLsMF8vYDAFxI5ougXdG8pcPqt7xrkNRXIrf_CCxbxlGt8LnQLK-MgEhErp_10lnQVY7lIh4YSpf6hH-4X9Iu7ALrs9733jkIwHu3CQpAe6rrMu2XSVx_8Jo__W7ZvdUJaWnt1n_4rMoDwF7DTz4lANzls8z1DLGEf_TNvmGWkqP0h9NuNNHbmBoOwFdyzC-_PLz2ZYuTi5MogrWTHpyxzBwlHIaR1F3n8oiIwHEbrA7kGr-BD0iUMbnHPhQd3bBvCJGInmA_EJ3BP4qBQEKzCtv_aYC-uIHNevghsaQ__iLWwvw3e2xnwM6vm3wJgE3jMlSF-_fiEjkbNvvN-xMoO8jqbkknuJIHbkZU5CCCwHhXODBNtpjzl85oYYtmwUEuH7GswTgiAeZfYZLKuXnAwENViE30_FxaxBbMuOMCBvP-iB4vqKIjSdvNUlKRR2ZMAG7wdpIm816ZRuiURpesbuExUAOd4IrVVru3_BarFqZGAFXzb1Ke2lZRwF_8Qw00e8J5Amy1Wvmx1y8wnSsHygTCwHmfEbSm7zz9JhzAnA_Y4w2DABjmIxM_PL6LQTr-clhAgABNlHjmG9eJIVz0Ve5jYQc2V0JvszkBkoIUSv_aTiBXxEBAZEX0e1FG4nLu0N1MdJAwLVGatZRH80ZvgAavPRhtH4LAWzDZw_sx8tADUbsx48_IAegzqJeOsx2MGnefDFL978sAaVjyZXx_4_H6qAbE7LBbfTVNkKhm6hvB87h7e_7Mi0eAYufcqSsyzfhQRuUKlx5vve_FbZ0pLK6rqGtIzUneBUWAXk9UdPO_qT3Q8huliwKwxfrfgLBkggUaAmWfSgEkF47AfmmornJCka3Q5CjMhj1N81hV-5tGmy7m3lybjlyn7s5AAEADEZptNyvuzC6VEKWLA41KBizlxVqpZwAfh8q-Ym5OAFAX7cR6un8p4h12422YYnFbUJv6gaPKCb-XLCwr-BqDgEOUBnvWVt5b4cu2uh03z5r0elEJK7Xuk16xf5a4iUkFQIBAc7OkkrxKJsib7tsvvgJuUQiqdkfB4KtoNh-_IPQGbkbAUpO6djO835wTVeDbivULGlkZuJxl-Fm5aSsh69vF6kkAd5-V-0CNe0TFe58dlgv6F7xNBBXGnU3vNe9ORnyZuweAX6owPslflEY5UjZx9WfWFjKFTufeFBiMT0lDiTiAykUAZ1TyFvbyLn4lf088oVAmt4k0HfGsfuIS-jtA6YJIHoVAZmE3lrTCRxSP5DbZ5JSazaz0JNr2oqoqoIRJ0jhqvstAdI9RFVcVpMkBn2CgXYypLSL4xQmcQGgmHMZcnXQKE8FAY0e-OJKzzXmj0BEgDJDUukhZFvDVLBWROe9TrOoDp0TAa2xr8-v_nVpZWtU1c4598EaVZWPY_Qy77qaqWM04_ATAQ0Z7brLnPArv1wcEFPUIkeVJoVQOMBydyoKlw86VNUlAYmscFLDb1Com80GC6Z_qURt_rC22Ap072F91K9mzCA5AaxdEFXm3IXmls3i5M1Y5BF1VmIt5hbASzQn689OeSE5AaLgVMZbkUsuzKOpuqM1oNalAZz7sZzgc-rVLh8Plj8wAd5kv_MWM4OvImh3TSn5c4JlaSWjhG4I0bnb_YEHCVAIARp5ySBnrzqT4447erVR7TDLJZi-PVMa_LMWH_RkUnkMAAHDGB2H0KtKmc7IhbPU3lGwvKMrMG6-zo3KGocrwO_EHQEBKIjCcWS5CzQal6iCxUVPWGio1oeWs_GO9UKA7j-WKDoBz-b1_MdSOT3L_JQSVsK6hJnTIiiuGt0SDQ--zNk4kjMBF-b82gBjIdJvaOKWiwhIdjYH-DL5rbC6pxoVuS95iCUB_9tOkJ13KWV17xYttzFYFpOorhomKOnXsRT25kgyMAoBQBKK3DI87NJLX03v-DS-lgyQpcl9Fs5tEj7ejJWyvzwBkvX83AxM0_beQnlIsHgxLgs3RLZJMrVa9hQc6P5u2CwAAUyx4bzshD-rfjd4D0SIDVjr-jwotMDJE65BSVpbz1sZAcDITf6hUwa7licVuSHAEX_enz-d_6lzT8qXfK6GVJA3rWzyWf_q0Y06_TgvQQ53Gj1dDyYUVPpplpPYHEXMgDwCAgIBAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAAEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEHAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwIBDwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuyrtyiN6zxlxRz0z1Ftlj1TueGPwqd9TfJMSCqO1dBsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0G2kKmNlLIXDt-z9Wm9be76nMoTsJPZWbE27gHS-Yaw0kbo6G89tRSj39rPd1BmgL6jDQ6EXDwNZX-kxkyVobJSgBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALsq7cojes8ZcUc9M9RbZY9U7nhj8KnfU3yTEgqjtXQbAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC7Ku3KI3rPGXFHPTPUW2WPVO54Y_Cp31N8kxIKo7V0GwIBATvXd2YAh6jWpag_ZAAGvKfBNt_MNZMI68RE_gDmgmsYAXMXa7vEw1pAywL42XIYys2Y8mPdWLWuj8G4FfLJxd0pATxhquw6m2ESb7OBlZ-VdgeUrx1ipTlIIzC8SDu5aUwGAbWUMVDxqsXeU2I7i61f-mNljqu8Y456Yyex_6krMXoeAbJzsLxx_-vxxcTgFIpl6QZbJIiHu-iZYH0C8RcMe0YCAeVJuaNsucaBdRfn1m36cfu22AmU21N_m1GSfPMNcIQnAXUz3r-qPXovuFZ9Gb9iVhRsorwSG1I8--QnkuCzUyIsAVf6n7Zxvg2KMRUE8TEiEYahi-BEdxBzDEu6p0yjSN4yAfTR8Icwfpal3S1B_SIBfAnkkG9WJMmp5w6FFYMr1Ew1AQGF71eQABy-bk4IlED8UiScebtNMSCK98XYgQjcx4kWAdw-P8ei6BNwYFA1-WDLiFT7gzUZhsyIM_3fev86_LAVAVNJr1CR480YwJLtlXvjcdebyj4aM78Pg4isGJEllEEEAecivws4T8FIO6UNiUYE3FVG5DTEyrYAHMK8WfrHmFoqAXpKhKdWXxXytcpMDc3xn5mTcQm5ayHnpUHRQgEkFlE2AegJP1bEjlQA_tXCqGro2zOFY_Wn6jGmay0IM-K3OtYMAAGmYWM-1Jcew6UBONu2fH1IQr_-77ED5Y2TQBr3BPTMHQEB9oE-cfEh-6pmHcuAlF7xGD7DzxC3xjcYSlA7Gq6RCAsBUr6b8PC7EZGdUG3wO7if9rU6ktb4DwGWHcVAJVyYVCABfliyT9Ip77FuEgWmS1y7mGVmr4Qa7GpNjaVCAF05dhUBl5r4JgvM6SeV9BI4zzTXe0Ng4eQU0ceTfaxreedN5TkB83KNFoDhCWgbS2-AEf6mp1j46SfcLhbs88QZvm-VdhYBeGT_NZ1qIHtyPxh_d4YV0vBzKzevFpl3lM-DSWTYeTkAASemdT48FrmJIdU9GFQC6HTzGKgZ_fLzrGZnJiBFqoomAWZOfKb-k_FR8GlQi4Jq1dBscVSTGMvJEdprdNBu_igGAgEBt3qHiLB_fNHJxhYYdVzKPQ0wOnsJYSTODALcX0UaDwMBLh5ocx0AuEcgA4gjd37GUi2aHp42WSDD584GSt4MLh4B2W1i5UoKSdOkTJGetLCJMz1kojbtzaGSEnSsaQO62TcBzOOnjfokLYxT6JRnzJht_TMtuYfXbGbnc1pH7zTpDygBw31pLIRzqpoka7heXEMjzQxaaeS5zhrhYPlhRHwxri4B2C04cXhCveMXFX7fGGpbKlrCoDWgabGKG7eQ2KG2DiYBaZTicPKEpVfEGK_r-qyieUyK9qR2yxuUeMIF6KkBFw8BcXEV5ZcTyE-Iur4uwCklGAYNLMgrVOmpyaLSqHzpHhUBXdk8myw_zuMPo0lg8kcvzQTZ3oSG9jXJuW13b64xIh8BqE-UoNbWS-C5cEm5KuLFioy5Pnkhefq1f6MsRpWr5yQBLHxqpRI7QaqOrOhafu6467IiGck1O5J2cRGZqqgBghcBFuui69qf6sRC4p75KT9cRXaTPVMabjwHUY41IkEFXz0B3PWy4SRTuDacQg52raD7bG4XPyJxqhnsbbgBARJhFgUBNTYtmG8gxZjlPD3guPxBMASEJDFyr4k8yZyhmaoWFjwB8JUeajhftOqLXizw6J5UgHqZk4sKtpx38bmyEKBdFS4AATe--p2Axij7iz9_UxaRLBdUJqCtmoPbeAhH1jbxzKsJAQHgDTbMK2B2wjGEBGwKKgYghSFWRP4pVJpiUgJQVb37HAFr3yMOwHqRUxnGBq2TDEHdfwlyIq2id2pITnVf6y1JHAHugCvq9N2687aWmGidfna2cMqmXdvZIZcierDI37o2JAG1yY06iB6q1WANiZIN_4MCUHnSe9486t0UQlv8ikDTEAHARBYoASUZ12_vAQdDTcVrsXTn0WEM3i_IbWqnK3WtGgHNcciv4acZ8uXoP855QfuaMT4rkmJICvpoZ13Pq2SyCgAB5YAJPSQEBvZoSzE85AZpvVuhyN8-1TztL0c8A3rxmggBmsyU2cPnvd9moyPYK_VFGbuPL1vdSP7OtFqL3gqnoDmWoQZCEbUrw00mWHh1ByTo1VKunOj65UksfRSp5m51Fw==","staged_ledger_diff":{"diff":[{"completed_works":[],"commands":[{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","receiver_pk":"B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz","amount":"1000000001"}]},"signer":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","signature":"7mXR3Jbayxmy3mJzxsjWmwok8cTgihgfQx4MRdHfaLiuMP9sbX6NrQKHnqhjssyKwvKMFu6vMayJP4TdXHNxT9zF23PHdAbj"}],"status":["Applied"]},{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX","receiver_pk":"B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm","amount":"1000000001"}]},"signer":"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX","signature":"7mXFnep1vvRWPj4TUaFRteFFLiJ7w7rxuEtJG5HXA4cu6SS3x5zGxDi5jXzBGYWKFWsxGiSCsU18TJKnj4Vhz29oqEmCHgUB"}],"status":["Applied"]},{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93","receiver_pk":"B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2","amount":"1000000001"}]},"signer":"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93","signature":"7mXKsDGcanUme9Q4KyMfTGrwUCDhmhiMxmC7G4K16xnPtw9V2pFGKYXsMXgnWRNkV9NyzBXYB3zc5cLCgJgguDBRfzTUKJAk"}],"status":["Applied"]},{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","receiver_pk":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","amount":"1000000001"}]},"signer":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","signature":"7mXUknsYg3fVPqfGy8jpf1yGtssbWWUixx1kCMiws6Bu6XtyoAf9pDdckrzixZwRqvAqVBRqsPU1B6hEoy7LdfDbRpchN9MP"}],"status":["Applied"]},{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7","receiver_pk":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","amount":"1000000001"}]},"signer":"B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7","signature":"7mXWiwbVUUTcCSXdV1vGiojgqsvahiiexSHQn5wnjPCQB3R8oV9sL2iujN3TEdmhD7fm2CFKZkiEqerMHaFjZ71LdpjpM8t4"}],"status":["Applied"]},{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq","receiver_pk":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","amount":"1000000001"}]},"signer":"B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq","signature":"7mXWwc431Gi1WSLhq2JG9cAEv5PMxk28PnxjJweD9wMUTuS5WSJGAKYPkn7DviBeXDUHFLznYPBk2vnsQP8kdT3ig1e66EyK"}],"status":["Applied"]},{"data":["Signed_command",{"payload":{"common":{"fee":"0","fee_payer_pk":"B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA","nonce":"0","valid_until":"4294967295","memo":"E4QqiVG8rCzSPqdgMPUP59hA8yMWV6m8YSYGSYBAofr6mLp16UFnM"},"body":["Payment",{"source_pk":"B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA","receiver_pk":"B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA","amount":"1000000001"}]},"signer":"B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA","signature":"7mXRaCFusjosi9sf32S7QUWXKbdQYwwZJDM4T1Q27ipA8s44D3PRm8nBjybsJvtGHeiQXGAgr4QDV9fRnqfAQLx6u8G5odkn"}],"status":["Applied"]}],"coinbase":["One",null]},null]},"delta_transition_chain_proof":["jwR8gGQ88A4UuWvTFnhkmRNbVoR6NYPtyBoPbrZwnaAcUQMVJg9",[]],"accounts_accessed":[[12,{"public_key":"B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"1001000000001","nonce":"0","receipt_chain_hash":"2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm","delegate":"B62qqgyc58PdJYfAR4To1hejtAC4NZJatEbLGkvdsdFvwiumJxQTGQm","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[2,{"public_key":"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"998999999999","nonce":"1","receipt_chain_hash":"2n25fb2jeJ3ck3LTd5PZGEGpcfC5bMc1HDeuoXUAWq56eVUHv33k","delegate":"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[16,{"public_key":"B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"1001000000001","nonce":"0","receipt_chain_hash":"2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm","delegate":"B62qovrG8FZpjg9WTPDhtgz4gr5huZaUQPFTpNtk7RNfBokFpNXoHv2","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[1,{"public_key":"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"98999999999","nonce":"1","receipt_chain_hash":"2mzoUQPcBY5sgNbkam18ehvqKz8WhGnkj7wXCRf8ym3aqQ3CxVmb","delegate":"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[3,{"public_key":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"1001000000001","nonce":"1","receipt_chain_hash":"2mztHhx8kBhchUEjxxNzKNdunhKLEzEF4ShW6DTw3F4VgpuhEyQ6","delegate":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[18,{"public_key":"B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"999000001","nonce":"0","receipt_chain_hash":"2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm","delegate":"B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[6,{"public_key":"B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"1000000000000","nonce":"1","receipt_chain_hash":"2n1PHzcqYXVxVLuUVqG2wFCZJ2YLsJrvRrhErkL2cx6CyQbu6reF","delegate":"B62qpgjtMzVpodthL3kMfXAAzzv1kgGZRMEeLv592u4hSVQKCzTGLvA","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[5,{"public_key":"B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"998999999999","nonce":"1","receipt_chain_hash":"2n1oMrrZLTgbAP2xH44Go1zo7nDhaNPjgMYjbTHU4J6ekYAbv9Ec","delegate":"B62qr4GMdg4ZVk1Y6BXaDHxgFRtCsZm2sZiyn7PCmubTZnAi3iZDDxq","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[0,{"public_key":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"10000000000000000","nonce":"1","receipt_chain_hash":"2n1DjjLEYona8Mmfs8C8fUC44wPPnszBn5hZrU1AaL75nhDF3zwP","delegate":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[4,{"public_key":"B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"998999999999","nonce":"1","receipt_chain_hash":"2mzcYDmKPT4vxWBS7C6S6PdPE5GRfrn8vu6Ey4DyBaCpVXNcVPr2","delegate":"B62qqR5XfP9CoC5DALUJX2jBoY6aaoLrN46YpM2NQTSV14qgpoWibL7","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}],[8,{"public_key":"B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","token_permissions":["Not_owned",{"account_disabled":false}],"token_symbol":"","balance":"1040000000000","nonce":"0","receipt_chain_hash":"2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm","delegate":"B62qpPjYco6oESJyGjdFNjmBnwEyzsujJ785aMAzygzSF4X9g4g1uEo","voting_for":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x","timing":["Untimed"],"permissions":{"edit_state":["Signature"],"send":["Signature"],"receive":["None"],"set_delegate":["Signature"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Signature"],"edit_sequence_state":["Signature"],"set_token_symbol":["Signature"],"increment_nonce":["Signature"],"set_voting_for":["Signature"]},"zkapp":null,"zkapp_uri":""}]],"accounts_created":[[["B62qo5ry9RSXFvZz4XjBn6Xgo65TraA3sgRMv7eChLB6oqu9kiqHbpz","wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf"],"0.001"]],"tokens_used":[["wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",null]]}
|json}
