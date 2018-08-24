open Core_kernel

let pk str = Binable.of_string (module Public_key.Compressed) (B64.decode str)

let sk str = Binable.of_string (module Private_key) (B64.decode str)

let rich_pk = pk "JgFkl9FmG1SLJ+Ph8kCGuG0bH0RHYdUe6VcmqlVBlNfDPm8y/9wZAA=="

let rich_sk = sk "ASjoODd+z5uFSXr3XlFpvy3O7j2+2RlnU354HErLSv9jrAUAAAAAAAAA"

let poor_pk = pk "JgL1+XZwf8h3rHAONU7JEEpC88rYKCsht+s1SQMHHBmjL6OtRuMeAQ=="

let poor_sk = sk "AShPfTImkKIlph1SoMhbcK6Ykz+CJnpJNg/Pm2TU6j9D5SEAAAAAAAAA"

let extra_accounts =
  [ ( pk "JgKdMWuYhlGknk9gfyfOCRcjWilIjb3Pc+7qohJ7BFeq5Pbp+g3QAA=="
    , sk "ASglIO54FD/TlwgRWvEGojlTmD+AsU+4MWRMmmIoKfNV8AsAAAAAAAAA" )
  ; ( pk "JgHQomPdDrSdw6AvQaDllbsaFsR5DXPrdauqz8smBw3TTPnoAuLcAA=="
    , sk "AShh1xwPJMrSbAcvsixZ2Ee2Te0XL4gyfINg4Ut0HTJtCxcAAAAAAAAA" )
  ; ( pk "JgG/Gcihxh/cp4UZpIyG66zotLGAbI+o/oK4nYzZZsSvV5R/N3svAQ=="
    , sk "ASiXPIakKEQm5c5E83oojXAEwIC5/Nu68lLTQihPx7OGZQgAAAAAAAAA" )
  ; ( pk "JgLeKZNVh25d//bfolkrpjDolpT+IA5oy6lFe8oA9GM5wwzatSY9AQ=="
    , sk "ASiPofEqMrYgyCmaqc6cnVZmtFliklC/OS8YLyQK7Dso3hMAAAAAAAAA" )
  ; ( pk "JgBBHAze2lg5N+vjvoufFX2n0U+Lawmr7cAI9D5y7Ez03qnyaVOUAA=="
    , sk "ASgLwrQ6u0KQwiaZHuq1t8UQyk7XSAK3x2sP68ta6/cdsBAAAAAAAAAA" )
  ; ( pk "JgBVIVLbAj9dFOUADVeWkicjXRt6iku3hWoK6Wrfu508KYfEVNkbAA=="
    , sk "AShzB9wxg86y6IJ6OYx1mzKoevElQBYgLJ/Ya+m52VNHCRMAAAAAAAAA" )
  ; ( pk "JgDtPH4Wmc71DaemHehT15FDOlwEVcqfZAQ0A4zfNvZxRrH+VHQ1AQ=="
    , sk "ASiLmAbMjU1UXLX1b7EAhVhoDCScRE3xZnMqvlIcGGCtZgoAAAAAAAAA" )
  ; ( pk "JgI+kOJEwsbjMX9FmqergrOS4s8qHwyubiJm/I/YVA7edrGrD8GkAA=="
    , sk "ASjxlKV5G6ESXaPgyXrYpFCEw5eld4B5isX0oI8LONTv0Q8AAAAAAAAA" )
  ; ( pk "JgDCWl0H7Bhjt1+ziZ0qhyK7DZNtln3KMB7rPXew0eZQzjFYmuvSAA=="
    , sk "AShytejYP4X494fkAHxHuq1sd6Otlsj76LBh0szD/A9VwRMAAAAAAAAA" )
  ; ( pk "JgNwXG/btGGLqDHiUf3K9bm1SxtHIdJInYTFLskdx+ZvO+Drn2+GAQ=="
    , sk "ASicKBiHnC2ziFlf6EiqgxF/YDufYZ8nTeGbB7I4lJTtbRcAAAAAAAAA" )
  ; ( pk "JgB2i2hSNBskUUpcFkhNnSIM2ROyGzwCnfE5OOsF4xKMylCBLEUYAQ=="
    , sk "ASjkR5IXfnR7IhaRanDRoF6ZSWNITRzD5cwsCGV1CgvnyBkAAAAAAAAA" )
  ; ( pk "JgH4QeZaI9hOPYoDREzZWq5erf6YWBZ+h2iTMbv835XwMOB+K56wAA=="
    , sk "ASj18UkA1Y7UqcRJVHLXUv/cbps7oWR0Li1N7YrdLw+BggcAAAAAAAAA" )
  ; ( pk "JgGMfB9wT38uwdWVwGtU90MLy9lmBzor2LgRUTwiDykZ/I4E1XhcAQ=="
    , sk "ASjAtg6VI/57qT6QtFXVQJWf12EYLM6ouzlykYZ4GK/FpSMAAAAAAAAA" )
  ; ( pk "JgFbsgkjQ67nmREtyNXlyQ/7C9t2F0z57KPzLtF72f5eg4liptR3AQ=="
    , sk "AShCqoW4MbDHjLIJDKISXLZjtYbLT0gLCxSBtFFN7P+VrhEAAAAAAAAA" )
  ; ( pk "JgDkCvx8Hnw6F926LjhJp64TLtAI9tc7hEIiXPFdo2mnZXQ0nKSQAQ=="
    , sk "AShYXjfIGV1wXlFrys33jvlIDT1TTUiO7I/Sw704osnKKwgAAAAAAAAA" )
  ; ( pk "JgFx2z13vE4jVAoepeagZ355y0j1zeaupL2LqbXH37XublciAFpDAA=="
    , sk "ASh3qcrRS1aJYcnbrLmLrZl5HpW/K2uIWBoDJF1Mz+fbEhEAAAAAAAAA" ) ]

let pks = fst @@ List.unzip extra_accounts

let init_balance = 1000

let initial_rich_balance = Currency.Balance.of_int 10_000

let initial_poor_balance = Currency.Balance.of_int 100

let ledger =
  let ledger = Ledger.create () in
  Ledger.set ledger rich_pk
    { Account.public_key= rich_pk
    ; balance= initial_rich_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  Ledger.set ledger poor_pk
    { Account.public_key= poor_pk
    ; balance= initial_poor_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  List.fold pks ~init:() ~f:(fun _ pk ->
      Ledger.set ledger pk
        { Account.public_key= pk
        ; balance= Currency.Balance.of_int init_balance
        ; receipt_chain_hash= Receipt.Chain_hash.empty
        ; nonce= Account.Nonce.zero } ) ;
  ledger
