[%%import
"../../config.mlh"]

open Core_kernel
open Functor.Without_private
module Public_key = Signature_lib.Public_key

[%%inject
"fake_accounts_target", fake_accounts_target]

include Make (struct
  let real_accounts =
    [ { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJsZZgAKgcuuqtRs8cb3SDJAfTdwpbAdg6aNnV2WZXftd2USKNFc6VPU7KtFZD1JNnCzWq3ygaioNNxqw1d6DW4KyR8MhNthdLDQMYK2nwz8zeCWUm6EQpREnvQDw11khpbKoyBX9uJ"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDzaS4FNdrvRoCA4outAYmewsL2wUgvuwDUs3xTfU6DNm9vqwpeb86rNLy1w7rvoNyGzKbw7xjFxDZcY9JB7mAMCkp3cZzqta973pRggaf4xQCcjwQMd4Snz31pyyAmXNZZ5GZLqYTAp"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEExsT5SkLqkvG32MQGiSmEY16XKLHTjXFAjKfY4CFCjXmvYHsgu9KbV6vN5jsiY3fk3sXnmsMgTaszmnuKK1fEZrq2zdguj7y4K2U17n8eBcJ5RtmKJT4KbaECkczDj5hjoLYKQLpSM"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEGQEhCC9oAqm7iwPs5Xwi541HD6VU1f3hqh2g8ghmWEKy6oRvEpE3j8j6nkJsyoY4syXu6iPiNyhRdxvcgpLmR6XZxRcBL3RLXcumaVFCauy1e7vYmSYwucdhY3uC1eX7AYsTgpcv7Y"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE9SFPbLMJVDAUi55swrtrozfHtUjkoS5d6w9oVM7hVzQNmJNYXV8cjYbwC9WaYaw1rfubkpCr2Z2nQhZKuY1WufEbnqbd3RWzriR99YYsVfm2sEsRJ33KZGvkmvLGQsVRgdH3yvxbui"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDzwg8k4P4tnd6j2bwkJXZ4T6yVicuCaywPBtPxUnAe6ux2DZHfTJ1DCtEYdqs6YaFfktbNVDM1SMgBCSLnWLYurK9scrzfM1SrSS1UKdgJGyZRb6jtdMdGVeBZ1CMczrUAL6YJhY8BU"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDvdJxhHMnaNNgT5WZVmvvNFJHtw7LKVwNsZAVKR9TqDEcCrRGZvgM7b39r7NzH7G4P62HQt8B3JWocvxqpw8sfZm45ccaKn9eshPLvr3SdShbmQNHYNXpzYS6puWsoCvA831yjqSPUo"
      ; balance= 100000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDyEyfcuvCxUUTujmmFLhPd8P8HYuaZPnNSoMzbT4avy4HRpuNYzH7x5bpcX3dSiK8BPmhW4sXzLMRD4rWTHqVKhjC9MWb2CSUwZTKSpHkqn9g9eByPqc9r7J4TEUPoUi6LCsh9eHUf9"
      ; balance= 10000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDseiVzaXHutEETThWV8r1o1sShXtbvmivKyqn4QzWKq47Nyq6ySSKTvtYG1smgwSvieHKTB1vcBgC4ri1tdUwqBRDxG9vAavYS5rCd9U3rHzxzc1vx6rLBJqc8K6Kprtvp5btvBh639"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJiNi1rQVyeceYAbuzNpgHLLBCVp4ytA94uMYfQ5oxsheMiB9ji2mpYcfZizZgWdUkkkSmHgoPXpy2QSHRfv6q1t7s6uz1pyy3VnHJ1JCw37a4fwGXJWwZ6B1EWJmbN6ZknHR6itVNs"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDo1ewp9qTSLoqX4EeHwPrEbXLjyJK5nMMwrKxPzn6svGs9JZFeDArrFTn9qQoK1FjrRYMxfEqqtpU61pp9tLyzYucL9RyCPYCqkq9TMtc5DqiEwEz6ZhgTo6Umqw3NBy3G12YfcpJET"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNECjtCJpUkSt7bcYqR6EYsq5PNKfBnHGKfms7P5ThzdSpmiJP5eortS1tqXZSYLoL4kcaZ1aWNe7vAxbenicp9C937bYPKCbJP9z6PsctX7ZAu7o8DL3Ksgtf617SFJNnKU2PeE5ZANw"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDofUmexJwPBsbr9CE8ubyJmYECeTvDiN4cQeDsfcYWjVdLRdZ9j3J3T8Wd11LzNx3pU6YGns2EnT53PkLuLkoTVHRM1RrNVxWo4tGUQ4zmGR7W84G2QvzWnHuGa4BogScimMUZ5KkYa"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEKeteDe3BiV1iUberg39NVDwtCx9FCuUVNnP4V4QaWbq6mWHVrxY6U4pLGKyh7kekkVksdKU3eSsoBnUfrQ31BabPG6mku96DBT9kTUdYn9CYEevvYNE6i4NW2gkMcPSp4fftpKxVSa"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDoKqufxKmUbeFn2QVqRZd9msgzv9jZJtXDSG2Ejj88SGYrYQGUCbKV1353ExMpgJ7JDd2StektH4VVcMGpU5QpV9cQ2HcG5og84YUFfZMViGndWujLPWh68aZabbxSvtgffRyH9b3qP"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE9sfjdmpzhbjGYbELYCTbpkRgPDFY3TQp9SiaFcjPbYcViEtHCBbY19SDSDYUucSLJMzFduMtmGdVUFVy8qHT1SoYeWHitxBxaS2Es66b6LxXgkbUbWYveaTRc3sYcKvhemup8B1U61"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDwBeQWGzfnEWwUFByib8zt3zvQXDuYTmZ5JiUuV66RdTC16WLLM9sqzFhSLKUBv5RLfJkhLoA3qQaHr9bRLQZPyCp84fX14oogB5eCxZ1MvnwsJXEDQqgHp7toBxNm1DyakeSxxUbXQ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNELqs9AgMskprmE7rYxD3sVFgc84AF5DdZQSo8d156WR423ybaPiACpJdhWanphSB44GTp6GZ35DXivf6QKFAMeXJAYKNWCrabydktBDjv28oCwbSBpJNoDwNMrR5aqKeKLjJuF129aA"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE9Q3osZ9YNR1XaHz2uA9nZwywxFvSw4YsH2aYeoR1AwLksRDib5hD8u6DxAizZWUohYYMsEPmpkywcQeWruRz8SXB8UgdHKbJKYP8BNaAC8Gz37Z7tK4vauEtd54QkmCHKqvUxrFKry"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEKPyJypfrvJ6Ls8KGpqVzdwG7fMc6rpBzVaxdDt2H5B6pNxASxB4FDisH13qMUHHgbQxUFDzJZ8hC9uxihpro894gBQyjchuUM1Z48g36gn84RV5cnXXWuVNfmm54n1s4gPEa1rXbiE"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJrfDfmwTDvbKK3Qy8jmTEcDciZrLK8eWMcTfgRXVemYkf6y2sVtEVofY6G2uZQPzeudQNWmzZUqrZzM5EKFCHwzTajUWkceNEcJipCNiy2oGnRSsZwb98NmCSGTFRAag3srHsdeFiL"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEAALQBv8M4z2BPBSzBGksmD2vSLiVZEqAnHiu5NqYzxRjzP6ijUSfhAEm6LdRmaEcixxHcfzAt8tEr6De1uhXGFAVYNuxKicJ5JMC4QJPiWHAnxwqA1mfkvCCEip3p5qzNv6fAe1ygg"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDuXmmBbjnqXVvfLfGJmnicUEZpXk29VQ3n99dLJyRxGJmcdmTmrnmX7zFV5xmnGvSvUb7CcmmELr1hRZGK4Kk8iqTUNtJq4K8vaK1SR2jKLyGCLH8m2oySkhVyZwZH4WFhLJNiCsC9e"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDdfLzsfk1NGHbaueTN4dWwp8ok7B63EPeBsuoQSLXBsSji4tubzm1ndsG9karrsXKnxdzQiyABgEEnUnYdFkmCpC1grJ2TDaiKaZ6PEb4zzBhmymWkiNm8DyjXb1hn2VLjw2zoiJFNc"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDfqj6e3d3BGTmoiFvx6aJwH3UZjRLTg4GTCyYrBM9u7CKqQQk7nPRqTq8mYx6DzUaHFAM3sLB3vwftdthx1kFRS3ibe29GLis4aRKHuW6pSvRzXPCGbv8zdLewMxxkwzthKWHX7pFd5"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDqHYV1HwRqaZVj5DmdwND7peQLdTvWjfeHWrNh8HEs6gwsGXeeb3QJ8iAWieVLdLFMtZHe6zsPS5k2Jc8DiuAtAt5jWnRLm9VL8ngMeb7zAXTwHXQ7F7Vos1TuLb7usmgHYeM9eaWCe"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDrApVY8wEHfpCWGN6vh77KjCrxBXeiGnddCBVivst5ULb7zhvpiMxk9tjGJrx8jEfkBic6dwrbFP3bFDon2BvixwMvsMTRqSKQKxRkggStEL46bEsSE7dbJhDoTbLYhjnLVS5knTebB"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEAjLYCYpbdnpQgYXHqHUGdxYnUwuWrYnGHqQD332gi6T69D9CqtTKEk2AYSyB6KukeMhvSiiRETP68A1x7FiDRGQoiBPEohY9vP5t5bfmKj16NE5NdGQAMfPYr2YsjNYRmb3kZCdkZX"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEDE6wsro6etWacrU1uDqdUJNAWLQtJiLbxYzd9jAyf6m9LXRAsoTN646LShLCcoMkhVsantNTk68DdtikLfQPhd78cx6oSkBNt8Gifmc7QRpt2rEcuGG83hj4ASb9uxL5nHVpEZjS7k"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDtxhx6n49ZG3s6iD61dak8JPCxohqwRHgH9axznX1YVPvF2DsSDi6M4E7mW89RWovbDZBDL1Lug4uNq1UxzBEeeSScpMz19FMRCYD7m4ZGvksiRAoQsH1fKibpR537EyC5uqdaEUSEZ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDo365GjDFYwrGeMcAc24GYRA5Y4XPft1xxzsXU5b3yqGAbx5mFy21Wf1DNDjpiVmt83inXB5DPfJtU6x96ytgLSaz1M8h4oR2a7LKBKFMfdC6YDUJWmJiZfhaSSy7KdfhQugT9fEaKt"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE3LsDXqtFhMB4uKTztuNzKdDgkZ4wLsVnceaQcVXyHwwd3TfzuXXiSaRjscSBMNx3d6tzoZV6UvC8xaEV3DBe5mm9c56y7Xp8d2aAKWiXYjALxqMzptS1iBgxAX4wdcJUzA6Dj8s78M"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE1bWtMm59NgZtdPgUsuxkWDiFPLq6RxES3ACTbHeXkhMP5nwTs4XKqxQkwoeED9LvEkUBQUYAZhoTQEPx2xi1uXjUQBBKaZgaCZDQsTCjAvzNdjZnLKV23esMGymrorcHZQRjdjugdG"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDfiC3eeXj7wXdQExgFNzoLqzTzDzWtKaK1bVqFuFvCvmyju6RA3XttPXw8aWk78VRTYrv6GEuHmSmmhK1ySH1FvLAF1PporkZWJuHCGQtTeBFDLWRqumAtwt2JHox7ynrgN23cZhPgt"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDr1aFiCowmfE1WijojqCh9bGrcrLRiviGNGhLixu8NKrucnZ9shC2dp5ffeaQnK6XAw5bgPCe4kj3eDRVYgvbfjRwKZfJ2K6CN2j84zL2j5oYyL8CZgjefRDfwjWCFFgvdMKxHxSu21")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDhGJJfh4f59FmEehpxUvoGytywm5V4hibRE5cREw89CCUDRt4MTBHxkksipUiErZBkn97KpphBJ6rCYedd59kZQNMazZw1mV5Cgu7KsedouaGPiiPuniApXBx2XwYyhigictPsQ6LHx"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDqDEzcSbfjBRbXBTN5MnuyCpbAFVWJ5AUT4XX3EB7iBuJZA6iHKNSTroxan9ch42TiVcBFeLWevL7rswsxqQYhvtjp7kf3mZeW8SNta77qPF7YMcDyGtuuk2PXWpbB1hnTDhoJqohVL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDmctzyT6GxHkVgK6XiENiS9nnpWK4S2HsxNZPqnBnYdF1m6gZGN8XKvjRcn4vkB4JfqxsovrwAFkVFNhe834KxfPyogfBhQRqjjugyroy9tQVw9zi1ELiBBrtaQmjhpJSmYwBoHWWMa"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDooDBT3mTmuuj884g86nSpL2Xj1xpo62Qgi2WP5xaE1P4wSPW5z3LSEpb2vNrDEdUhnhu6n9jbhLDtdY9XfqbWrYKsgxMhn4WDtsmURBf5pgZEzNxWa7KK4x52NKQfpPJLoNBAU5PV9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE9dzjSxBDt8xSSV9aE3wdoQCX93FdfMS8a8ubxD6JrrWoibXv9Ca6Zpwh3JLhQw1rEdMkVoqQbJBio3qEMEYtoybjyJnEwZVEp2h9EXR6z7KHKGomfx9nWVwc3DJk1vYLBcesRU9pY6"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrx7wCSMGJwL2XFscMBn5C9hjmnBRSHxB6zauwCoMnF3iWf1kvBSCPfBVseWpoUjrAXyJRh4GqtCdkMfCbiG6KcusjCjz4tDdny4ac1q72vKeTivU3ne66LpESAUmLT3r3LRcurBXAd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE8rLbUaSA22uYfhchpnSsrCCKCeotufFgBkmB8H4hz39UacX99guZc8bdirrJRvT9wyPn47545haNPFxCkkn2csq3eCeAN1WGctpoTFiTtseuUxoaofh9vSeYV4JYzVTvDKbteoYxB5"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEEgDD82AT2X7mgHv4yYgyL4oKjP3SFNJMKLRV5xfjcxKMCYgE6MKAM6moSBQiR9MA2v3duA6Mr2mB4QhipHRmNq5EKchDoYJjuQcoPo2rGADW7AuCwV4zdowX6CR9rvBa6aU6AKP2dD")
      } ]

  let fake_accounts =
    let open Quickcheck in
    random_value ~seed:(`Deterministic "fake accounts for testnet postake")
      (Generator.list_with_length
         (fake_accounts_target - List.length real_accounts)
         Fake_accounts.gen)

  let accounts = real_accounts @ fake_accounts
end)
