let vrf_winner_keypair =
  let conv (pk, sk) =
    ( Core_kernel.Binable.of_string
        (module Signature_lib.Public_key.Compressed.Stable.Latest)
        pk
    , sk )
  in
  conv
    ( "\001\001`\232/\r\250p\253\234f7^I\156\235'\243\001\027;V\249\192Y\158\198#\143:\2138D\211\202\022t\212}\205\208\193\174\253\153\192\192\215\186\217\199\218A\185\187\178\165~\241\198\224\149\184\152D\130m\b\128\166(\209\022yUK\r\243\223'\026o\164\170\150\255\2234\155B\227E\191vb\236]\000\000\001"
    , Signature_lib.Private_key.of_base58_check_exn
        "6BnSKU5GQjgvEPbM45Qzazsf6M8eCrQdpL7x4jAvA4sr8Ga3FAx8AxdgWcqN7uNGu1SthMgDeMSUvEbkY9a56UxwmJpTzhzVUjfgfFsjJSVp9H1yWHt6H5couPNpF7L7e5u7NBGYnDMhx"
    )

open Functor.Without_private

let of_b58 = Signature_lib.Public_key.Compressed.of_base58_check_exn

include Make (struct
  let accounts =
    [ {pk= fst vrf_winner_keypair; balance= 1000; delegate= None}
      (* imported from annotated_ledger.json by ember's automation *)
    ; { pk=
          of_b58
            "4vsRCVdb3paeivNPqB2Lkmy9kivPcxK79n3zJtYQJLcQFW3pWQLrB5vWEsH59ZphcLFx35mFpJFxZnkPtMHSffNwPuRwjqaHHjnqb2KykUKZdkJAnco3ww1zXzFNWfoSycsMVe5oELp6GGYh"
      ; balance= 6000
      ; delegate= None (* echo *) }
    ; { pk=
          of_b58
            "4vsRCVTWAahC8BACy5Ym5XLKYXkvaigTAyjgCLuj8LCE4sHS6LAuVB29qojvkAoB14bGgKbRrn2z7YzjiZMYryABAhtkmwB4r7En656iKB98uqq5jbqhSEbftoNJ2vLhXM7swgTzvva19TuX"
      ; balance= 6000000
      ; delegate= None (* faucet *) }
    ; { pk=
          of_b58
            "4vsRCVNQNsK53pRYDLCsk2FEGs6mVtEDebmCPG6RRmRss3zx3CJfHiViquJLpG1gWJFUEgEEFcvC8m12MUr8rAPqENmbAznfY9WEoK12yzcrmimkPM7Pnoeqb74Nv3qTepWnNqRd4fLAZLkb"
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
            "4vsRCVzusiNoK5vDNn8EQFAnW57hVz9iQVN5wuAvmbEZQ6EgGxdjB1Kv4Dm9BXMi1FshNXnmuAcAqSM9Wkr1HxDkdGRBAvDZEqYwdRBJ7NkQ4ep1sJKWhkEAd9xcCvc3hRJWHRTxMmoir5Zn"
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
            "4vsRCVvSJLJZe2wJN3Z8XgkLqn8ydDdvZ86skKsbmHC98tR1MvaB3yjih5jLSVYhxYT57YdjdSL5X1AZbQ6esXpVPGzhje6Seya1FDBeW53JdpNRAwJ1GU6QkGQdLi9T3YPDvnNNF94XUXsf"
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
            "4vsRCVam9rPmjs2VTAXKzMpwyr9dPcACfP51ok1tYhBNZLkLXVZn5XtXkQKvY6RWhDzKcfkPyR7SqQhQ2WCbxWuR3iGsCA2xCcG6c1VjekudSvJHnKjKqUEhMJ712GPDijygWU1zJNLdGqBv"
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
            "4vsRCVztonDLACijLP5JxYGLxN5bKxcuFonwcnpnY1vD85c4gVmmHJfwQL6YbUXb2pYkFitzZg4etavj1tAdU2v8G7BNfXZcpgjTKKE1aK8uXrrvqhjyzgprwaKg2rPm7PzW2UGrvPVZHYU6"
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
            "4vsRCVcyAWLYrFYYdM1LszD2H41cr49gysrRNSqZ2A82YgGdAHaC8LHYAPAAP9aQz3kZtaUHAUUPazfdG4E7FzVW4X1XELHVjhTQJU1ZaCLq1pq5m8opx1baNWj3vxdGQQraxJPA81TBAUAa"
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
            "4vsRCVwyugW8keuHnja3nnn5SWmqRoRqBKBiSUNxHw1qrEXkC4isnCYpiGUKaYUAMK2Yz1qMzVqjNzhVBLU4wyLbVpHniU6kPAawgX4Lx2KfJaLL3TF9ChEFuovKtf1Y6LAMqEpSnnacHAfd"
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
            "4vsRCVwpDTjVE1pZR7mXwB8aswu4RUXM8atSLeLkLPosyG2cYLahnAusjM8F33crg6c92EyfWkTyZ1oR9Pz9tb4gdc7ibCkkrFV1D7LApd13zBNDBkXDSeTXLkrPn2uh8knVhNPFSVMtimnh"
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
            "4vsRCVkKpTMHRnx1BHpFnMW8WcJJ6rkSexK6ixZw1gr58GgxTXLCMAUEPjwiMAgZhEM4A8j68tw8D5c13xdXqmLMYnunX7svPn8phLYFEhfupq1AN3CTEK7oM2Zoa4X14B9rpq2gbphLaRmf"
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
            "4vsRCVYt3rDntq6gZAVoc2qXRVGtGepUUbDJkoDuzxViBZP4LR4U4JEN3dAUSGUh6c5abywnKEPBwupfhMSHA9VDWTtezxokFFD2bQrrCQ1wRP1gwmwk8u13Q4WVfbjyEqWifsGDKLkzyt8o"
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
            "4vsRCVU4AQSq34dX7DhWMNjCKJdtEgnsqYywZKBUbX1sUDXVvLFR3XcxKzSXhr7Nt5Unsf7hA6ry8dGLkCJLXVQrypwdJkq9dq5BUgF7QpSaBA9ESCzn6iheYZwy1TboqxaDtKRpwgUGumgg"
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
            "4vsRCVqEDBh2Yhn3Vdc8nwVsdixDHfSau7MoBP9fZDY5TCtPYnbUWQvhkwoD84tALsg3Y8L42NVvradDuyBZXy9RkSpchjA1eKLACXBy6jwjBbrGvnXwEHPNjyqzzV7RHThPyUSrYCAx6mDJ"
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
            "4vsRCVM5yrxUNHhfbz3BgvR9tg6v6gxzWysiRHapmTFtPVB65jmH1Tsurb9WkEUWKpj9KMiZVubUWDmTvSejcWv8avGfkqnNmz8jVstM3QeGJ9qQNdf7B6ujXk3K2xjwS4cHagVZgEP8MHem"
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
            "4vsRCVGCQLp4rN3wx1fPMsWA8ao6dp4qL7rUnqgYyZuKgmG4bNSiBoVpkPhTREpLMGURxf7EczZH85ZCMjCd26vRfFyWAVF7ajFD6KmrEZCHfVnrqGj6CmPBXV2Cw1doXiCwp6YrMdBkbMGU"
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
            "4vsRCVSXXXx6drwhA8rHMjB6YduFaynX5jWbkAWPoZFooWAHRTEGeqbBPYeWF4MVzJHGqxoC9qo3kNZLSHY8e11vSXJnEU9NeL1aVsZTXHULXoRkC9JoCne3gSj6mefqVqQkcfQiQsjDZ9Gs"
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
            "4vsRCVgf1e1S2sASQgF6x4P3nXwZP7KAmPysgirSfANe4y3TTfBqJKxATPBKSsXy5GprZ1sfA68YNKaZLCHF8jzeHLkHsXUK6WSqLNz7eUB8637eXoThPuSgDUJTirCkM9SUXytdXJo8TwBu"
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
            "4vsRCVMs6qcWdfPLZnHz8BRCj9X8tfAVfmeA16Y4UNJnJA5vjoP3AfSLuddFwLDYT5xS8ykfY8TbBzyyzwGnvi52XxQhiikBQWKMrktRbLnUw1i4yfGkSZmRbFvPDEhLAZ3qPFGHAwxzJu6s"
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
            "4vsRCVnTMXaeF5oJmVWnoSaPjk8Q1nFy4z3VRQTqJSdFKDJQTGNeLH4sywAhbdBAx299xrTZgk9fp9Db5zdgUSGAJfman7rA8AL6bxxthDDdHiFHJuSrtMzzk9Xoy2iYjZ45G4zGsukXWBs6"
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
            "4vsRCVZ96BpqnCMLNskog9bUsxXs3NZRxCE7GoZNurTytZ4zHATy5LKWwaFXtEJqb765JpQYNQiZ9YR7BWEA3SS2iJnySFaRargjfuos4Esvjid6qKKRDDXyxyPESPChUj76U8EhrpLhHrpV"
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
            "4vsRCVcGamSnfGF715Sc8yB4USerVemD6aa3viuXVSFMehU9aDEfVqNcU5ZVHRQCHnyZbhs5AzsYm5TpesfSPm2mQVuxU1GYv4JwDto3AEtxCvRZwL189sX64EqF3x2Wbtru197EkNcQ3VGF"
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
            "4vsRCVKe4RiQN2fGvHcryo42ecLTKKJP7EunFVWPhFbDxBfjebw68kCCPkWNayYxQxNjizCTQrumvYPajLKGTd8a84hLWqoqD8oDHrJEyJbYUxuxJPNQETZKMjcUfwerFKX3ANSVLbKGXbYT"
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
            "4vsRCVZBP6Sq7q344k38DUgWCCZpTAEDQTr2JT8uXbpEbzoLtDfJM2JUhReaLwgiRnLeUyEReTZVp6aJaajHaXWDg1yJU6MR3PYRtocAezffhKkeMbDYi7LPqErJeuaErKRkN4uEg3mjLZvy"
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
            "4vsRCVuZQt6czqay91yeAHN2NyTvTtmrooMTQUdEcCDE5mGyXoYUHSVx4fSMXVjf7kR2hBxBxK8WCLUqVv4umuHDhFrhaGwBZKNyjFHdcZH1Shtsif9LU8eagcaVijWGTZXHWXoY2q48ptwh"
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
            "4vsRCVmK4KPw9ZJUamtdcZoZBd4J6VqdNUbHmnXyRTYQsJbFrjHMs4UAMQ1ANFDzHHZxa6SY5D2wobN3QmchSfNrdSPjZYz6fsTMmnbjzNZEkBhmfghmxatv2hLJQQBtKyynst4n5iiTVWMp"
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
            "4vsRCVdcbD5J3Ecryp7xrydkWJueCUuxEU2U46tDno6dtZE1yJPCRvvXvF9Swb4HnFxXQHipoGEVuP6wvTseK8d77WyDfC9jXxxmnu3PNX7avo62a2mJBM4FEGbKYaWxbCnXzx2djFxBTfUD"
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
            "4vsRCVXU6ryLNJUFMx6hmQ8rFRkmUQ2S4mexBWoRwwT9VvcD3Sgu2h5LHXvpuy7d84m16jGcGeVxVRvVm17GCn13YoppVgihEUW4Z1XbReqWCg5kfWXus7iGY465x8LNnWDfkUjKEb9J2M7g"
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
            "4vsRCVgvZPCedZmv1eMYNmbH6AkWtVKaSt1xFo3hxTs9eeYT5srae9ZDGxjGw6kCJsTEcnAoENfUAiN5P7rafJVnBSQfKhMQKu3T5mvKLcvd9VS8VanrRLTqXCkoWqf9hDuPX1AVu91GPnMv"
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
            "4vsRCVKQCeHCBvG4itENzomZZx5sAaWuM1gePHMTN4Cd6bCKTnecqJ4vCb8oKkQ1VMEswQYktT2b9FUf3DcUCNApfufczJNUevHHpEMMbfrHEC1kZLtZnWXSnsiQpcJcWMSFx2MAJzxiuarr"
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
            "4vsRCVNteiY5Jnu2sakGG2QDALG3D5HTsiaWeZkRiWo3D33a3MoUZyAGZ8u8vvhmbvxMTEz2g6ZdDuNqyUMh91nzDPMv4vumcfMbuuSyDH8byvNNvErZEzxhTicQ8UGWP9BwgmGdjjR2wiXk"
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
            "4vsRCVGL5u3bLETKRhacYQMvZZj41gn5hu5SbL7jZGWeX8wCiYes5Vw9SZ5EQ6V1nvNAen2xSMDFV5AWZbWw4haFtXf5StaBWaABPUHsoTTQPe3jgH9TnUS963akjWcLweX72KwG2GJu1frj"
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
            "4vsRCVKzHxqChyCyBZTVuAH1zcu9G13JMmGULMkHVvF3MLJGqLyhPg83UMzby8ZuuhWGazejd3F4udpa6WTugLKfAsWWVPh6DJdTxa6vJfBe2QN7Z4s4DYa6v554RH4RoiD48kiKmdkFFvYa"
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
            "4vsRCVN13EnZUBFWToPGCMpm9JV4ae7Sd2pX5unXJ4SVwuVYY81u76VPqGK4hUABjLQDytYSjZqXQUKjKKGXw7Y8csKTZjS61etnv2aLnMVaTBLPGomK8oU6LKE9jnQHLxDbXFibRDjjcmuu"
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
            "4vsRCVJUmkeZm5bLxjdirREFh1JdzsbQpTbJiQhD8obasJEj2rfhUNtLm8z8w4PFVMaAXiDBGauoo2xoKrzpCMbi7dMevKG3dizfo6KEhFM2zMsEPJbrKAGhpti55t3JrUXjKPWCVRQ2oG4V"
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
            "4vsRCVVuiL3hTyNjG51C1zmYZwcXnr1Um7tHW1o1qDGtHQAVEApyiuw8cg5ASqFDYbpKfeURfTEP2vRVXb7qy8Rsf8XuCV2h2FutcY1BjEbzAhPxTrzuay2c9GuTo3EZ53Ddmjj71USfi6bW"
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
            "4vsRCVHgbWBWZV7awmLytVmU6HWysnpAFxCGKjuLfCddAsCKMujZrQTLpYsSnYSw53jjwXtiVtvVsd6rPrJ8poCx9CLTTzTiK7Vw12WyKm5yvADnm1KxuYbyip736wFbLwGtEftkh44wtAZP"
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
            "4vsRCVNhbT76HFhrLN4xYeZadUBKM147Z8LGNfBFcaxYpeoGkCMWpWAMcExrtaqQK5rQXvNsQZ6rhyam2Ktxk8wLWwgf5pj1KJtkb37snqSwoqhD1kTag2uj1iLZJQzCFUVQuK21BdvPT4s8"
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
            "4vsRCVdKFTjVwueNAbXn52SUS1EuDKzDKKkYZmYk3rBZcpb2Lb9okUVtjVXJHvf6vz5kGVbCDh2Yu5UDkBNEeRhKKM7FjWSKXwrb7Kpu9iH8Dy8zLLLr42df5xQoWw15DyqpMeiJof4fxxQ1"
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
            "4vsRCVQEzrZr5Pz9bvZMJUdTwBpL54J1a9E9DLpQ3U43GysCLPe1tKEPJ3a2agQGzSGkfJ2VsRvkdch7akUuhEYxxDsfkSzh7UjB2iLZqVT78Uc7k8zSJ5t81Vh22Z2ViPkyfN6Q6mQaARGX"
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
            "4vsRCVpyHJQZRMc4jdvpX3CFpNS5Kg422DS8frc92rmVK1bVTNEp4mmrUcTs6gyDy7G14BTrMKYUfbXLTqbBDgq8CT2CNYeRf6CJHATqpoWG7viTiMQTDb5Jtd7SammciJrvT9kShjMXb1LU"
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
            "4vsRCVSxa6VcjWumpp2hUhLeXmZWSD3RmZPhNn2gHsEyw96Nd5a8wov1n7xDVUjwPsNNrmSEqp7gnQgxiPzqeWEf7oJX9Dz4sxH7zAwzJJZ6tuWFMkxw8ao3b6MbcgeuHqmUdT7sNNdRLNQM"
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
            "4vsRCVQsNgCXmeBXKruhSa6jzYKhJcDc9xnzqhkVAAENXEw6yc3vRjWYz6iPw8LnaDyKJ9tv4ksgztuPR1YNXiYZcS9UzefKMGTyEGCn5fZP7CeoxoEGSqC8TniYD73Ma5SaRJwsPL59h2ub"
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
            "4vsRCVPepr7qunrdHakngFSvctRZ7o1wT9gXY5G8Y8vQEtFBMkdJNtuHPpjNfY1n5YsGfGNJkbUvXZoAm8zEiywx688zWTj76EoLUEouiKcxurrkRJmtvFdx49e8vWsDsByggNq41XVp5Aan"
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
            "4vsRCViHnPowutaipEwU7yYEWne5hr7NfUBjTv7k821TMoCS1nggSvPuk4jBnfdoe3L1hweJpqbwwqYvdgmNvN5dsVFwK15HBeXyzdLfH5Mgx5CyBCtJANnRSiE9z1n4XKAsCchxgfNvAgdQ"
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
            "4vsRCVMu2HqEJW4vUaZqqf75H17obKNFiPNRMabqjj8Q4t2KY85YA8dt9ZxhKH9AqPaXvjNndoNUjotAyZ8XBxjeDJXKh84xAc6MA2ERGaotFLcrcfDhuGUUpuagSiKEZ5WA5GT1bxGWw1xk"
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
            "4vsRCVf5XQDLMC9YrXeDqoVNa8xA56K7iZ68iXczXSpdBGdML9ccxEUAmKGqiuyj3dDxgBrSp7GGprumuHYo2JmhcS3jUC29HPC32YDyLorqKbpH7Pn8Fn2vbRUbs3RWwPUmmFmepNqutNoH"
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
            "4vsRCVvFUYLAScR8HTgYfT1HkXsuxuDn2X4FAYFVv7vqbAuKdxTDuG194tZdaAr7csM37rm6WAEwagiaZjiZiKAvQft3kmroQtrbsuZFCCVWJzN2D87huYDsmC6xC1AkDsPMLXMRRZChz26h"
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
            "4vsRCVtV5qzZHj4ZWogM3nnWFZHimj439eKPxMpMZuBNRXguMrJyU6GHYNjQ7zruN7j6YNvEk4R4bvrNB8Zbre7HfLspGv28n3bkdzQMp1ycaK4W6ehF53EUkpX5WKMtBN4rF4woKFy93n7U"
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
            "4vsRCVNbAsKuKRNRcKchQfcxHYQceDcSJ444mZy73Co9oNsQXwytVXE5ar5tyDbR7k53A7gG9yzXAwbnCjZmPqmsAtAHcksCzNDXvajKmqKLHt6xfdaiHFBHUTE8dPzbj9WXf2DGQhcf9NL3"
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
            "4vsRCVRyHjTkvh8ppZvxnVZGVjdMQ88JffeedesprRwVrvj45f9vy8EF9gj9QFqWekg3F3LJB5mG4PD7JUcaybSWJcLrK8VinbDJUWFnLuPNFL3PtoVN8Vmka2WhW4fyx7ajtJVRTainpG1P"
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
            "4vsRCVwr74XqD8xTXvmjctb4TDmq1rituM8PG6ZdGqkiBP6PSNv6e5sTSdQgydwAPMYnLvTtqQhK1m1i4iFtmfN4Hw6T4VUKpQXx27Lx7A5NkvnHy3V1sVAXJdt2EpveEPkXkB52QcJvJj6V"
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
            "4vsRCVZmn4LxcdvwfSff6DCahhMM2dXFucehTbbkTFUCDCJAc71L3RajU8vS2gieC4jGYR6bpg3f46rQnbpuuHGF6X5VZeytPig7NTTyM3Kf7DnsguAjWr3NRV94oxfkPdDDRkePh4N5WnSP"
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
            "4vsRCVvqiExCYUVRoo9xesrVe2cCCTdu4871wHb5ThASKbitxhhSTeiiQ1CVn3YLS4FSZTCiFuv9V3ggn7wxt4ZSohRTos7aA5bKNrrpThSQdSN872T4op3w9XeHiwN3J9zuhX7TzcgBk8cy"
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
            "4vsRCVq4uf3KkujZNYg1FLRhNH7Y3zZNVxVz9aZX1wfdbn36EsU3Jpi5gr213dE5B9ZHpoYLWyXCpTFjyyhrE8GcWGwPoVncaPUAEFJDtF1jKw13taDwNkb7FBwCRdPBhyMqKMhQxNAXH5eP"
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
            "4vsRCVav4VYt3wZJds6KXaDEBKMVE57UiQwKx3JvYBVynrektuMM515LERbCFbfqE2n2UTuk9uHyiD5mv2s8CQ7pWZep1zHNsaRSQVW97dSxi9Dma6muMCeDD9gYqMtVfatt98urWk3RdeLL"
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
            "4vsRCVeWx2o76fz3R7XHGpQC3786mQmFDa6mnNin314RTkWaMNH2WFZLNNjVcoz7mfwJyeKbZ5NHToUiSaLaSfU4U6dfpqFAzFJJMQitb2hDf5X46XJC7ynYSi2HJ76oyFdg5yzWu7o8JVrZ"
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
            "4vsRCVQCjn7QxTezbyRyA3x5GGMLYZu6kFMBAXWaBuwSYxTtMa8vFm4fuKH9qBFnU5asHYVFxYvUBBh8jWW6HR4Y6UcTvsMFSnwaEJqv18NfF65TEa4w8H8pfUEyWJMCuCqZdvSgZxYeWZvM"
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
            "4vsRCVy86URtD1fZWEUdGkv4CF7pgHTkQyqnisU137uCwvtfVXYdHz4gChxUw7Qus2qR35vMWoCwPQqWnE1fdBnETvzfBE2djUS2dKqB4svgGqsVeo7E6XXaXJZcsP23hSeTQxu5sQtd1WoX"
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
            "4vsRCVrLLMUYvAa5mEEyw2LVy3DQY54R1pp1SEb1SrLWqBFS2E2HPPa7LW2Ls7vf7ErB6F43YHAhXdpjPSMBrm4GSsuGwTAGu5SLngKiCCAH5dnK7PsED99A5GL5FQEyymaT9B8nNnN7ovng"
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
            "4vsRCVgu8YWR3rXYsbvDHZsTdTJYnWDWZ8FXwrEtqVcqhpKHp2VMspHUcjbb4mCQ2k5DzWZphRpm5CjvFmUJXu9ynLdWKgmknn8fDxZa98e3Zhb8P6dUovxvYS3gBHtGgZLCDpZbVfjoooyG"
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
            "4vsRCVth7GkTaV1kkRs7q53oqAYDFGUcmp63zeyehs2StTWwEKYg8BpDT6r6Uz7XDTuKmpL1gbFvnojLx5txwQ8AAH2hKdsZmftaEjaxA8oj1uEcjaAP7SJeYQ1bCxVR9GR4G5xYDmFwt6eX"
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
            "4vsRCVzfbPS8NFAuxBkazHMTURMdnWL4dnmDTYAqZdNYTT8bPwiFzoZtyvVLF2yojK8Ljr58t2z4GUy6HEuedD8y3vBnjfpicswWVRhNPtMQouAe4XKexwruFy6r23WnEoAqJfTpfDTGvfAc"
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
            "4vsRCVK7keXdy6y5Y563kPVb1ktC2Nbfj83VADTcqzam6rHUnXEGE9ftTuz388z5B7ycawmLevmkjciZCN1Buc34ncue3NgZisJWnwcP16gdNsxkJWJizk1nHC421D94BD1RAXHPuowcsZJz"
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
            "4vsRCVgAFPC7B8uDRFx3R8EAgy49GXFx9ka7pjiaXgF7qsum114jkR4XQeuG8fmD3w2Ehzt7irs2zBSBHYF74xEhEY2wZC5WUjoLGDMNYZAAPms16HFvQgWeLGw84ThZPDystHkxXDtFEJ4z"
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
            "4vsRCVhAXDJwfGQst1eEXat1gYeE7rMA4FVTcuFd3eeZDne1AJq3JhZP6VCyMv3o75XDjpgKVSvNqQQYDotF6LaTSU9TT1ttz8wmjKkSy5WpgHKnjmT3Mc36xi7U7sBiup1HY7hozrYrdPbe"
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
            "4vsRCVZajFCqTfn8XBU3oFGAvgFNUAqYBEs2Dw1NhWrGBoVRX5432cc76tV9MPR2uNDzXyVNyAXo6WktLgdFGHA2iHcqcFUS6cV118SSvWvADU3EyhstAUzKwiPvY2Tu8PTuddiaHo4LJnDu"
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
            "4vsRCVTCpofJnRmAVWFgKHiSwtKWSVbCaWCb6Z7poLZL4ti8ejAqhsSswDuXkor3bJ9UJkPjrWZDxPf9mBcG8v9WJQNsG2HzWpcRMxqS6qzCwjQS2KCdrafkUwmeci9MFyg5GyUR3VLhcqPK"
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
            "4vsRCVbHuXQ7DWtL4i7YHk1RuE13Kh6sGk3dvf85ohcTWAS3Q5gkLQvSFMfSNNcnuKjk4iexwktXYJZ76nQeTpSe2U9LDiTHtnD62wxw1ssnq5MNP4AjqkAMiUGZYTJZJ7dGAXiKj8rumxrk"
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
            "4vsRCVnHxHpNyv7G9ZEcr6Zc1yCFLQ8oVfCpT7wRgzJDoeacuafa77CfENNPptjSGg6vG82KYHo1jkp2Zb626E6ZQdhL9ZGrs6bUtMsCYaC52VEj83n41HB2yoMghWm764FMZH5mwQ34aGCe"
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
            "4vsRCVUQUdGwXxyKdLsAH4scN3MHuP1crtboJhXRkEkMAtJgFfp7eTEu5SQThpKG4kP5b6PE5zfrADnu6Qqyz4r38hPNQ8DZNuBDSbXxshVkQ319wyGpCJv7KwghwaUbVrBJbhUFSijna7Xn"
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
            "4vsRCVtLHEYzL5ESPQiCLyQeQ1uF2y6v2CS7vYTrnBx4GpAVTupbXS5RgosHqdLZu6U87kQ2kQyiN567awpbhqUxVDJhjNxmr7YSFPhwQ4AUcAFPano6btssgEYJVys3UiPgUW6XKLkmRdni"
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
            "4vsRCVhzsVBu8u7B4kbAHhhsKNTjg3tkaHei4pnmtAYuoRWNHz5ofAovwgcPL7rHdM854aJQET1nddHYhF3oF7Ja5LSpFmY8YnrbnAt7hJpM2uyv6D52jy5Wmi1EKMoqPqihFH3jW3SxPhs5"
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
            "4vsRCVvwb7QVrypU5fmCz9TFyFtd6ePBDkyLvQy5VHJsQ45JbeJv7VVdAoogJhhhWVnF7iF8uQaagxW6PMPFkGyLEq88R667QWEeD4tEeQhNNBaks1zRSZyxRhyESjFo9Wrvf4Cga7wbDWzg"
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
            "4vsRCVhWvHWBpng3GY7CJKtYyAMbDM5GhtamQbDVyqZh6G8nCiHvHvPts2yzfpA9jGxYi3pGTp6gWfMyvRGix2e6gyMAhVSNRGYw8gXgZFYr9oEA2EUM6yWYrb5qrzzYSjCrybJQ7UREbHV5"
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
            "4vsRCVX5yaamAEbXoBHJccvfG18edc5nT5Ngwm4Y76R3BjofpmFfKKReSE5A4wSuyMccqyhF8ne3ipLv1bSD9ucVDhymCCgxmgv4JABbqfKEQC9aMF4xicq8eBBFH1KqWLee73PjmmkotqyV"
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
            "4vsRCVgjtE6Tgg4j3mYCnV1zLLpgZbkzkqMmJ8jMa7BVadTkiwSuhVTJ9xGe5W4uhRPiPYPaUrCCXhAAvasqLcRiJxymfGmuTVH9mS1eZYBfJrNDYw4uNRZ1T4Qdz2fiA4Kx2L8wc23zyeY1"
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
            "4vsRCVoh1YZgDXndQduNFAWsjYn1ytMq4QSR4BE99AQwR32Um6cLSYzURJLmnzie4ThMEkQvRws9e5aNUdBc33MSgCgaHdduQY43ycFxspimECVCLa9fdBcPmn3fSy8PVhBmqdbUJcgwQawU"
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
            "4vsRCVRHeBsrXHVsrnMCsKj2xBUdfn2PpvXLcffxJWNYnaZL8RYSgi8KU5YziEr8FRmwVYW3WngEc16z68kcd3JGTxk8A1iqVsbrcKc46UGRyBwWtrp1hX4TAntaUd1V9x99DUQXdczx2iZ4"
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
            "4vsRCVc1SwWG8Cm2qg6RsucyiM1WvCQrPTCpm4cmAuBEX1Gu7ZsE8E6pJMAGZm6NRYgzuzPCfWrYo5fGL7cXihHkmV4Fr6yvUpjkLsi5Jnc8x4fi31F8HsYtRNB8YKzZRQCVUHq5m85SnvbA"
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
            "4vsRCVY4Aq9SnWcw5ZL8MvVz5FgotyJfxgT3Ze3ERtcpfp8DFWDf1UDtznqCYTAf2Gggtjx3YUW95tkxHWZu8BrVQ7taF97hdqhdv8kgFjqQiWCydXcKutu9qeTm6oQKsVnXvjvCqD6wHH2k"
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
            "4vsRCVgKpXugQpQffU726SX5WUSDA61wdfsfKVdhmDGe9aPDFwYcgrbsaVYUJ5JA6iWzRsJ6imBNni2DrmdsvQaUYqrzeGeJuzd6tjuzQ9v22X5fMBfL4RmvEmADfHrPgyV6wpRsDT2hu7yJ"
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
            "4vsRCVvuJDdWPhSDmUW7nbM2raXb4dhBBeFMwMKmqk9UvM1D8r7eKC6PCnVJVNuCemBS35ab5kf4wT2iRJG11Wur1P3KqjCLUReJD6cFMTcEEtr9sLFzLB3Hiky1iFZmEdiM9cHpFKtvahEu"
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
            "4vsRCVLZyEHQZXj2JPt1SW1fW4T1rLEtw9YEM4PmWwK1sSPsbYETdJAkxEwC4Wu9RqRjhH325sMSHT4DCSdJzozDqkfaqZvfPYgWMTmyZ8UiMRFLVu3RovXy7wGL1iVweLx9cnBBJbffys8k"
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
            "4vsRCVNDb2dnTDe9qKwdSogSoNMRWhuWZ3vSjSit79brxEFqjMyefxZ5SLWhb6nfARnZV8pzyXsuWGUpciXAHYuSkh1F98YcX3kHoT6DnEWhLxuHkQgUz6HwXNhcXzQeUVcx4A4wSzgPdZnX"
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
            "4vsRCVeFGBG5wxJxMTHd2XvBgzt2tQPr6Qu2vvX391De8ZoLFLj8BUCugtH45TZrPiDnDx3wHkxUdecB5Sw9S4P8AgHQBrkbTbMivLrmWZgVDQS7ZtNqkNTAqhNXaKNRxEVgJVHnvfXweepV"
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
            "4vsRCVX9A871aUSStE3mftjanvnxTqb6BstxdVj3mmK4DfeqxwMZH1sygtYkDpSBnd6WL6tUEkvEMUiq6TAp7VcCA24PjQemR6MzMfAGtpAB72wuFY8TkVFVfWJoWhbr3YWFVfj5pSwmPPA9"
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
            "4vsRCVqB4c5pcXthCiHAKg8EHLcErpck6tT9jQ1K2hoNwGVibJM82ypkhCgFvCLWiyr6f86fvkDs1JDEqjxqXMUHevbf6iVTk5GbTmTgYAicQvuLC3AFNfRXyniGxyKCWEm3RtpbFBQXaLbA"
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
            "4vsRCVWH3qyyZmmJ8e4cAHj9R67DDPVMRajU6H41wUsT3st18iQA2KBmQ1M2kFYAFPeabUUNeYuYxkEpF81GzLkgeNJML5X3iTL4Fab2ouFTtWzQQMDbgGW1X2aQFzMGbe1fRBhsTeGkPFMz"
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
            "4vsRCVZh3Z3xyo3vXnp3w4v9xzGCWFaUF9dzwcSUX2de9fqW6d11vExQ7i9XaT6eUD7mrXG57ivCsWsnWH9RBfYcyLvuEvTXDNaiezshxTauHWiG33qBH1sRDkRnwoPmaWS3XKQmKRJJmmjx"
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
            "4vsRCVZ8bZwFTHpVFxLP5RfDqu7CvGnW1SCmkgwdP1MCzkDPq7JL28YeAibXJG31CZXnv5pn2orEGQfUadbQHV6CnKoKeUpHrFzjziZv7sAiTBkkiv96Gxn1nist2vo85cTBUR8xgSpupkTE"
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
            "4vsRCVxgCMSkdL8kLAvuhkeNbKUkL2Z3MXkhHkiooUsdNmLy7GMuCPmQNPrSvnfRzVE9TzeNP2bMUK3nbAcMHuAHaoy1bGmVp9jDRwFHtmbj5U5QT1osmUek5GfxGQd7CzecEJemHvsVkUE9"
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
            "4vsRCVweSPv4dX4JVLzSjhhMkFMspZaLjUd4vWVBcLYZVpDN7JU1RcHFYYGzkTPQb2bmdbL7V7XnNMPNRPrH97KQbdinXh64Kkyyqp9Ktih1bqVJKJ7h7Ls1m3f2b1Nvqsaj9Uqo6Pyq6Tq4"
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
            "4vsRCVJSBSLwfCd1881X29f5HX8WHcZxiZMyHu3uZvkLQueZWeGpZP6z3hZfrXgMv1F2mdSNYmQBEnYreifx66bUDRgrtFT97NeGDSwrQrdrX3oohuZLkYy2H8RKixB3p6RpwNY6NmqnEzXH"
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
            "4vsRCVHGPfspna1k43eHa8gpj4545hMuSgv67KrbTrcJ4dMBAEwDxNrUECN5VLkbYLSRx3cJmuY9GnRdUPdssF4hFMxcNfEfHiHYNC5vK8zgSpREUhXyxYkV48uNGokwQ4CB9sCANsjS914j"
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
            "4vsRCVYPThxqNXiSwSK2qScZd7p6gHBLPDWMwmqdJHZoZKyJvTWNQdR45yi2pEhN4hnViNJCb7VoKYU2yNfpzhRvDecGYfsaRL1zQHKP973aqBqAJJuK8SNpZD87h8kwx3LmAbD7vwP5P1yN"
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
            "4vsRCVJKovMgV2H8mQ9kd9H2nJcY3Q3t5VrPLBe4sQRVzwNbZyMjzKnTfsZJgCJWdQ3TJLnYrauNCbqMnUPAZY5CwnUZMUbNnYeMdVXvzhMoFgN5rnWvnkeFuqZ83eTduh9UiBZ47xSjxfaw"
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
            "4vsRCVHuVdbyL7TDLeTTG47MiSRLwBNwhwFBZZzkhFg8JHyo11JohiwPeeYfskV6wvy4Yw6xZhMV9MReDjupdyKzeYqc3HCmWhrxXLa8SV4ebATnBZP3muEAzLbUqgMfiuUVmQFoa5DvuSwc"
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
            "4vsRCVcAa5PcCDYfWqTkjcgTiKTpmqg32jt2S9G68vkHyAjpz1KosRcYXUhPWUE27VT5mwoG2xkLzdAgT5Sh25tNXTY7Xj1VqwqWbNfFSnLA1EueP3b7CUVCUsdjcNdvTxXhMYV4wC59T5x8"
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
            "4vsRCVp1tS5dsdsfSV4tc2WMankh6THm72nA5xL1tPbEu1jYWZQNu2VrWB5UthMj8fPfDwzQkWBJ3i18debeawydE36KmgCJYFVuEzFWtNwUM7cHH1CekTSWBd2uLbQu7DwF4brY38eTckYF"
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
            "4vsRCVXKcqdgw53FRQpUapPr8zQp3DPbSmHPRRB8S2tTxJCGvLoeTnyN6H5XaNeNWsq2axCDBvL48VMUhyVFqxu1tfW9d8jiEYJJytduUhpUDECx6jndjRiVrwy4YrJgTF6iGoW2STbS9r6E"
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
            "4vsRCVfycqnd7SzvJmwvAbSwc1kgef5bsPCfavgpELecKEfTYGjUWmSyj7osS62CESxbTCXcdDmRxCKsKaCNRa938cmcEdnN93Va2PabKdPjWPCj7C1Yw8Viy7B3zdwD1y3rc999pVJDxmbQ"
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
            "4vsRCVugGuxKA15PoK2RjjZcshVKSBfuiRRywgg32mihHVZAF6BCtQXC4LXj154UePSJBNpYJhGrQXrEb3EY2yG8XJPPjzbCUPxcqGdzejQKv1qXXNgaWyhaEuhFdPcrF4mHVMzGXbt2Z8FZ"
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
            "4vsRCVMKpmq8oBmecNmXMyPD5cHbmzrFg86qtJTV1QNvPzJcNdvKm8fteJHg1Np1xhvKWTDRGAuo3RdpNvEBTxWAMZkKKTwkcufYGurmsNoUqzDCCCP86XzfkoejFBERsvXZi9aRaRH5qUa4"
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
            "4vsRCVra6XfvkCLWXApaYPjDzV96JKonS4iVMywwvDFb2NTxYXAq3qiRy8T1YoeLxGhiqjfkM5t6oguCpq4nFtsbH65ant2Yj3TiP7aMctSYiKzr8TCwpWj3aa4BRWy5ZgAbun2KHZWYhrvS"
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
            "4vsRCVJY98biVNxQSzRCRnChe7QAf5rVUgFiY77Cwdbvus3Nhb1mtdBeE9QjYfAywinEfHm8ADmBuRQggFU3Ceur4sEQQdZc1nyQ3fzZGMhojPCKnxxd6UyV3R6jPYZKoJQ95Ys8Byii1KYB"
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
            "4vsRCVoFcRAQFbEWqfVGpfHkJKAPLdjgCjbsEwXUWbBqySyvaZbh2sWzNPAkjXWT8nKrG5eK1qHVcHMsChg2cEijvGpTEGGnbwmYpioJAgbYPDu9WpqYryMjuxcNwDZHHdevSe3WELxVpSzR"
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
            "4vsRCVPbt1xMWuQh2Cz6zmdrTfML2n66siZDEC4FW5ewncRRN8oHPCKSGFPtw8Kd7q9jMFFd1qNu2NrAbQGusebBQhFpfXChuxmZEwd5xb5aJ2eQScsuhtF429T99sTVgwZUB6xGPb8WrnEK"
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
            "4vsRCViYEyGiDv6ntuUcrLrduDKgGuS82GFHPEVmvrNZTRzoxPG6YqsxZnT5GxbAEgmr8TPebvjjN1RWPxZnZMPfXjmEYvsmmagCtZzmj7srg8mHs2F5FdibuSmiXSF7uiCVyHG4jKTa4TyG"
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
            "4vsRCVdkSLVmV3552KD5wRUb8f3Cm4wLWx3KQ2BbxaxXGf8nxCX85S9NJ19qk9YZtmhr7tSGsHxHcNhAFjfpmYiBimE1WYppGYbwLzWXxH2MnxeyjXraq5oa4x5Po8hz6jrpqTbBcVw6Tcs8"
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
            "4vsRCVTon6b2NLtBXhNidsZDJe5DGRosrLTmSnVAQu6G1WC1BYkqk9r2C9YmSxKmQiPUoDuDRLvNU9BGpSB8SMspRNmtqikcLRsYnbc5TZbTid17HzGb66WWd3i27WtMd3pNcS2fpJpcSxtX"
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
            "4vsRCVeT7GaQdcVs9JN2gnvhhDu1simiNpMbzTkdWbYmkDxCdfAhdyb1hLzEfsMUKwFbBouH5kkLsY24D8MF5mpshEwR5HQ7WKarK6c84BJP7Eb2jRtVje4jZ737ezjUvjeynpqsLVYjVDJ5"
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
            "4vsRCVZ5y9U5Xu7kqeuazmmkTKtcAMJYq33nobWpgqxdwFBrSsbgBYjV2ufBxwuZWgTvtKK4XMhVqFuNCKvyyxyBDJYL9hT59tbwPi5fkdxohYdJ4KsY4wgsgcgz2haVwCE5koPTyA6AJa8p"
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
            "4vsRCVh5cE2i4TxrvfSRddAyz1qXPT8DmBGKKbUq4fUuCbnyv1ZQAGTBzniywpfB4u3UaJG1PR6sfdwZCpNfZudcGoCg4CXRCFMgnsFUzYsTpMLnG7E3bpn9R9C812oaZM2ap2WS2D8X23un"
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
            "4vsRCVKErieYxmR63qxjBJT24JfxswkSspq67NSeQvMRsNhUrVs8kPtM7fnCWBbeUog5zirBA59fSnWTJtEp6NRekGACwEsJHr7xXDNbq5HiWW7nqrAxYhPGwn2wonEbqj2u8osXFYZvgwy5"
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
            "4vsRCVc4YNTcsAAVduM73vZbF7LTHyffANXUousFYC97VjTkdG5Sy3LFrkSevZYe7sSyb1mwsyS4S5NADFHTMJFkYQWY7ymjvtZXZMjStRZwAPXNbGnrs9UktyEyxhCuBeG2pCvm9Zi4M7gE"
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
            "4vsRCVwPZjm8WUe6pfFsVmC4GHeaUAUqRVhSB3FrsB1afAs24ygj7GSP677z6LimgURsuwfHaSap1ysWgx2LUtpenYesmQshsY5CQV9zHbrZGKGFQmc9pWUW2PRxMYkY2bRnQPJuV6LFqGUo"
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
            "4vsRCVVoRbdXuxHcYP976NXRuirjAUhihbgvfwgtxAoFjwxys96h9nuuXX6QgHdVTRAXK6XWGRisKfJVARr7fV6XihxhTnqtD8JX63p1Sc1ioBXBjjvEfohP4Hf9i4kP14RSUqoTJivLkbFE"
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
            "4vsRCVvXJ7GvPmcmwX4w8UgwcyMwgRPkn8aZVojWRMXnpaeort1t6V5zeUfX74THJZkSay93buYn3ETSSsFYjPtH2rjfX6phgptK7QAr8pE2pyFQMyCwvyPn1PBAR35HvEdffuf2wWRPfc7B"
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
            "4vsRCVg8i7e3eYkAcSsGiAcqzrGPi1QA7AJBkH6XW74LGihN7786TLGgofu5cH3ZFNrtnhV55WqEPnUM2oAf7hUxFerWquBw32MNEACzGHCwm4vKHBH4FJMd1faaNntoTRmPaaohwr2hAGKh"
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
            "4vsRCVncmdMGHvWW13XXFsoCS4S84sLSUYfc2pS8DeEHY8SFhhHSachM6QvgNpDihzmQUvDWahwuNXiAwuQXG4bby2oc7NXvovQbLYEjcwCwUGLC4xwcFEGMtT9Pbp22PR4MUEGjcx1jkzTS"
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
            "4vsRCVvmvKkNdkeXLhbRsEaxFHeUjmqtJfzmXU8J9WrD3bXu61wj2YTPgBeo9d7BC5QBpuChKhgAeTfFqBdcMtejAAd8iuSquYuHQfFAAXJmp9fF8be99gJpMAFrZGukpvAW8jVhcP7hxxJ4"
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
            "4vsRCVgJg7FjQNv5ayCh26GZfjKfQz3DigeLnjf1gQWZxZhZTQxJe3FYa5bkvMLjqmFZSwNJRznndrUYQiKswd7yiSBnfGt3q2P77eXNSC7ZV6Ng6pEGCu8Wd87srPfvf1kYFyRhyDqZy9SE"
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
            "4vsRCVzTt7Cf5oprpbue8bKLpmYxQW6vAyRKaZYK8bu1QYbFgVo97xHxdVLkrbYfnYcCSJSc5xQduLbf96K6X9M5BKthuWeJnQJbatdjvDBySRsExepn7SuCzVa6JhfyoC4qdpYuDwsc97ZN"
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
            "4vsRCVcaZ8pCYVTqvW2VAHkC25VP6AL7N4S4kTsyhP2P9QE6AHqKXzH4x3uvvVCPEVhk4PhJfFPkiuu4TrvGMbgmG9Fo2BpRfJCBMUbPZH8js2G5ocE1gebcDd984KK7aFvkbJHnPpgQRJcY"
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
            "4vsRCVhiNVbBh5fdtRf6o4j67HKa4i3ATNpoovKiMozTPTcaL4vQrg2tMdYryqXNs6wwgZLVsFQqtdYCnbojwDm3MYNMtcFDFLPfhiocTfuvFb1STr8UrZuy4TWfjVembMLTPvR3BWUMqVTD"
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
            "4vsRCVjMrwcYyETScUJE1jWWSkZbHyNVrTc9M7UrK3SXeYuHY15A2ScawzjrExhiKZFcVNB4mLSbS66ZpY6uSyLMN95Mk7CJpD5FGARzv16VXBY7FnxRBziHsn1VWwQXLRR7QsLWHuEiAwiN"
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
            "4vsRCVoUFwrCy3yKTJ8UTQTprRquv4oAnv96ZjuS1oZNcfKr6jvNL337JrbLF8HeGDr83gChEok3nFdGTUR4719mRZ2rxDe91dhB45aHRBaKmU7ka8dkFNzjhtJdeGy75AWKtWhj7HHzKRUz"
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
            "4vsRCVjtASicomgzYrth9fWK1EeTg5QSjQwEqkHZyNvy6KZQt3zfYZjbxEjdyZ7u9g3EqzBLx7BKLenUAKDGHwt1Ck25P3T6A73mxnWS9JupxBomWu3AJdbzycg6sWih1XRUhENAR7m8CZpo"
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
            "4vsRCVT23i1BKemSA7SJfvvvZzF7xFUUxQgHtf79rTS6XwuTbofXW2EzsyAyQEKFNyb4LUsS6H5wEzPMknCsmZSK9PCnoeQ4tVr1oL4g9wa2K7NPR1erB1c8g445NbPLqQSar6BW9AKFd7tT"
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
            "4vsRCVVN1xYu51aNLo4i9HnMUiaCSgb285N8DCyP5arQXhfwyNS4FZmPKrvXCJh3Uoe8S1gpnxsdkV6aNcn7i5ADhZNeyaJ7j7sHyPrDQtNVfj71VdXV1ZPE1ui7DZ2xD4tsfWEQWd7f1ue1"
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
            "4vsRCVbts3y3EDLhwkjHZYEngwuPmG24XXaxWsVrPEyKsmb82zedZaJKC77v9AUcDd8B9y4d7vi8mxYWDEZK1QpZ6Gn99s1EuJEkUzrdzdVZXhy9pbtpNqnHxN5Wah246SRwiVszussYvdrj"
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
            "4vsRCVnnGVBpz2oHPjnod5kXHamJPo588U862EVcY275Y5RuAfD8QJYSNmMBfisW3AgeZpP4aJwo7XuYudW9yLoZRnkdoaCoth77CpHzmCTwcri8VmX564sWbXGPhBY3epmu6kmV5MK2mMSC"
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
            "4vsRCVwpCJRaHAro6oVGDWLYqDf9df9fAjDHbSKkbmdzh86mBBqJaQBJM9YpifAGSLuYEfHPRN1u4Ma5VMnjui7Vdvs7WCVZodyRAgMTDpAEGu7mU648QVtKi3kVa276knDvyJFtxeWmPfqD"
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
            "4vsRCVQU5f89Cy9onW9MqWG48mPf7YtGk2ZB1RozWeNZ7w7FnsTnHuaiHoZJcQmeyWWQFT3moCcRP1GPc4WzCUbiew6zZKivwk85xj5G3PuzekbNfWyvJwVffTdzgkEyqW3FaUe5Sh4NMnv2"
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
            "4vsRCVbCQs1uQFHKotxJvLwNxat4cSY1Aypi9WeexcpnaHEx3LszPNKKuryCQEdD8mfhgC5Ahin9J3Mz9VLFk7QGncgzEdrtcaSktLy5UHuM5zfGcWKK3pVf7tC8UutCrEaxVXbSzTzMZECo"
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
            "4vsRCVkfAovznMzZSFsrF9mQUNGhuUtQrNhyQTdo9A2enNtzfr2KTvxzXutB4eWof8C42pNVGZhYZ1WTKvx3CCGY1CxnF2SQWyrgx8J2F32NNdhUhWJSwhkFigUTT1DYXwtrWv8ae5SoF8Sj"
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
            "4vsRCVVDm7869KkqGREWW2HcuqpW1MebJnGidnGgwXYi7kX7HRiHDVTuubZfPXurRzUG7D1o7FdMeufopbUrRjLkf7kJvwgx6zqRG6rBcL7Uy48YoLxufxasgyUJeHzyMRHqC9EWa6wQ5MnN"
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
            "4vsRCVTxWobjRb9gjUdASLffgPCyR3Kti7gZCp7mbzAwm7ijy2eWRKhQem9UV6jZgT3GB38eMTMm2trA9fTUzWKpjkGx1z2azBqBtiRVjsjPvNXr5fXskd6EHvEGvPSfoqTygtfRTTo3HSqy"
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
            "4vsRCVPvf17PCJe9SCC51LWdq2SeMFGGdEwKKSMAZTmA9xFATLZ5hBooSoyTFugTy9Q2f8pBCH8VoTxNRfXBcZA48ZXm66cUHmawMMzkkRoBXNcwnzDWhLiAwjRSKb6tQkBVeVRWUjed1DBk"
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
            "4vsRCVXD5tQtPBhgtFgZRWRJ9qsMaT65VLb84cUokXBARxzXwUi73qDBYdZnQZD1714rm4vS49Pw4fhy8fgUHN42QoxWi4pqjKnKGPCBgJdywXcoWvugZPW4pU1Lb4woJQDAFt8TFxZU2jBu"
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
            "4vsRCVPRKpvCnSgzGg5GQseheTpQBykXWztBJuJgsZBEmX7hqZ84Jgj8WkqPa6BxfgAWrSXw8k8ERpEdrh84exwo6pP8AMguAqTW8NP5uMUudViwthZzEyTkibiKWa8CRCnek7BBjZPU94J2"
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
            "4vsRCVf898ZSmy2asbZvR9HgeXYH3btLNSfGYDNFPrdjWAzXd5MexiCU5Zm2JFFTivrQJGZQ2cazuxGUyqSan1tEfSrMg2LsuxotqqJyiM2iiXnwKmFJAbMpxBwC7AKvetpXk9aU9knCZPzZ"
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
            "4vsRCVmemt1s9oaLCr9oLGMZwS9qT9EFE1F8FGGNRokhxHriPwiygii641h9kE8Y1i2wbmZWj3wvjtvXrJA3oUVobykfVGT3ovNB9J15xsCjpV7a1MYbRUDR8Grn9Zx5Zv8B1s5L7JeFmDx5"
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
            "4vsRCVyiNfvoUK4qxx6BCFZ9Dw43NnTWwdr4pvcekgFsW1bL9NsGak6dU5JfG6yhLNFEDEyTxMjmnzJbfqc361ufja9bMatbqm5K9BkTrbugX4pkiQhChSU1n3MAcVEZQFQazsUijuhjNMVt"
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
            "4vsRCVYVccWeW9z3rC6qXBS1B3dZumLSZUE98ijBX9mBk5L6UmTnEDqA98T1Y34uues6uSXoPvpfHbtzM1ZEgB8WsSHChJ6pP5mCPKo4nGrcmqgjGoaix26aRS1kuEPNR4QxNico37pmdQXi"
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
            "4vsRCVPZnP9Mzt9tt3L5kt4aSgUxQyrHSgMHMUSCmipAXi6ZMcr5cDuuQzSTnvtCy9c83CDvLHBiMBkVCacfykLsNfMwvaXPN5nSrLAMvF2rKAsqFTWjmR6MjEjwKSguCrCGAheyMqTfvKxj"
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
            "4vsRCVhvvqVvxe1Np75tAGUYCDg3F8wgKosFoNE4v2XAwrWC1YzQhAroWHm11u569mo3hr4brEHePKNYhC4pwx1hhJM9j2rt5ue1dzKTUaFKKXpfjGvgnMzs4CJfbPAL9RRE7K13SQUbZPUW"
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
            "4vsRCVdMqaExzwUW8FaDeCMXAk5wZxp2VsCQodA8kxLpf33kPoHvDHBgYbSAiZvbVSbtRZ8TmnhWRsGZdvWz2oG6A1gTesGuyQ4Fn1yog9sAQVkULKWKWiiW4Jo1bLjv5KT45ZyFHH5HH1sa"
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
            "4vsRCVx6rcxfXWaqhrdZ6MmaUefB81L3dtoEsgScQfzAQyDfQM7E2WqdfQwpjSHBhZtg452PHPCpLHxfDUyW4TFTNRLEGZVXzYuEHzUNb7WTPuuv6xfrQ6oQTfSarhiuUrGKW1VbbEZEwNTj"
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
            "4vsRCVsGr9N7iRKRgq4Z19wjWvDs7W94VZDrt1R3hR1RH9h956XFikZV7VK5DdYZwmPQRSvdLrNWuWwNvEuqncgmi2G6JG7pVWD9k5ZwoTTVzgo9KUbQrX1qpaL5uQmwiux1YMDB7SS2r3ir"
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
            "4vsRCVN6NQyzhvu2BsxcRN9oSxwzqggyz184MnTe5Kxxfd3QaZ9WZNJHLNnCzbxN9cPzHDUaG2M8UibXuyiZuM2izRmmUbwqGWazCqiXjTNWaDnVKZ9CXBQz5tfUHCbt5h5UvYYRq9wnmp9U"
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
            "4vsRCVYLe4hFJHjdD1qENnyyGzQnxCsAu9xVYNvEPAnpxdLjKrk7ix52Lk2v7yJQpnShh7k5x3nA7464riKDvcnwSY4u3ESRwXHH2fTJjS6GAbqeAW5j6ZM9uDyejfUuaCEMcEfTX1hcjJgK"
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
            "4vsRCVgM61cyCtzabavBXiaBMGAadmFSZcmyRgV4C3ecQkNwUQw46cgtntzttFWfLM6Ayh72bdW52edtmiJwcpJQMM79PrtHvBXTwMbMJBpDe6qoc6MBcG2Y7H1WAhz6yztuXtvQWEPgr5XT"
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
            "4vsRCVV2wjgQbbjfiPZFxFvrM4aDkhrxedjruV67ZfsCurxvD55WgLhrDKagAur59fp5GZRRurauug9EBrF3aV2F7Fke5Ce177fnnojb5xYBzX2kn71uA1KU1RUnEKes9yB17izhcHJNgrJ7"
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
            "4vsRCVnaom1Hu5yJWdaYuDSCBzDC3yZypfWJ86tDMKXxnvCaUquvC4Gidzd7mBHNcZQLGKKisjfRtAf5BRkhtpkisL1UTjQxpTMhvHgNonVzEihHRtarYDuHiFPzNs4TAX2fYiCrsrErzV8d"
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
            "4vsRCVk6qk8Lsg8CLP5aBY7odVXEfbNJrH6PEHFqJSUwKvtMEiG8x5U58kX89yemsjSAp19abS7euDD3UbeLdYm35aBEfaG7WnCLjkUXstsq9gHFznPMr2Vaz1adBgW1wnjSqLWnqbRzhb6Y"
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
            "4vsRCVfPqd6y25kP22dSqRfvXT7QCFjW1UfirohyWZ7SAt2MhfBw4NNC3E8YVWKvEhU7GsGKkzL3jd1fS98L1BSFWcbgLd757zPmD9hgHV6KUvNbPX6sPEwQifxFQQfs6hnzYckGoreQiztZ"
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
            "4vsRCVUUhcY1W6vFUx8ZanSxQew8hvBD5FqRQ413YkRjxaU7rXfUnxtKx5tNgcbdtYJyDkzeQ2zkCrRjo4QnhTX554XZ2b5vQGvWPDiQBbCQwow973Y8XUTWVXJ2qpaXBFfewjFPPiAFn1y7"
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
            "4vsRCVfSovmdiB5fWRnGLYF4tdzA4bMJupk8Zs12MdY9GcANmn5aoZw4DMWDdfGK7dUs7V5tPdhgcrLaki7HF9HBdGTgscP5tHr4g6ggFnaMYzNM5R2pgkvwX4k7iT59YHfCVEsAPB8gS6t9"
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
            "4vsRCVcMpecN8eqStR65XSuaH1ywHfXitE5sCML5GMRhumZAtMAcoKpTFcrheMpNJYQsDfLfBn4zroiKDemRMUcFMu9eyRRv6F7oJnhZJaorSh5j3BAY3q5f9w3rP443y5Q1SdqJZEVU2uhP"
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
            "4vsRCVak5jZZnAwPCVvoHqwKCiBsEv1VJMpywSF7sXT3oH5s8ACKGPMaMzygyaKhxQrLDYgxAd6kkedozcUmR9CTa8UtzhgJdx47M6zHfCk4LFy1mjuvsNDT3gCfuJ2sn9yMUrfjNojcNQuV"
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
            "4vsRCVgvfkuRYfesDy5P9z7DX9di2skmZJfNMYaFXycHzM3U2YLQNyTHWHXwgUxSgQ8zmZjfckDiePDAhvsH6UDQTCWBnTQ14KfxgdVcLWsN722drjqP626V8bhY76kYuwVjNUSCXVcznHPD"
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
            "4vsRCVTp5KrSqp7HcqRJsyKEhLbVwUh5e9K8WYht5T7vefv2ngHFTi3mAB5owtJQRGkqRRrxMMpevXBf3qLSceYDKsRoGbBq6mAoJM8AqdRrQBNTpjPQvSiK8nHNDQyPZHVFhKdtBPSrqdPD"
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
            "4vsRCVfLwKmsRK9axvZFqapQoCKhNbGbw2LqGtG9VKW8axBS45sie2q3DFbEpbL7Y1xEtMu8QtmdpR8wERVtzyTwvykiHjcUGxtC2GJG7UxfzGT8JiK734HuRi17aQJpnQckc8fh3Z6cE357"
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
            "4vsRCVJQRJidXw1oHPAfWR28mNmyxFw26zpjWxShEU32dkbzTpLyUqZBvhqKCMZp5mwgAcPSMtBGHZvQZ2zHAVe9rvdi1HFJtiMUF3hKfhPu297kFMKRMNteXS4Hnh4RpWig8gfHwGfZTBpz"
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
            "4vsRCVU7xykRkRB4ujf7Y6B1otYgckB3zTPTY7VA8Y6mu3F3U5KuvwoHs9559JfTzxJcMcJoKqLLCy8qLPTGRSrG4bxhUqEt7STKd9Su8wkHGFv9KSBDqFzddUgjnbpZkeLDmrybQnAiVnTA"
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
            "4vsRCVvH9TXNx2JsAuPu5JvDwHjvkTFketFhoyXeJWrYzkgz53yfSMvLCmYKmN1NKtAtSdSznLwFTFm3QgwVWBNBSCK5bREAuJfWMjRru4FU9sgLUf8kZUj3Qsj5aX8VqfgPn1DSwAceimiG"
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
            "4vsRCVRs59mZDEEUq6asCXRAHb8tGQi73p1w8Br1euf8ng7PBn6v9jHGM63t4Dmuqe4XyKtCcjZ6DBeTT3QVabCfk2fhSRhsdEHWCcM2uVpLYpyGwawxFuXtfLHu9jFh3QZNs9EsHj1F4bN8"
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
            "4vsRCVxqEVphiMKptKycnWsHxdBZczAm4V4vYuidzFV8WjbLqn5GQFTg31UfEUKYoS2jnL1rrXjnvczvbrSNjMaY5Petmj7HX5UYiMW1tP8iFYV5rrUfsH7tpmc5vC8akHdJrEwynk3gbWo5"
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
            "4vsRCVPdcL9NXyqGKP5iYY7iuCZXTp6Vs2AyJ8FrsfxSsmtDM7UShPwzUBKsgKwiP3TiCaSM45MFF1QiHcMnaTsWgnHiykz6pKVXtCdYb9Ho2aSgAgQy4To1xmP6rYSoN7L8UMrUy26teg3m"
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
            "4vsRCVNtwTVrNJnhgVdiGs8zNephTvCXnSFfRy974KWqwaQVBSvAR5RB9k2fm5jKaYPXXsVga3CwJEjwYZQANmdCGTFSpQWi6X8ANj7fSiZjDvXYASGhAAarVops8UmN3Z3BwY1qDU6LptQm"
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
            "4vsRCVkRhYJAEJg6NBLcJTi82hQEmtKLqY13Nzr1qnNDgvu1kkECo1VojvtAj8mnaExwwPNDGFBGWoUwtiCM6MnkC6UTycpjVfdBquGf9dGLzgzReGVY2ZXgg4XWyrc1BmT8cuy8c8cZkBeD"
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
            "4vsRCVmZ7cuedwqVygVNCJLkWQrYjFh1n2511jVN9dJ3CP8dATotRZ4p6hRc9ZwiSXsVwRDCUf9UjNq7KVZaWBpbnTksae7owQqa3eHqK5oVY1QJKoKZhUDEx5QuYuzyWgcHmBM4g1DrWb6N"
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
            "4vsRCVwYaNkcvHn6tUfrwieC5Gvctdd1TVeLtApQo7GUcF6k3kNEPjRkCwDzxYKjnjvBjeYD9QaBiQJrfiax8WjdeYKXyB5DaNmnx6fcnePPq74FYNezUcPKoTWgV5ewDMT3UT565nu26jsQ"
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
            "4vsRCVwEXDfewzKg3aHcNcgeZZnVfoKu2MpiyQ2S1U37s2vKjRELe7QuGjft4fkQsK3itfXg4uM5dskfBsorWKSjY4v7CfCEb3vLBmpGs8TYBetqcNt2jiNXSTx7KGeAknNPakCKyVurzzUj"
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
            "4vsRCVyYuyytsi4L441J4fwv4HEPTu6XR7oFqm7UH4kQpKDFiQGDMVkZqdcGxJF6tzKQ4S1Hu4ZE9ta65nmERLKpyux3XKFmoGqK2X7DceeYWwHZ9xsUtDk1UxbcPTDeVz4RSpxNkwaCUt4D"
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
            "4vsRCVMK3qn9E76hbshTtYgXoACt4XmCr9Kmus8Ty4yahdsTyDA2vM79FGSbff5DjpHFxzfT5239zThJVbwb2NdgNifsU27PQf8vBHeveqvACqwqWmqUGK4ZJehNBajVsi9fBtADJBvZAN2V"
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
            "4vsRCVQJNvv9DC1oHVqxjYwyskv8Zm7TXqvuBXPwT9GnorToc1bAXRZDn1Zd6TJdLYn8Eh3rNCiyb2bmz2t5BPz6ne6QJk49FBcTuqkui5mYm7xpg4mHfxGWwmztTLjmJdDSnCWLDLx9GCVE"
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
            "4vsRCVLWCb62UwfZvFZy3xrisp9WtaHTZXDRveu5jY5dJxp3iDx24dv23rLwTEeMY1CUFxSZbLRXJMX5uiARsX9yAuC6XNJNvF4a7eV2mFyGpSkgz78YLPLfLqVgxH75HAnSoL1iAmxwD9mt"
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
            "4vsRCVzNtjhkhitesDbs8jduhveSGvpUNnS3Hgu2VKq3VVcnL2Hr4SZdCwcrQVGRswucK91MpqwSHXpfDTgAwKUyrhWUcne1XgFKSxA9PCh2WEWfpLmbNxyRRpTPswFgPfP3j7X8rGpyqpm1"
      ; balance= 338622
      ; delegate=
          Some
            (of_b58
               "4vsRCVm1vvgb6Lh3NF9w2mVJX7HLGatXZUAzhcs74z4sc2y7EXE5XgGsiHQGZta1TG8nuoAoK3Rk5znuRPALjrhDnov6swaYnBeJhDCikvJmsvwpvhP73XeySFgzkqY4GKDW6kir3vPxSgJW")
          (* icallfunctions#5999 *) }
    ; { pk=
          of_b58
            "4vsRCVm1vvgb6Lh3NF9w2mVJX7HLGatXZUAzhcs74z4sc2y7EXE5XgGsiHQGZta1TG8nuoAoK3Rk5znuRPALjrhDnov6swaYnBeJhDCikvJmsvwpvhP73XeySFgzkqY4GKDW6kir3vPxSgJW"
      ; balance= 1000
      ; delegate= None (* icallfunctions#5999 *) }
    ; { pk=
          of_b58
            "4vsRCVRt8AqRLhUKheJNNxcWV41bR6HAR5VStWhNaEhcEWchXb4bG4ZE13iJoKDKaWERpFHxpNA131n3gaMzxzjhFHR2octNCxurk4qBDGbtJipDJ8kkpUbJ67dppPMzzVYuDd3FPqAXNDMn"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVYhoYydDfs8SySqMBugZSTeqpeYfvFqS4Ep8KfzBtNmLVZKmzMw8DMT52ykBtK7heFajVNkYMNkAumLvihhEEpsgcbexVmVQt89YNhNvTmov39dQLbEFJ4ub1xh2b512wH5aZMRmXMo")
          (* CodaBP0 *) }
    ; { pk=
          of_b58
            "4vsRCVYhoYydDfs8SySqMBugZSTeqpeYfvFqS4Ep8KfzBtNmLVZKmzMw8DMT52ykBtK7heFajVNkYMNkAumLvihhEEpsgcbexVmVQt89YNhNvTmov39dQLbEFJ4ub1xh2b512wH5aZMRmXMo"
      ; balance= 0
      ; delegate= None (* CodaBP0 *) }
    ; { pk=
          of_b58
            "4vsRCVwAPEApPya4F9Pw3BfYsgShvLZCkGXHztpFQgkJ41YXXUUvKDFo3eCF12cw5P4uCRcxAAJbViAADEXKt1asDsxtxWXkpYJMwGDkEwgt2FQykNxEYRGarjEJZvAecoa3kd2SZBwyvQQc"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVmdd1xVj1nLN7R38KpbLpCHPsbdEpZjFHi1nWgSoo9aYPHPN5F21DsX62pdjaA2q4ugCa2UzySjTH1racfkuHgjdE5tcDaboiNMuLTvcthp65EwGtUwRuPMqthLCQ5Z98SWyiHwUfP6")
          (* CodaBP1 *) }
    ; { pk=
          of_b58
            "4vsRCVmdd1xVj1nLN7R38KpbLpCHPsbdEpZjFHi1nWgSoo9aYPHPN5F21DsX62pdjaA2q4ugCa2UzySjTH1racfkuHgjdE5tcDaboiNMuLTvcthp65EwGtUwRuPMqthLCQ5Z98SWyiHwUfP6"
      ; balance= 0
      ; delegate= None (* CodaBP1 *) }
    ; { pk=
          of_b58
            "4vsRCVr8Qpixz6hJMWM8g5MZh5oja6NoY77g748KaQRVzDd9TqEhNWSwCiRzwc8ncoxD96odd9mnJNGJf5ohXHUVEodmeSsTddh4fJXCTeED55Xbokfszu74NjREpKujCVcNtDwgxywV5BPz"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVpr4TwM1K7rVdRJbybw9vbDySQBQs6xMDbacWybt4TYNChrCDqiAEJsxp7hm4zu1EVGzpD5jjKWQixU41ubWxQYGP46b8y8jJ9L94g7QhVCqhuj3yz41npo2B4oC6UkXNCaHsEvkh88")
          (* CodaBP2 *) }
    ; { pk=
          of_b58
            "4vsRCVpr4TwM1K7rVdRJbybw9vbDySQBQs6xMDbacWybt4TYNChrCDqiAEJsxp7hm4zu1EVGzpD5jjKWQixU41ubWxQYGP46b8y8jJ9L94g7QhVCqhuj3yz41npo2B4oC6UkXNCaHsEvkh88"
      ; balance= 0
      ; delegate= None (* CodaBP2 *) }
    ; { pk=
          of_b58
            "4vsRCVZgvj6UsDGBPPvKWEZp2c3FxKPqgArRGgjczsaoivgWLoMf8CKhTQ3Y6PrNmGDwdb6sP8ksTG2Lo4upyZr7xkbDqZ36jMBw6eRTkCuWtgVUdrnZVqqhVJzAKCLxKdqnsZCpNywrJvAA"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVT5wTkmebkugGVySU6E3t1JFNZYktPPujozezMn7j8TXZqbfuuHyFaJg85FXinXhKwTGcSvvWb8Uv8BWMttcW2QdSUy7Bb6mefrU1FZHnXALzHFawp9MuktypnYexyG93WnWPLXDC9z")
          (* CodaBP3 *) }
    ; { pk=
          of_b58
            "4vsRCVT5wTkmebkugGVySU6E3t1JFNZYktPPujozezMn7j8TXZqbfuuHyFaJg85FXinXhKwTGcSvvWb8Uv8BWMttcW2QdSUy7Bb6mefrU1FZHnXALzHFawp9MuktypnYexyG93WnWPLXDC9z"
      ; balance= 0
      ; delegate= None (* CodaBP3 *) }
    ; { pk=
          of_b58
            "4vsRCVQLG8PJk2sAuMcLE8Y4K7sjxBqDpCVTzjGoxHvVDcJYcEbgsfYsz52axDZKJhwWv3RcdrbLUtejA5DeL1heZCfLkZ7skkGpmwg9p5WFKviDKmxigw9P7ZxNsCovU1xCLdbBCKuNoNdy"
      ; balance= 9600000
      ; delegate=
          Some
            (of_b58
               "4vsRCVXeqihX2Vu2nNTSxuQ5gnEW2hUMaqV6kvQ7qN9qGMZR6u2fd21oiHAneNseW7McmyVu2bKaPSfXWoG89NePys2KVyz8D5Hro73EkKvYNz5wYFDzAwdjXBk1ArHSjvaKeScRxsyuwCDK")
          (* CodaBP4 *) }
    ; { pk=
          of_b58
            "4vsRCVXeqihX2Vu2nNTSxuQ5gnEW2hUMaqV6kvQ7qN9qGMZR6u2fd21oiHAneNseW7McmyVu2bKaPSfXWoG89NePys2KVyz8D5Hro73EkKvYNz5wYFDzAwdjXBk1ArHSjvaKeScRxsyuwCDK"
      ; balance= 0
      ; delegate= None (* CodaBP4 *) } ]
end)
