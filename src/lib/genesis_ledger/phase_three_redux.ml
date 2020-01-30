let vrf_winner_keypair =
  let conv (pk, sk) =
    ( Core_kernel.Binable.of_string
        (module Signature_lib.Public_key.Compressed.Stable.Latest)
        pk
    , Core_kernel.Binable.of_string
        (module Signature_lib.Private_key.Stable.Latest)
        sk )
  in
  conv
    ( "\001\001`\232/\r\250p\253\234f7^I\156\235'\243\001\027;V\249\192Y\158\198#\143:\2138D\211\202\022t\212}\205\208\193\174\253\153\192\192\215\186\217\199\218A\185\187\178\165~\241\198\224\149\184\152D\130m\b\128\166(\209\022yUK\r\243\223'\026o\164\170\150\255\2234\155B\227E\191vb\236]\000\000\001"
    , "`\222n\145/\225]\210\202\031\136\000\016\001\174%]. \
       2X\143GX,\137\209\157\177\201\190\133\006\135>C\015\227\187\\s\237\0169\236\215\030\151\173\236\018\134\006\194W\229\027\232\021Q\141\011\173/\209(\015$\226\244\254\194\154yT\213J\227\166\155'K\209\203\231\1662\221\239\217c\252\151\138\131\001\000"
    )

open Functor.Without_private

let of_b58 = Signature_lib.Public_key.Compressed.of_base58_check_exn

include Make (struct
  let accounts =
    [ {pk= fst vrf_winner_keypair; balance= 1000; delegate= None}
      (* imported from annotated_ledger.json by ember's automation *)
    ; { pk=
          of_b58
            "4vsRCVSvGyYnd3fRPVQLzUhCXMJ7biScER1qgPkmQLRBYnMjB51Jatn7ZqDPFbNwvFnkStaoXZxtVsRH1dSxLoB8DYx4pURBFQ6f9avMLR66xXZn2M3B5HV4nxFAzJtBrdwKsve1u9L43Q3E"
      ; balance= 6000
      ; delegate= None (* echo *) }
    ; { pk=
          of_b58
            "4vsRCVkqvArwrFyhj9UccVGTSJfoPyiKrF8XnvoaD5qDfDjraGHBFY4X3kJ321pvhKD5uPnPFADzFerrhKBC4TS566rnG8R9YQYNZMaDQpidGVP2uGGhhPJt38FGL5rdaP2W6BbKN8UTMh6h"
      ; balance= 6000000
      ; delegate= None (* faucet *) }
    ; { pk=
          of_b58
            "4vsRCVkhZM3WGFzNUmEzbn5DiM5iCv1pej788Ssx8SrGMq8QF2CLDYk9ZRU1SCV7utZ9gfU29oHwmK4636zSvA458mhLdViwva4CESDjwNBqcPara6EVC4rLK1Fdibrr51Q5vL5xr88rVCax"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVFo2Hu6EXWHCT5PoNideGkV2Lap9f3DUxGQRrZ4whvSad9MrRr3EFRE3XNtTM6FkEXHThS2xuxGfRDSviS4uN3uCDBbgVSHADCHNsJHUYLiw3sHNUJSsSAuBHcC9fcXbyscqEZ7s547")
          (* Greg *) }
    ; { pk=
          of_b58
            "4vsRCVFo2Hu6EXWHCT5PoNideGkV2Lap9f3DUxGQRrZ4whvSad9MrRr3EFRE3XNtTM6FkEXHThS2xuxGfRDSviS4uN3uCDBbgVSHADCHNsJHUYLiw3sHNUJSsSAuBHcC9fcXbyscqEZ7s547"
      ; balance= 1000
      ; delegate= None (* Greg *) }
    ; { pk=
          of_b58
            "4vsRCVmQAAGYU7wXwWrDm46zTVgM2qmR6HYWr43qWkYNw6LG4yVfdfEDsukxBBbkZixdKyBtLGkJmySxGx9yFUgBCBXmKvapudP2nJQ5WHy8UzLgMcnRhc7LAv1Yr1EkiTjmWuBCDAaprX1y"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVPJx5sX4HCBogeHMXXcqvYNQF3deRB79qapoN7NNKVxRQ8TvVADQrzrkxicTrdUQHhkWwRsUzJWwobEWLRn7zKjTqTgJKPBFyjFXy3dSAGjHhCm473keDcPyqqPFJJg4QnbMyTyKDry")
          (* tali *) }
    ; { pk=
          of_b58
            "4vsRCVPJx5sX4HCBogeHMXXcqvYNQF3deRB79qapoN7NNKVxRQ8TvVADQrzrkxicTrdUQHhkWwRsUzJWwobEWLRn7zKjTqTgJKPBFyjFXy3dSAGjHhCm473keDcPyqqPFJJg4QnbMyTyKDry"
      ; balance= 1000
      ; delegate= None (* tali *) }
    ; { pk=
          of_b58
            "4vsRCVuCte7ekdHdgZoP1ZzM4ChZqYeubNQVAHLHoZhW3pYwaZAwapFFCfqTxmRS9Q79sduyk8k8RkJYhvDXw2bGTi1V6ui5N65ewZ73HXMWH8LLWyvsKnNJqnRTwB8WnKHMixBJiZAzjntk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVnJ5FPRTSrbVMRZawwV7PNBxacvkUb8dUUdYAkPv8Upa1gUfUJbMPE9eTLwB3qJc6cqo9KtHk2igHFaDrzgdWxUrM9iKJwdBKae4PK1oc56PLwiYxrVDUHFqySWfFBALR9Pw312msYA")
          (* jkrauska *) }
    ; { pk=
          of_b58
            "4vsRCVnJ5FPRTSrbVMRZawwV7PNBxacvkUb8dUUdYAkPv8Upa1gUfUJbMPE9eTLwB3qJc6cqo9KtHk2igHFaDrzgdWxUrM9iKJwdBKae4PK1oc56PLwiYxrVDUHFqySWfFBALR9Pw312msYA"
      ; balance= 1000
      ; delegate= None (* jkrauska *) }
    ; { pk=
          of_b58
            "4vsRCVtkboR9vWcFLEV91aWL1h6gV8ahC92mWKNAvY6Yuay1rAoTYo1swLQ3pGPJr9vu98iRqwwNXzVmF8icXBhmNdwZu8TF8ik3RQm8zi5q72mFv7uvWSBJthqFwLQqa8YMJFK8T6GnKcLv"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVhVWwRHHpWhtskhbrJpRyY3DepjEPzxXodpXPKapSU9V8TfSQhy44eRXBGPoqB4MhZx11tv3SidUv1eyJRDEpaEqbUp2SoTHg7JquHyNjvwMF46JMEbBkRnzK3wQgxJjgXUctzELqcS")
          (* novy#4976 *) }
    ; { pk=
          of_b58
            "4vsRCVhVWwRHHpWhtskhbrJpRyY3DepjEPzxXodpXPKapSU9V8TfSQhy44eRXBGPoqB4MhZx11tv3SidUv1eyJRDEpaEqbUp2SoTHg7JquHyNjvwMF46JMEbBkRnzK3wQgxJjgXUctzELqcS"
      ; balance= 1000
      ; delegate= None (* novy#4976 *) }
    ; { pk=
          of_b58
            "4vsRCVmLww66BFgw4bP15suMpbcXaAAheBGjq9X5eoUAzDorcBDCh92ztsrPLmcKRiH9vBMmyXp47fMirRyZ7o8pDzn4hWcZZ3B9uMy2JeHPkFhc7NbuKM3mNKCdnRdVsrQxoWxzFFSsDfpQ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpZxM8pD4jkYfSomk6HEBVmq3ZT1iDVkf2kH6qg6NfvRhZvUEfcVUv7Z7VT4pkDXbBnuMYdCLuCB4JAuuYzp9PSF1g8jM5ekgd6ExnQSEmZyzE91NJfm5Whp9TS1k3LwBooc4pCpFdd")
          (* fullmoon#9069 *) }
    ; { pk=
          of_b58
            "4vsRCVpZxM8pD4jkYfSomk6HEBVmq3ZT1iDVkf2kH6qg6NfvRhZvUEfcVUv7Z7VT4pkDXbBnuMYdCLuCB4JAuuYzp9PSF1g8jM5ekgd6ExnQSEmZyzE91NJfm5Whp9TS1k3LwBooc4pCpFdd"
      ; balance= 1000
      ; delegate= None (* fullmoon#9069 *) }
    ; { pk=
          of_b58
            "4vsRCVmraxqSaqXD5mkmXZq4dBV5Nv6ehawudThAhSox8qSJW8VsVPmEeU3Wxza2B5ckN6z5YhTPwLUFGYiFzMSERvaJedZbDRVNLWPJRMPeM7GJEEh66amoLbdSb7FM4icikWp443nLZji9"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVM9y4Z9AgKzvtP4exn58e1j2UtBBRzkzna1AMU4TPMJBhFuAQQ63bXouvbAnuaeYYFbVWNNXSuKVr3XSsVyPZY7K1bWNvDyZj94mMqMVbkHB8qTWaW8uZxM2R5phUBzzMD7kHMj77zQ")
          (* pk#9983 *) }
    ; { pk=
          of_b58
            "4vsRCVM9y4Z9AgKzvtP4exn58e1j2UtBBRzkzna1AMU4TPMJBhFuAQQ63bXouvbAnuaeYYFbVWNNXSuKVr3XSsVyPZY7K1bWNvDyZj94mMqMVbkHB8qTWaW8uZxM2R5phUBzzMD7kHMj77zQ"
      ; balance= 1000
      ; delegate= None (* pk#9983 *) }
    ; { pk=
          of_b58
            "4vsRCVZFiBTLsmErsHDgSUimKzvskb9HHQtM8qTZ8FMggUHnENDr1GLpfrbns6dQaV2DJtpaxm6PFoJRfLBYgSpEiuBqp9n7CdTzPga2ToyEV7ivbWiTNRnrXpB5svXaXBpna4gwWjvdGFr3"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVwLWZAxAj7ueZeW3j8ddFTvu23oWFLZVdPbv8tSdqJ3h28jgWMF15jn368jqhBNAKE8xmrmjanjYL3Z65oEMo262A7beF7bin5yMDkCoGHpKcSdkdSrCXPoZ6A8xNVVeTR3b8YhrHZZ")
          (* Kunkomu *) }
    ; { pk=
          of_b58
            "4vsRCVwLWZAxAj7ueZeW3j8ddFTvu23oWFLZVdPbv8tSdqJ3h28jgWMF15jn368jqhBNAKE8xmrmjanjYL3Z65oEMo262A7beF7bin5yMDkCoGHpKcSdkdSrCXPoZ6A8xNVVeTR3b8YhrHZZ"
      ; balance= 1000
      ; delegate= None (* Kunkomu *) }
    ; { pk=
          of_b58
            "4vsRCVQUq1xTVrpWrk3VPrXLuZLoUP9Ro8RZNZAzwX3rZaL4WzQHx6NgYSTVG4tKmhLovTRZVHaawGXYvBAb8vb1ZRUuUCNriyX4ibpr25z3kVXXjby63UNcMPqVWW4KEvj4xvwNJZUeZkAz"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVuW9PadBMoEHXUqCnegbHCdQwdXzKqYqBpfSQQNVgeV1S8kN82H9QTfpcFsYTMcJbZNjuxY3fgoSA3yuQrL4ag7RbiXU2HMZUWUGrgpmWTtgNmV5DeWULUgsBVRFJXtM1qb1mg9Py75")
          (* shella#9701 *) }
    ; { pk=
          of_b58
            "4vsRCVuW9PadBMoEHXUqCnegbHCdQwdXzKqYqBpfSQQNVgeV1S8kN82H9QTfpcFsYTMcJbZNjuxY3fgoSA3yuQrL4ag7RbiXU2HMZUWUGrgpmWTtgNmV5DeWULUgsBVRFJXtM1qb1mg9Py75"
      ; balance= 1000
      ; delegate= None (* shella#9701 *) }
    ; { pk=
          of_b58
            "4vsRCVmJvYKAMPcvufDRXuGCB5Rmudzd6NG9ueJamxoDGKkPg4G1djUBCiJ5Xaw92ztbbf5Q7fdURp9K82PfhUUeoWXAHFnTfvjeDoQGjKPdwEJiM5GfQAKaKwAVAmfGbVWn23aEFqEj4ynt"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVoCHVRHhNJER9WDEn61eUB9BrJtZjW68C73LNuARBZQB8qdjLQR4b4XPwmwuEKtZRcfFmfdSTGRiQn2SgfjPrP6f7Z6bNvHLQ4EoVUUqmuiJD5nhQfRWr6Ahs8YdHioRzFyB65NGRi1")
          (* Adorid *) }
    ; { pk=
          of_b58
            "4vsRCVoCHVRHhNJER9WDEn61eUB9BrJtZjW68C73LNuARBZQB8qdjLQR4b4XPwmwuEKtZRcfFmfdSTGRiQn2SgfjPrP6f7Z6bNvHLQ4EoVUUqmuiJD5nhQfRWr6Ahs8YdHioRzFyB65NGRi1"
      ; balance= 1000
      ; delegate= None (* Adorid *) }
    ; { pk=
          of_b58
            "4vsRCVwB4XbXKD2arq9zhwydj6rQ4HZ5xu7QXT3bHD1UJTaaqMyojWLGX7GdVkkUQM8pzdhp6eoSZ14cwpuKdEBo9Y9vP1gqf8yeBLLxj9qTFksYWsRHN8V48sENY3UCoMtuhPCLVcLfVnCu"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVTv7CHy3ay3ZFvUdC4BWQuqUFVMKFaVqAFnqyGNv1deRBmA7jUkp7ZAHcSrDzgeUwjzRVKr4b2cqqyzfw2vF1zYarUEbWzmxiMthapTUQ8EXBkLGQ5B7bFmafjJ6UeJE5VaJbp5FB3e")
          (* Mikhail#7170 *) }
    ; { pk=
          of_b58
            "4vsRCVTv7CHy3ay3ZFvUdC4BWQuqUFVMKFaVqAFnqyGNv1deRBmA7jUkp7ZAHcSrDzgeUwjzRVKr4b2cqqyzfw2vF1zYarUEbWzmxiMthapTUQ8EXBkLGQ5B7bFmafjJ6UeJE5VaJbp5FB3e"
      ; balance= 1000
      ; delegate= None (* Mikhail#7170 *) }
    ; { pk=
          of_b58
            "4vsRCVwMYG5DfhVj3vd7p6HySNFwp5LaNxfffLg8F2zj9T5DjHf4tXhb4AbuiKGVrBnurVba2QuNW8AadUEdRCDHdSN2eaxGmsWJnh9ejgtRPCKJps22jmk9ZjgFJK6gzUuLSoUcegN94doc"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVgNVH79kF9sW2Exh6k11TzH3PeippBAPE8PcewT9aHDuhxYgvfBaW9ceMqr5Jsk9Ghn3czs7JMNTp1QbQk4Bko16wGNKBBgiQKTmikFmrLqm3UcWQuGvB4po4LyZMKGtFmjiDGKCfg3")
          (* niuniu | Bit Cat *) }
    ; { pk=
          of_b58
            "4vsRCVgNVH79kF9sW2Exh6k11TzH3PeippBAPE8PcewT9aHDuhxYgvfBaW9ceMqr5Jsk9Ghn3czs7JMNTp1QbQk4Bko16wGNKBBgiQKTmikFmrLqm3UcWQuGvB4po4LyZMKGtFmjiDGKCfg3"
      ; balance= 1000
      ; delegate= None (* niuniu | Bit Cat *) }
    ; { pk=
          of_b58
            "4vsRCVaLtWFsnV46sdSWB2DGGA4zK7Jagr4FhCDKyP4nH6pFVUpa8eqpZS3GQMafBQ4R4uPaGVyWvRnEVkYwdRe9X46XwGFcA4CTMsBH7LKzzvBq1qXoi9TpUyVo3fUgojLzaZvDpfPk6nmB"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVXGrqhWcZWea5YVVytq35RSUKxSJFRzaJWLB8rQKhAvsiYfMgw2jSrxdr724zZkvTMSgX9HBWk375hntM6V16SbgSVV3epDA8Bhft1CpFEL3xEG6kGJeF9GHjLAuCKRVozFGT5rbP2y")
          (* Viktor#0766 *) }
    ; { pk=
          of_b58
            "4vsRCVXGrqhWcZWea5YVVytq35RSUKxSJFRzaJWLB8rQKhAvsiYfMgw2jSrxdr724zZkvTMSgX9HBWk375hntM6V16SbgSVV3epDA8Bhft1CpFEL3xEG6kGJeF9GHjLAuCKRVozFGT5rbP2y"
      ; balance= 1000
      ; delegate= None (* Viktor#0766 *) }
    ; { pk=
          of_b58
            "4vsRCVv6wLApNFqzTxsZVxLwVfuXxRmQL91nCRZPT66EH2b9kKWt22vFCH4odtirxUF7esmeZxaHofaJ5CFpP6a7HA8M78desFDGwtPuK8niPVzTmVYqU1x2Mmy7voTZjr51BhKoxMuigwZ2"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVjHN6quKw69DY7NADqX3aNngUvvVWh1SjtXmD1ammSRRCTwGCtEU7wmH7r7Q8QZQJRnpqr3fVe7btaFGgbmuTeFxt57qi22ukkky6pwjSPv4WqUNVWphXUkj9WmaqUTBe3yycda1rfz")
          (* WilliamGuozi | Sparkpool#6724 *) }
    ; { pk=
          of_b58
            "4vsRCVjHN6quKw69DY7NADqX3aNngUvvVWh1SjtXmD1ammSRRCTwGCtEU7wmH7r7Q8QZQJRnpqr3fVe7btaFGgbmuTeFxt57qi22ukkky6pwjSPv4WqUNVWphXUkj9WmaqUTBe3yycda1rfz"
      ; balance= 1000
      ; delegate= None (* WilliamGuozi | Sparkpool#6724 *) }
    ; { pk=
          of_b58
            "4vsRCVd121xawDVBHUwafjzFixyNE1U11c7eKakFi3ALmL63Gi5LEnav4YHWBRZT7fBS2oq9qpXUNgd73nYSaoKdcWxQFQSUMUFUjVS6aouyXdqDV7VGxJqYqYsVryKbR4ggiid3RUkL97Gn"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVdTa8crwCtpXm13FYGVd3ioFgXHSNqQGKgcxY3sZy4jF1X3YuVMaeUH64FwpLWSZnavU1F54p4Eh9GDoFtCjMoLyFdUSz6wTCxv9Tc49gp1G9svf2d4ZUp42HVvjMs7fASRgeaxoPfp")
          (* Ilya | Genesis Lab #6248 *) }
    ; { pk=
          of_b58
            "4vsRCVdTa8crwCtpXm13FYGVd3ioFgXHSNqQGKgcxY3sZy4jF1X3YuVMaeUH64FwpLWSZnavU1F54p4Eh9GDoFtCjMoLyFdUSz6wTCxv9Tc49gp1G9svf2d4ZUp42HVvjMs7fASRgeaxoPfp"
      ; balance= 1000
      ; delegate= None (* Ilya | Genesis Lab #6248 *) }
    ; { pk=
          of_b58
            "4vsRCVJZWtRMN8dc67aHVMRn8oBD41ohWQEM2Vf8n3WU4p8WQQDPpNd6kBsTrZ2idrjUZTeDW9N3D62Af8NtxEG3Smee5h27ZFigsdsfQEqncRfcNooWcq8CzXCSk6LN5LmU6gNsAwWdWHjZ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVZ6nL4JoV6zKty9YH5KYLKF14UzfEt4C9FqaG369ewE77uQCY9ZYBWv2RmiDYFipmDxHzKpmHUvyk5vM9ugdumESMsT6dqoV7apHNfYc7RCazPPtPvuaDW2fana5r794u5xxgoivJxJ")
          (* Yfdfcu#2293 *) }
    ; { pk=
          of_b58
            "4vsRCVZ6nL4JoV6zKty9YH5KYLKF14UzfEt4C9FqaG369ewE77uQCY9ZYBWv2RmiDYFipmDxHzKpmHUvyk5vM9ugdumESMsT6dqoV7apHNfYc7RCazPPtPvuaDW2fana5r794u5xxgoivJxJ"
      ; balance= 1000
      ; delegate= None (* Yfdfcu#2293 *) }
    ; { pk=
          of_b58
            "4vsRCVhhafFiXdMdCdjdapNZ1paeHENn2zXZ6iQrLrGzCs5ureJxz16p9ZV7cmAAWJZVWt3Tn16QAbC6hHMnbwRQPBNc1fQ76XVSmUNUaUSqy5hpUfG2giFiJLUydm1BT8FVLJub3Daop93m"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVjnJcYxCvceC5hsUWyyjCWfWz99az9wH9EdYCMGeffc1bUqj6bKxeTW7XbWbBr6gymRMdD1xYY8Hmd3xbP9yjeb28kVttcf8uC9u9j57NqD7yyVwjfaSMG3CxnBsQsVdHy7GikdZWZB")
          (* windows | Nodeasy#4629 *) }
    ; { pk=
          of_b58
            "4vsRCVjnJcYxCvceC5hsUWyyjCWfWz99az9wH9EdYCMGeffc1bUqj6bKxeTW7XbWbBr6gymRMdD1xYY8Hmd3xbP9yjeb28kVttcf8uC9u9j57NqD7yyVwjfaSMG3CxnBsQsVdHy7GikdZWZB"
      ; balance= 1000
      ; delegate= None (* windows | Nodeasy#4629 *) }
    ; { pk=
          of_b58
            "4vsRCVdUX1qDycbdCGSAXmrgCkv4V4645j2rsNXdWWXUtPiLeVNaeroXKEzoRLmR7F1yMwZRUK6HSqKqC7Fx83TaaKpRpo3TSXbx8nnJYwuxXnzTGk9ox6F84sCx9mBNCNpEs8ksUqwAzB33"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVSE1Q7ikVwGM5VRPKRFV41gbYJNJ7eTomZ5cjUQFBwnubMFRsULkz27gsskRJWYQtyhyRDaY6m2zC3aRdEQdd58ggWjT98DTbCVEouFWWdcyDTMays9gc88u6uN17kzjkXiXQYdU8DY")
          (* tcrypt *) }
    ; { pk=
          of_b58
            "4vsRCVSE1Q7ikVwGM5VRPKRFV41gbYJNJ7eTomZ5cjUQFBwnubMFRsULkz27gsskRJWYQtyhyRDaY6m2zC3aRdEQdd58ggWjT98DTbCVEouFWWdcyDTMays9gc88u6uN17kzjkXiXQYdU8DY"
      ; balance= 1000
      ; delegate= None (* tcrypt *) }
    ; { pk=
          of_b58
            "4vsRCVW43U6L8eCfGkVNJHZd22uJ7WBXrVmAmpwKYsj8z8DRK92ay11145Todk2qQBinpbr77jJrXn1keQnSU8BwHakg3UExRDnzz2Cr3u2w5HiXGdNJJtCjFpjuXrvDVwTz8ap8o4ZF3XMk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVPrt8Aqekuq8m9xBPJdiNQwJcYFvt6pBsJ733K6JXpjyT4RYotgXYXLaToCTpB3hReawWxdTifN1bHC2un8BbpZP5AVuvPhq6Em9r2wXpoC4mYNArBCHoDCStWNmSC9Tj8ZYSGdJUGP")
          (* @Ender#0521 *) }
    ; { pk=
          of_b58
            "4vsRCVPrt8Aqekuq8m9xBPJdiNQwJcYFvt6pBsJ733K6JXpjyT4RYotgXYXLaToCTpB3hReawWxdTifN1bHC2un8BbpZP5AVuvPhq6Em9r2wXpoC4mYNArBCHoDCStWNmSC9Tj8ZYSGdJUGP"
      ; balance= 1000
      ; delegate= None (* @Ender#0521 *) }
    ; { pk=
          of_b58
            "4vsRCVNT47iA4EkkTbDqxtMErzRiJ4CfjWDRy7oj7WMaqQnxScSCvJgAcPaeq4JzKQNb9LpqPU7HoLNimHCNZ4sudfVNdj854gQk4LdEj4zTxtGCW1YX7r1QscV19Busym4RnEj28UXSVg18"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVRrHzSyZNT7WtjaLDyAWXpWPvi833dvNg3KVHMkD6yXTji5zjKZGLpwfa1L2Jn5KANpgwyf2HrTZtKaD1WWKqFEhgoesaZBAjSNU92wMiLUhcLLyMobUgkM2i4G4QgztMJnMeYAjqrP")
          (* OranG3 *) }
    ; { pk=
          of_b58
            "4vsRCVRrHzSyZNT7WtjaLDyAWXpWPvi833dvNg3KVHMkD6yXTji5zjKZGLpwfa1L2Jn5KANpgwyf2HrTZtKaD1WWKqFEhgoesaZBAjSNU92wMiLUhcLLyMobUgkM2i4G4QgztMJnMeYAjqrP"
      ; balance= 1000
      ; delegate= None (* OranG3 *) }
    ; { pk=
          of_b58
            "4vsRCVjmgTumSTRffUt5FmxUEk9uV7x3Czbxeuhz5DwsvqYsE51Kv2qYReJbABs6JMfCtgUpFgjVSzjxrQa56yqwgBSxVxaFTDLU8RdnA7g94fi7kKteaMwbPmawtWEWachwsf9aKz3uNprJ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVNGDW4zRBWSrkErBCwQwKR64am6TSjjFnfoByMt8yfxXHuzyyhwd9Erhbn43JTm6atsFBh51ReUeqGyoPyYNsMGFJAHSGyAMtSXhTc2Usd4GR1hiyKF8Cyep7K9sXj2cQDPn59f2B3L")
          (* Star.LI *) }
    ; { pk=
          of_b58
            "4vsRCVNGDW4zRBWSrkErBCwQwKR64am6TSjjFnfoByMt8yfxXHuzyyhwd9Erhbn43JTm6atsFBh51ReUeqGyoPyYNsMGFJAHSGyAMtSXhTc2Usd4GR1hiyKF8Cyep7K9sXj2cQDPn59f2B3L"
      ; balance= 1000
      ; delegate= None (* Star.LI *) }
    ; { pk=
          of_b58
            "4vsRCVUHWXBsjdP3YqaETAP2meXnz3FmPuVgGBeQgCK36vzubZEnY6U9RmDNBGk2PCUZUSLUdvt6xkwmCPGp5EVdJ6kNQ4aZKDuYhzCx9Tr5pM8QwoGxipLiBJBD4CXsF7CKSEFX2ZHp245v"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVNwcePTb7jmKbqPfHFuQPd9M98yHSkGbREHd1N3zAtZxCHQ3DfXJSf1buiqqkT6vyMPiJgwcTkfVeGyjAAhAjVVaD5RLyyySnAK36cczKJ5BCPb2CFVa9Xvue5LopMQ55XhxcTX4gLi")
          (* y3v63n | moonli.me#0177 *) }
    ; { pk=
          of_b58
            "4vsRCVNwcePTb7jmKbqPfHFuQPd9M98yHSkGbREHd1N3zAtZxCHQ3DfXJSf1buiqqkT6vyMPiJgwcTkfVeGyjAAhAjVVaD5RLyyySnAK36cczKJ5BCPb2CFVa9Xvue5LopMQ55XhxcTX4gLi"
      ; balance= 1000
      ; delegate= None (* y3v63n | moonli.me#0177 *) }
    ; { pk=
          of_b58
            "4vsRCVxmpF1XGfMHwLBYXjJuAR6hzq2ExaYQRxizDdKNxcxoGRHgcyhe7RJGT6dSSYn1TuwAumL37S9D1S6hfpw5z6zLREmBk1TacjEsc3B24j8sdGEmExwB1VaPfoXQ2pSD42Zo3UZsaSbB"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVReYRVDBVn3Xgyjdb6yPxaoMym4MVMNP4F623PM5sZddFYBkf8iNkYHn3mkKHsUqY8LRfNSGNh5GEyRDbwpmmzRTm8XjXaAxThQmeKcNaVitvoRq81scBM4ikuixt2g6mbCo3whQLFb")
          (* stevenhq#2903 *) }
    ; { pk=
          of_b58
            "4vsRCVReYRVDBVn3Xgyjdb6yPxaoMym4MVMNP4F623PM5sZddFYBkf8iNkYHn3mkKHsUqY8LRfNSGNh5GEyRDbwpmmzRTm8XjXaAxThQmeKcNaVitvoRq81scBM4ikuixt2g6mbCo3whQLFb"
      ; balance= 1000
      ; delegate= None (* stevenhq#2903 *) }
    ; { pk=
          of_b58
            "4vsRCViZKUb4MYLbYX6ZonfwgvFYdJKEpsvfMjTpGHVazzT38KTN4n9JQb8TLjdSF6KPfjpVcQLuQ1ep7v44iQF93saRLLHX3kcuLdR5m1ToPvHUm7qTRiZa9HASjK8gdD468jPwLmZZfXcu"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVoNbBe1JV7c6WNUPRoeAM7HENAd5KQCoDppFsKt6meoQx4kH5ijwVdLCak63LF9fkketJriVpSmQBSfPitDfr2SWqSBuW4Lvq8Woa6UoaYMdo7XzoJWr77jh9QtwtrGxb83pe7DWgqY")
          (* LatentHero#5466 *) }
    ; { pk=
          of_b58
            "4vsRCVoNbBe1JV7c6WNUPRoeAM7HENAd5KQCoDppFsKt6meoQx4kH5ijwVdLCak63LF9fkketJriVpSmQBSfPitDfr2SWqSBuW4Lvq8Woa6UoaYMdo7XzoJWr77jh9QtwtrGxb83pe7DWgqY"
      ; balance= 1000
      ; delegate= None (* LatentHero#5466 *) }
    ; { pk=
          of_b58
            "4vsRCVhiJZyCFfjHHhTuqHmGKtBo8yZ1wQvpyRMi8fmD23G7MUetb7Bn5iaY5NLuGWY5s8eit6GyxHYzPwkbYTfHBpv5NsPnZjBpMRQrhwcQ71F4k6KQWLxXKoEv1Mbb6ExEhiYmQSfruH9Y"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVUVmUtGZ9mbkHhPHA2zkQSxVbHU7vHYf1YrMAiAYa6UBhcyXJHYuXUucH9RUsyYCQEu5AveWnGpaHFSy9YRe1TgY3YbNEHNhnErt4bWdewEf2zre4LbmkeBo4JuQkNJDqJ8gcch1JqC")
          (* Alive29#9449 *) }
    ; { pk=
          of_b58
            "4vsRCVUVmUtGZ9mbkHhPHA2zkQSxVbHU7vHYf1YrMAiAYa6UBhcyXJHYuXUucH9RUsyYCQEu5AveWnGpaHFSy9YRe1TgY3YbNEHNhnErt4bWdewEf2zre4LbmkeBo4JuQkNJDqJ8gcch1JqC"
      ; balance= 1000
      ; delegate= None (* Alive29#9449 *) }
    ; { pk=
          of_b58
            "4vsRCVvFUkZfWEg8p8iTT8f6cQYB5LaJbq5qtYT2cvWTjbAfVD98KWiEtnME1irqhh2Y7E4dXuUAan9SaxStPG8pJZw2Jq4Gwwbb5vELcMWzvihSd9PKioxawSioyR3n524xmzq48cPe2g16"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVP2TTzXNQ29pDqnyLqk7FNuWktNCU3eBHNWRApxLQ39tcqkvyCuF9P1AGeAXQpKuKRWyL9K7aYxmDqdvK6PBUppb9gsbochMA7X7JWLXpUQ3SvEzTV9ATsBTCS1kD6JiCQ6TWy4sj8d")
          (* Anna1242 *) }
    ; { pk=
          of_b58
            "4vsRCVP2TTzXNQ29pDqnyLqk7FNuWktNCU3eBHNWRApxLQ39tcqkvyCuF9P1AGeAXQpKuKRWyL9K7aYxmDqdvK6PBUppb9gsbochMA7X7JWLXpUQ3SvEzTV9ATsBTCS1kD6JiCQ6TWy4sj8d"
      ; balance= 1000
      ; delegate= None (* Anna1242 *) }
    ; { pk=
          of_b58
            "4vsRCVgecZmceHrmeEW5t2koBusr7NiMhgG55ZhDjnshCMDgZnQ6QjovhwJruhiy2qmNHjBKY8gqmBQSUZBwZDhVSqt4fi8mtYgXvcEoFXJWMmTWmtXArepwPEVNV6tCGw4EJfpgXLgMD3Xh"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVcjJ2zTVNvF5zdzH3uUMnRyuYRL96dMVTXE9zwaybzg7XB15fi4jxhoUPFuAszXY7W4vtZJJCr7dNVNPpEQoxyxveyaCsmVjSMKRFSuffW1yV2NBP2Xuj7JmWMu1X3N4aJTPkhHmTkD")
          (* Kitfrag#0272 *) }
    ; { pk=
          of_b58
            "4vsRCVcjJ2zTVNvF5zdzH3uUMnRyuYRL96dMVTXE9zwaybzg7XB15fi4jxhoUPFuAszXY7W4vtZJJCr7dNVNPpEQoxyxveyaCsmVjSMKRFSuffW1yV2NBP2Xuj7JmWMu1X3N4aJTPkhHmTkD"
      ; balance= 1000
      ; delegate= None (* Kitfrag#0272 *) }
    ; { pk=
          of_b58
            "4vsRCVqjUqhp1Z3CFJ3c4baPhqNwL5dH4qSrc8r5vArqgzcUiWME7b76Qs96YUZ14LYLWqeyDK2yeWukqiY3ZmDLXHEb8TC7seZQVeBsdtDAtHUs6WSC1wg8w1KvNWpoy51XriGXZNqaf8kk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVSAaVKYVDK5WA39BK7hPL7z1DxjPyEq2yArcD5BKuCowk1wgBVX44CADgRzLsVHf1qUwmWPkQw5C2ATotNFXLZBw9i6wtyUT8ufEs61CYN4iFSqcR1BUDzSahFhhCNNfkoDjeJTeCmN")
          (* slayer_hellraiser#5093 *) }
    ; { pk=
          of_b58
            "4vsRCVSAaVKYVDK5WA39BK7hPL7z1DxjPyEq2yArcD5BKuCowk1wgBVX44CADgRzLsVHf1qUwmWPkQw5C2ATotNFXLZBw9i6wtyUT8ufEs61CYN4iFSqcR1BUDzSahFhhCNNfkoDjeJTeCmN"
      ; balance= 1000
      ; delegate= None (* slayer_hellraiser#5093 *) }
    ; { pk=
          of_b58
            "4vsRCVxzwf3GKXCuYn9tuM76ZCK74ZxHN7bKqctThtgswK9ryzKSq9B7oCYLAHwRppp6dxfxyb8Vt3L6wpuVYpBecpJxaMeMTcfhDEYu5xBrzgkqK7o4hsRNMfTx3P9FCFUx4H3mnss9KHiZ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVkoFa6tYwahNAFYGXq7jHSwXPoKs3N9BgHQUTykskdku7SiWHMMV2LQaVKJh8U7Zp4P7Q2QmnxCrm4EGzUUGrQwrM36S4LrJswz7ytgeNrcrgcn93uEXhcat6CbT5JdBPkhnKvGGcNc")
          (* Prague *) }
    ; { pk=
          of_b58
            "4vsRCVkoFa6tYwahNAFYGXq7jHSwXPoKs3N9BgHQUTykskdku7SiWHMMV2LQaVKJh8U7Zp4P7Q2QmnxCrm4EGzUUGrQwrM36S4LrJswz7ytgeNrcrgcn93uEXhcat6CbT5JdBPkhnKvGGcNc"
      ; balance= 1000
      ; delegate= None (* Prague *) }
    ; { pk=
          of_b58
            "4vsRCVp4RNSNKAywaEVRfgr7NsdFrgoRreC2doU1VQtt8YBKCz4KTuj33fTDLmnBZ5t5pX1jcwMH4tHUByFncPnc9244zNQnErjNpm87t7AwGvbjHRB1yhG96houmyKCMGTFcb3A9rfmrQFK"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVqFBQKUTWV2wakn6gcAMeJRtgz8FcMyK1DuQ4BCazvJ9aByZxVMAFNePUaKpKaXBJt9FRcoUqx7MvPV5v6xagkPfQwHUTwfojE47M9GJ8vMiEgXrmU1HA9rxrkwJtL3BvJuVfhtwzzM")
          (* Ionut S. | Chainode Capital#8971 *) }
    ; { pk=
          of_b58
            "4vsRCVqFBQKUTWV2wakn6gcAMeJRtgz8FcMyK1DuQ4BCazvJ9aByZxVMAFNePUaKpKaXBJt9FRcoUqx7MvPV5v6xagkPfQwHUTwfojE47M9GJ8vMiEgXrmU1HA9rxrkwJtL3BvJuVfhtwzzM"
      ; balance= 1000
      ; delegate= None (* Ionut S. | Chainode Capital#8971 *) }
    ; { pk=
          of_b58
            "4vsRCVsSVaRpaHveNhzfRaqJbRsebfSucsLf3FaTYqo1abczdq5heGXojbhALFt8npJR9DM145u9oSnGPsexKLrHPr2UDZtq1hwr6fGEhtP83n9SNPqKZFmNN2D8HX3Xmey2pxrPmhGZ6DUk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVxL7t27LsPU54SYwfWBjA8UrgdRH2QVyXQZCZJdWMXr5kFJ4yTDbfaXjqphVPKUXWZvzougae6YX6icbngH2DLUvfAFvkp8NzWPoW2GMqZCJ3aZKEZDjB5tG9bnZmM7AuhZN6L6tDZZ")
          (* nikmit *) }
    ; { pk=
          of_b58
            "4vsRCVxL7t27LsPU54SYwfWBjA8UrgdRH2QVyXQZCZJdWMXr5kFJ4yTDbfaXjqphVPKUXWZvzougae6YX6icbngH2DLUvfAFvkp8NzWPoW2GMqZCJ3aZKEZDjB5tG9bnZmM7AuhZN6L6tDZZ"
      ; balance= 1000
      ; delegate= None (* nikmit *) }
    ; { pk=
          of_b58
            "4vsRCVbjv1UtrnMqHDgJb8fQJKAZziSTqTqKUWT8MS8F6ZvUrXecPQgdrp98w2V5q58TvJ95bWv7fWp2otj4t7P3cwV4nXUdxXcy25Qc3kSx9Hzxjs5iPAfBQi7xyzCRw3oqxiqTXM7EE8XE"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVzELDndGtuCeRP1XcEdNS5SkFQBr9jZnUMBj3ii5b1wP2coVA85i34fSvgjq2KDVqKUPe66dg3zZG5JCBLRicKCW8J9eVXPdmx4QUBk7FFYCxP2bGRRwkHYo2udXaUkW6VdWdANVRQi")
          (* Guio#1996 *) }
    ; { pk=
          of_b58
            "4vsRCVzELDndGtuCeRP1XcEdNS5SkFQBr9jZnUMBj3ii5b1wP2coVA85i34fSvgjq2KDVqKUPe66dg3zZG5JCBLRicKCW8J9eVXPdmx4QUBk7FFYCxP2bGRRwkHYo2udXaUkW6VdWdANVRQi"
      ; balance= 1000
      ; delegate= None (* Guio#1996 *) }
    ; { pk=
          of_b58
            "4vsRCVyzybPVAiTntNFqQ772JPDj3otmV6cpEdEDhTJBx1ZPeTHz3USXP2wJNWXJwqWLwec77UcfnyuozayhDVVpPntvozq7rR35S8WUAvdRpoBJ8kPtxejotRG3WfgCoTJtNUzmGDhW9LaF"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVW9FYAdxR2Gmr2mCyWkhc5Ao15szNfnZC4ankMziThSH4i8EBHcFHvE4F7m1geULXRMkMZUahkEyh3ZLk5S9zBZD2UMDDkLXX7HzEiou6WGYynUqiqMfm6KAoe3WSuoDhVLtY5CiQFg")
          (* OliGarr *) }
    ; { pk=
          of_b58
            "4vsRCVW9FYAdxR2Gmr2mCyWkhc5Ao15szNfnZC4ankMziThSH4i8EBHcFHvE4F7m1geULXRMkMZUahkEyh3ZLk5S9zBZD2UMDDkLXX7HzEiou6WGYynUqiqMfm6KAoe3WSuoDhVLtY5CiQFg"
      ; balance= 1000
      ; delegate= None (* OliGarr *) }
    ; { pk=
          of_b58
            "4vsRCVGh85xS6iiWTQfKqYBQt9Bkf76RKFqTQfHkwJ6h5jG4CzMyxQMyTXfSUAsfULvK4vVQBPpkyxCiA6kUquXXfhAktUfP5gFNpJYS13bgdqME1zsDTdLSv7GAeVfSb3pw3qS9cF92obPA"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVjGzktkfxtuWd3Rxg38dfopH46xuDsFz6bxPCTeB5UPAy7TTfLtSYkUP4apD4x5KMrgq5YT5tVVdU4txELkupezUccj3Fi7fdZW23VBArU6WjqWYXbFGVx5BGW5RT49gJM6b67xX6qN")
          (* TommyWesley#5661 *) }
    ; { pk=
          of_b58
            "4vsRCVjGzktkfxtuWd3Rxg38dfopH46xuDsFz6bxPCTeB5UPAy7TTfLtSYkUP4apD4x5KMrgq5YT5tVVdU4txELkupezUccj3Fi7fdZW23VBArU6WjqWYXbFGVx5BGW5RT49gJM6b67xX6qN"
      ; balance= 1000
      ; delegate= None (* TommyWesley#5661 *) }
    ; { pk=
          of_b58
            "4vsRCVqYCa8bw6fBgDGFibHz8zkFuHaHnR7RN3Dd3aU1mArKbUdXQSwgZZsiajmzVZrCdj365WFWkRnhK8RQfUziec7acuXWA831189cp26qao7bzBgE159Pc3xKNj6paZPbqsMuDCw5iYru"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVtogdNX9biiEsASXSf5PT9imP9HiKZN1bJrEjgDFC6J4j5i1vzqm8o94rDRo1X4tsavgq7JSUr67DYx2xyDi3qzcxFkTFuHGU33Ex24TsjpiPcv3GWxjkWJgKnKZhZp5UmJYVtedXpN")
          (* vision2003 *) }
    ; { pk=
          of_b58
            "4vsRCVtogdNX9biiEsASXSf5PT9imP9HiKZN1bJrEjgDFC6J4j5i1vzqm8o94rDRo1X4tsavgq7JSUr67DYx2xyDi3qzcxFkTFuHGU33Ex24TsjpiPcv3GWxjkWJgKnKZhZp5UmJYVtedXpN"
      ; balance= 1000
      ; delegate= None (* vision2003 *) }
    ; { pk=
          of_b58
            "4vsRCVfDAHfDMD6UtHizn3KrNp48YbAdAtc6seL6HYWpesyWLrwkqxbQQcAG4Nv4uaWSFa5dHcM4avWYvqegEQuybRfmwVKkpy4zWUB9ZewmZk7QHBBSUparQm8ZyuXCQawHnmjW4mTsBTsb"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVkERcWks2VCNhsv3AzjZ194ivB4J7L4kdxe66JtcwcGWT4XJCuFfESoEETQGR942mYgDYGvSt8raFZcgyL9NLUyWSmpuwvUSRvtPaDMMSar4PXH794xnYiEKLfBicdu7KscRFTkPBFq")
          (* SimonHugo#7540 *) }
    ; { pk=
          of_b58
            "4vsRCVkERcWks2VCNhsv3AzjZ194ivB4J7L4kdxe66JtcwcGWT4XJCuFfESoEETQGR942mYgDYGvSt8raFZcgyL9NLUyWSmpuwvUSRvtPaDMMSar4PXH794xnYiEKLfBicdu7KscRFTkPBFq"
      ; balance= 1000
      ; delegate= None (* SimonHugo#7540 *) }
    ; { pk=
          of_b58
            "4vsRCVWY5QG7a7aUEfcNQZEpftm5mc4odDYv9VMRaKUb1JhFxaitgtYTUpbNm6s33BK7oP8Za2WKDiGwBsLv5q8Pciyq4EGDAvez1oaJRnNXPHUqAj7aStTyk92UBbz41X2Pn9JwM9ktTSb5"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVKmG7QD9aeSNTmbtCGpcfYBGgaZMUAYaJZberL7QaR9stBb3XQj2WR2E2qg2FYVZWhxqsqbUwf5KxQZ1unx8gGfvkQK1nWdjJQpzbdN3pmcpg3CDPkFfWXpvQenm589VXaE1JKfnyyF")
          (* JanLiamNilsson#7070 *) }
    ; { pk=
          of_b58
            "4vsRCVKmG7QD9aeSNTmbtCGpcfYBGgaZMUAYaJZberL7QaR9stBb3XQj2WR2E2qg2FYVZWhxqsqbUwf5KxQZ1unx8gGfvkQK1nWdjJQpzbdN3pmcpg3CDPkFfWXpvQenm589VXaE1JKfnyyF"
      ; balance= 1000
      ; delegate= None (* JanLiamNilsson#7070 *) }
    ; { pk=
          of_b58
            "4vsRCVLMK7WsBADLyeaqKDTsX8xcxyUxqE5DqtdJU2XQAgHd2WmE89nMpb9pdbBpp67rrcXGgpE8jk3VFkzYrEdpN9r9k6Tx9kDg2eJ7VTtxoN4FFphUvMgZ8tPL4tEG3mnsjCLkLs7FrQWa"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVnePSEjR5Fu9Sr6xPh7LjMJE933YWd8Jza7qyzrxzyqhpo2RHZTCuYwWnuEDsRtg69TWgcsPctHUgJAjRJ7WcBxq1SMWvREKJ2BQmCePBdcJhW5XSDqxYY4cGxXTczHexTMNdxWU4jp")
          (* FredrikMalmqvist#9370 *) }
    ; { pk=
          of_b58
            "4vsRCVnePSEjR5Fu9Sr6xPh7LjMJE933YWd8Jza7qyzrxzyqhpo2RHZTCuYwWnuEDsRtg69TWgcsPctHUgJAjRJ7WcBxq1SMWvREKJ2BQmCePBdcJhW5XSDqxYY4cGxXTczHexTMNdxWU4jp"
      ; balance= 1000
      ; delegate= None (* FredrikMalmqvist#9370 *) }
    ; { pk=
          of_b58
            "4vsRCVFcWoZppCySA67ZH7bYaP33iWTTWNZosmdhqsx888MU56o3dJZzohdcsd9M4Dm88DCuhhmApKKQo3AxFW5Ti7XDHdsDeoFw7BpS9MGR3RiimxCCS5wdQrMKA92Q2z7U9UsUaUPSjZ2i"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpkDQTagrGBGk3BRLd3Z6tyid4gXKAG8yo6RJabWYzXu47Pfy5zPz3akxzXuRMCk2vn2PTAWBSchVFbMpWnVptog3Uq3zCjizD25Rn8iWK3bFX8CKoLfpJUM7bXcraTxDGK9qohELuK")
          (* aynelis#8284 *) }
    ; { pk=
          of_b58
            "4vsRCVpkDQTagrGBGk3BRLd3Z6tyid4gXKAG8yo6RJabWYzXu47Pfy5zPz3akxzXuRMCk2vn2PTAWBSchVFbMpWnVptog3Uq3zCjizD25Rn8iWK3bFX8CKoLfpJUM7bXcraTxDGK9qohELuK"
      ; balance= 1000
      ; delegate= None (* aynelis#8284 *) }
    ; { pk=
          of_b58
            "4vsRCVjJbFPoD6EGY2yCrPPRtgWTX8sUuTy5JdmViaUD1eHMN2QAVih4xiTDznJcDpkjPzXyYtMj91j8e3mfkQT888n5y1bfxrFFJqijKnAKRFyWMdMhaSSJ8vHvoYewsrSY7gRYYFnNSGod"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVhjCFY6Ekhy9C8bjm7s88G2sHqiWddF88byCBV9Eeh2H57frfQ28LoUaxNp72mbDjySZtfxLB1oM7w8iMHFPzHymTi3ZnhF5agtEVF7gPv2GBu48mHXiHm4KjPaVefjKtXHYjHsr7eY")
          (* Ilhan | Staker Space#9767 *) }
    ; { pk=
          of_b58
            "4vsRCVhjCFY6Ekhy9C8bjm7s88G2sHqiWddF88byCBV9Eeh2H57frfQ28LoUaxNp72mbDjySZtfxLB1oM7w8iMHFPzHymTi3ZnhF5agtEVF7gPv2GBu48mHXiHm4KjPaVefjKtXHYjHsr7eY"
      ; balance= 1000
      ; delegate= None (* Ilhan | Staker Space#9767 *) }
    ; { pk=
          of_b58
            "4vsRCVhRZmeUum1GANvRr2YQJd3oGaApJyy2SL3ibsddorLoxdubZNofQ9SVPAzXon5pXP1kLwrmH3yFjiYZurm5Jg8GVuzvHkQo6XfaQbg6Vt5ef1XJKsfmjDUrMs5TdMArRWRZV8V78nLn"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVo3tpYbJo1WB7zzZjJtjbzphaDE2i4aw6YEkL2kY5W6XQhSsnmYZnRnvt3Qjk23GUswVXEew8KYGiEMqy7FPYmsscwQ9Rm8irEpFzJjKQ6xW9my2oVKpRfZPn5TmszcvnR8G1k5wyd2")
          (* Dmitry D#9033 *) }
    ; { pk=
          of_b58
            "4vsRCVo3tpYbJo1WB7zzZjJtjbzphaDE2i4aw6YEkL2kY5W6XQhSsnmYZnRnvt3Qjk23GUswVXEew8KYGiEMqy7FPYmsscwQ9Rm8irEpFzJjKQ6xW9my2oVKpRfZPn5TmszcvnR8G1k5wyd2"
      ; balance= 1000
      ; delegate= None (* Dmitry D#9033 *) }
    ; { pk=
          of_b58
            "4vsRCVJwnenPUXK1ZRhqPgK7aRtJEsVJ3pAFuefzjHbhriAQX5UoG7b3j7wKmD5nBwUD5r6dsuY9F864AjmyhwMUdtLz84U4iPCovQHi2XjXAs8u3MhvpyPRVXbcvehqAYxKaCv6G3soGe4P"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVk4VbnRYMoxcDUPqSQnCx6q9rH7j1ZVhSZkPi9vbgVZEpVSfwBZ5bEFVXHTHg994Qd7bPb33qcs3vbfb9L4rzK5GQzhmh5vYNdbH3zdWHj1kmVWmDtoryer6dM56DQHFyvwA7pQey77")
          (* wxc *) }
    ; { pk=
          of_b58
            "4vsRCVk4VbnRYMoxcDUPqSQnCx6q9rH7j1ZVhSZkPi9vbgVZEpVSfwBZ5bEFVXHTHg994Qd7bPb33qcs3vbfb9L4rzK5GQzhmh5vYNdbH3zdWHj1kmVWmDtoryer6dM56DQHFyvwA7pQey77"
      ; balance= 1000
      ; delegate= None (* wxc *) }
    ; { pk=
          of_b58
            "4vsRCVnyedWEZCizCE3tQRYVYS2peqVa769X2GJd9kBgRLxnd9FGtNzwNg3BpV1gFmBhHTw554PjVhTE6bCpjPUML26ZAoNDk2Cxzp1N383rV5jP6eA5AzmQG1UtJKuZq3FB5VywENNwX6hc"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVRq3V9CjkLm53jJimnioUBFhZy4Jtya6ebJd7L6k94hrErGFFYFj5WDGb6A1xVm2ro1HRK8BAfYmhvnecmRPnS4gPGJ8uAJhDTtX4LTVuDL7UDxQMMEbzTFro8BX593xiMWyBdMBiiX")
          (* @nakashu *) }
    ; { pk=
          of_b58
            "4vsRCVRq3V9CjkLm53jJimnioUBFhZy4Jtya6ebJd7L6k94hrErGFFYFj5WDGb6A1xVm2ro1HRK8BAfYmhvnecmRPnS4gPGJ8uAJhDTtX4LTVuDL7UDxQMMEbzTFro8BX593xiMWyBdMBiiX"
      ; balance= 1000
      ; delegate= None (* @nakashu *) }
    ; { pk=
          of_b58
            "4vsRCVNcamJdP9XSFzwiyrLUEYFgMwdSAzJdnHcGu7vz8YaFx25FiVFkqBbVzSd3SWMwbyQDQKkxrvs2pXCne3uekApezixbfiEdSE59o2tKpRL2dA9mrAWnxJQxCQngsYFDZ1iB6fkasqcu"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmwym4g2JS5niLKR6a5wUQmvMuGSXqDqn1UWmFuYNNJnbbmRuND4RTraxYAZNia3yTahGdPvv7pqDFMMp7DqqRs3ke9PEja1iBMG4fnC13ZVZaf9Gn51RfMKEBcr5Eaox3ma3zqLErA")
          (* huglester#0730 *) }
    ; { pk=
          of_b58
            "4vsRCVmwym4g2JS5niLKR6a5wUQmvMuGSXqDqn1UWmFuYNNJnbbmRuND4RTraxYAZNia3yTahGdPvv7pqDFMMp7DqqRs3ke9PEja1iBMG4fnC13ZVZaf9Gn51RfMKEBcr5Eaox3ma3zqLErA"
      ; balance= 1000
      ; delegate= None (* huglester#0730 *) }
    ; { pk=
          of_b58
            "4vsRCVtPfgqYsCKkqNYdV73CwvVVqSEuermUQNtNWtFXS83XhRbrHcRrV9T4BJ1ppTq1GtfyBPprUyqwc6XYVRf9EzkuDcyDqhfvHcNWXX6uYUT3A3EH52ceua7J5Hc67C7Zkh9n3YN1WeF4"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVH6p4fajJPyafXSCyhkawgvaZ3TMhvtR7WwdPyJ3yGnFNNRYgizXRbskn5bZXAR6BEmZMunS5NXeUsDBy3kZuQ7MEF9x5EMDCMpeyLPY9cmBGbfdjhWD88W8ThbR5SqUh8sagJdVDQa")
          (* Stjärtmes#1496 *) }
    ; { pk=
          of_b58
            "4vsRCVH6p4fajJPyafXSCyhkawgvaZ3TMhvtR7WwdPyJ3yGnFNNRYgizXRbskn5bZXAR6BEmZMunS5NXeUsDBy3kZuQ7MEF9x5EMDCMpeyLPY9cmBGbfdjhWD88W8ThbR5SqUh8sagJdVDQa"
      ; balance= 1000
      ; delegate= None (* Stjärtmes#1496 *) }
    ; { pk=
          of_b58
            "4vsRCVLLdNLFXPVBxb1K4qLAo6khDASB197WZh2VkJHtYggtZ9z3h8SoFh8FF6WVjJSSHXrFYyJtsR5tY5ygqh9M4ARfTaUTMUW9MJPTt1vKchvzArE2WZ3QDoGQyhQzdWxsUCVczdusu7g2"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVdooypm6rQ2eKNqrRv15GC8qNYTECD2BozVqmetxrk5kiPeeSwy1CRDR6rmoXukdPrzSRiC84yQDnimyGL6E1Dci32D3ovyniJ77DFEgW2hmYzjKWUj5Df1ftAAp2qaR9VPLr7J2ody")
          (* Ilinca#5351 *) }
    ; { pk=
          of_b58
            "4vsRCVdooypm6rQ2eKNqrRv15GC8qNYTECD2BozVqmetxrk5kiPeeSwy1CRDR6rmoXukdPrzSRiC84yQDnimyGL6E1Dci32D3ovyniJ77DFEgW2hmYzjKWUj5Df1ftAAp2qaR9VPLr7J2ody"
      ; balance= 1000
      ; delegate= None (* Ilinca#5351 *) }
    ; { pk=
          of_b58
            "4vsRCVY6fhwyfs8hvV5NywWnGzqB3vdCmJN2omfxLkLKkCydxUEBEVCQEZB9w45R2jmSR6bd1NAn3KxT9131KSRyrZ3EAKKRoBLf8E8qeadN5Nb1cY4v3imZSboF5MiLLrC4ELHKKjSnfinP"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVf63APy9AyMQLx5BCf3mLUj3y5ma7CH93VhVbfBz7V1FCYTmfuSpMmyJUqqKvDmGyCrr7ne5PGtPLcWwZWtqQhMUk71N54yunUDxeabH1vGdE948woch2cSVoCyihY6wM7rD9ERvN8q")
          (* Bison Paul *) }
    ; { pk=
          of_b58
            "4vsRCVf63APy9AyMQLx5BCf3mLUj3y5ma7CH93VhVbfBz7V1FCYTmfuSpMmyJUqqKvDmGyCrr7ne5PGtPLcWwZWtqQhMUk71N54yunUDxeabH1vGdE948woch2cSVoCyihY6wM7rD9ERvN8q"
      ; balance= 1000
      ; delegate= None (* Bison Paul *) }
    ; { pk=
          of_b58
            "4vsRCVoMPXRM5CBZQMgS68YaGaVJ4c4qCrLj5NbjAj62WpiX5J1Tmr2Mc5M7r6GJi81JF9h65jovu8EMVBwxJesDFCMQoZbTNkZBCjxen3rZdsr4yswsU294f2QmZXv5RK6siP7bgkCourzM"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVfxFs66PDTfRoTPWQaTz2m6fvScLjfxXPNzhS4eqphFE8AMBdziqA7nRuazKZR4DaEitLVsGeC8B6WmubAj7tQZe8bRuyD8yC9SxkcD1zKpqagZ2fB9G5Go5CbyetkaGuD9Ry64qQ1X")
          (* Hanswurst (333) *) }
    ; { pk=
          of_b58
            "4vsRCVfxFs66PDTfRoTPWQaTz2m6fvScLjfxXPNzhS4eqphFE8AMBdziqA7nRuazKZR4DaEitLVsGeC8B6WmubAj7tQZe8bRuyD8yC9SxkcD1zKpqagZ2fB9G5Go5CbyetkaGuD9Ry64qQ1X"
      ; balance= 1000
      ; delegate= None (* Hanswurst (333) *) }
    ; { pk=
          of_b58
            "4vsRCVmkPAyJ6QdKKma92yqKkBsbV2jbd4E3fVzQCvTr2weXBSeftMzo7QXH11zhjPzofmyMhNyhDQDbfRuz46JQapw5w3HUoHzqWVuggoRe1geoU9vuzz74ZuZuFDPZ99jb7y9FZsgWRBqd"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVojjvE2u3c5LgVtTyvcF1Rmrx69EcQ8xx19jAgJ53uZidh1U1odhaarkPyjKvHKqLKF2oz9C7tiCdz8bbbYPNE8KNq6sLr7L9fauAjirzdGe3HhgVkQzLKGPVALKePSMYeG7bYKxf78")
          (* oliver#9118 *) }
    ; { pk=
          of_b58
            "4vsRCVojjvE2u3c5LgVtTyvcF1Rmrx69EcQ8xx19jAgJ53uZidh1U1odhaarkPyjKvHKqLKF2oz9C7tiCdz8bbbYPNE8KNq6sLr7L9fauAjirzdGe3HhgVkQzLKGPVALKePSMYeG7bYKxf78"
      ; balance= 1000
      ; delegate= None (* oliver#9118 *) }
    ; { pk=
          of_b58
            "4vsRCVkiJxiessUzGspKpFqy2GFwVheDv9qSAzHD3Lua4YoFaZi3Q1MiGkZsbxudyGoAMMsnesYQYgfvcBLPJ8ymykpUQvidLWTDnKVaF546RyxwcRkww4exXWJkJReWtJLaBPSHKd9ccooU"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVwuYk3XS6nmbn3vYbRckK5uTMpQNSS8dFpgBNfatQT1HWivctkHsKFjCxqMw8w3cj3bqrJteVRqsvDRxaRdWtcHDXeJUpLBTkSqefipVXmJJYjmmUJ6y9fQxt3tuFgjKkeeJMJgQw4A")
          (* boscro#0630 *) }
    ; { pk=
          of_b58
            "4vsRCVwuYk3XS6nmbn3vYbRckK5uTMpQNSS8dFpgBNfatQT1HWivctkHsKFjCxqMw8w3cj3bqrJteVRqsvDRxaRdWtcHDXeJUpLBTkSqefipVXmJJYjmmUJ6y9fQxt3tuFgjKkeeJMJgQw4A"
      ; balance= 1000
      ; delegate= None (* boscro#0630 *) }
    ; { pk=
          of_b58
            "4vsRCVkSicE6ypB2gFkWm923whVfRGa8mh5Cw9SBpgk92QSTWgQRuKAdRGgFbtrnmA3paCzcLgitqm9VoQTckwphUtWAxDLyLpEjNw7t1YngrU2xBAhHUifxv8PgrFjbYKM5eHasDafHVYWZ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVJhmBojW4PbXgWUhn1hSNX4rypY4NUYh4aSuwfuVXJdy6WKbCoz9nuAN3RJVDAn3BvN9b8VdnvC4G6tL9JU7xof5fQjSCAD2F5RtPKC3KQfpYJk72NU4m1XMZhDK3PdFmHcyfFUpXDV")
          (* Igor888 *) }
    ; { pk=
          of_b58
            "4vsRCVJhmBojW4PbXgWUhn1hSNX4rypY4NUYh4aSuwfuVXJdy6WKbCoz9nuAN3RJVDAn3BvN9b8VdnvC4G6tL9JU7xof5fQjSCAD2F5RtPKC3KQfpYJk72NU4m1XMZhDK3PdFmHcyfFUpXDV"
      ; balance= 1000
      ; delegate= None (* Igor888 *) }
    ; { pk=
          of_b58
            "4vsRCVrHqF9rrCfY2t8X9g1iQvaqE9dUMzopxJvAcBCeAcGrXU8tbYxNRmXbPpEWRxjpxmtiNttR3cZgduf9Wm1YX4oMmE5HJResPcexd2hkDvES3q4SdTzPAWyPPs5x9UZDQpZSaHMc4mNd"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVcN5cfrxu75m5jTJphoGbKai6MQfNi6tcC9YWdsVq9UWVGakhG19wH79up1ix9e3XyTBL8o5GEevwKKMQAdATv7HeQ8JKYWTDMwBt36DyAGE4nad6wwe4DB4XisiygzDftzKWqUbfGG")
          (* garethtdavies#4963 *) }
    ; { pk=
          of_b58
            "4vsRCVcN5cfrxu75m5jTJphoGbKai6MQfNi6tcC9YWdsVq9UWVGakhG19wH79up1ix9e3XyTBL8o5GEevwKKMQAdATv7HeQ8JKYWTDMwBt36DyAGE4nad6wwe4DB4XisiygzDftzKWqUbfGG"
      ; balance= 1000
      ; delegate= None (* garethtdavies#4963 *) }
    ; { pk=
          of_b58
            "4vsRCVvKyDjzeawwunSycyNATcK6a4wkWX3B79pqSe48ZMbbZSKGVatAVmeixVRsQNR3iWzMGjsTw5GbDfSCj6TSWEEPPszf7EKJsuQNxRF2LeVECqPTQ94JB11pZQ3dNAAu7n6py5ncm2tH"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVqjTY7R5V5jsT6CbD6B4q9WYH8v9ocNrxTjKp4dfsji8iNWCKAKsnyfZigGhuHHXTomugHgpZD6dsrsnL1b5AbvqRZa57bxRLFq1UCL8xYrhHiHmyK2vdKKVTAznTVtkX8ATPD3Z93C")
          (* TJang | OneNode *) }
    ; { pk=
          of_b58
            "4vsRCVqjTY7R5V5jsT6CbD6B4q9WYH8v9ocNrxTjKp4dfsji8iNWCKAKsnyfZigGhuHHXTomugHgpZD6dsrsnL1b5AbvqRZa57bxRLFq1UCL8xYrhHiHmyK2vdKKVTAznTVtkX8ATPD3Z93C"
      ; balance= 1000
      ; delegate= None (* TJang | OneNode *) }
    ; { pk=
          of_b58
            "4vsRCVw9UFFfziCtRdNLYG1ZGY6VtSFK6FAgo8qZju5vVCUrhhPfrXEZixN1yhms811CTGkuUBzo68PE5wGZVEMi2PKowwa9izHWuJG3539Tn2HwQnin4VDuVHZMBDGksW25CHWof7mrnNS9"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVf3q6Ahsa7xmWMnW5YmE7XJqQ7nngnZE9yox4vQiGbugqLXxd3KLMW1nh6L8T9kLR9umcfQGofrU987gKc2fZssG3bqtkBnR9RJ3FTbhN5qMbeAXhtjvhX3WdmTxJREFSVJ5c2BA3cW")
          (* gunray#6321 *) }
    ; { pk=
          of_b58
            "4vsRCVf3q6Ahsa7xmWMnW5YmE7XJqQ7nngnZE9yox4vQiGbugqLXxd3KLMW1nh6L8T9kLR9umcfQGofrU987gKc2fZssG3bqtkBnR9RJ3FTbhN5qMbeAXhtjvhX3WdmTxJREFSVJ5c2BA3cW"
      ; balance= 1000
      ; delegate= None (* gunray#6321 *) }
    ; { pk=
          of_b58
            "4vsRCVpnzY4rqj4XL9MvC47WzDMBYxxbvp6Q4edafkVTSm2q2LH7eUrkb8hdBZJePk32NR3Cu4ni4dsibmRyNXfQzm59pE8hXtTu6jw847R6cbjYTzE3USXTXA3BXMtcmHHoiKwQp66fWTRf"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVrqnhaNiwJ1AAGgecdCeo9DXTYraTrgQrqsccUNkzSDMWPPUYrhFQKZAvqZBGr7AH8ePmoyuX5eYJ8RFs9rQhoR3pPwjTwde9iSJNyijC9ufAMc33Aors6yA1Q11w3nKu4G382FzMkw")
          (* GS *) }
    ; { pk=
          of_b58
            "4vsRCVrqnhaNiwJ1AAGgecdCeo9DXTYraTrgQrqsccUNkzSDMWPPUYrhFQKZAvqZBGr7AH8ePmoyuX5eYJ8RFs9rQhoR3pPwjTwde9iSJNyijC9ufAMc33Aors6yA1Q11w3nKu4G382FzMkw"
      ; balance= 1000
      ; delegate= None (* GS *) }
    ; { pk=
          of_b58
            "4vsRCVaSP4gQyuRL8CrpWVPMHTF3h5BKMwVvw2o1vivjWd9inpeJHNzAHpgif9wLLyK6NdNYR5yM1G4akiR4UTjhTkrL3LyFnCd3QjZb4APUJYpnwsyPnY789mpjzzpoqbwN3uvzmPT3kR8w"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVFthKDMZqsREKX4n5NsMUxXAsVxvjNb9t9qiekyf53xXFDxTuyx6Bay6TCAYJdTjuzivnh6m1mvZA48yBMddG1s36HsPTDDFbTEQoWAshtP8xixeopFegbc3GV7yeZtHio1uGy9ohsX")
          (* argonau7 *) }
    ; { pk=
          of_b58
            "4vsRCVFthKDMZqsREKX4n5NsMUxXAsVxvjNb9t9qiekyf53xXFDxTuyx6Bay6TCAYJdTjuzivnh6m1mvZA48yBMddG1s36HsPTDDFbTEQoWAshtP8xixeopFegbc3GV7yeZtHio1uGy9ohsX"
      ; balance= 1000
      ; delegate= None (* argonau7 *) }
    ; { pk=
          of_b58
            "4vsRCVHuB4TsVGm6yvUqFTQzpufHTM8K8WCbDLBJGNx3ZGr61jzuqQj7U9y2kiyyqgd753SXFEXTB2bDkJ4VgYiMS9M7heMr12G4DtbLGmZzsYEuLjg8NDH9VZjdZVe4VCoMBih5xV1CQwXG"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVyRfTWyzB6rLWEa1wBrWMQ9EVd4LGupCXCjpFLY2v1eTWy4ThU6XBf7Ex4UaB24JzthFaxHagHLA5NVgRJJE7iSMV9Uwo3m4NMzVzCsZuFZeBWZRxVubB6sQCZD69to5hLtYLpS5w3h")
          (* alexDcrypto#0005 *) }
    ; { pk=
          of_b58
            "4vsRCVyRfTWyzB6rLWEa1wBrWMQ9EVd4LGupCXCjpFLY2v1eTWy4ThU6XBf7Ex4UaB24JzthFaxHagHLA5NVgRJJE7iSMV9Uwo3m4NMzVzCsZuFZeBWZRxVubB6sQCZD69to5hLtYLpS5w3h"
      ; balance= 1000
      ; delegate= None (* alexDcrypto#0005 *) }
    ; { pk=
          of_b58
            "4vsRCVSoKsrfyXZRucdh9dvvuhKNWu1tYE9VMJgbHGQZYYFz5yKh4c1SoyQBKqGjXkMUPhGmyefkgnYTisfztMruqW5i5WbTN4et6Czhj5eUkNdRYvf7wt5FGi2wnnw8thmPAuX2UQe2RV5D"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVbALo2jKAJCMe9nYNieqwX1J4nAdQY1ygmax4mUUEYihCf1xf6qoyzrNk4k9zgCMKCmmHpPDfzzq3MjNxYgSwv3jSWQ1U4tCnY7eEzQe4HvfAQZE4DpUEtxPoem5nu7yEopVFseQ86e")
          (* Thanos *) }
    ; { pk=
          of_b58
            "4vsRCVbALo2jKAJCMe9nYNieqwX1J4nAdQY1ygmax4mUUEYihCf1xf6qoyzrNk4k9zgCMKCmmHpPDfzzq3MjNxYgSwv3jSWQ1U4tCnY7eEzQe4HvfAQZE4DpUEtxPoem5nu7yEopVFseQ86e"
      ; balance= 1000
      ; delegate= None (* Thanos *) }
    ; { pk=
          of_b58
            "4vsRCVSst6CfjhjkBLfbgo7u39r1rVz21o4rPXLRt7fkxNbTiLc1TnsEuM7SXSXJzD4VLG86qF2vZW2nNFSyGXRa2DDjfZtqUmkK8cVv3XqLjv7yEhDpAEWyrk1X9iwfQBFfBrdBN2DhQsMH"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpe8sMvSoA5XScYtUgip44Wj7XPzPyMiscz5eC49uoXMavP9Wdc9hmZBhBSZ7bQLv7Nw8A9DfCahSPTpzJwGP5YqHApyXHvM688GxXtX47bt8E4a2RthTUChVbscARmXq6y3RTVxKbz")
          (* Lars#0517 *) }
    ; { pk=
          of_b58
            "4vsRCVpe8sMvSoA5XScYtUgip44Wj7XPzPyMiscz5eC49uoXMavP9Wdc9hmZBhBSZ7bQLv7Nw8A9DfCahSPTpzJwGP5YqHApyXHvM688GxXtX47bt8E4a2RthTUChVbscARmXq6y3RTVxKbz"
      ; balance= 1000
      ; delegate= None (* Lars#0517 *) }
    ; { pk=
          of_b58
            "4vsRCVHyLH96pLkXaBTxNZKUyb2g6txDWfPYWXV15iUHKNm4yQn7N7SyXYLWQhj3UxnDyyttJPHae8kQLdeoAWgzYmLj9uMJszUj5YpbdbK2riEtdbMZCQ9odKmQwn1Uh5r9Sn7oen3aV1ZV"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVgW3K7DvevEoAsPAAhhRfGiPLGh8GBQYmQje9qztbzrPN4RrUP4gJwU5w6YimTdkRv6cExVrHPqBBD8o55XCmZ5x9a7jL6brcRFQGyC4LQYe3YUYXEau39PYqWuvesxU32Vkh4Nhgb1")
          (* Donkey *) }
    ; { pk=
          of_b58
            "4vsRCVgW3K7DvevEoAsPAAhhRfGiPLGh8GBQYmQje9qztbzrPN4RrUP4gJwU5w6YimTdkRv6cExVrHPqBBD8o55XCmZ5x9a7jL6brcRFQGyC4LQYe3YUYXEau39PYqWuvesxU32Vkh4Nhgb1"
      ; balance= 1000
      ; delegate= None (* Donkey *) }
    ; { pk=
          of_b58
            "4vsRCVKTrgdgGzS4xDcudNnwQu2EY6EEiN329qenvmFveTXdGT8rgzRGVYidbc4n8PtApSWnHi5BK6yyEkLkSxbJF2jwtoPNEHvkGXeLoYedfLz4FvCDMhpbF4NEKnx27Rjx1GmcE9GETSBF"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVtAde9DuccMwUhyXgx2xXixmTLE8tZyajPjEJUiNwgn5WVkC5SRbWXKY65J4Ezn9HciS216bn2eLyQnMP2RfZPboi6dJ55ZWCTmQXXh3Hko7DDtCgiYhoWBCLyTeDU83uJnAuk3VrTZ")
          (* qi#7767 *) }
    ; { pk=
          of_b58
            "4vsRCVtAde9DuccMwUhyXgx2xXixmTLE8tZyajPjEJUiNwgn5WVkC5SRbWXKY65J4Ezn9HciS216bn2eLyQnMP2RfZPboi6dJ55ZWCTmQXXh3Hko7DDtCgiYhoWBCLyTeDU83uJnAuk3VrTZ"
      ; balance= 1000
      ; delegate= None (* qi#7767 *) }
    ; { pk=
          of_b58
            "4vsRCViHE5Uxa6SVrMjWgin9D1xNZeJLtYwEawQPNdRvsCKTTR23MNmsmL3spEHVZVrT9yLHFtwgSq3wZ2WsKnZHUCcTAPXJYjHWbyoEvumLq3B5WaexUcjJsf9SwE9h5DwtryycHtmwjAT5"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVUqVBnN53FDpWBXgQX1BDDPeY7oFN77F2LxqAZQguToCrcj13jQKanV4LM8eahXxkLDtqNqwqJwxC5sYUqUUvf2dDhHPVf11xyMqrHfwgQBJgSY5v1zC9q7FiN15V38MmRcQMUpKk15")
          (* thomaswo#0033 *) }
    ; { pk=
          of_b58
            "4vsRCVUqVBnN53FDpWBXgQX1BDDPeY7oFN77F2LxqAZQguToCrcj13jQKanV4LM8eahXxkLDtqNqwqJwxC5sYUqUUvf2dDhHPVf11xyMqrHfwgQBJgSY5v1zC9q7FiN15V38MmRcQMUpKk15"
      ; balance= 1000
      ; delegate= None (* thomaswo#0033 *) }
    ; { pk=
          of_b58
            "4vsRCVtFiFwEoGFrUK76LLNcRdX5ePuRkMjM9eNm3q3jcfTymy6SknhYxjvsM1geX2aUwruJELQ7dsaiXq3VtTXCadwNLdPsX4UYRXZ81WbPPGtbmHzx8ck4md2MzNGFH56LKq1GPVovb8or"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVzBeSxp3iBQ1C3ahHyKjKVbPd93JLSAsqtRtmjB9Xhn29NBdnzT4o6Hb3iNwaFECrh18YsxhAkqMY8nZQrN8jRX5LfbB9h4p5csrRe8xza4VWToXnFaHtGx6gB9FKAr1eKebSiPyH5c")
          (* kuka643 *) }
    ; { pk=
          of_b58
            "4vsRCVzBeSxp3iBQ1C3ahHyKjKVbPd93JLSAsqtRtmjB9Xhn29NBdnzT4o6Hb3iNwaFECrh18YsxhAkqMY8nZQrN8jRX5LfbB9h4p5csrRe8xza4VWToXnFaHtGx6gB9FKAr1eKebSiPyH5c"
      ; balance= 1000
      ; delegate= None (* kuka643 *) }
    ; { pk=
          of_b58
            "4vsRCViTkcusCMsBghW1P4AX2hZc964wGUbRxwST1mVFMhTJ261qctjPLAkmoqmhoFPxpPCrWPC74g5beR9jrsBg7CC4qRektd3GTVa9HFT9TGBYPmPF5bwsKyLTn3o8t5gxjbZVmTf2pSk2"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVLScf1LoYkZK2VdYKgnG5LpKrobogjRs72iez3m1tgCyjmN7f4j8kvLg9Nci3WLoJZ3kciUmLMVYLnWi7oLbxKJvYFbq99dzeeyVrLUrgw2N8j3eXtaoCFcSfD3NmMgryuHDUF9cVpm")
          (* Olga#8100 *) }
    ; { pk=
          of_b58
            "4vsRCVLScf1LoYkZK2VdYKgnG5LpKrobogjRs72iez3m1tgCyjmN7f4j8kvLg9Nci3WLoJZ3kciUmLMVYLnWi7oLbxKJvYFbq99dzeeyVrLUrgw2N8j3eXtaoCFcSfD3NmMgryuHDUF9cVpm"
      ; balance= 1000
      ; delegate= None (* Olga#8100 *) }
    ; { pk=
          of_b58
            "4vsRCVMyFk9TwbJXrfaq8nwTSqpE1jhjecfTnhN14eBeD1GjxUYy2DrPB7mnYT24y8A7D4zTBrAoZJongHRDH4LDRz82ibSCR5H3fE8AU1cQYEB179Mx1GtqTERSMUw3u3B2dbNJmVLjcW54"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVN6sHsC8SSZmqZJKjwPmiCeqBX244ZeAdz9z9vyNpT7EirWR6Kv4iCB4ir7D5sYSoW7RVqzZ18Fm8Fqcvr2dWghhh1hKyZeHxx97Q3GM5X9KtHPp15WPF6TSSmyaa6JEg2ACroFNy4F")
          (* RussellGalt#6326 *) }
    ; { pk=
          of_b58
            "4vsRCVN6sHsC8SSZmqZJKjwPmiCeqBX244ZeAdz9z9vyNpT7EirWR6Kv4iCB4ir7D5sYSoW7RVqzZ18Fm8Fqcvr2dWghhh1hKyZeHxx97Q3GM5X9KtHPp15WPF6TSSmyaa6JEg2ACroFNy4F"
      ; balance= 1000
      ; delegate= None (* RussellGalt#6326 *) }
    ; { pk=
          of_b58
            "4vsRCVTFjcG4im8BvhQjNc1nmT8ZXbg2rJUnNvnXzxs9iHTG4n4SznHpxr64ukpG3ajSmyJsy6MetaoUuH62u9R9Lj2UxDWbsdTV49Jn56Tm23YiDfSbKC8qt6WxGYTfPUk6PveB9DSBL712"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVHEu5M8Q2Us31wzQZ5rqpkNNe5GTM4De3SpwGUpxDYu7nSM3LSWMSVJ7HxLorNb2CQTjgnzbhjniYcz2nEjLvUNZLm8gCtq69o42bhWmEW87xJdYfWJPBSxtuhrFdYVUsdhE7TQqdm2")
          (* fible1 *) }
    ; { pk=
          of_b58
            "4vsRCVHEu5M8Q2Us31wzQZ5rqpkNNe5GTM4De3SpwGUpxDYu7nSM3LSWMSVJ7HxLorNb2CQTjgnzbhjniYcz2nEjLvUNZLm8gCtq69o42bhWmEW87xJdYfWJPBSxtuhrFdYVUsdhE7TQqdm2"
      ; balance= 1000
      ; delegate= None (* fible1 *) }
    ; { pk=
          of_b58
            "4vsRCVWxWYhhmZAWzT3cfccaQ19Ga8VTGSNw7AfJTCR5RhQfMrTgFunX9K63fWJ4VpBcfv6htUPUPJZy34aFG32vDCAhafYgpyFa9FBJ8UK9zsCx2tEFwW5nL92gUNucwWCqtzBBAALj2Hx8"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVSXDQaEyApPh2kfrHK9oVAwUWcNBJk2JSHdfqZssUJiQSziGwGBuNebbsXKnVm8umNeziKJJeAXzfYGGhkcKQ8juTgarXRykXhuvxwNmS2Xeckq7zSQ37FdFXoSLGp45zMiS9koJEgi")
          (* banteg#5000 *) }
    ; { pk=
          of_b58
            "4vsRCVSXDQaEyApPh2kfrHK9oVAwUWcNBJk2JSHdfqZssUJiQSziGwGBuNebbsXKnVm8umNeziKJJeAXzfYGGhkcKQ8juTgarXRykXhuvxwNmS2Xeckq7zSQ37FdFXoSLGp45zMiS9koJEgi"
      ; balance= 1000
      ; delegate= None (* banteg#5000 *) }
    ; { pk=
          of_b58
            "4vsRCVKoW9PMgFVXYPMd6fMr5ThoprMkTpGp8Bi73ocJYRHJzUkARo8qz96G3JUyy5ehPLLLgUhjew9ecfiC66cwV2KdWwSLe6KeD8YMXKvtjWzuoHx1423Ki9vkD3GHe2L4fYHU93uwZMEQ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVQeT7J3CAGibBSKkWAVorSPir7KwJBSquwnWArs2EZbvkCKkEhtwmjpJDcnNsgNPnkUMPKwuNyNxii1P4hWbSmRU8irjM3z7XE2MtemrvEu9wweycFnyt2m441jqyycrv6cMqaN8zX7")
          (* CyberFoxky *) }
    ; { pk=
          of_b58
            "4vsRCVQeT7J3CAGibBSKkWAVorSPir7KwJBSquwnWArs2EZbvkCKkEhtwmjpJDcnNsgNPnkUMPKwuNyNxii1P4hWbSmRU8irjM3z7XE2MtemrvEu9wweycFnyt2m441jqyycrv6cMqaN8zX7"
      ; balance= 1000
      ; delegate= None (* CyberFoxky *) }
    ; { pk=
          of_b58
            "4vsRCVtXZYA4nbr7z33rvz461k6Sw7aXM1vTTA3BTmdvXyTwN6vE9fjGYJe8ebuV5AzAtc4UVLSv5pmyskEPe7W3hnFUszCdhPjAFbwdyRAtynJ5TZQffYJG6ms7H2DzHw13Fo5KWhK9MXAr"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVbp3WYQwJ7EmJMjYjnrLc6E5Td1EwJ8BEKm1wUPvEsUCaNC4xRQyiUSH2unCXrdbMoGZg6tDv86Bez4QN4B6J8AjbE9pmrds8NYswDbnZfQpsYyPLuVrdobv9gYPFTL2UUH8znsT3Za")
          (* aseem#1124 *) }
    ; { pk=
          of_b58
            "4vsRCVbp3WYQwJ7EmJMjYjnrLc6E5Td1EwJ8BEKm1wUPvEsUCaNC4xRQyiUSH2unCXrdbMoGZg6tDv86Bez4QN4B6J8AjbE9pmrds8NYswDbnZfQpsYyPLuVrdobv9gYPFTL2UUH8znsT3Za"
      ; balance= 1000
      ; delegate= None (* aseem#1124 *) }
    ; { pk=
          of_b58
            "4vsRCVdHZEeAJCZPvtJcvj6VVdqbosHM57zW4njVFcH4c3uKXeFavCFbdoyFn3u2FV3ThSkjJtCBJo3o1oa52ckBRHPdpXbpZyZG4RM8XJxJdgnbeKhvoWKfKZDAtMcMYaj1Qhv8oq8p8pMs"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVG4jsfQHMuudVkKVz3ftSQzNSBJLZexKYkyfXsyG8LsCgdJWVW1xjyPXfpeyCEaJhxCbBvkmJkzPAZHaJ3y6eJTD5yMhgvFyVADALCuxfnJqemKsn36ny7wnTiayxx2fsx8HzySdj77")
          (* stakesystems *) }
    ; { pk=
          of_b58
            "4vsRCVG4jsfQHMuudVkKVz3ftSQzNSBJLZexKYkyfXsyG8LsCgdJWVW1xjyPXfpeyCEaJhxCbBvkmJkzPAZHaJ3y6eJTD5yMhgvFyVADALCuxfnJqemKsn36ny7wnTiayxx2fsx8HzySdj77"
      ; balance= 1000
      ; delegate= None (* stakesystems *) }
    ; { pk=
          of_b58
            "4vsRCVTNJFdeqwBMjnZrv5rZq2XXuLXioW5CGcJwHA6rC1ooVXTZRm6fTQDuhsp1up3JL4Xx7EnAj6jxtRDuCpLNE8rnGgpsizJfKVZ9hEEGpTuifaFKd3uvRRn8cfTLU5gbM64bJDQ6VdjP"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVGTnboULa9RRSvhXYEwKed9zGgR8rjE6ag6zFQtrhy2LhXtm7X6yzhMksFovCNTBmzCCzwcGLNLas7tf2vYjiasefyyodoK3uaf9S3VszhqgJhZTLQRpQqbDscySeRLjTrVi4hzYKYH")
          (* nturl *) }
    ; { pk=
          of_b58
            "4vsRCVGTnboULa9RRSvhXYEwKed9zGgR8rjE6ag6zFQtrhy2LhXtm7X6yzhMksFovCNTBmzCCzwcGLNLas7tf2vYjiasefyyodoK3uaf9S3VszhqgJhZTLQRpQqbDscySeRLjTrVi4hzYKYH"
      ; balance= 1000
      ; delegate= None (* nturl *) }
    ; { pk=
          of_b58
            "4vsRCVuVFXTGFrQtzoBcdi2aq7BxxWsWxZ66xnZahV14AbLV7Q2dXWQMvHxApgK6cigg5JRwrdUFmx9MyK3wSHC4wNS7cZirRCZH8xN4J5MnpRsrAYQx1XhQpQrwB8EFo48MHuxaWMb7PPEi"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVNazpevFz1WuoyLUSpHvtQDsUgvqZnMV61Y95xDNVRyHzvnDC1z8YZ3kqHa2A2LyjbRjMYgHrwQxpJJkM8Zrk7TApLnJKFpVAHXVBAYtX7DPKyzBhw6rDh2tNXjUs9TjwkjhptKXUwy")
          (* Arke#2635 *) }
    ; { pk=
          of_b58
            "4vsRCVNazpevFz1WuoyLUSpHvtQDsUgvqZnMV61Y95xDNVRyHzvnDC1z8YZ3kqHa2A2LyjbRjMYgHrwQxpJJkM8Zrk7TApLnJKFpVAHXVBAYtX7DPKyzBhw6rDh2tNXjUs9TjwkjhptKXUwy"
      ; balance= 1000
      ; delegate= None (* Arke#2635 *) }
    ; { pk=
          of_b58
            "4vsRCVhBwqMoSkEmTL3YsGeJ4B2Q6JdHCmDkdu14W3hDg1gng3K7bQ3gkHRfTmeRaXwPA45PztzAJeaykv6FmdmpTZtRYZXnuDVPQM4F1WKnaReBvGoeRjqaTifvFf4kxVubCgxHqhwz92oU"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVXacrc1i1fPADHR9rkyHAzHbjUF4XA1bnJESDpYrNbsWCGHXTMnuTzVwZetvZJqVa4BBPcmePkSzKyGodD43UVzgfeyza7aNQusybqJwF99rZ6J9NZ6T8S4GNRKShfaaSpbiwyyxxSo")
          (* fmarcoz *) }
    ; { pk=
          of_b58
            "4vsRCVXacrc1i1fPADHR9rkyHAzHbjUF4XA1bnJESDpYrNbsWCGHXTMnuTzVwZetvZJqVa4BBPcmePkSzKyGodD43UVzgfeyza7aNQusybqJwF99rZ6J9NZ6T8S4GNRKShfaaSpbiwyyxxSo"
      ; balance= 1000
      ; delegate= None (* fmarcoz *) }
    ; { pk=
          of_b58
            "4vsRCVcn7wNAEL8azwAR17dayCjtQdLEqcfd1nAtcsUEc6ZtDP7Ju2cri9pWUkTLjXamSFzRRwKnoNeFbbEqjF8PWxrmhRvn9ca6c63B88uUtq6PUUx1PDyAZscXn49btuGDdnAR7CngHCzB"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVRZTV7BxyP3FKg8jP1dwoqeoMZSbmhwAnRt7bnNCUhBVPz9GZdnA6Ue6cAUzwdCMSPPjVFbru5XfaXRY6WHJcBuLUxjfeknHVUWXZnUDZQggevdvZqSkASZFqJziX5FCFNtzzwh4X9Y")
          (* Pierozi#6400 *) }
    ; { pk=
          of_b58
            "4vsRCVRZTV7BxyP3FKg8jP1dwoqeoMZSbmhwAnRt7bnNCUhBVPz9GZdnA6Ue6cAUzwdCMSPPjVFbru5XfaXRY6WHJcBuLUxjfeknHVUWXZnUDZQggevdvZqSkASZFqJziX5FCFNtzzwh4X9Y"
      ; balance= 1000
      ; delegate= None (* Pierozi#6400 *) }
    ; { pk=
          of_b58
            "4vsRCVcKL9wBvZKzmTaKSwkRBDzuJPibH4SU8HY5LfMV8kqccbPmk1zv3iD4E13qisSUuVi2kDajPHxxP3c2zRgYoGe7XSpktN6KZ2phZQMuuUcSsfjaoavcCgWMeQXnc66CBkVSwrshaijv"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVv7buMXzXCsFodGsisdKwgxoSE2X2xaHxr9NYns3WKEsonpVftSEDT1AGA1SaShRbphBwrye5zE5a4akDwfw7bgxsi6mdjgKnuxysQRmsjd1FGipNwyyCEZtGBsXeGdxahURrPPcFWQ")
          (* Bi23#6675 *) }
    ; { pk=
          of_b58
            "4vsRCVv7buMXzXCsFodGsisdKwgxoSE2X2xaHxr9NYns3WKEsonpVftSEDT1AGA1SaShRbphBwrye5zE5a4akDwfw7bgxsi6mdjgKnuxysQRmsjd1FGipNwyyCEZtGBsXeGdxahURrPPcFWQ"
      ; balance= 1000
      ; delegate= None (* Bi23#6675 *) }
    ; { pk=
          of_b58
            "4vsRCVmB5afeLKJtT9dsfb8ZQycFDH3LN9CjncYjQWQovHMMCU2yXh2kdAMEo9m2rXB5h9Pk1VjxP1HiaVzQrd9MNtnznDL7eJKvgSouiAo7zQiXcBTjiHpPsvBJULMweC8wEz82GGwv5Qq4"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVUZ97cfAQpvjBDU6xTZ245LwSfSYvmxdpfU9fhtsVMsReUw3kn5EYTeNfSQ73PvfHZZexK3ihb8qqRoRNJhQHrno2HGcnsHn7ESdjVnn6kQ1E25kUvt64YSG4AtigMuLhcovh6Lb67Z")
          (* Hyung-Kyu (Hqueue) | dsrv labs#1907 *) }
    ; { pk=
          of_b58
            "4vsRCVUZ97cfAQpvjBDU6xTZ245LwSfSYvmxdpfU9fhtsVMsReUw3kn5EYTeNfSQ73PvfHZZexK3ihb8qqRoRNJhQHrno2HGcnsHn7ESdjVnn6kQ1E25kUvt64YSG4AtigMuLhcovh6Lb67Z"
      ; balance= 1000
      ; delegate= None (* Hyung-Kyu (Hqueue) | dsrv labs#1907 *) }
    ; { pk=
          of_b58
            "4vsRCVxzuVpY5JSHq9X8gz4bg6W9LuiZJHfYsT9S1hq1JPBzEcpwG6iwJ9tzs5qYnHoPt3mcdimZ7ShpCbmpKZ214q77hdLDEyA1LLwuVs1u3tuPwAkd9aC9QD3coS6LFZYewCk3XiLpMcUm"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVviNorjuxJuDqaQniFwBPb3dcs57zESPFAtxhRYBTdeySVuJsj2pKC1vxJ29pWwYkhRsCaPzLm2qskFbh4UJUPqf7yxbjXX24TPhsKyebzJZ2UyqQrH8ResWrYduzqp92Y8DaNRnQLF")
          (* CrisF#3405 *) }
    ; { pk=
          of_b58
            "4vsRCVviNorjuxJuDqaQniFwBPb3dcs57zESPFAtxhRYBTdeySVuJsj2pKC1vxJ29pWwYkhRsCaPzLm2qskFbh4UJUPqf7yxbjXX24TPhsKyebzJZ2UyqQrH8ResWrYduzqp92Y8DaNRnQLF"
      ; balance= 1000
      ; delegate= None (* CrisF#3405 *) }
    ; { pk=
          of_b58
            "4vsRCVhanvPjgrJKRa6H5d4NL3ANd7RaUkqpbshvP3skcLdbw7Hoz1YRprnv94LxBRXz5ELbMuDS7qdNi9dzVWpSKNEAa4vtk3Z7CvdnJeTwjMXzRpyyBn6RRgWXGBdcsKFEoqfPwQhayNZS"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVWQe2BneRPcE371duSHNpqTjWNe6eVMc7aa6rh8cMSUGKT3gkg6H6TByXsUz6thrK1tTbFg3EiTaX7fB6X1NwhMDMMGbGAqdMN1LK3yrNtQabxRTMkh9XAQ8rdZBTGw5Ra6s9sekCfp")
          (* Alexander#4542 *) }
    ; { pk=
          of_b58
            "4vsRCVWQe2BneRPcE371duSHNpqTjWNe6eVMc7aa6rh8cMSUGKT3gkg6H6TByXsUz6thrK1tTbFg3EiTaX7fB6X1NwhMDMMGbGAqdMN1LK3yrNtQabxRTMkh9XAQ8rdZBTGw5Ra6s9sekCfp"
      ; balance= 1000
      ; delegate= None (* Alexander#4542 *) }
    ; { pk=
          of_b58
            "4vsRCVSvkeehkWAoJis1ZaUpGt69B5414z4m1xAXTyUotFmo36BegAEopiVpEERcnKB8zRPVZ3CsY6AnGVWC9DvCbQEePXPALegVvaJEy8jiW8FgkJ1KCdEpugBaK3dPactm1qUNQjz9QNxN"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVfbHVoX5hmpcoypuNGMW29ed9k5AAzyhXJsNFXhNJ9ZyUvPagSQW69efSW3RxUkbvrHfnpnyHemLCuqj1kZpxeYhCq2Hsg5XvwQszsfkqUZKF6qtVaXneTxK9LB2iE36KMSHqU86EXi")
          (* Runite8092 *) }
    ; { pk=
          of_b58
            "4vsRCVfbHVoX5hmpcoypuNGMW29ed9k5AAzyhXJsNFXhNJ9ZyUvPagSQW69efSW3RxUkbvrHfnpnyHemLCuqj1kZpxeYhCq2Hsg5XvwQszsfkqUZKF6qtVaXneTxK9LB2iE36KMSHqU86EXi"
      ; balance= 1000
      ; delegate= None (* Runite8092 *) }
    ; { pk=
          of_b58
            "4vsRCVFibrALeNvmpn37TsJEWEqVGc1vLoCWYd9ubEcCpkeURf2mg3FXi2cFsdBkH4cCTQgVPJGs4N81xoS4ScSK3RNDQeLMHqJseBjGzrjRjop1X8EspgV7Ht3mVzTiRZCg4N2U85tg9oXT"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCW158kqvtbUAz3uusagz2VQjw8ybDgit9GhUgL5eq3dktJREE5DSSrNciFmDpJpsJjLXx9edAYgz2uvtGwhQziWdYam8ZCR2GsZyM8RcHhdG4zENW5r5PxqQW5hu4ChUCpHzZ7uE3Qcs")
          (* madjae *) }
    ; { pk=
          of_b58
            "4vsRCW158kqvtbUAz3uusagz2VQjw8ybDgit9GhUgL5eq3dktJREE5DSSrNciFmDpJpsJjLXx9edAYgz2uvtGwhQziWdYam8ZCR2GsZyM8RcHhdG4zENW5r5PxqQW5hu4ChUCpHzZ7uE3Qcs"
      ; balance= 1000
      ; delegate= None (* madjae *) }
    ; { pk=
          of_b58
            "4vsRCVzeN8RqVoau7UqfvMRwKnMSnC3AuTzvV3HSdBmMBrkncVg8iV3AB92xRDEq2q8ASRKcA2k7yz7LPZRNRoj2aw17mVA1Bfgo7DF2hpqFVPR5aDiq5DpqpSzeLnkZiPmfRgVmfor8buLT"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVWaAeSRzPBQ561PDWVdmMDbLN5WfPs52HXQrgoZTGVzDjAoaNdKvYEoCwV1H4oYLbzDamZGeiWEJc8ZC1FHsxsJZzMbczwVWvkdxjXqjLDTvKMy1jAvRoWwL2cDvrQwot6bUKzeobLZ")
          (* illlefr4u#2957 *) }
    ; { pk=
          of_b58
            "4vsRCVWaAeSRzPBQ561PDWVdmMDbLN5WfPs52HXQrgoZTGVzDjAoaNdKvYEoCwV1H4oYLbzDamZGeiWEJc8ZC1FHsxsJZzMbczwVWvkdxjXqjLDTvKMy1jAvRoWwL2cDvrQwot6bUKzeobLZ"
      ; balance= 1000
      ; delegate= None (* illlefr4u#2957 *) }
    ; { pk=
          of_b58
            "4vsRCVb53abUPcqz9vQhLXyoBaV7ydfBogoe7ZDyxY2ej9uWUtTkWBWoA4fAUhH2n6ofBq55hvwVBL8Y2XrVN43LxeTFxfMTVCxzddNS5yavRTBdJF2t8pCVxfCUFR8zpe9FuaDPNfKgQ5UD"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVTvGZ4sWRpt2ow4pQFkqRNtLNa2Uj26aqwt941ZMXEChEbs1WBRcofTV6FN2H5jJ4CHZejZBW11Bwfex8U8Md7z7krgKTkCCBDA5WaVMQ7pstPBz3Wpe83eUY3t1JXywTiy5MeqNrDM")
          (* ◮👁◭ Víctor | melea#9821 *) }
    ; { pk=
          of_b58
            "4vsRCVTvGZ4sWRpt2ow4pQFkqRNtLNa2Uj26aqwt941ZMXEChEbs1WBRcofTV6FN2H5jJ4CHZejZBW11Bwfex8U8Md7z7krgKTkCCBDA5WaVMQ7pstPBz3Wpe83eUY3t1JXywTiy5MeqNrDM"
      ; balance= 1000
      ; delegate= None (* ◮👁◭ Víctor | melea#9821 *) }
    ; { pk=
          of_b58
            "4vsRCVmFUG8UGavmGXR8ggBLZaEa15rXiJpy6E79uwcdmdRsoRPYmYPssH6YGMAJAtNdr7NnnQp45gx6Bo3ypqaJvm9kMoHZkrZtZhrp7MZtc9x8pyJoKo34c2ZhapvwNUmM6FBSNV6bBrir"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVspyQcpgaBWfktPXt5QNkpJQ164v97NfQzKFySMdjV6N4Bp7QmgpGziJS4UnRy6avJkRv2nqUUwccfe3Bu2XaQgVs14uh86Gy94dkgBSmYaP4GGvUsbW4D6P2Sd6R4Nyw5Z2eVtSdk7")
          (* roxycrypto#6342 *) }
    ; { pk=
          of_b58
            "4vsRCVspyQcpgaBWfktPXt5QNkpJQ164v97NfQzKFySMdjV6N4Bp7QmgpGziJS4UnRy6avJkRv2nqUUwccfe3Bu2XaQgVs14uh86Gy94dkgBSmYaP4GGvUsbW4D6P2Sd6R4Nyw5Z2eVtSdk7"
      ; balance= 1000
      ; delegate= None (* roxycrypto#6342 *) }
    ; { pk=
          of_b58
            "4vsRCVNt2WgDcRHhnE7yyVp6GWQvutMfmpvLm4PuFnpgTg7uvLE3iTzMAeEudLqgkTAPjpUNUF7hyihkJNpi7vwPWwMfz13jmQidPVtcwTAQdyRkSBNgvX7o9FJQB5Q4RtkXsvBwVs2aYvPs"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVY5mK7bH2i8hXTQu98ChjGrTr8TGFJrDoya9MPgKrSn9D6RTACZkHKMaat9h8kDvCdSFBgkUCTELTTKDXmXe8XuugSXSfjUHuoDQ8KsK8hnYc4h7HuStgqLbnE2Nx7mFSLJusxE645n")
          (* mbrivio *) }
    ; { pk=
          of_b58
            "4vsRCVY5mK7bH2i8hXTQu98ChjGrTr8TGFJrDoya9MPgKrSn9D6RTACZkHKMaat9h8kDvCdSFBgkUCTELTTKDXmXe8XuugSXSfjUHuoDQ8KsK8hnYc4h7HuStgqLbnE2Nx7mFSLJusxE645n"
      ; balance= 1000
      ; delegate= None (* mbrivio *) }
    ; { pk=
          of_b58
            "4vsRCVQknhzYXZq8eZLyTKLDXdZXgkYM41kg6wn1ERJvVLJhfBa27rnnzY7tuED96S3HAWkb6hqYrhMhAmrKV1RZRhhCx2qCVxsUKdi2WMPrBeyxuYDmHuHt9qLmT9MjMXcijeBrwqCYmZsm"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVhwXK1VVgPHQqfa9APoavbcy2iqkmHdqti7YvB3WULovTPEUDAZVq4AcTHD1ATxsas4oLqjB3ysfXeYWs4HLtMkR3RzJ56YhoKMdeHWYq7aTZHRtR3tmqrNq4exRjHGyoZhviYS537A")
          (* arn77#5301 *) }
    ; { pk=
          of_b58
            "4vsRCVhwXK1VVgPHQqfa9APoavbcy2iqkmHdqti7YvB3WULovTPEUDAZVq4AcTHD1ATxsas4oLqjB3ysfXeYWs4HLtMkR3RzJ56YhoKMdeHWYq7aTZHRtR3tmqrNq4exRjHGyoZhviYS537A"
      ; balance= 1000
      ; delegate= None (* arn77#5301 *) }
    ; { pk=
          of_b58
            "4vsRCVpQHPRHz8vabWuotfPAv48smA73hcPURVPJQYDer9vFJKjnUB2XXYUX4DxUJW2719hjouna9meN3ne6XnMHjVc6y7G4Bv6vatstLtcVjGn44oWFftsDAKCQVzJKRJVuBAcyP6MoEo8C"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVaSshCdu2QW8jJ8ht91ghUehNgQsc3HK3gM1erFuhdZKeK6WxMTs3XmsrF1BkL85HdqYvKnds99NJ281T1whgLE9EvrG56KAiT4r6HDDy81H42wdUVkLWo1bxbhZ586AscRkLhsPkx8")
          (* Nabob#5004 *) }
    ; { pk=
          of_b58
            "4vsRCVaSshCdu2QW8jJ8ht91ghUehNgQsc3HK3gM1erFuhdZKeK6WxMTs3XmsrF1BkL85HdqYvKnds99NJ281T1whgLE9EvrG56KAiT4r6HDDy81H42wdUVkLWo1bxbhZ586AscRkLhsPkx8"
      ; balance= 1000
      ; delegate= None (* Nabob#5004 *) }
    ; { pk=
          of_b58
            "4vsRCVnpPjdxuPu3qpwGnPPb6ex36dtx2URvs9nWwV4GyuM2NC9kY1cDQk2t84qZKDFNmyk5d8nJoZtVVauetmdYhos9vbzSX5wdQsgTN5RcxCbtcSVCANEusW3TzVfY2KBUDGMoMiaivkHA"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVfNDCCuduG8PBJM8wjwZRqibUPWiodwuSpnj9XVtXWTWBbeJKe2e5JSqHhxS11mLfa9LRDAaM6TWHdPr27fba7WDqvoyTy67uv1mFf1mUfunjoxt6xBVS7yQwRNms9NLeDGoycfG94W")
          (* axone77#4236 *) }
    ; { pk=
          of_b58
            "4vsRCVfNDCCuduG8PBJM8wjwZRqibUPWiodwuSpnj9XVtXWTWBbeJKe2e5JSqHhxS11mLfa9LRDAaM6TWHdPr27fba7WDqvoyTy67uv1mFf1mUfunjoxt6xBVS7yQwRNms9NLeDGoycfG94W"
      ; balance= 1000
      ; delegate= None (* axone77#4236 *) }
    ; { pk=
          of_b58
            "4vsRCVZW13PBhX3dzA1zFZsAiWMKHL2juTiiiHynu4NJogfiiPSqZKT9ty5nWj4C8kwMpS6FppBCpFwQ9zhBDnzVff3uXASUMZ47V8JhC2vbUUY8CudSpgiFhuUniethCocsdQRo8PFCcbUn"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVivGBeELmSMnZGP8m4fXTvFpfP2AqSxKgM5A1Gx5B5R5d1qy9rCBozYSh3WygrpU1Dexo33PYLVTezivEKqhd83USju4Wak7aUoNAwp9htjQmEqZ9EbDVv5Zxpqa8gYwZU7MG4euWzJ")
          (* @erknfe *) }
    ; { pk=
          of_b58
            "4vsRCVivGBeELmSMnZGP8m4fXTvFpfP2AqSxKgM5A1Gx5B5R5d1qy9rCBozYSh3WygrpU1Dexo33PYLVTezivEKqhd83USju4Wak7aUoNAwp9htjQmEqZ9EbDVv5Zxpqa8gYwZU7MG4euWzJ"
      ; balance= 1000
      ; delegate= None (* @erknfe *) }
    ; { pk=
          of_b58
            "4vsRCViHAyDUQMLUFkUVVSmvtJ3UrK2rgzzTFeznSm4rpBufHxwMPrL4mGmaZ9vY76BSMwrVwJniy8Wf5jd7GSbW3fZZYDv6doa1jzM4X168bsvyJTLqDnRSLm5ZFVBuQPRie82xHtGZTu3h"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpQdfaMyAutBiLcnd5QqFAnxPvWtA5XpCzYoS7EphzoUHUoVPo4Hp4gf69VS9Ey23JTw9tKUmPWcQCmvcjZNbcDuCWjETz6vjYDZxAEghWmwEpB2QMR5vtmweFrY6hhUY88yvwoWfY2")
          (* SigmoiD | dsrv labs *) }
    ; { pk=
          of_b58
            "4vsRCVpQdfaMyAutBiLcnd5QqFAnxPvWtA5XpCzYoS7EphzoUHUoVPo4Hp4gf69VS9Ey23JTw9tKUmPWcQCmvcjZNbcDuCWjETz6vjYDZxAEghWmwEpB2QMR5vtmweFrY6hhUY88yvwoWfY2"
      ; balance= 1000
      ; delegate= None (* SigmoiD | dsrv labs *) }
    ; { pk=
          of_b58
            "4vsRCVfVuha9k1WPMmUqs5iSZJDYhziQsU3utipNP263QaDQBK6mhhtNPCJzgrWWZLeMC83qzgF4755NWmMYQz6gLiJ2oj2c8NYecfTn6Bi5E7LNuf5yUt31dbyW1y8YEmd4ZRT4dbzgrU3c"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVggPFx6ApkRGdfLyqS9Fog9ogcSyo2rKt7kDNwB5Y7MCtpmq7sPBtFqgp7LkYtis3DVKvEG6BbiGTGB56J9u3motVXSaK2jJSh8TSajREftuA4HQoGUjPJFa5hMWjanA1vmhALjaGBZ")
          (* d3fc0n#1892 *) }
    ; { pk=
          of_b58
            "4vsRCVggPFx6ApkRGdfLyqS9Fog9ogcSyo2rKt7kDNwB5Y7MCtpmq7sPBtFqgp7LkYtis3DVKvEG6BbiGTGB56J9u3motVXSaK2jJSh8TSajREftuA4HQoGUjPJFa5hMWjanA1vmhALjaGBZ"
      ; balance= 1000
      ; delegate= None (* d3fc0n#1892 *) }
    ; { pk=
          of_b58
            "4vsRCVKf6i7ABzDbjgXLgWrbNwaNxZL4zPDa9Qj8xAEK1Z9GS6nBHk7UGW9RJTCe77JaZyCoqkXDMPGMJ5Ns5a4wQvahnxHLp34y2jRvsf3khnUvF9PJfHtamM37VqoNDLivGwBaNPYR2q79"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVcp5QkSpM6CSqMsBhRd15QHbXxABe424kDcy81jVxWY1fAaGMQq6rndkfijxP2qJ1oD56Wc2Z3bpZpoVKzzVGHbNQYw1bJxpTt7kg9hRFQFrKEg6adw31g3huJ85aCRJXTyVnjw8ZDB")
          (* vsh#0264 *) }
    ; { pk=
          of_b58
            "4vsRCVcp5QkSpM6CSqMsBhRd15QHbXxABe424kDcy81jVxWY1fAaGMQq6rndkfijxP2qJ1oD56Wc2Z3bpZpoVKzzVGHbNQYw1bJxpTt7kg9hRFQFrKEg6adw31g3huJ85aCRJXTyVnjw8ZDB"
      ; balance= 1000
      ; delegate= None (* vsh#0264 *) }
    ; { pk=
          of_b58
            "4vsRCVUmkcTK48288GrLMUoBY1RWna4mjJ8BXN4YrqvfJY5yFjdsweXeDWTd7NrML55CM4Di3uNMHeusCAakE6Pdhz8XjKN4ZYJqXA3bFZUqB5LgoG1rz7HxjJZhv7EskQ9AJmKzxfXNUptn"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVoknK3UkKamFhX63G1ifii7nouqdbAGoMjq9kiu9XbsvTQBzqrnn8SwnjizffHx1R1eBiN64PHmwpevUEgapRtvKgTiqNv4rEsFfvoQdeeQXEDaSHhhz3vn6ijdh4T3vCHfwVXMQ5cB")
          (* Phototonic *) }
    ; { pk=
          of_b58
            "4vsRCVoknK3UkKamFhX63G1ifii7nouqdbAGoMjq9kiu9XbsvTQBzqrnn8SwnjizffHx1R1eBiN64PHmwpevUEgapRtvKgTiqNv4rEsFfvoQdeeQXEDaSHhhz3vn6ijdh4T3vCHfwVXMQ5cB"
      ; balance= 1000
      ; delegate= None (* Phototonic *) }
    ; { pk=
          of_b58
            "4vsRCVStBW5eDmMTrixaY3Vsv6gg9XSwK2YCvpg1ZfGcTgeMf51gvAsM91DemdiiHppw4AvPayaB5ULoweGcz9Zu5dQicSE5HMqih9TuA6XXSaDB7BwHFTaBJuBMqwRMnNYm44QmvTpfmKk8"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVT7AnTqH4KoxU1vpDn2jQifru2keMLfNrS65REEHLsUEJq9A2jaf6rHZEYu6PzmUGZ3B9BMoQfSAzU1zpiWZjDDyLLkdg2DCzkqnB3X9XFyvHm4XhnBMjjvbfXA1J5mtJWeXKRE6CnM")
          (* alexmironoff *) }
    ; { pk=
          of_b58
            "4vsRCVT7AnTqH4KoxU1vpDn2jQifru2keMLfNrS65REEHLsUEJq9A2jaf6rHZEYu6PzmUGZ3B9BMoQfSAzU1zpiWZjDDyLLkdg2DCzkqnB3X9XFyvHm4XhnBMjjvbfXA1J5mtJWeXKRE6CnM"
      ; balance= 1000
      ; delegate= None (* alexmironoff *) }
    ; { pk=
          of_b58
            "4vsRCVGoUgMrciEBvTgBbvksoxtDxgPe6dTwDGZKj47MZ4eAAnSofVEq5x5x17WL8EfdmRjQux94HKu9VMsDMA6mQPvjSanpRED8naw4nKpYbEvnutmzeBcWL3CiJbkuENGmnUvX1SRcevGe"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVgjF76uuwWUoMU7DqgpSVhRQbeqCnzRdhdqdmXU3aeah4jjxR2Zx4hYsb2c2wfdj5WMXMUR6T6auKBjRv6AuFdDDEjm3HLt9A64iivnB67sAjtsf3HncS524samdrmLwwK62r7cUzmU")
          (* meshug#6256 *) }
    ; { pk=
          of_b58
            "4vsRCVgjF76uuwWUoMU7DqgpSVhRQbeqCnzRdhdqdmXU3aeah4jjxR2Zx4hYsb2c2wfdj5WMXMUR6T6auKBjRv6AuFdDDEjm3HLt9A64iivnB67sAjtsf3HncS524samdrmLwwK62r7cUzmU"
      ; balance= 1000
      ; delegate= None (* meshug#6256 *) }
    ; { pk=
          of_b58
            "4vsRCVfS8taX6pkdEKGYK6Yr9yptJoVDkrKTLdsf3FHAfamH5TjRmFJHu3kkKgisAjf2rZ8r7x3nSTsT2LjsRhgStuGe2BwSDamcJhwNNt3toXG7pUHNUqYv3KywBT9zUPRZzfmrppzz1QLm"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmSTPYQSsm7XD2VLNmc7PtiXUqkbyNrJzoiPtQWnU56AJNCC2tEkX9bVFtY6yUTbTNKHVufQg3B6yYbAWExeiKUtRSLjx6q7k3FE9Brvze1RRWL47V9CjNLyLuCipHWikTnTUwjZdv2")
          (* secretcat#3066 *) }
    ; { pk=
          of_b58
            "4vsRCVmSTPYQSsm7XD2VLNmc7PtiXUqkbyNrJzoiPtQWnU56AJNCC2tEkX9bVFtY6yUTbTNKHVufQg3B6yYbAWExeiKUtRSLjx6q7k3FE9Brvze1RRWL47V9CjNLyLuCipHWikTnTUwjZdv2"
      ; balance= 1000
      ; delegate= None (* secretcat#3066 *) }
    ; { pk=
          of_b58
            "4vsRCVi4zk3u9SCChvK8wnAiheDwZshv146FHwSvSs1MGvVq7mSvj7BquYUuP5hf4SF6HaRVeJRsyhpEY6EtR1vZUGiNSKQfjPbq3kGChZivEr4sfAPmDY3QjfR89oMYYok3ueEK1EUyzxMo"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVfggkWVFFgiwbwbiM5NC1wCWPZ7Jb17a36woGHaP1qkG854XgW4oAVuyyMhAS9q9opvhXZ1mGZghQpEyP5qzPBQ5K7xvXrw5wQM388Rzz9xLLNf9TkwvZKeEo5aUp7gjkX21mHK6HNA")
          (* TheBronzeKing#1273 *) }
    ; { pk=
          of_b58
            "4vsRCVfggkWVFFgiwbwbiM5NC1wCWPZ7Jb17a36woGHaP1qkG854XgW4oAVuyyMhAS9q9opvhXZ1mGZghQpEyP5qzPBQ5K7xvXrw5wQM388Rzz9xLLNf9TkwvZKeEo5aUp7gjkX21mHK6HNA"
      ; balance= 1000
      ; delegate= None (* TheBronzeKing#1273 *) }
    ; { pk=
          of_b58
            "4vsRCVNDeGCM7NJCG8jBq5svu5HzR43m31iwZYUHncmwQ9nDEfUyqhB8nXtGsxuXD5fiw1g9q22jWLN2oepXVQQrtu2unKwh2RKw7Dvym1MNv1m8oL8BUgPEyrLh3Dx8iaiLq36dhSfi5Nqx"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVS7H2VNCUEVJyCsaDEJ6vZVEVXcAPF3E97a9MLvjQXtpE41o2g86fqmrpGwi2AwmU4oG71GYW1yPLQ8DkyXiHpFh2ACyG8fQParUTF3wAFtj6KkfXHpFCy5CUEyrahyBaF4quPFUpni")
          (* Artem|Bakednode#4275 *) }
    ; { pk=
          of_b58
            "4vsRCVS7H2VNCUEVJyCsaDEJ6vZVEVXcAPF3E97a9MLvjQXtpE41o2g86fqmrpGwi2AwmU4oG71GYW1yPLQ8DkyXiHpFh2ACyG8fQParUTF3wAFtj6KkfXHpFCy5CUEyrahyBaF4quPFUpni"
      ; balance= 1000
      ; delegate= None (* Artem|Bakednode#4275 *) }
    ; { pk=
          of_b58
            "4vsRCVk9jzYsrMwgiXw7gUxEgFyDiczM45etgFXxdy5wdZQ4QGUW582fApaogoZh3sELAM6tCPhJmkz3k38E5CydWyCuTnU1yqj7MBxUDUvK5rDRpoL4XwP9zb8ixjmCxZMFTL3VwDciV9p1"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVs55fUCmf3ziRBd37WX2FSGqiSHENJcST7dkjuhnuWD4tV1oTyGUwpjj1Ud1yBSJ9L1dinmLhHWHNdyHFjNfCwHC7sWTiwfyX9kXutM7tF9fcswFARY7REjST5ADyZKuvqaeeinwZFw")
          (* alexbond#3442 *) }
    ; { pk=
          of_b58
            "4vsRCVs55fUCmf3ziRBd37WX2FSGqiSHENJcST7dkjuhnuWD4tV1oTyGUwpjj1Ud1yBSJ9L1dinmLhHWHNdyHFjNfCwHC7sWTiwfyX9kXutM7tF9fcswFARY7REjST5ADyZKuvqaeeinwZFw"
      ; balance= 1000
      ; delegate= None (* alexbond#3442 *) }
    ; { pk=
          of_b58
            "4vsRCVf961XDRb9nKD1C5EXJjvpgGqmBUaAekF7rDLNUgkXWupLWZK8YtSGGvvNZD958jvwm8rvL7WnT7a4ZNiiqfH1szDt1qxDmuPoWBdEbK6PMjr8VZrrkawRMXokuL1bhM5mozHHuKzYs"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVezaQEozaosZKnNAGu57DW9QWSPVyzquNXs8VAx2a6VJDFJ3uhLgmChGoKk5dgCqPN7mPVerS7whDYMsekMStibru1V1UPAkYKQ6xbwZAWefnwUFQqdwkVHt9d4ai1r3jg3nDjgyhGp")
          (* BabyShark#6874 *) }
    ; { pk=
          of_b58
            "4vsRCVezaQEozaosZKnNAGu57DW9QWSPVyzquNXs8VAx2a6VJDFJ3uhLgmChGoKk5dgCqPN7mPVerS7whDYMsekMStibru1V1UPAkYKQ6xbwZAWefnwUFQqdwkVHt9d4ai1r3jg3nDjgyhGp"
      ; balance= 1000
      ; delegate= None (* BabyShark#6874 *) }
    ; { pk=
          of_b58
            "4vsRCVX3h432PyFFE4pz4yjZhi3RjouDHXk9vH3HyZDrybHZkFYq1a2nQuPsuMCtAAqJE32JhBsyfmZxVrwPuJ7YK9QmqXXfVJprrK5bwFYfoArbqHaUADXAuu1QP2zKM1Sm5ctqeniNs6do"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVVFttSubCvYdnWNK6Jr5SdGB2g62Em8LTLBcYX9gF4yrMAHNB9Nhs5YzLJBAy7PLig289ZrPH3yhUfbNpGx5TuUcBY8sHwLXu2W7uvn35juuKJAymamxDNwjwmwU4YsdZTquMBaSGVM")
          (* ssh#4098 *) }
    ; { pk=
          of_b58
            "4vsRCVVFttSubCvYdnWNK6Jr5SdGB2g62Em8LTLBcYX9gF4yrMAHNB9Nhs5YzLJBAy7PLig289ZrPH3yhUfbNpGx5TuUcBY8sHwLXu2W7uvn35juuKJAymamxDNwjwmwU4YsdZTquMBaSGVM"
      ; balance= 1000
      ; delegate= None (* ssh#4098 *) }
    ; { pk=
          of_b58
            "4vsRCVgTAUm1RTsoYsZ5i2SLbHRZYGusico1otNB1EeTx2kEai1feGpL9Bn1xYbCxjZ2Kb495pg6rmUCgYGSezKoRW5a8Fxedrtfo8dDkkqJsmxbgzjExNMdFqM95WzYnA2CEudkdtVW2221"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVVprFwdhNyBQr1KHPFNdDgGV8AcpDJcdGBAhfgPptaqVmwJucCdqYRKBJzYt5h1mmyNt5XPLAxr1ixXEw3TWgAuFgV79GGHQi1omH988b98uGoKtGqeRbE9A4TotwRcGczku6yLxYRM")
          (* rt_td *) }
    ; { pk=
          of_b58
            "4vsRCVVprFwdhNyBQr1KHPFNdDgGV8AcpDJcdGBAhfgPptaqVmwJucCdqYRKBJzYt5h1mmyNt5XPLAxr1ixXEw3TWgAuFgV79GGHQi1omH988b98uGoKtGqeRbE9A4TotwRcGczku6yLxYRM"
      ; balance= 1000
      ; delegate= None (* rt_td *) }
    ; { pk=
          of_b58
            "4vsRCVdWDZoUwSmtuw8iiCrJfSigXnnRuEXug2StWajd6onqwqpjf2WWGaNjCPFyPPPvJSRn3pFAjWXxZjz11m2s5t85g2HztG3JUiYsXTYRAad9JPXrbAmiX5RrSdCar5hAuCuefCH6uTjc"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVoFb5vvNPCVVKbnmjbhzQcGLCtPoJGNFKFWTiTsSCoXdGjZBRuq1Yw9yCABkBuoHpJJRL4zHMndPH7Z2oKpvffGUDjsM528fAoqpH2zwPQfK9uKgzdVqjTZaYgqNUm2u5S3VsGcDZmh")
          (* CryptoVikingr *) }
    ; { pk=
          of_b58
            "4vsRCVoFb5vvNPCVVKbnmjbhzQcGLCtPoJGNFKFWTiTsSCoXdGjZBRuq1Yw9yCABkBuoHpJJRL4zHMndPH7Z2oKpvffGUDjsM528fAoqpH2zwPQfK9uKgzdVqjTZaYgqNUm2u5S3VsGcDZmh"
      ; balance= 1000
      ; delegate= None (* CryptoVikingr *) }
    ; { pk=
          of_b58
            "4vsRCVxq8cWPmjuFVypefNaAKor5kPkeoqTbyvFyzxJUfn2LkGskU3oJ3GUf4tJ5sqaEBhGam1ipgs8HtKy2Q5YQaSBPmywk4sahu8ZsSDvp9EwkR7MP7xAVT7Mp2YXyK9Qu7vBE3ePBjdX3"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVqbuAPPc1K9AL5wsFh1PxpzUe5fn3KCTPZi4mhMdRAqricG2PeSbFbyQEFfiBCmbmmvgagnQs2R3ZJ9J9oc9LBuD3Uo2yYUxdbEHecGxpeAEbsXcNoVDCqTMeERAW8Nj3H8Ti8Ko16Q")
          (* henk.yip *) }
    ; { pk=
          of_b58
            "4vsRCVqbuAPPc1K9AL5wsFh1PxpzUe5fn3KCTPZi4mhMdRAqricG2PeSbFbyQEFfiBCmbmmvgagnQs2R3ZJ9J9oc9LBuD3Uo2yYUxdbEHecGxpeAEbsXcNoVDCqTMeERAW8Nj3H8Ti8Ko16Q"
      ; balance= 1000
      ; delegate= None (* henk.yip *) }
    ; { pk=
          of_b58
            "4vsRCVxikWwbsSjvjAp6nEZx7uuGKiLKp9dTvF5zNZ1oxcEVxQqHkhpt7zWgy7YGyi21KiHZqaxRM37kYuhgt1WFHioSXBLmXiRzdqxGWya5tEtzzH4D3gVPqVTp4cqKPoJVBwaRyst1HjYz"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmXMCr73yjouoJH34kshfELZmXtx5LF7k57iy8advVcREkG2EZ8t3CB9mdXv59HSx8n8QULMPXXyCMuvmuiEdVpxf3fzNna9H9ruxkwTaRuLo9WQeUJFKSNQcKoh1vJCvyyzD6xiRN3")
          (* cryptovestor#5714 *) }
    ; { pk=
          of_b58
            "4vsRCVmXMCr73yjouoJH34kshfELZmXtx5LF7k57iy8advVcREkG2EZ8t3CB9mdXv59HSx8n8QULMPXXyCMuvmuiEdVpxf3fzNna9H9ruxkwTaRuLo9WQeUJFKSNQcKoh1vJCvyyzD6xiRN3"
      ; balance= 1000
      ; delegate= None (* cryptovestor#5714 *) }
    ; { pk=
          of_b58
            "4vsRCVq2dBfQgTSt4HyeVvi9CtJjpN13QfYM4ZewgD2eFgsXdxx1AsEWzwCGcwvoPqaVSLDJXK8PQkXQ2LyLE2i6mcJPoeL1gmnmVitPAJKXMsUJDmgwDDrkt9KMBpmYzeP6Lyz7yCF9papp"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVJnfL4KGvUK2f9PRvHXbGJp61UhChixXCZWc37ryHNtY39duzwK72zS6LpqzyC23NNNjPMZrhUa5xvpn2A849s5FatahhYkj4MX4jFw1qJmRXVz96w2T5bkQxzmMnuKAakGPnJq6JB9")
          (* audit.one *) }
    ; { pk=
          of_b58
            "4vsRCVJnfL4KGvUK2f9PRvHXbGJp61UhChixXCZWc37ryHNtY39duzwK72zS6LpqzyC23NNNjPMZrhUa5xvpn2A849s5FatahhYkj4MX4jFw1qJmRXVz96w2T5bkQxzmMnuKAakGPnJq6JB9"
      ; balance= 1000
      ; delegate= None (* audit.one *) }
    ; { pk=
          of_b58
            "4vsRCVMDVfiJEaShquzYSHMogazrpFqPy1F4R2hH5SeC8mTT5gbveEu9ywr6iLHFJFBgTa3dH5fzRbELVESYRb7n9NLdUXLjvQDBYCo5fnTVGC2irGt831jkDXNpfLntKK5rs7vZxYGGVg2z"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVr42qQfkqEH5HQfAXJuSYkHgmqjmj44dL1qzp4KFeGQMtfx41XscA1ocGx1jb7WcC2LBykday7yeeoPmDs9uii8a8JzbrrCgzrXo17Hb6fhB93jAp5gRH82r5Tvfenj8hxaMAjTQ85b")
          (* Gerrit#0366 *) }
    ; { pk=
          of_b58
            "4vsRCVr42qQfkqEH5HQfAXJuSYkHgmqjmj44dL1qzp4KFeGQMtfx41XscA1ocGx1jb7WcC2LBykday7yeeoPmDs9uii8a8JzbrrCgzrXo17Hb6fhB93jAp5gRH82r5Tvfenj8hxaMAjTQ85b"
      ; balance= 1000
      ; delegate= None (* Gerrit#0366 *) }
    ; { pk=
          of_b58
            "4vsRCVfjkkhWcMz6gC6wUhGuJNcdtDaN38fJ5nton2XNmZTpmYQx1Qu74PBiDJ5Fqmw5vrPUWrNPvqR1yZ48NYpvdTa3L6sFsyVhSUATs5mG516KLx71fQUgHA2xZuG85nhWUbccH3ASNYkd"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVgzaXGAPXDNz8B976Lbtudebp6P1SqEbyeU4FzAYt4qc98Nh4ahtwEY9o9ziZfkS1hZuQLTRkM1Vnu2rLan4XXG5Drjx1pBoMdqAiY2vUrPxfH4A5Giyxc7AQoLj8ri4Mz7hUkDBx6q")
          (* NarayanaSupramati#5017 *) }
    ; { pk=
          of_b58
            "4vsRCVgzaXGAPXDNz8B976Lbtudebp6P1SqEbyeU4FzAYt4qc98Nh4ahtwEY9o9ziZfkS1hZuQLTRkM1Vnu2rLan4XXG5Drjx1pBoMdqAiY2vUrPxfH4A5Giyxc7AQoLj8ri4Mz7hUkDBx6q"
      ; balance= 1000
      ; delegate= None (* NarayanaSupramati#5017 *) }
    ; { pk=
          of_b58
            "4vsRCVm9zmZ5YjJviikZ9LPZ4DFnghJ35v5guRnTNJECBK2yvxSij3X1o2pqH3vmfSMYCk96k1dBm4GexogWkt6gn5rMonfaKeoFmBreESBPAw1LsB41wAqM9byoZdjBBKtZhMpZGy3kNMSu"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVzjaGeH84JWK2wUFZoTYB5H9bjxiixiSPxVPy8cDetCxgQ9mbPHt9L6nc2WRBFG5MU2tgU36n6p6BvPwpoASJtnwZvHuDaknnZaU7um17UmW9kx2Ngvfhmm1aRHSJnKXDU43upc4264")
          (* Fouda I TD#7266 *) }
    ; { pk=
          of_b58
            "4vsRCVzjaGeH84JWK2wUFZoTYB5H9bjxiixiSPxVPy8cDetCxgQ9mbPHt9L6nc2WRBFG5MU2tgU36n6p6BvPwpoASJtnwZvHuDaknnZaU7um17UmW9kx2Ngvfhmm1aRHSJnKXDU43upc4264"
      ; balance= 1000
      ; delegate= None (* Fouda I TD#7266 *) }
    ; { pk=
          of_b58
            "4vsRCVJAXUCQ2jjn1MB6ZvedSBZEZp8SsaHBa56Ckkq8JU8s5GLF8rEkDYgr5bBMJgn3B8bbGXF1RLPWpqagKxHhfdgRrKK8mig6YCt6HaqqLx4BaXC7KtieA6Vr5MceeXuvAJ4FWD2R9rKM"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVdfAgvFv6swu5P5GECCri83TXfGesqUuUqFLVLouy4RYg8ymRnKfNWr1u4pcbRhBXHMdu2Z4FaPxogK2JjBpDtcXnCxb6HVtU2nXW4nLjFazNMitqRHVKvG9QEKD9XHTFx5Typ5kZ4y")
          (* daveydoo *) }
    ; { pk=
          of_b58
            "4vsRCVdfAgvFv6swu5P5GECCri83TXfGesqUuUqFLVLouy4RYg8ymRnKfNWr1u4pcbRhBXHMdu2Z4FaPxogK2JjBpDtcXnCxb6HVtU2nXW4nLjFazNMitqRHVKvG9QEKD9XHTFx5Typ5kZ4y"
      ; balance= 1000
      ; delegate= None (* daveydoo *) }
    ; { pk=
          of_b58
            "4vsRCVoT779QQ3sZWr6SZstqgVFaA5rnwiqt6ALw6YkLPHG5kzbdpPDS4aAJkL8b22iukS5xC4qNd4fMRHnNfYpxPoVfMXaigpYxaLEmNsjveksLrQs2naRSjXuQaPo7WEPvJC2qxRwRuo6a"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVj5kMV9oTNJBntmb55ahu6JKpVfwZBYGK44Pdi4Uw524KcFXsNXhu23a1paaqPBc8jnp3NnDrS5kAR6fkMYKzGP28e3UYhzPtYKb3fNakT2dZPopbpN3vTkmRFdaQhEfE2HqJQiRoK6")
          (* oonac *) }
    ; { pk=
          of_b58
            "4vsRCVj5kMV9oTNJBntmb55ahu6JKpVfwZBYGK44Pdi4Uw524KcFXsNXhu23a1paaqPBc8jnp3NnDrS5kAR6fkMYKzGP28e3UYhzPtYKb3fNakT2dZPopbpN3vTkmRFdaQhEfE2HqJQiRoK6"
      ; balance= 1000
      ; delegate= None (* oonac *) }
    ; { pk=
          of_b58
            "4vsRCVyT1SZCcvLZi1M1PGWkHCbme7YRcm8LoA1YqgR9ZrJ4nwesYkKLEsuZHXX64bcMvNNBWgaGNezAN8x8xs5doR3wsB2S8nniFW47WzqrQaT5SVd84EXa9E35cuuzrjNac5nv4U9Vop8v"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVQmcf47zfoLUnmiToRdYojn5v1YACfhdPGnpJTLSX2k4Vv2DSw2de1dCttYkMLg4SgeTDxat24QWQfsBNyGTxbhUEiUAk5F8tLNxAggxPDkdTsdahZcYAEnPWVahBHvJDXHzucoQeGm")
          (* aawessels *) }
    ; { pk=
          of_b58
            "4vsRCVQmcf47zfoLUnmiToRdYojn5v1YACfhdPGnpJTLSX2k4Vv2DSw2de1dCttYkMLg4SgeTDxat24QWQfsBNyGTxbhUEiUAk5F8tLNxAggxPDkdTsdahZcYAEnPWVahBHvJDXHzucoQeGm"
      ; balance= 1000
      ; delegate= None (* aawessels *) }
    ; { pk=
          of_b58
            "4vsRCVLBdNd6JNRdbqfJKWThvmEKfpyMVjpitsE3pHV35sy2oaAVybSzf1sYq3DcDBTzd94Ad6z4VHLEpFziumLBd1Z8j4C3171ci2Qmuxrh54c6ETAFwB6Gyophsz96Zpyd3BEDjrmTDsgJ"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVK8yMihuCRwCTzXjouETV75nAXPpAQ7CsA1i156L9YQWayywPBovzSaUxJJJYuWapZ6566rsoqS7shGT9L1BSC4wwmCKpvnZMgFxeaQG5AWgaWQJ8EG1qnQFHqFkVW4grXiyiPRznwa")
          (* diemou#0386 *) }
    ; { pk=
          of_b58
            "4vsRCVK8yMihuCRwCTzXjouETV75nAXPpAQ7CsA1i156L9YQWayywPBovzSaUxJJJYuWapZ6566rsoqS7shGT9L1BSC4wwmCKpvnZMgFxeaQG5AWgaWQJ8EG1qnQFHqFkVW4grXiyiPRznwa"
      ; balance= 1000
      ; delegate= None (* diemou#0386 *) }
    ; { pk=
          of_b58
            "4vsRCVw3XXsNc852kmx4dcs3ZrA8XHFXLAoPQZ8iBUoULh3bDfPHhKgDYSXtLv232QL7hCk94qH6ax6gMAgyWcjJJsBcHV8iJJjWZnyH9Je2UNn3sCtWgwr1sgbqZNd1UTyH1cQK6VND5UZT"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVVV64e4dFkkUactXBXqkDhczSv27sxKefEQ1v1h5KtXevTPyTiBSkafWAY1NGhbiRrNKDaEqRh9n6E5j9FNM7vKH5BAmFZWWfbUByVxHMX6VaLPwynY4se367wPKq4geyik5fZuWv6x")
          (* willem *) }
    ; { pk=
          of_b58
            "4vsRCVVV64e4dFkkUactXBXqkDhczSv27sxKefEQ1v1h5KtXevTPyTiBSkafWAY1NGhbiRrNKDaEqRh9n6E5j9FNM7vKH5BAmFZWWfbUByVxHMX6VaLPwynY4se367wPKq4geyik5fZuWv6x"
      ; balance= 1000
      ; delegate= None (* willem *) }
    ; { pk=
          of_b58
            "4vsRCVWojsHYtDJEahaZqZjmtp98Ceomtz9hQgnFqeQEYijmMPHWTr2DqDpeCsNXa1L2HLbPnbwn5F85Ve5qqojPxGc8YpiZRMaLNAGJvKVPF4rUGkf9nbrcm6XNTXtq8xsFPvuVqXsPTYF8"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmhvf2q1h2hwGcU1ruYuBKgXwXAS9kwZmy9WwSobnmFScaq2QNMwvWrGjacztNhXot2z8T9DTsfpmKUa7Ucf5T9wqo5hDimPDTSnLSQDwjitDgtHoLZ32t7EYmMkqZB719j2Ndfj7yx")
          (* paddyson#5479 *) }
    ; { pk=
          of_b58
            "4vsRCVmhvf2q1h2hwGcU1ruYuBKgXwXAS9kwZmy9WwSobnmFScaq2QNMwvWrGjacztNhXot2z8T9DTsfpmKUa7Ucf5T9wqo5hDimPDTSnLSQDwjitDgtHoLZ32t7EYmMkqZB719j2Ndfj7yx"
      ; balance= 1000
      ; delegate= None (* paddyson#5479 *) }
    ; { pk=
          of_b58
            "4vsRCViCpajEAsCUBMefKKZT6WzAiNF3biyKegSUHoG1oo3uNruLFy2En8JfG8BCWboFSWgVTTqu4PWeJznHkinVzYzoMw21vWFysvJqMFUVYun8sBt4edT7bMCWh5DoqbwXZFZAbtqbVbFB"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVtUX3qVKjRBt6uYyoJn5UnEdyVMHMzMxVHb5tWGWxZ5dtckahZguWRGcZJPvXs4em2gqnUHvumx5NswNDhE7SjxVL61jgkhfoY7q9Df8rA2x3kXsg961G4XTYU5kcsErRRJEESCrpkT")
          (* PixelPunch *) }
    ; { pk=
          of_b58
            "4vsRCVtUX3qVKjRBt6uYyoJn5UnEdyVMHMzMxVHb5tWGWxZ5dtckahZguWRGcZJPvXs4em2gqnUHvumx5NswNDhE7SjxVL61jgkhfoY7q9Df8rA2x3kXsg961G4XTYU5kcsErRRJEESCrpkT"
      ; balance= 1000
      ; delegate= None (* PixelPunch *) }
    ; { pk=
          of_b58
            "4vsRCVi5yoFghXZGqEb6Qfw95VqMqjDjuUnffxTMwzhbNW38MYJeamLLNYvck68kieZmkKuNZoYfGch1LKJ74U7Hzf5KuYGcBEf5GA57whEVnEdenXg1oZcNAr2VcoTNJ5njwB2PJGwuWXaS"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVGmLaKmEHCGVtWUCs7nGP85WqtEa84Y7ych5AVZN5XZVVRpPQJ16hJsSGWu36gAXigQjMrctMp2UvdibycM2hmU2eTrDezgmbp1yCj3KH85AHLg74QkbxwsKcDL56hTV4ewb6LNMs3Y")
          (* paydaSandros#1054 *) }
    ; { pk=
          of_b58
            "4vsRCVGmLaKmEHCGVtWUCs7nGP85WqtEa84Y7ych5AVZN5XZVVRpPQJ16hJsSGWu36gAXigQjMrctMp2UvdibycM2hmU2eTrDezgmbp1yCj3KH85AHLg74QkbxwsKcDL56hTV4ewb6LNMs3Y"
      ; balance= 1000
      ; delegate= None (* paydaSandros#1054 *) }
    ; { pk=
          of_b58
            "4vsRCVogcUHuq9h4dNMPUew3zXUrBJ6xG7YwcKzJtWVBPnMCEMwMQGBu1zs1RBxUXSpVYBts4aoboewmZLctN33Q6b3UYw1DvabirbEw1Yet5gJpoUEvWEgUUVMnNS7yDmhSGKFZ8aRjEgva"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVuFXwwmk9oSWzsmLaBDveD4zUH4KnCg4XwqrQX9RNNGudTsEHKeb542ZiHLTvxopjPg9N7g3YgFksTArXXAGe2XqxsTmg9cZKYnPmVKAzLgx9V4YwxeML7i8m63WNRy86Vph7AAkHHh")
          (* JoeSixpack#9543 *) }
    ; { pk=
          of_b58
            "4vsRCVuFXwwmk9oSWzsmLaBDveD4zUH4KnCg4XwqrQX9RNNGudTsEHKeb542ZiHLTvxopjPg9N7g3YgFksTArXXAGe2XqxsTmg9cZKYnPmVKAzLgx9V4YwxeML7i8m63WNRy86Vph7AAkHHh"
      ; balance= 1000
      ; delegate= None (* JoeSixpack#9543 *) }
    ; { pk=
          of_b58
            "4vsRCViNBptApqtMKGbaM1fuMc5LkezjpbKAxxvJfVH6VHge79kq7WhZizPoaFaBYXsSeunPERdsQUQD2fNm6HQVEY95RcG4b9qrECJ3VsUdbDV988NyuXRxt9bxRo2jSa4j1LP8ESyi1JQK"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVRjqcjN6fSr57M1S1Gup48Ht8Tzt6odWxiyARiHdY1PX1d9gLvtL1D1QoVNb47nux2ppitU1qpXYccWPjMBtUU8jao6vQUK9wbV2uoivYdJoBsV6niNqRVbSC1cx5qviPPAedi1QoST")
          (* Vladislas | hashFabric *) }
    ; { pk=
          of_b58
            "4vsRCVRjqcjN6fSr57M1S1Gup48Ht8Tzt6odWxiyARiHdY1PX1d9gLvtL1D1QoVNb47nux2ppitU1qpXYccWPjMBtUU8jao6vQUK9wbV2uoivYdJoBsV6niNqRVbSC1cx5qviPPAedi1QoST"
      ; balance= 1000
      ; delegate= None (* Vladislas | hashFabric *) }
    ; { pk=
          of_b58
            "4vsRCVVtD1wk8iwhPjdWx3frnTbxKpwK3WnLqbdtwbGSB5SiH5gvK1pqqVnuuX4gGXtJpFrQSFqvd3UipcAkmQNKFCih51VfdXJ9CYDwuKS2fnxn1nPtN4ELDFCrFp4w9qoEKTNkfYV5NrNa"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVTZaNjGAkqQbBbDdYjV7rZ6B1Lu29AtEHXs6qk9E6MJ734pgqqvHZoirULs7puqHVUvJdYGBEYqLF8aTqsQK47xArZvbVHZSy8u6CEPRuo9MaF75fbdGTZNJrrqBGePvv2wvK3cu3nn")
          (* Bulldozer#6355 *) }
    ; { pk=
          of_b58
            "4vsRCVTZaNjGAkqQbBbDdYjV7rZ6B1Lu29AtEHXs6qk9E6MJ734pgqqvHZoirULs7puqHVUvJdYGBEYqLF8aTqsQK47xArZvbVHZSy8u6CEPRuo9MaF75fbdGTZNJrrqBGePvv2wvK3cu3nn"
      ; balance= 1000
      ; delegate= None (* Bulldozer#6355 *) }
    ; { pk=
          of_b58
            "4vsRCVpHrHReX9pj3ixMSGEqUFVov3tVu4QsAeefwo1U3Cf4rxw5XgZyt8PWwS8KiDeDymphgiQAKVVT9bCt3yFz98K9A8892KgMEBXARqK7jQEpbD2A4FstynLwiHDZiyD42d1ziAVfqRZ3"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVHbD9MwsjFQGCNSpBL4kVHRWzvyxiJPKFNJFTSPPKdx1rhfL6kfhvE7PtxLWRE7Cr7xaXQdise9kHWGqWx3gvirsUAcoSguni99BNh4VsWUrUnHutdK8FCLK1dfrv83Yhsh29kZrPgG")
          (* Bojauran#7995 *) }
    ; { pk=
          of_b58
            "4vsRCVHbD9MwsjFQGCNSpBL4kVHRWzvyxiJPKFNJFTSPPKdx1rhfL6kfhvE7PtxLWRE7Cr7xaXQdise9kHWGqWx3gvirsUAcoSguni99BNh4VsWUrUnHutdK8FCLK1dfrv83Yhsh29kZrPgG"
      ; balance= 1000
      ; delegate= None (* Bojauran#7995 *) }
    ; { pk=
          of_b58
            "4vsRCVWHnSV1h1N4pyfHdW9X5CmKVAKFtPfR8U1xBpQSXA6BYGGYmRUMPA85vyDNa9YeTHhCxCtZEGbjoQTLFyqQQ8AmSqUVHXuUXaefSy9WAm1oJitkM8YZPa4c19cYHWQYEaRK4QnGfPrk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVhoj1MDrQrDonKvo4BT9TevQXgRqBpK9CkFdqSgCgEPngRbaotJwusiEWPz7NdYMApTeDheSgLShQeSy3T7QPBjEA9cpmqd9UwcLhjfnHs5VZMNFcxYgxdVqBiJnAXcjRKqf1VZAUq6")
          (* JoeSixpack#9543 *) }
    ; { pk=
          of_b58
            "4vsRCVhoj1MDrQrDonKvo4BT9TevQXgRqBpK9CkFdqSgCgEPngRbaotJwusiEWPz7NdYMApTeDheSgLShQeSy3T7QPBjEA9cpmqd9UwcLhjfnHs5VZMNFcxYgxdVqBiJnAXcjRKqf1VZAUq6"
      ; balance= 1000
      ; delegate= None (* JoeSixpack#9543 *) }
    ; { pk=
          of_b58
            "4vsRCVXonBfhQ1PFdZrp5bDJQLqw71hZnFHXVgL7sVMGpmZp1JAozYPEFh8JSrcwZv71TTVg25kUrPQUaHHe8QhZfjLQHJR3N881rnTv3YYSDMAXeLybzUCsnNc6EuekZnqLEG3StnqwJ6Pk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpEF1oezbSEC4j8fusDDbwmj4Y7AFTKfpT2qe59jEnwcpXtDmyVWLnHmyJ8iENbfznxotke5wtpdoWxm5yfc5zBSaUUM5P6P7hgwSqsFuUTtF8hjkuD39Wh5uG1kTVom2dDmcWXDFur")
          (* vires-in-numeris#5324 *) }
    ; { pk=
          of_b58
            "4vsRCVpEF1oezbSEC4j8fusDDbwmj4Y7AFTKfpT2qe59jEnwcpXtDmyVWLnHmyJ8iENbfznxotke5wtpdoWxm5yfc5zBSaUUM5P6P7hgwSqsFuUTtF8hjkuD39Wh5uG1kTVom2dDmcWXDFur"
      ; balance= 1000
      ; delegate= None (* vires-in-numeris#5324 *) }
    ; { pk=
          of_b58
            "4vsRCVRY17RV7NHfdERXQYqHrANY1Lw9FKxnC4oQf9zq3fcz2X1YY8T8JtCeViVc84GaxCzTxqpXXfZMyzgiLC7gqoV1MUyPvtjcKVjSkuGqfXU7UvL5ezoptnaiHVoNXNDpfXWDajnwSXtq"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVdK4DXPeebQhtf9JS37fzDXoEmz8qwMFnAaHwDARBAfVwqvsdD1M1sBP5mRHEjkcdBLGNKeTqk9UMC8G5itH1xdTv5LXyCXqAYCx8kbPvGfT1vKh4fy1d36nqdEBvSE3KLchsFCc5C8")
          (* keefertaylor *) }
    ; { pk=
          of_b58
            "4vsRCVdK4DXPeebQhtf9JS37fzDXoEmz8qwMFnAaHwDARBAfVwqvsdD1M1sBP5mRHEjkcdBLGNKeTqk9UMC8G5itH1xdTv5LXyCXqAYCx8kbPvGfT1vKh4fy1d36nqdEBvSE3KLchsFCc5C8"
      ; balance= 1000
      ; delegate= None (* keefertaylor *) }
    ; { pk=
          of_b58
            "4vsRCVJZ2vG6gZTEzGkcVHdeGDtSvRERHfogUiexekStJApF4QQCmEiXW3XPiLCeX3zGQDuTW7rrxGeLuSCo3y2XjaNpFqghbXeW2KAcn44XJdCm3BXc8zBGWSLs1QiJCVCFcwr1xDqqwN1y"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVj3nniFXKGL3N3vTA26rufiaRtDfVUG6JEhpCZBSTaE1fXJU5jgDvwLTiBQgjC1NymzkQmQXP7KSkeNZDJAdfRJCJGXeQd7yPBYET3sVPrELdC8LxwJMu3BxpECzHK9RhTzY9QXUvbQ")
          (* []☠[] 𝕮𝖔𝖗𝖘𝖆𝖗𝖎𝖔 [|☠|]#1216 *) }
    ; { pk=
          of_b58
            "4vsRCVj3nniFXKGL3N3vTA26rufiaRtDfVUG6JEhpCZBSTaE1fXJU5jgDvwLTiBQgjC1NymzkQmQXP7KSkeNZDJAdfRJCJGXeQd7yPBYET3sVPrELdC8LxwJMu3BxpECzHK9RhTzY9QXUvbQ"
      ; balance= 1000
      ; delegate=
          None (* []☠[] 𝕮𝖔𝖗𝖘𝖆𝖗𝖎𝖔 [|☠|]#1216 *) }
    ; { pk=
          of_b58
            "4vsRCVjTsPdAYoQXoFLNrfwmt7ts375ztuV1VDJnCZ93tMa39MRt6sLEqHDiKcdVWa5S7tBjkoLZ3vyH68XgGm85gG3jRwyX9EypCZsrQcR8MMRkPFRqFdGhoYU8L5PmK7zbefzj139T8263"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpV5DWeAs96wzMyYcxsgMPftk6YZBRg3vHTN8Vn1a8w3oEWKVw5Jp7Qbmr6qA6pcAtrPZXMxYTreBTqo1dyek91m8VVxRviQfsfdZY97hYzNA6GFN5uPedaf1o6zmHrvMtxu3aor1ji")
          (* ag#7745 *) }
    ; { pk=
          of_b58
            "4vsRCVpV5DWeAs96wzMyYcxsgMPftk6YZBRg3vHTN8Vn1a8w3oEWKVw5Jp7Qbmr6qA6pcAtrPZXMxYTreBTqo1dyek91m8VVxRviQfsfdZY97hYzNA6GFN5uPedaf1o6zmHrvMtxu3aor1ji"
      ; balance= 1000
      ; delegate= None (* ag#7745 *) }
    ; { pk=
          of_b58
            "4vsRCVyX33EhGpenwWqXdxE7eHRWkuW669A5cSdiznn49tr9n9NxgTEE4XCvaEcfrpj6wXZ6adnCFUuGdextU5yKGg4HAJv22rL7tq3D5ziXzMg4gmV73LNaA3SQruTvjNm32o2cNHGmkRKG"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVvetSbLpFmcfYX1R5Mzxv6d6WjqoQyh76hneFKzjovxEvzsWLpQdPdLqeQkyxRYCAiHV7g1n3oYtN7kdjCMKnPpPvWa4PaTz6Ht58EU8JCtFCymsjcgufUkLnw6urvrKJhaRNeNVtw7")
          (* hiro0322 *) }
    ; { pk=
          of_b58
            "4vsRCVvetSbLpFmcfYX1R5Mzxv6d6WjqoQyh76hneFKzjovxEvzsWLpQdPdLqeQkyxRYCAiHV7g1n3oYtN7kdjCMKnPpPvWa4PaTz6Ht58EU8JCtFCymsjcgufUkLnw6urvrKJhaRNeNVtw7"
      ; balance= 1000
      ; delegate= None (* hiro0322 *) }
    ; { pk=
          of_b58
            "4vsRCVmDRnTnvQdSVtU3qZsVWojnNYM4FehhoYwECV5q7jNoGELSNxuLgX7bHKEAPBQg23AtnPn7GgQ75KBpBwvnPco3ob8k2kdFNRc7CjBeTAxuy1mScQZdPE31HexSifC3LzfAt1p35cdq"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVi1g89BGiyWT4J7Ek3mGquYxSuxh8vCbxP4avqtjUv7Aywt3Jep6pSeAkUgx4SHBu6rUy2mCQEWEAbc3DmKk9WPPoaCAQ1ARbHuBvtN7H7oMoKerAATuZuGtReLkiHjcp88Qx4BXy8T")
          (* nshrd#3066 *) }
    ; { pk=
          of_b58
            "4vsRCVi1g89BGiyWT4J7Ek3mGquYxSuxh8vCbxP4avqtjUv7Aywt3Jep6pSeAkUgx4SHBu6rUy2mCQEWEAbc3DmKk9WPPoaCAQ1ARbHuBvtN7H7oMoKerAATuZuGtReLkiHjcp88Qx4BXy8T"
      ; balance= 1000
      ; delegate= None (* nshrd#3066 *) }
    ; { pk=
          of_b58
            "4vsRCVH2r9PMvEyYdHj5bTD6sGkARUYWe5JNBA8nhz8ppVBp2sZdAWri2KiEaqjtBKeGZ8ea7HpZiuF5bTedsx6WqU7RitghnHTb8VpbEyEx7TZeHLe1QeZ43fLWGbf6dhdjCC1qP67hXbtV"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVHHULiX5UAVkVV1oY9RLCM2MDVf69LXNnq5QesvvHdba7CDT3jnT4huGDB3zsBSJgyytKSbRJE8P9uB4nu7ejSwVMrcu3zmULFPMggVEJCPFuTV9Poxsrh5yhEGhM1mwMrR2C6W2X5p")
          (* SITION *) }
    ; { pk=
          of_b58
            "4vsRCVHHULiX5UAVkVV1oY9RLCM2MDVf69LXNnq5QesvvHdba7CDT3jnT4huGDB3zsBSJgyytKSbRJE8P9uB4nu7ejSwVMrcu3zmULFPMggVEJCPFuTV9Poxsrh5yhEGhM1mwMrR2C6W2X5p"
      ; balance= 1000
      ; delegate= None (* SITION *) }
    ; { pk=
          of_b58
            "4vsRCVJhG19NMFaDzf6WTZ4qxsKq1vSdhyCpjBoGAFp7JyaGt5heKkVJzJW9Tz3PbPoFN5avLhUWiW9dXnii1LodDVqNmhv73342CBK6SHUTU7fLsF7iDPsrt4jawRBJHPdZowwyHLom964M"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVyFJQjBoRJWX3rAfJoTXK77ZQTAcrzPxCtmukR4X8g9SPHq4qFaNUSPPmSW3GUfBU9xW2TET6m6AD9DXf72LZ4q8bb29dVJ1rmjaPhiHeJb42r2QfCaC14YTzvErmu9xZbpWUgmHGnf")
          (* Aawessels *) }
    ; { pk=
          of_b58
            "4vsRCVyFJQjBoRJWX3rAfJoTXK77ZQTAcrzPxCtmukR4X8g9SPHq4qFaNUSPPmSW3GUfBU9xW2TET6m6AD9DXf72LZ4q8bb29dVJ1rmjaPhiHeJb42r2QfCaC14YTzvErmu9xZbpWUgmHGnf"
      ; balance= 1000
      ; delegate= None (* Aawessels *) }
    ; { pk=
          of_b58
            "4vsRCVrX41j7BDJZ4BUCp9yeEz1SEZT2aaaXLjRhwiGCzm7hSWPXKEdvU1q6a8Ub2iWtEjK49YwCy5sXqDxXHaKfw6yLzQecNN3hEZgRt83bMVJMz7WH8ZkK4UpzcLkgQBrn2a974M14UUUC"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVfuyJwfp7rdA4p9ChUhHawK8UdWbD4uBkTEF8p7mrvKrxLcmu4cSkySYs7pYRH9Lk8yzijhfazuU1cAr1snP2aN7wupRSBZj2upRvzQqeXewngj1gepX1ALwZCdq2RodTKuKpFfpr9T")
          (* cryptohotdog *) }
    ; { pk=
          of_b58
            "4vsRCVfuyJwfp7rdA4p9ChUhHawK8UdWbD4uBkTEF8p7mrvKrxLcmu4cSkySYs7pYRH9Lk8yzijhfazuU1cAr1snP2aN7wupRSBZj2upRvzQqeXewngj1gepX1ALwZCdq2RodTKuKpFfpr9T"
      ; balance= 1000
      ; delegate= None (* cryptohotdog *) }
    ; { pk=
          of_b58
            "4vsRCVPw3L47L1mb21RnGja8hqTRQMFRXLpaRH8rfB78jCBhKZnt4rwDzp9VQ6fSaj5KukpupWNEEggMfw9Kg8kNWTuoMmj1EGeKDz1gyzJMqxnWuPWjcbeupYG71XmsSxWcAEE5mTwTNtFN"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVo38WDAxz7hteRJePURVpaPFpHx8C64Z64a5ppyNW1Gs7nqoUYUB1dDjDU2gbJNCj8Pwz4mGK466XaqfJzBXJnDgqRi1cXUdJSeDLAhWn1gSkzVPMiqHq82ZmCSeVSct3wamMBZbVhb")
          (* Saynana #0351 *) }
    ; { pk=
          of_b58
            "4vsRCVo38WDAxz7hteRJePURVpaPFpHx8C64Z64a5ppyNW1Gs7nqoUYUB1dDjDU2gbJNCj8Pwz4mGK466XaqfJzBXJnDgqRi1cXUdJSeDLAhWn1gSkzVPMiqHq82ZmCSeVSct3wamMBZbVhb"
      ; balance= 1000
      ; delegate= None (* Saynana #0351 *) }
    ; { pk=
          of_b58
            "4vsRCVaDomKg1mRFPXyergdiNhE7kXfqF81iXNam9ppcRE7SuiVVVUeRRxJD6MxhKFa6aVX4ra19hEGPCvXcNKgeFP1uNXHUFyzjB4j9a5Ztru9XPQ48woLJxgMwpUodJGcYEV95qq7fwuZ6"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVyi5kYxp25KrMWm7xBnkdBCpBrNbHVd3KLKy4oU4VN56vPLjABQZnrEzuMVcudLK3zJsayY6z9AMwMGXHryLDZhudDGCxcXktUyia1sqhzKoG6WddrbUUaBzVzYWcbJLkZS4aZe9D4i")
          (* WarFollowsMe#8044 *) }
    ; { pk=
          of_b58
            "4vsRCVyi5kYxp25KrMWm7xBnkdBCpBrNbHVd3KLKy4oU4VN56vPLjABQZnrEzuMVcudLK3zJsayY6z9AMwMGXHryLDZhudDGCxcXktUyia1sqhzKoG6WddrbUUaBzVzYWcbJLkZS4aZe9D4i"
      ; balance= 1000
      ; delegate= None (* WarFollowsMe#8044 *) }
    ; { pk=
          of_b58
            "4vsRCVdUmGkg751fZkEk8vPsqVqHPnEGpeJxTXSeb2orZT5KfJWfiYWi9SyceGEmHp1QZKVsuCGHeCG4cuWo9ddbk9B1e7aACC2qFEhnzKxdLXq3sKUR82qzEm1gaGTMs7V8qvNQEtsfn6yR"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVuBZpmcNUn5eUZMjtAxeipsg68KHTeZZtF6j7g8obAZHxhotnQKsWJVPoBdpo6JbNRYBRbi6Uv7fNxTroAdEp1W3wi1ZSe7e2JHXJHGVR9NsnsavFp1btVUdDQ28VSjnZKtL3nPXsqu")
          (* nelinam#2318 *) }
    ; { pk=
          of_b58
            "4vsRCVuBZpmcNUn5eUZMjtAxeipsg68KHTeZZtF6j7g8obAZHxhotnQKsWJVPoBdpo6JbNRYBRbi6Uv7fNxTroAdEp1W3wi1ZSe7e2JHXJHGVR9NsnsavFp1btVUdDQ28VSjnZKtL3nPXsqu"
      ; balance= 1000
      ; delegate= None (* nelinam#2318 *) }
    ; { pk=
          of_b58
            "4vsRCVcAdFSzRG63bzWwDAycwGfew8LYVE2aqf5EwUqWTyGeFKWizVH2w2Q7Lk6YDCRmBwswm6Ts3bH3WY5Sj1GTBJAnY6j731G2a2aDN7FqAjRs9JJCg4SoWmn3xfyTZbxTZ98R6hEpghma"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVyUS7wED8kJUnvCBBZNUuPB5XHUUcJeyeHhw8JzA8h3R8DUAFgqgFXXyZn7SSqn6n199cQigGGqmqSWjTB6Fzs7qPDzacXkkHVmABWbf9KxNU6xFoYKKELkvhSZzMNoYn9DpekzW36H")
          (* Cyberian *) }
    ; { pk=
          of_b58
            "4vsRCVyUS7wED8kJUnvCBBZNUuPB5XHUUcJeyeHhw8JzA8h3R8DUAFgqgFXXyZn7SSqn6n199cQigGGqmqSWjTB6Fzs7qPDzacXkkHVmABWbf9KxNU6xFoYKKELkvhSZzMNoYn9DpekzW36H"
      ; balance= 1000
      ; delegate= None (* Cyberian *) }
    ; { pk=
          of_b58
            "4vsRCVezBFhSUHQxceNfPEAyC8P3FLsaYy4CDYBLpVaiLs4siEM66GP2xgotMyct7DrQrhYzuHmt1GbQhmNP6MwqR6biJWe6gkfGGvzbH99i7gK5yUFkTJZDyK7ykroWuoTohF1mzbfEhh3S"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVv9hhHtidkF6YkXwEpn9W7vDWoFAPV7TnrLVe248qhPXNMzNttuPrEM12XvyToV3Jq3J3YupgWaeidgZeQzEiUX46X1nr6qUCtDJNanSf9TjYHJwAa6bL2yqsGL3c1jyi66GLs57H4X")
          (* Gunslair *) }
    ; { pk=
          of_b58
            "4vsRCVv9hhHtidkF6YkXwEpn9W7vDWoFAPV7TnrLVe248qhPXNMzNttuPrEM12XvyToV3Jq3J3YupgWaeidgZeQzEiUX46X1nr6qUCtDJNanSf9TjYHJwAa6bL2yqsGL3c1jyi66GLs57H4X"
      ; balance= 1000
      ; delegate= None (* Gunslair *) }
    ; { pk=
          of_b58
            "4vsRCVQ9mdbNXrQv8K5MR7up8JjUE6ixHJdeTqKGA2nCseF5tWT6fGaEZUNNUA7EBbUfXn8mNcbzPtrG6AVp6gQwtK9Uyf2A5fnPKPrg3bbh7GhnMtSDGhxyHZQAbaarXrBkjFJB54caT1X1"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVc3SoE8dxfqvUGB2EtWB8uuBRJEo1KQBXgWdqdgg3b9ScxkQxmQKAywoo8XUTcTxr8r2kf3p6CKn1UCXgY5x7HCfWWFxqLBdDKMRHb8arU7RPFyRuj52LkP4gZ1pqp9mydNFeLEPay6")
          (* Jordy#1249 *) }
    ; { pk=
          of_b58
            "4vsRCVc3SoE8dxfqvUGB2EtWB8uuBRJEo1KQBXgWdqdgg3b9ScxkQxmQKAywoo8XUTcTxr8r2kf3p6CKn1UCXgY5x7HCfWWFxqLBdDKMRHb8arU7RPFyRuj52LkP4gZ1pqp9mydNFeLEPay6"
      ; balance= 1000
      ; delegate= None (* Jordy#1249 *) }
    ; { pk=
          of_b58
            "4vsRCVW2q8Lyz4rNxvHwG8Q3B34ocmrQhXQkSnhDpmNEKHKkwKRqaHt2Kd8iZNyqsX72kb2hZW85FPfpNBdZxf6ZuhruNZ7ZayQhahGbDyfTL5AijRiFKiegNxNKUcqByYVPjHaF4N8iKnCm"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVFn9S9dUcQCMEoo9kjpvHHWb9WGue733NYb6WEkZYTiSzVe1uAfpxM54xsrup6P4QFS5kGfXGsiKRxSAnrvKLD3mit8VEnVTR67Rdpwr43T3n3FexW6QWbMfQ9qURy5jmJGxCtaZT4o")
          (* nick cloudpost#7139 *) }
    ; { pk=
          of_b58
            "4vsRCVFn9S9dUcQCMEoo9kjpvHHWb9WGue733NYb6WEkZYTiSzVe1uAfpxM54xsrup6P4QFS5kGfXGsiKRxSAnrvKLD3mit8VEnVTR67Rdpwr43T3n3FexW6QWbMfQ9qURy5jmJGxCtaZT4o"
      ; balance= 1000
      ; delegate= None (* nick cloudpost#7139 *) }
    ; { pk=
          of_b58
            "4vsRCVHFdySoJLmxYBJ1cDZkNDSnT42F2YAhWPofqkRDRK6ugEzTfruRXrz84pyFUgiGVoeUvAnDZpyUXq2ziDNz5qk5R1fn6dEDKgDCkWioRiAoMN4EgJixKaLudYDS5GjEkCAK7YHzKpos"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVzakqjuwFegNJQjh3HvognfhPMAG9dJC6Pa4PmyrPfrPgeDdWpUjMtUtynjVEzZrgBdTZsv2w7NFaLtD3Xq5NA1Urto27EJRhr99aUCaoqLuMZZNbmbsfCUEXuNKHdFRH1fXeLsLjiu")
          (* Alex | Masternode24#0722 *) }
    ; { pk=
          of_b58
            "4vsRCVzakqjuwFegNJQjh3HvognfhPMAG9dJC6Pa4PmyrPfrPgeDdWpUjMtUtynjVEzZrgBdTZsv2w7NFaLtD3Xq5NA1Urto27EJRhr99aUCaoqLuMZZNbmbsfCUEXuNKHdFRH1fXeLsLjiu"
      ; balance= 1000
      ; delegate= None (* Alex | Masternode24#0722 *) }
    ; { pk=
          of_b58
            "4vsRCVMFubYTrQwwS77duAjHRfSNmpP5TfD6SHG8GApTwuo8cgZQ8ptzNzsVJegJ6xXuGgmtN9dEaNZRTEWtYCR5QzYWGoPuWh6oKGbrkAMWZfuf6Bwk1h2HQWrxrtePko7Z7N2QjZvuabpM"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVp3ZyeC1YYqfi4gTN8WH2JTo9aypkGrEmmcMeNK9dGLBN6SAaH1WAKsjwoWtiku8Zj1s4UemYzmMN2z9arZPMVAyYxSWQLjA7DjnS3nVaCivtdtqjcj1tBFEKeVwQ5r6M22BRWdMTAE")
          (* jp#1540 *) }
    ; { pk=
          of_b58
            "4vsRCVp3ZyeC1YYqfi4gTN8WH2JTo9aypkGrEmmcMeNK9dGLBN6SAaH1WAKsjwoWtiku8Zj1s4UemYzmMN2z9arZPMVAyYxSWQLjA7DjnS3nVaCivtdtqjcj1tBFEKeVwQ5r6M22BRWdMTAE"
      ; balance= 1000
      ; delegate= None (* jp#1540 *) }
    ; { pk=
          of_b58
            "4vsRCVf3DYeBuMBFuAH3uL653eFHrvZLSNqZrjKkKP41fNccoSZ1E7F1AeMK64GxyNqhAofng6PA4GyWyXBPrc43nB9vtdstMQwZeEZWXJyGk37P5qGHKyo5jLT4JJV9nigCmnF614jzSZHr"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVYsVLBu4owj8Bt9SzdAEKZcncHgS9jQ5tmuxTwfPx8QJP7tXwbj1mNAo575nmRbpECzTyE5G4br5nz98HWW37S2YUtGnULBEd29mCuEkfMrx8qfJdd3Lm5uGPtDUz2ZDgLfLBZ5ePKP")
          (* bender73#5737 *) }
    ; { pk=
          of_b58
            "4vsRCVYsVLBu4owj8Bt9SzdAEKZcncHgS9jQ5tmuxTwfPx8QJP7tXwbj1mNAo575nmRbpECzTyE5G4br5nz98HWW37S2YUtGnULBEd29mCuEkfMrx8qfJdd3Lm5uGPtDUz2ZDgLfLBZ5ePKP"
      ; balance= 1000
      ; delegate= None (* bender73#5737 *) }
    ; { pk=
          of_b58
            "4vsRCVwxsRevve6jrZ9dEGmfuLUTzCGGe2dFHFAtqSAGngoFamp5Vbqjfo2seJT7i6KXvPVBVFLZ3tPyhTmb9otbWGoAz4KTUX6m8MQd6Zwbk6ewvgPV3Pz945rzZX66QHNHxZ7RcV9pTdhk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVTM6TdRpLP82LmKamuuqn6Vb6h6kvMPFHr1oGsezCftm2LWDj7yUc6wUfQKB2kZStySQCTZ2L4vya9XCr633ZdReQdWR2ftcHK7b4EJ1ALJ746EGYomh4Krc1nogKSzpq43vYp5aWMj")
          (* inv0ke *) }
    ; { pk=
          of_b58
            "4vsRCVTM6TdRpLP82LmKamuuqn6Vb6h6kvMPFHr1oGsezCftm2LWDj7yUc6wUfQKB2kZStySQCTZ2L4vya9XCr633ZdReQdWR2ftcHK7b4EJ1ALJ746EGYomh4Krc1nogKSzpq43vYp5aWMj"
      ; balance= 1000
      ; delegate= None (* inv0ke *) }
    ; { pk=
          of_b58
            "4vsRCVyRD5jLKitRtAbbgiVJrsVcaLjnU44435CwH54eYurf3JaTMMT3JGmwnz7LS1BFjADzBY8hXtnuJXLvmjR4RYMtRWkvpVNy1vfgX57pKtb5RmfsZxswygFnd1wE9zXf5th1zURzPfPT"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVQdWnMou6FPPGmAgXpcDuPE5c2UfrdaXAv9CbSrRH6v4iXt9LoWFH2jWfseWUCsjZthjxNirk2qn2AUsyKeFdFfFHp6nXbXWtyL4Mb96rfUKrNiLLWau25dtrJwPV9ETGvTdyYnUGJH")
          (* Lutkarma#2218 *) }
    ; { pk=
          of_b58
            "4vsRCVQdWnMou6FPPGmAgXpcDuPE5c2UfrdaXAv9CbSrRH6v4iXt9LoWFH2jWfseWUCsjZthjxNirk2qn2AUsyKeFdFfFHp6nXbXWtyL4Mb96rfUKrNiLLWau25dtrJwPV9ETGvTdyYnUGJH"
      ; balance= 1000
      ; delegate= None (* Lutkarma#2218 *) }
    ; { pk=
          of_b58
            "4vsRCVrKgfj9AdDjKthRPw5Pu3CG1hpDFPwgeVg84gqYsnL63tQhei7yaHt8XLhBsjoPiNjUnVQGJvKD8ADxPDYmhUUoZ3aYkEDrABsa7aexkazr8bvcGBgchfAoQPxErTgZwCrgwFwQTtHT"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVjnd2E2yctsEzt6QsownL9rAYA9ex4RiXquherq45CYtJZP3cK1uhqUxD1yDPGKVBAUbR4umsmcCPtiXwpMou7qgp5Dm5jDaacdyT9A2HsoN4N1qK4WBS4YZc3xdr1PV9LHvBz5h5ay")
          (* TLA#0318 *) }
    ; { pk=
          of_b58
            "4vsRCVjnd2E2yctsEzt6QsownL9rAYA9ex4RiXquherq45CYtJZP3cK1uhqUxD1yDPGKVBAUbR4umsmcCPtiXwpMou7qgp5Dm5jDaacdyT9A2HsoN4N1qK4WBS4YZc3xdr1PV9LHvBz5h5ay"
      ; balance= 1000
      ; delegate= None (* TLA#0318 *) }
    ; { pk=
          of_b58
            "4vsRCVtapnDpXUUJxfqacr6MMVPT2Zcfud6dUh1RX5EZh7yuoT9e5WjiCYX34sDHQPV6QZ4AXbk4FJYdpnCnJqp5PfsczErFkESL3WLSSY9yMC23cezyk6aBcSkp1oruFxX9Q9ruW2VhfdQG"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVwpuKTKMs2UZint222LYUSxjiSnutwnMGH94VgS19H2Hn8CGo48GMe7CuVLjAN1edA5DPSJzrN5G6SeYsxneZc7KhcUZGzhytGMhDpFRcN26QhtYNb6xY4pgsGpKVjioYiYQvXUBZim")
          (* Chromatone *) }
    ; { pk=
          of_b58
            "4vsRCVwpuKTKMs2UZint222LYUSxjiSnutwnMGH94VgS19H2Hn8CGo48GMe7CuVLjAN1edA5DPSJzrN5G6SeYsxneZc7KhcUZGzhytGMhDpFRcN26QhtYNb6xY4pgsGpKVjioYiYQvXUBZim"
      ; balance= 1000
      ; delegate= None (* Chromatone *) }
    ; { pk=
          of_b58
            "4vsRCVd9HU82poB2RnDnD9vactwFp4SZ63BCHJxBe1y8b9yGydYWCyhugMZqPAoyvZXkSqnJwnqnKbuKAgisHKPDWPxQEREJZhhBDZWhioMv6RaWgd1AH55bKtiuGRTKDArd3rjasrHtyEf4"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVLKbYx2LFMMjJF2DVmZBxyfom5GFFPHNDw9PhBH4cqosbpj8uzPhbUiQfMZ6Rv3HbtUTB4YNggk3pC4NEad86vr34sugGo7DCfAxv7UYkoWwxoQEbpcfhZt1fxXdfUuWmu8L8oJHoTx")
          (* jiyeon *) }
    ; { pk=
          of_b58
            "4vsRCVLKbYx2LFMMjJF2DVmZBxyfom5GFFPHNDw9PhBH4cqosbpj8uzPhbUiQfMZ6Rv3HbtUTB4YNggk3pC4NEad86vr34sugGo7DCfAxv7UYkoWwxoQEbpcfhZt1fxXdfUuWmu8L8oJHoTx"
      ; balance= 1000
      ; delegate= None (* jiyeon *) }
    ; { pk=
          of_b58
            "4vsRCVfJvbF1oLFQeYXUgzmfW59mPzaAhbo5yGGpzhoiCTs2BuNXZGrviS2rWGQNttSZUjUJJF5wGjePo14jc56Z9u2V2apF3DcFcJwn14eJSt8Fxv74HXYDG8J3YzhWTyKmuhHNLYZQCkrd"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmNQ28aeXgfUxrSBggdqw4e5EUyUxUzHsAyDyRYZL88zPJop5TwAY8maqbup1g35kdyStHK7wARvAzF6EBugbAk1xLZ6EwjhE3uhVXbTC3aER3H3kjwAjqKtmx5L9NmYDmRcpMMbYjp")
          (* jjangg96 *) }
    ; { pk=
          of_b58
            "4vsRCVmNQ28aeXgfUxrSBggdqw4e5EUyUxUzHsAyDyRYZL88zPJop5TwAY8maqbup1g35kdyStHK7wARvAzF6EBugbAk1xLZ6EwjhE3uhVXbTC3aER3H3kjwAjqKtmx5L9NmYDmRcpMMbYjp"
      ; balance= 1000
      ; delegate= None (* jjangg96 *) }
    ; { pk=
          of_b58
            "4vsRCVnLjWatSCEVMtTWi4NzLgsLDBEauSuoyWX3Pvj9uyudthvoHXgLrVPfM47znBLrxKdYvjcJUgqeswoMAGAByLqHeGQKx35F5pLS5QgaHzbocgeUBG8Hi4f2qhpXr3WrctzEDmQm5gTe"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVyaGfDRehbSGw3Ucz9yaLeomSoLVR43f2DvxBxkifEoRYiy9bzU3L9wm2EJu3nJivt2zivdLhGLy1Jzj8W6KvS38g3enHrhEcreszpBc13m7pJZKmQDZE3uw8wSXweAEBZKBKLBDonz")
          (* whataday2day#1271 *) }
    ; { pk=
          of_b58
            "4vsRCVyaGfDRehbSGw3Ucz9yaLeomSoLVR43f2DvxBxkifEoRYiy9bzU3L9wm2EJu3nJivt2zivdLhGLy1Jzj8W6KvS38g3enHrhEcreszpBc13m7pJZKmQDZE3uw8wSXweAEBZKBKLBDonz"
      ; balance= 1000
      ; delegate= None (* whataday2day#1271 *) }
    ; { pk=
          of_b58
            "4vsRCVLBpLqESr6N2uJBzA15WniYjM3prCTxDWjNwGQUnxPsVemnoVQeA3EUUB34bqQLed36csJLYn4pUfksoyeKWCniSNU2GSC3E7WDBo24cDsKjcat1Nd2Rbcjw5iEwCAykgtir1q7kxPh"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVZNWRNK5x1TbNrGq26Aw8duAY5DXYiZV5JiigC6dTc3XSqXpjiBD97PZVBzbXCV9Md5M68Q1eXiBwN6rvee4EezUxFs1cy7DUf9Yjpyo5vqe8xUgHA9t6KA9roNaANQK2h2CvWqBDHm")
          (* Natalia#3647 *) }
    ; { pk=
          of_b58
            "4vsRCVZNWRNK5x1TbNrGq26Aw8duAY5DXYiZV5JiigC6dTc3XSqXpjiBD97PZVBzbXCV9Md5M68Q1eXiBwN6rvee4EezUxFs1cy7DUf9Yjpyo5vqe8xUgHA9t6KA9roNaANQK2h2CvWqBDHm"
      ; balance= 1000
      ; delegate= None (* Natalia#3647 *) }
    ; { pk=
          of_b58
            "4vsRCVaRo87qwkfDvLL2Yf7DPYhVwp8yc1rVfgdiTWvCQNt9z9Bt6JrusoU6q1CdQuygu6s5UdhUun2kzuKzQqw7GsA95GgMFybR8JqELegLd5eH2LJUYZDywPnk1rQKNyCDhMiKHTotNsom"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVaM7jZJSQVF6f7ZXRMJPMkfdy9WBhdboP5mSSrhKkfm3erzxZ9uBzrurhhcFgAgi5md1NDUewadmxAZobcKpAEZsAN27UzUxPRQCLTrA5huBXDTi57cJjrPDRpBSuAPMEuJhP7jcrt3")
          (* bluefroq#3279 *) }
    ; { pk=
          of_b58
            "4vsRCVaM7jZJSQVF6f7ZXRMJPMkfdy9WBhdboP5mSSrhKkfm3erzxZ9uBzrurhhcFgAgi5md1NDUewadmxAZobcKpAEZsAN27UzUxPRQCLTrA5huBXDTi57cJjrPDRpBSuAPMEuJhP7jcrt3"
      ; balance= 1000
      ; delegate= None (* bluefroq#3279 *) }
    ; { pk=
          of_b58
            "4vsRCVaNDTN2d6rhQFamswLgdr5ZMt9b21t1k5fqKrFuSZjaHsLazNpizpPuBm5hA5vrZwy6tK7nvrphcJ1CBdVrm248X7j1qzoAb9DAf2JmjmfwTjWkxrogjwt83UGJdBEh2mmAZuNyRZZ1"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVQ7KcNaZuUpow4kjUJ5jxjauxrc9cdEcRV8kpn2PhaMWnDqMj8iueHw1ZS7nHkk4QDuzibsNmbuxrEpjtx1DvhBjFyQYXaAoryvBFMN19cNds3vptfiQNkYwdmcSVL5KoXRoLU18cZc")
          (* []☠[] 𝕮𝖔𝖗𝖘𝖆𝖗𝖎𝖔 [|☠|]#1216 *) }
    ; { pk=
          of_b58
            "4vsRCVQ7KcNaZuUpow4kjUJ5jxjauxrc9cdEcRV8kpn2PhaMWnDqMj8iueHw1ZS7nHkk4QDuzibsNmbuxrEpjtx1DvhBjFyQYXaAoryvBFMN19cNds3vptfiQNkYwdmcSVL5KoXRoLU18cZc"
      ; balance= 1000
      ; delegate=
          None (* []☠[] 𝕮𝖔𝖗𝖘𝖆𝖗𝖎𝖔 [|☠|]#1216 *) }
    ; { pk=
          of_b58
            "4vsRCVhz9AtXg4pR6EaGk9Acbq7LbviGKn9qU2h1uVkNCPhHSLtuoJcrzksNW8Cax1pKseNVThAoC4WWQhn3uD6RoATrHnshKc9nnwxG3rL89ybtfqAB2WfBfehyAQsMRTF8qGErrZQaNM77"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVVhXjp6ZgWw1iCEA2vfkGSPk9XvavaPK99HpfXqF6yB9tzVnZahucsCsgvYR8LqdBfWwKktjCBVcbjvitotagJ6LUJNo4xZkmv7vt4HtnhsYu3UrFuw9QT7sgGNhMowmzX2pcjuikwA")
          (* dakuan#6810 *) }
    ; { pk=
          of_b58
            "4vsRCVVhXjp6ZgWw1iCEA2vfkGSPk9XvavaPK99HpfXqF6yB9tzVnZahucsCsgvYR8LqdBfWwKktjCBVcbjvitotagJ6LUJNo4xZkmv7vt4HtnhsYu3UrFuw9QT7sgGNhMowmzX2pcjuikwA"
      ; balance= 1000
      ; delegate= None (* dakuan#6810 *) }
    ; { pk=
          of_b58
            "4vsRCVRr9z4NEkf8EPwYbpjRJxQycJpAQhQ7Viq5dRvf4mPSQfUWvxZ75uYdy2qVK2VDMnY5fXrpmF2w6ks7YHmYjeGSjDRNno9MQYCWPJJFBg4oXEerABwfVtUqYhg5HVUwwvDUXnvuyUYe"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVTdnwGB1pZTqpU43L73qcZ7BDmELqvkLcGo1i135xKBNMAQSm4MeuzVNCn8di7x8x3YFcUK6ftqeGvfRqMvhuiWHQSsWHTgBocDt2ae8rpbHsa1YuUdcZ8DSqNrAd1Bf26DNBg1u7A6")
          (* machin#3911 *) }
    ; { pk=
          of_b58
            "4vsRCVTdnwGB1pZTqpU43L73qcZ7BDmELqvkLcGo1i135xKBNMAQSm4MeuzVNCn8di7x8x3YFcUK6ftqeGvfRqMvhuiWHQSsWHTgBocDt2ae8rpbHsa1YuUdcZ8DSqNrAd1Bf26DNBg1u7A6"
      ; balance= 1000
      ; delegate= None (* machin#3911 *) }
    ; { pk=
          of_b58
            "4vsRCVwDaVNRKTj2SsgKYkqv5dQsbTid61qHkr4CtryLUiM4RubWNhz6YBWgW35Lmuj8npy4iw7xYuW13Zbuv98t7yzsPcWfhy4txkUUC4SDX8KMF85yxArGtDenpYjBNUBtu9kcDTSUtNt6"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVaaMEaSW4icTqMWNkaaqw5CsupSUygkVQCG1QCd5sG76LbqqzZHofK2kczAHYSbWAL7juycrYQ43VxPJ4eXFqmbdsknQU7ycFaYEEEjPAudSAHYxazAqrWZrM2yrGusTJiqWFDqcTLK")
          (* Oszy *) }
    ; { pk=
          of_b58
            "4vsRCVaaMEaSW4icTqMWNkaaqw5CsupSUygkVQCG1QCd5sG76LbqqzZHofK2kczAHYSbWAL7juycrYQ43VxPJ4eXFqmbdsknQU7ycFaYEEEjPAudSAHYxazAqrWZrM2yrGusTJiqWFDqcTLK"
      ; balance= 1000
      ; delegate= None (* Oszy *) }
    ; { pk=
          of_b58
            "4vsRCVWmE1Ma8kzBJArCbkg5CaaQ633ZzYrgBKVJh4BhN2bRmKWumzQfBCmJgGnLwD6dCpzs3Yd3L7jBqRHDZwRbgHKGbRbky7EnpVi6iX9RbUVzS1RFQSCSwpT7dWVZruoK15g6oy2TyRFm"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVuidFSRoBrHQSkNEVT7tTn4FwXQsnj7HeHs534kUM9gEVdGyXGk5NDs4q7jEQK9das7qc9CvpMmnkDJygxt5kA24BmaFfvAhpZBr5z1Ba34oAN2RbCiQXREykjm7eUQmWkL2N4UeB7N")
          (* tylersisia *) }
    ; { pk=
          of_b58
            "4vsRCVuidFSRoBrHQSkNEVT7tTn4FwXQsnj7HeHs534kUM9gEVdGyXGk5NDs4q7jEQK9das7qc9CvpMmnkDJygxt5kA24BmaFfvAhpZBr5z1Ba34oAN2RbCiQXREykjm7eUQmWkL2N4UeB7N"
      ; balance= 1000
      ; delegate= None (* tylersisia *) }
    ; { pk=
          of_b58
            "4vsRCVxjHfYWCXWRSFQARnzqegUzYYeaHwFay1ejJcwFeDxr629tSudGxwLpFPpnJdbtxs9WnWLMcufdt7UhaR9RJNS7wN6iEsxuojwDbhH7yusztNk6GmtgLjzvmmBJvL9SzisVmJm4Jds1"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVb7yfps4BGG7hsMsGWhNU5a9UaDAACx9ziXGHQSj69uG62H5kg3ZnEa3JYzS79vyW4TDy8vgzA2KS3M96G7RTVNSnpwdzsjmxNXJmhU7XnwMGxQEZ8RYaWcRKrmdT6FBSgjX8W8bjBm")
          (* kubi *) }
    ; { pk=
          of_b58
            "4vsRCVb7yfps4BGG7hsMsGWhNU5a9UaDAACx9ziXGHQSj69uG62H5kg3ZnEa3JYzS79vyW4TDy8vgzA2KS3M96G7RTVNSnpwdzsjmxNXJmhU7XnwMGxQEZ8RYaWcRKrmdT6FBSgjX8W8bjBm"
      ; balance= 1000
      ; delegate= None (* kubi *) }
    ; { pk=
          of_b58
            "4vsRCVZKQ2pdKPfUZFTn9vHQC2AV3KoKSq5r1tau3afvAp2HSD8v5aLYKh75Q9cAuLSQQpY8mXrgJ447eRN2uTPkjE1KaV1ty5i7Tge6NYzHv9vfE8DF5bV2WoBBgo2yR7bVpVi5zQSPV6zE"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVRpEZmEBJbDp4A3xBbmLvSyABwW8DTVfmg2nGVgZViLHZY2PyS6EXd7YyuMtBZKAcBKTJqCSwVJEUS19TXc6SvguqHgVhRQh7tdezyDcNVg1gN9FhCUdQTArpy7hvBCq5Ugd38u8RWQ")
          (* Alibaba#0280 *) }
    ; { pk=
          of_b58
            "4vsRCVRpEZmEBJbDp4A3xBbmLvSyABwW8DTVfmg2nGVgZViLHZY2PyS6EXd7YyuMtBZKAcBKTJqCSwVJEUS19TXc6SvguqHgVhRQh7tdezyDcNVg1gN9FhCUdQTArpy7hvBCq5Ugd38u8RWQ"
      ; balance= 1000
      ; delegate= None (* Alibaba#0280 *) }
    ; { pk=
          of_b58
            "4vsRCVUJdXE1CgmLfme9CDUXTcfVVEfSXksFQEzzCbUCrSQQN5S6FWzAKN86bCVCDC1JykiDceFzsEsVTig36nrQ29c3QoumXEh8S2nUCCrvmwrufiMcy7Gbzs8dwvzGUAJB23dhdfFaE2Zz"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVw8qeFHYwfb1jaAXrwQRZUyJUTY6YjWunifDaYeHHbwdELmGKjwnMZN7ScQ1vSk1GT92uXf9kHNQEikBu2fhrdELoSNVgVtZyfNUiyCG9KuUYTjffTUtWCnXW63VLpquMbKi56gtu5E")
          (* Julia-Ju#1812 *) }
    ; { pk=
          of_b58
            "4vsRCVw8qeFHYwfb1jaAXrwQRZUyJUTY6YjWunifDaYeHHbwdELmGKjwnMZN7ScQ1vSk1GT92uXf9kHNQEikBu2fhrdELoSNVgVtZyfNUiyCG9KuUYTjffTUtWCnXW63VLpquMbKi56gtu5E"
      ; balance= 1000
      ; delegate= None (* Julia-Ju#1812 *) }
    ; { pk=
          of_b58
            "4vsRCVd2RXkf5P8U5pRJUfnyek3KiChJL3qAmZCUra612U3vBSn3hAGFswXUNfZaJ4279j4TMEcsUgZrt4MgqvQHtzmZs6Uy9pHXjBoHHFKwGU22jCwcwfYx64M2P448ZYQYYqU6FErDmUcW"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVt1g2ukXTtsJp8fGwnNG1XFiATFrzqnNWMNpFbbTmy3DRmQw3GGX9UiyQvkKzFZgXJZerCv6EitU2iyRdY5R3Vq9wChiM5KrkUKVV5c19bmaAj4VVDgdAmckuwnMjMabwkdc5oDpoQz")
          (* tragenmi#4113 *) }
    ; { pk=
          of_b58
            "4vsRCVt1g2ukXTtsJp8fGwnNG1XFiATFrzqnNWMNpFbbTmy3DRmQw3GGX9UiyQvkKzFZgXJZerCv6EitU2iyRdY5R3Vq9wChiM5KrkUKVV5c19bmaAj4VVDgdAmckuwnMjMabwkdc5oDpoQz"
      ; balance= 1000
      ; delegate= None (* tragenmi#4113 *) }
    ; { pk=
          of_b58
            "4vsRCVxv2oM2tHGk7oRAdNtMRefe41sN6XmrkQw6MzVjqjotKjgrDJnkJat6qddMizPi6YgUVkH5Rkau58QFiEDy3YRMGq8xc8H6Q8Fr4EvCLUthhj6ABEbt9WAi94CcGyFhwVhyCcre5g67"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVWSMBAvg2kS1tsGKWi6MCN1bJTYGp95XnT7xsRUPWheucbhYrnjmV2ppESSS1EzckdB2X9Kpsj9w8VxNHhfRaZexuWRQ3hggu2H8FVhRB1gQQTncanVAPcNAhFfEWzq9Fz8arousUuZ")
          (* Woiketsuni#4824 *) }
    ; { pk=
          of_b58
            "4vsRCVWSMBAvg2kS1tsGKWi6MCN1bJTYGp95XnT7xsRUPWheucbhYrnjmV2ppESSS1EzckdB2X9Kpsj9w8VxNHhfRaZexuWRQ3hggu2H8FVhRB1gQQTncanVAPcNAhFfEWzq9Fz8arousUuZ"
      ; balance= 1000
      ; delegate= None (* Woiketsuni#4824 *) }
    ; { pk=
          of_b58
            "4vsRCVS4ZzEGdtSMZnzEbZcKdqxxobHxpZrdagP1HJZngjeyWiUY14SfmBCZcX5feU5DoDs4LPBUQXEURK2gW97CoHWL3GLJM3o5n1uqF9wKaXWqWSVbo4KYck5U4MjvbCbpN9X4YKhqE6jg"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVs75TKa14DztB67JHqb43YSvW4xST5sj26fh5ctSpMM2gignYRit5NrApR5M4R7BgUicpgUUq61AQNzdbciuXPzFAMHweKpVMyXKhCGj44e27QUvy94pCAUfKVHW6THPHWoPYy8yqdt")
          (* Wanderer#1042 *) }
    ; { pk=
          of_b58
            "4vsRCVs75TKa14DztB67JHqb43YSvW4xST5sj26fh5ctSpMM2gignYRit5NrApR5M4R7BgUicpgUUq61AQNzdbciuXPzFAMHweKpVMyXKhCGj44e27QUvy94pCAUfKVHW6THPHWoPYy8yqdt"
      ; balance= 1000
      ; delegate= None (* Wanderer#1042 *) }
    ; { pk=
          of_b58
            "4vsRCVmUsVBZ4ZcBWhj15vdTupu6JGtxYjGqBJf44Z9H4ZMLWG7DsMHKzg16cJu3Xma5NBGxXzBbSufRQNmkGNBfxkNKjNUg3yfLNY9gV2my4wB1asQcWPKegpAdN9rLhk5wbrH9ETkWMs4M"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVMiB69EFzi6JijtFDvnK4VT3p6nKv89tBeFNLit17hhh9gE7rEj5FPqARV2KvVTFcHKTcKqrTt8rsVG6timVX7EetuAprnYKZ3u1rc3zsdrPtXvqMtrLVovFHzsBTtdabYQqKHJ9xKD")
          (* kumosoukai#6453 *) }
    ; { pk=
          of_b58
            "4vsRCVMiB69EFzi6JijtFDvnK4VT3p6nKv89tBeFNLit17hhh9gE7rEj5FPqARV2KvVTFcHKTcKqrTt8rsVG6timVX7EetuAprnYKZ3u1rc3zsdrPtXvqMtrLVovFHzsBTtdabYQqKHJ9xKD"
      ; balance= 1000
      ; delegate= None (* kumosoukai#6453 *) }
    ; { pk=
          of_b58
            "4vsRCVyKSCNXZYHg1sUJNiahsMie46eEypmZoR2n83hnghSibpo6qYr5CsoZVtXYowo5Kbagzxi5qVxgAoekYBf5LQEdbYLQ5sLuatQTqaVDr3sEwre6ec7rdFmD5qZaJ6GFSqoQS4NUhmio"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVPPvnRGf7VMvEyAPrAPMLMLcGMEBgUgRVEuPvwLpV9YskiGmWstQ8JK9Us4HzGDiJmTW8qa18kByFNejn3JRPeDuRw6AKtHRz25bkaM5A5vDGNHSMoBSShoQs62gFhbdJyVe22YmTNv")
          (* Breather#0955 *) }
    ; { pk=
          of_b58
            "4vsRCVPPvnRGf7VMvEyAPrAPMLMLcGMEBgUgRVEuPvwLpV9YskiGmWstQ8JK9Us4HzGDiJmTW8qa18kByFNejn3JRPeDuRw6AKtHRz25bkaM5A5vDGNHSMoBSShoQs62gFhbdJyVe22YmTNv"
      ; balance= 1000
      ; delegate= None (* Breather#0955 *) }
    ; { pk=
          of_b58
            "4vsRCVgqmnU3xVkpAWg6r4U3cQg7QyjFiAycMzzQtPEqXFHFqGYXzdrxJK7UXKLqnYxjewNYDruecpsnwpXQHU6UQ2xkaQ7gXy7FMWUGqDCijCoouE2z3zSDufjHtrCNFzdDF3QsNis1tK5r"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVwh5YJbGTHe5Dg1t419uam3GpBY3iG7JM3AFxv1z1fHbQxVNk2mszYFerocLPYwPeXzgY7n2ji8pZKPfN7Q2HTNxK7hzKjxv34wExNSwe6myzBa9AqWDfv5SNiR2MbRWvB7zLsfPedH")
          (* skh10 *) }
    ; { pk=
          of_b58
            "4vsRCVwh5YJbGTHe5Dg1t419uam3GpBY3iG7JM3AFxv1z1fHbQxVNk2mszYFerocLPYwPeXzgY7n2ji8pZKPfN7Q2HTNxK7hzKjxv34wExNSwe6myzBa9AqWDfv5SNiR2MbRWvB7zLsfPedH"
      ; balance= 1000
      ; delegate= None (* skh10 *) }
    ; { pk=
          of_b58
            "4vsRCViYWWwS7fEbS91ZJ2CMURrCVKdSGeJax3huD4atHgr2g5pnD2eokAhD5ss2PmBqCKHf77cDnxdWfXBSEnaQamTkynyKSNMtbztecJtXufUxfQRgG3JUYvPNzHcncHmbCBn9ybesphaf"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVMrAp3TfBZeFdRk3Hx7Tig9pVWrC5He9FnX6vW9tVVa2pgsKRe8gmTaRaffrRVS87he1hQF4rf1rDAB99ocV6iAExjCBz3AJBzcXmMAekjxSBvpHSYjYmd4GY2dz6fJLnBmNMyJxqJD")
          (* lqyice#5944 *) }
    ; { pk=
          of_b58
            "4vsRCVMrAp3TfBZeFdRk3Hx7Tig9pVWrC5He9FnX6vW9tVVa2pgsKRe8gmTaRaffrRVS87he1hQF4rf1rDAB99ocV6iAExjCBz3AJBzcXmMAekjxSBvpHSYjYmd4GY2dz6fJLnBmNMyJxqJD"
      ; balance= 1000
      ; delegate= None (* lqyice#5944 *) }
    ; { pk=
          of_b58
            "4vsRCVmyuCdnpXTUTmr4W7jTijJxxHRZxpk6fz6LtvF6QjqFgiNw2ULEYNRFSzN3FeiPJJ4kmjJb5SoCdFGyobUxkXSprd8eRap6YV94CiY7tVgXUnCDSwJVKSSF6MB6MYktxyLqKKDB3zqa"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVpqsssyUTXCYRVTytGMtTgqNdd1idE3eKc89CNkQv7JcnpN85MiXiQDT4F2eFAqac3fmcLwwBpVvcF7H3uUVvJjQsjnU6YvEfTXWmqZw7FxMNnBLyJnvLJL5z1Ghhv9wHEZpG3EWWAw")
          (* Destroyer#6296 *) }
    ; { pk=
          of_b58
            "4vsRCVpqsssyUTXCYRVTytGMtTgqNdd1idE3eKc89CNkQv7JcnpN85MiXiQDT4F2eFAqac3fmcLwwBpVvcF7H3uUVvJjQsjnU6YvEfTXWmqZw7FxMNnBLyJnvLJL5z1Ghhv9wHEZpG3EWWAw"
      ; balance= 1000
      ; delegate= None (* Destroyer#6296 *) }
    ; { pk=
          of_b58
            "4vsRCVzwPqXFK3enrycAYWdaUTG43agBKLyFpZJAVHNRULBNoNaVjDxh8qBBW4hxR8wwsH3yQF3PFfWcvZKKorL4Nv9wkTWZuaY24Bhppphqyh7xy6sFdrAyBbZdBwN6jdYpwHPqvEzQN4cu"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVGMRvEq4cgM3uK7o7644azuujKnjHFT7jnFjkQyfdVjLAGWAFq1RfPJFvzuiFm8DfcUo5ByuxWX4YLPN8ivas98cUVjQWTxZGCQeJLuNuU9rC3WGGPcWzbMYKvnv38E7sPcqMihcbPw")
          (* MadMaX#0593 *) }
    ; { pk=
          of_b58
            "4vsRCVGMRvEq4cgM3uK7o7644azuujKnjHFT7jnFjkQyfdVjLAGWAFq1RfPJFvzuiFm8DfcUo5ByuxWX4YLPN8ivas98cUVjQWTxZGCQeJLuNuU9rC3WGGPcWzbMYKvnv38E7sPcqMihcbPw"
      ; balance= 1000
      ; delegate= None (* MadMaX#0593 *) }
    ; { pk=
          of_b58
            "4vsRCVjBmBc8qNFgy5vmvimLUQG7BwmUA9N6ATAahSLFZa7H9xLyFdnXvB8qJERCZAHAfdN1FcfzdsYVqUYp6Ej2wBZotscyPxh94Zd6yCC4QecDKWP6bym8p4qHe26mt7SLJDCSbK9kbcTk"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVkw4hF6BqhKtCFnsh2yQCLxczvi3V2YVcmAUUpfky2jGVXxEDZYWNkmjsmPwzy1JUyZWU3ht5QygVUwJB9CSMbRAUcYe5Q9xtK9hC37R6sLdhN4k9e6gpFebpVjRPkAGUaW827B9uAW")
          (* Chern#1560 *) }
    ; { pk=
          of_b58
            "4vsRCVkw4hF6BqhKtCFnsh2yQCLxczvi3V2YVcmAUUpfky2jGVXxEDZYWNkmjsmPwzy1JUyZWU3ht5QygVUwJB9CSMbRAUcYe5Q9xtK9hC37R6sLdhN4k9e6gpFebpVjRPkAGUaW827B9uAW"
      ; balance= 1000
      ; delegate= None (* Chern#1560 *) }
    ; { pk=
          of_b58
            "4vsRCVTmdednDJpyNVomkfd5XE2dGTVTaw3D8ggZiY21TkBY8YFdLQTHUuBPW7yvEPDxNGB6sJiASjYbC1TVucnKp4s2sRvfYww7fFeqA3D3H2voN181mB2xMxDLVTebh7aYSwmWJKdLJ6m3"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVu1n7QFpeeHkKu6xgX8u46hbDEYJLA5F6E6YJaLv6gS8K3G7CWf2ELr773UYJE8fJxeG2aTC3wUu4MwQQmS7Souon6eDP2PQPQjEUjx2eGc6iNXgE6zZLW4fo8PzNPKGT1amCxmRTM8")
          (* Neas#2600 *) }
    ; { pk=
          of_b58
            "4vsRCVu1n7QFpeeHkKu6xgX8u46hbDEYJLA5F6E6YJaLv6gS8K3G7CWf2ELr773UYJE8fJxeG2aTC3wUu4MwQQmS7Souon6eDP2PQPQjEUjx2eGc6iNXgE6zZLW4fo8PzNPKGT1amCxmRTM8"
      ; balance= 1000
      ; delegate= None (* Neas#2600 *) }
    ; { pk=
          of_b58
            "4vsRCVpQAJqGnXsK64r16NdWX6bQ2uQFQ9NQuzVbSh64snubxxBjTpSKjx1jxkVM9nzTvaoUiMdtumfENzAVKyhwdJQYAThLC1v9FqzywHG7u81Cjo5RKbGzw9jPs5AnYGYdb7A6UBevRD3w"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVKH3RNa2JTPrF17RwRG8HJqEAVuWVep1ExZZy7yw1tfaEXnQq77cN2VQ8iSSqRpKkd3dfxaM7xAxMw6A3PKYEer3hFonYjhQGCFzDZGcxwy4hobG73uSobWQaRbg1JE88S79MUhb9fa")
          (* GeometryDash#1216 *) }
    ; { pk=
          of_b58
            "4vsRCVKH3RNa2JTPrF17RwRG8HJqEAVuWVep1ExZZy7yw1tfaEXnQq77cN2VQ8iSSqRpKkd3dfxaM7xAxMw6A3PKYEer3hFonYjhQGCFzDZGcxwy4hobG73uSobWQaRbg1JE88S79MUhb9fa"
      ; balance= 1000
      ; delegate= None (* GeometryDash#1216 *) }
    ; { pk=
          of_b58
            "4vsRCVsBLrTszJfyT9CRrXakMZNV6EvExmREqemnX6GpVBPVj9PQaiFygAJcd8t4vKTayzKX1mSCePDsQazaPqGpaPYXW7yNo69iwo9uxjaSgqCwmZvk29ni6Hsv9pnCT9x6rR5S9njtK4FX"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVHuL3cUkC1yP2GbnqqGiV5vYBY4PRhUqBvJAbaDV8FBQ9KCf68WMNybEnoC1piY2fKpQYrKz4txNf8Lz8ohmyQCJpeb1d2twQcRXE4yKLLg5hNRw6HuF5TiHJHzAnBfGGieGkkP8MaR")
          (* maugli#1860 *) }
    ; { pk=
          of_b58
            "4vsRCVHuL3cUkC1yP2GbnqqGiV5vYBY4PRhUqBvJAbaDV8FBQ9KCf68WMNybEnoC1piY2fKpQYrKz4txNf8Lz8ohmyQCJpeb1d2twQcRXE4yKLLg5hNRw6HuF5TiHJHzAnBfGGieGkkP8MaR"
      ; balance= 1000
      ; delegate= None (* maugli#1860 *) }
    ; { pk=
          of_b58
            "4vsRCVWgkgZRFwzT4pJvwYepRG3uM2CccdLSd8cYmweDDQnVALmw7JCk69GvVb28b4FsprougmL65HGZ6ruYsYQjXZXZd541nua95PnajtXC6Ltgv2Y1kYL7rCcYUhBbW8HagYGD7rxnBsJ1"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVNUdRVhETYd2vrcfeLFTmRXHhJtrDHFpkQCQmyv9qAygwaVdv4yw52Aj4GgKyCKGcJcct7urFGD9HMxWXR8DnPebrYnSvgqkU19uYgk1hufyR5fbgL4TaGoKfXbxqQsxqdms7DMKhgH")
          (* DiorO#9959 *) }
    ; { pk=
          of_b58
            "4vsRCVNUdRVhETYd2vrcfeLFTmRXHhJtrDHFpkQCQmyv9qAygwaVdv4yw52Aj4GgKyCKGcJcct7urFGD9HMxWXR8DnPebrYnSvgqkU19uYgk1hufyR5fbgL4TaGoKfXbxqQsxqdms7DMKhgH"
      ; balance= 1000
      ; delegate= None (* DiorO#9959 *) }
    ; { pk=
          of_b58
            "4vsRCVrHD3w44m2dPAzaWs47WvtFxBBzMTJYsq6VTiafC1SQQSLv9qNYovauj3biyHQRD4SqE9cNiJmoRJJve2s9U5aeAFadVYYJURCenfBgrs6nJpZSjH9UM164Lf551w2ZHpy3anXS81pq"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVsFRzEBh8KqBbwMdmGVeApg5exEFowfUFMDVuR7Qbm4TNyZkUyVZbV124MZrJSj3ngpMG7U4aRy3cpQA8EUoKug4SrChRQVyQBSs7BHP4pk4BwyMhKym4kHXC3k1E7V9GuWgpkoGpkf")
          (* NGA#4384 *) }
    ; { pk=
          of_b58
            "4vsRCVsFRzEBh8KqBbwMdmGVeApg5exEFowfUFMDVuR7Qbm4TNyZkUyVZbV124MZrJSj3ngpMG7U4aRy3cpQA8EUoKug4SrChRQVyQBSs7BHP4pk4BwyMhKym4kHXC3k1E7V9GuWgpkoGpkf"
      ; balance= 1000
      ; delegate= None (* NGA#4384 *) }
    ; { pk=
          of_b58
            "4vsRCVHjhBpSLCAZp1VUFtukcZrfdbkGfheDCobMzmhJ6VxUvSv21Yn6us5iSyR2iB3gP57JZjnGF6vTMieYtwDkDtLqf4F3Ca2ntxBgUy2jEZKfsaiZL9dZiNBHqiYyWRPd99GwwjnuD21M"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVvzFRJMXmDaumqvB9wJG2mCYqd7ah7D2Pv3ZHHvSxR1JSRKaaPY9gLXaXSo4CRrFyND2owVSLhkpEN6KBSiBgSHQg25fFio9driyoifVQ7TC5NpwhTtTLunAYjXvCsNCXMkcAWk9hTg")
          (* yana#2048 *) }
    ; { pk=
          of_b58
            "4vsRCVvzFRJMXmDaumqvB9wJG2mCYqd7ah7D2Pv3ZHHvSxR1JSRKaaPY9gLXaXSo4CRrFyND2owVSLhkpEN6KBSiBgSHQg25fFio9driyoifVQ7TC5NpwhTtTLunAYjXvCsNCXMkcAWk9hTg"
      ; balance= 1000
      ; delegate= None (* yana#2048 *) }
    ; { pk=
          of_b58
            "4vsRCVQpz67fLMhaUc1mZ8CS7G1HwRph5ws7rhJZtBFAk2eX7g2PRfpL9Sv34GzsBSvN11G8Hc9YJBxzZAvtcaNeWFR8Ue34492Ki9eJz3zxiRcUnRsgyqYwGVq99XfvYS1TK5MVsiBHQpAw"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVNX3fAkuC82mkEkoM31pgHdAbFSTWGDLCwk3e9miGGx4HT87agzBoAhwKUURY7V96eiNYNcniB3WqTqyDAGjheb9eMg8UZT67rFnTgACydcwWSi3ABqgJpNjSG3h2Zjv9LSE5fsguyn")
          (* SecretRecipe#7739 *) }
    ; { pk=
          of_b58
            "4vsRCVNX3fAkuC82mkEkoM31pgHdAbFSTWGDLCwk3e9miGGx4HT87agzBoAhwKUURY7V96eiNYNcniB3WqTqyDAGjheb9eMg8UZT67rFnTgACydcwWSi3ABqgJpNjSG3h2Zjv9LSE5fsguyn"
      ; balance= 1000
      ; delegate= None (* SecretRecipe#7739 *) }
    ; { pk=
          of_b58
            "4vsRCVxsaHa9krEasiqJbPH7acaHB2rbWpdEWNLqaKufULWSuRBnukZfJYsW7JWbENHVrKGKTfi1Pe4u4Rum1q6nTeqw6NiHN5N9MFVc63xhCevBiBsBYq2zCj24zyNu4FUDdmh6BXCNh5ME"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVNCUPvJT627ZZ1Cr6vJ1sWWpvAhhRPaPU4ETVcZsqpP3UH6A1E2kjDHwvyz66VUhyXVyPBn7ozn9x2ay2JdzdZtCkXXjBLBMphfjzkcrhg78RPmg84jGSiHrv2mfAWppK1SmvjywNPP")
          (* Dan Mac *) }
    ; { pk=
          of_b58
            "4vsRCVNCUPvJT627ZZ1Cr6vJ1sWWpvAhhRPaPU4ETVcZsqpP3UH6A1E2kjDHwvyz66VUhyXVyPBn7ozn9x2ay2JdzdZtCkXXjBLBMphfjzkcrhg78RPmg84jGSiHrv2mfAWppK1SmvjywNPP"
      ; balance= 1000
      ; delegate= None (* Dan Mac *) }
    ; { pk=
          of_b58
            "4vsRCVqU1njWVo5CKzZoiDAsH13nvMWmVa6CX4zxprgmcpmaRiFwgczYck9Z1rVnwuRTxo95vBixY2CBXCvFfsaWpoRvLUELhZ2j9ewUV2JsonDCzaSqE3bBaNcs39u2rxkoqmS8WtabtNsE"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmXXke6mZEBNaXyUhf8okJJap7DZKVmo3TaPwrbgsmCHo7T4pTkYUydofgKQ4PxVeaGo7QSU8AhbNTagEGfkp29apdcM3vFF2fVRqPxiZjfdj3ooQu8x1cucqxiC43x7XYSfmRCiCSM")
          (* @Unstacked#2191 *) }
    ; { pk=
          of_b58
            "4vsRCVmXXke6mZEBNaXyUhf8okJJap7DZKVmo3TaPwrbgsmCHo7T4pTkYUydofgKQ4PxVeaGo7QSU8AhbNTagEGfkp29apdcM3vFF2fVRqPxiZjfdj3ooQu8x1cucqxiC43x7XYSfmRCiCSM"
      ; balance= 1000
      ; delegate= None (* @Unstacked#2191 *) }
    ; { pk=
          of_b58
            "4vsRCVp2zKPQC1JQNcywRCmUJ6W2AF6Cd7voGTs5XRbUbrmnEHvExQ8EQ6VrHsAtdqcNFt7M1qWgvoeNP5ForywtDNQwj12TXuros3SxrHQNKL6pw53ccmuZKUznq8epSty77KHxH6W6Zkze"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVeKaxjEq69xZMVCFDEqABAqmSk5TKZ6SSgvBvjfecpyewKx3JeTFyzUY9viDAyPwQfzeTdBYTSZepsSMHRTJwhayimgrwakH99m7jUDBeSbotefHvhdMJuujiZAvVz9J6QsttJehZYJ")
          (* cchris#1478 *) }
    ; { pk=
          of_b58
            "4vsRCVeKaxjEq69xZMVCFDEqABAqmSk5TKZ6SSgvBvjfecpyewKx3JeTFyzUY9viDAyPwQfzeTdBYTSZepsSMHRTJwhayimgrwakH99m7jUDBeSbotefHvhdMJuujiZAvVz9J6QsttJehZYJ"
      ; balance= 1000
      ; delegate= None (* cchris#1478 *) }
    ; { pk=
          of_b58
            "4vsRCVkh47vN1bEw2zQhHxVtAcYWTBvB58MPe5iFS3b9PLV4pG9jwHYydXEMcMRqvLUwSDYCYeKZQiX69Uwu3qab6kSqGC6QuLUaG2F2FS5a1ujYMngKhaE3NmbhoVtLtZ4YZFwW9BD75sKD"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVmrc3aw1iUmZ65XRd7q5EXqCQ52Lu2WNexB9qGmMxiszDVDohwAhSekwVyoPzvxmJrGuyj3XWx66STbA569LxbzabF1vJWx35QbND2ifmhVwfz1m6whUa1tm3XB2Qc92W8WXEum49qJ")
          (* Tyler34214#4119 *) }
    ; { pk=
          of_b58
            "4vsRCVmrc3aw1iUmZ65XRd7q5EXqCQ52Lu2WNexB9qGmMxiszDVDohwAhSekwVyoPzvxmJrGuyj3XWx66STbA569LxbzabF1vJWx35QbND2ifmhVwfz1m6whUa1tm3XB2Qc92W8WXEum49qJ"
      ; balance= 1000
      ; delegate= None (* Tyler34214#4119 *) }
    ; { pk=
          of_b58
            "4vsRCVRuDDeKvtfsbBRUe5z6ycvKN8ZC9Dmo7uD3QVbw7AuHszw74vbfmtiwznGv857PfAQC7V4eyunf1WP2PLgSDD4vndPXcAKqS3wRxyKkUTiqoHLPqg6JPnYiDZY3qdXDR6GSkDVRHeb8"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVak6Atxy4JtTxgdijBTTKguUokBvUKWevncdpUZxp5YoskerY2A5SpkBMyr742Jfw6YMCh94vQqApNSYsB9ZRwNtzs8muLyHdQinQEijiJQqvvs82EnQQSkrr1jzVGNtEmdW23jdF4V")
          (* LikeJasper *) }
    ; { pk=
          of_b58
            "4vsRCVak6Atxy4JtTxgdijBTTKguUokBvUKWevncdpUZxp5YoskerY2A5SpkBMyr742Jfw6YMCh94vQqApNSYsB9ZRwNtzs8muLyHdQinQEijiJQqvvs82EnQQSkrr1jzVGNtEmdW23jdF4V"
      ; balance= 1000
      ; delegate= None (* LikeJasper *) }
    ; { pk=
          of_b58
            "4vsRCVJF545Cpmw7dYwpki9mJmjcbzr1Ut9i3HXua78PsAp9v1q9dqZCr19QXY1ySjZyit7SrtpTCc5Z6VpxVnzWD2wkibhuo2tKkksLboXKPyZBcS7Ahhafg6mWd9Nc7VE1E4U34yo6E4qX"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVf8b2AyNkrrrDyxrtuiL1vihTvTHvS2bcRewJfcnbu9QvCqovzhcinJxoAvupnWQcCpvFbRCjASaaZfcjTWyHG9WRY3f7a6jRmYnZNmGknWQcTqwKFznQZPuJmhTKF7VwJPDAT6cALc")
          (* CodaBP0 *) }
    ; { pk=
          of_b58
            "4vsRCVf8b2AyNkrrrDyxrtuiL1vihTvTHvS2bcRewJfcnbu9QvCqovzhcinJxoAvupnWQcCpvFbRCjASaaZfcjTWyHG9WRY3f7a6jRmYnZNmGknWQcTqwKFznQZPuJmhTKF7VwJPDAT6cALc"
      ; balance= 0
      ; delegate= None (* CodaBP0 *) }
    ; { pk=
          of_b58
            "4vsRCVyNcyQuthHSRzTnor2nnzxeoWigqmEWnL71mik3jidfCk6b32dz3XcizMbxB5ycAj4adiW3ZqK7o3Knp6wtb8sP8iyotvAvjqmTfvmNHEVVhj6E25CtxVaYXtVmeZxs7M8KEihnNGZb"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVcXoP4NXAzAAs2DNwhWgDmhdC5BSWu5aLUC3UfhYYzt59tGkFVdtvWUvDTKmfTauzaZhc3vGogRp5HdeiN5jGMwoAkVPfRY953RdNfZBMCpFMFWEhUefAo9hXQofy9eeQLAeMBEyr7X")
          (* CodaBP1 *) }
    ; { pk=
          of_b58
            "4vsRCVcXoP4NXAzAAs2DNwhWgDmhdC5BSWu5aLUC3UfhYYzt59tGkFVdtvWUvDTKmfTauzaZhc3vGogRp5HdeiN5jGMwoAkVPfRY953RdNfZBMCpFMFWEhUefAo9hXQofy9eeQLAeMBEyr7X"
      ; balance= 0
      ; delegate= None (* CodaBP1 *) }
    ; { pk=
          of_b58
            "4vsRCVwd9b1cfUTUiNtLwKb8HMV7dyEwZUx1RvoRnCgRJW5Ca6peFra6nDVsJHk66Dzg9354qsKiptRPyZRmgzC6AHzBDQdcByZTYpCxfiqBH8qsMPTNZXBa5JvnYEgfc1ri4uLcdwktYL3E"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVmwvSTF88Da23NZwRExMFMFZ23sCQQgGLpiqKgdqyKg8bADKYwcvi8q2WXpc6ffwAbZcr15FcWy22MBoH7h5kjxRJrWbMb9BLrj9jrXtAKm8AUHgqCtFkwdyQuMxU1mxEoj2WymZykt")
          (* CodaBP2 *) }
    ; { pk=
          of_b58
            "4vsRCVmwvSTF88Da23NZwRExMFMFZ23sCQQgGLpiqKgdqyKg8bADKYwcvi8q2WXpc6ffwAbZcr15FcWy22MBoH7h5kjxRJrWbMb9BLrj9jrXtAKm8AUHgqCtFkwdyQuMxU1mxEoj2WymZykt"
      ; balance= 0
      ; delegate= None (* CodaBP2 *) }
    ; { pk=
          of_b58
            "4vsRCVxw5W9MoRrj2PVCoeMpcTxmSx3pnH1AxFbg9L311EUf3ShxvkP81PjxJpxwB3b3Bv7CyHUzWm5aYnDsapCwd12Ro5xmRtucQw6k8GSQTHDtLVVDWEokhoMXeNT2AyJGpcKP2sYX33Xb"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVR3kgqeJK7rykfeQaUqVE6hdCDS2eDrbqxr1xh4PC144Yxc1mQAp3bq2KwY551c7EqjAv6igGJdKFSK7JveJuPNvi3p8fkRSmeDTUtB32oiU1oJTZZ1QVzxj1iDmhTMNaBZriqNe9aN")
          (* CodaBP3 *) }
    ; { pk=
          of_b58
            "4vsRCVR3kgqeJK7rykfeQaUqVE6hdCDS2eDrbqxr1xh4PC144Yxc1mQAp3bq2KwY551c7EqjAv6igGJdKFSK7JveJuPNvi3p8fkRSmeDTUtB32oiU1oJTZZ1QVzxj1iDmhTMNaBZriqNe9aN"
      ; balance= 0
      ; delegate= None (* CodaBP3 *) }
    ; { pk=
          of_b58
            "4vsRCVyaM8pT37YGZnKqyLrYYmXKXfNPYiBLWWJ3k9TvR2KP2xCrR6oqcfAawUJhqTcW4SiBB23jdjPVQd9jWj3kY6Ce7RpDDnUeyaZtpWcam51QDTpQTo5TFU1d65SuttXMjRMJnDGiK61v"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVNfCPLCcjuEdRn47XeajqpuJCVD6onRirCKEfXpL8s3s2HHy63farSCPq3BnVtCJFSVRXXJJaeMbBvPk8cz366mjkbwp7Tpq2jdhE1TXHcC1RhU4ffjnx24XM1fkhJjUNt3JC1VYVaM")
          (* CodaBP4 *) }
    ; { pk=
          of_b58
            "4vsRCVNfCPLCcjuEdRn47XeajqpuJCVD6onRirCKEfXpL8s3s2HHy63farSCPq3BnVtCJFSVRXXJJaeMbBvPk8cz366mjkbwp7Tpq2jdhE1TXHcC1RhU4ffjnx24XM1fkhJjUNt3JC1VYVaM"
      ; balance= 0
      ; delegate= None (* CodaBP4 *) } ]
end)
