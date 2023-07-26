open Core_kernel
open Mina_base

let%test_module "zero_vesting" =
  ( module struct
    let mk_zkapp_with_vesting_period n =
      sprintf
        {json|
{
  "fee_payer": {
    "body": {
      "public_key": "B62qkb7Sed1VVsogq7qXzi79JNx9MkcbRihwwuSphUtBiEFPNTQfzNR",
      "fee": "0.01",
      "valid_until": null,
      "nonce": "0"
    },
    "authorization": "7mXAxX8GG74Dvgf8t4bdFDuiv9LnXeQmPcev9aSyZKxgsJNsSsJBz92Vqi7uzarkj5nwj9ngVbcya5cizm9af1G4RU6JA7q4"
  },
  "account_updates": [
    {
      "elt": {
        "account_update": {
          "body": {
            "public_key": "B62qkb7Sed1VVsogq7qXzi79JNx9MkcbRihwwuSphUtBiEFPNTQfzNR",
            "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
            "update": {
              "app_state": [
                [
                  "Set",
                  "0x3D569D0DB7D61D3FC72EF212BF5A654E5A56FA9F5A6E3B7A3F01BC033339AE3F"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000001"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000001"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
                ],
                [
                  "Set",
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
                ]
              ],
              "delegate": [
                "Keep"
              ],
              "verification_key": [
                "Set",
                {
                  "data": "zBpFCuCnTznAquyNEJPic1GkixxJfWm4U6TFRyTwS5RaiXP3329qikhTY6ZQv7GLsJYxbPAqA1UKUf8m77LnPx7XRQivXpqypRNBska6ChC1hSog88HUEbnM1XwcPhuSKsxVZ6VWFuP3BNM3p8rb59RqnvF4mQbK35VW2pWiNmkXGp7SZEfkCWTqaRaBcjKndV1WPAWFrHPdHfCoMUqV2Yya2WiW42sJ9AD2VbaXHdf7vi6hZQzQSTzLsfdAqaBvs7GyLEvfySdw3RSi2V1MYqLee3tnCQypyfYP1vKD4ghNSkD5WJ1eu7gxWCtBtNmg5mGk7X28ntX4QCKDXbdnBtE2dTRJCvqryYbhQpmjQVb7nroZUVWtEkFcjLqAG4N9zpLmKqpzQXgt69TMMJ5399iaprJKdMMcg9SUkBwLjDHgvrsZrWYyuzifyimoLrZwebBBXDR7xuusqSgh5fzFRHMxWguJMHGTGyG9TbDMwvSDz2pbrg6k3VM5NgyJc7THiTutEnc1JNHnfXucKKnVSYZFYXG2QxWHjDqzXowwbqm9aMueHyJAxe1qfw9Z48fgrpxLzpsnxpT618eedaKQig3BffhCCwtUCktaAKRsWeFdV3LvmsBjHDbSUhv3ARhCtTSqm6tiDNMZL5c14NBt1RQqaeKjMe5GsMDEAfsGSkC1RVxHx6inVHTvuLzQosKEfwc5WXZSxE4z4x4EfwsaZF4GRPPnE9qr7b2DbNDyhjPqF6BTTS9pjtFvKeNDQdwsyM9FJaSRQd31DeoUSTA7EN8yjWWPnGAs2UzhmqEHquqLWHpr9aHiiNX7HvMi18zqnE3hGjPnmZgr7bvm93YqWgfP8GRvBjvsMMoioCSHA9VFameNRMQzNgdRGocLqu1CrFBDDpkevDaAjCWz4XN4gDK1kbDdN3rBaoJzusavtLHBveP2UVuV4PseB76zWKHELfrKbjSoxKygxj5qmGaozutmJepaqTdY6cLRMak9yU4tBJU2eyCD431GL9Khuzz8xDuT1RdsjtVNDhkoDk66PHP4MurEKiLJrUs4L4bKnzmj1RUeBnw3jP7xbrWqZuUtnNqqbf4EwkqG5MajD3aM2n3ymH2jSLi8oNudVakQtdLDnBh9Hd3A2GLAerr9eXv9LC4BFdyY4YDpev9Zmj2ektnbZiDKB4UG7Wa7d4jqbxEBCqicUeAknCnQLdc3XsZ992rNooFbLFsyWsgAtuHdDcXxbfKH17S8BGfmV4wWP5bLzhHYaBD7H1LrztLydnDjpKrMBz3sk9QRpntTeiDgaxqk3Pi9ZfErE1PgHdmvN9xjnrNTMf2vkgSoUMAjTXy3jgiKHuFQbr7EgrB5matQ9Q58ckfkxZN8Y7neD7w8cF92MCm7SHkZFDMvWvitVpzDFcH6p5B8QKVFYVmxX7ZiUj7qwvhvZNXeqfHBrbxSQQLAxUoof4SmuYQB8zYPUBsVmkXJ8SaPTGnMapqpZxmPFPyAuF3eqjCCyPRYNCdmFGZ5tHNs3D4wmimhthbYyq9iWb8DAVwXEPgPXfdggT7P7gnuzpbat8gHKXJ9XRrLZ2N6aHnSoAfyeJwa2gB7zeGQmPHQ4jscJzi3v6qdRMHTh5PjgEBhUbvdPNYBSe5pBrJzbzaov1zH6gqeud6M113BzdkCBJLT7WqNLW92Kmkh1i7aV2gDUcSNmQHpBNJdrpfe1T2j1szfNYMWtjbu9wKivyn8YzPtnfdXMXo7GFwnWchhJ4W6fockxx99zH2YDSMEcGjEHEa6kszhSeJ3AQefCRQiTAA3kVLExMYFGY4vWpFuLtf2sigSwcAbKwwfV7bVPy1Wce1Xq5je6iPTTTkHFNyGwjBbiLXk3JsUjZaAoACmhtgSUZs1wsL6PmSzsUuft7wAXt1eZTTUZSKsHnRwX4rqyNZw8buhwZ2jBoHHM6dHZZ6pfMd7RXB8FQdqHFDKbvj2H2QXUs2bfVNefNskPKWRFdUkQcuaX62CUij3AiLDPUWu9a9vAFqzCMAsEjzZZjMQCAY2v3Zh193xAUXhdAnBAnj2dtAyhe3EyTdGAHsaQ7FSUqD61nzXZKLudb4ZfKpY4LwjdZfJyszzsJxuTKLZrGy1akAGLJ5TNYjsdEmEW6xVMLon1aenYHj2QegyvXEq46oa13i3oW5mNbzy8mfZpS4RYbmu7rKo6e2dqf3XV4NesQuCb63qP5pMvXfDegxEVdYRc9b6ygcvzBSY15gvaaWapeswqpPPteNuH6CNMXLDs8fZFYBd4vcJFfrmSf7HYMAo9omXCGkksYHH8af5dmgcCbZQnKFbPaqYskSqDBr7sLnZufz7E2ZTcE9384UWWgPAr6YqMuD5S4yUTZAVozAGAajj9LY4JNNMceo2Ubbx61kp2s5CCqtAD7YcVd7GujDdqGokdjXwxhkRBRPeNTrWL2MmCSfNBoy2yGcod7F",
                  "hash": "0x098A22988BD5956BB3879A9AA74592A4E2E5D2FB783ACDD238D46CF7B19470E0"
                }
              ],
              "permissions": [ "Keep" ],
              "zkapp_uri": [ "Keep" ],
              "token_symbol": [ "Keep" ],
              "timing": [ "Keep" ],
              "voting_for": [ "Keep" ]
            },
            "balance_change": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "increment_nonce": false,
            "events": [],
            "actions": [],
            "call_data": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "preconditions": {
              "network": {
                "snarked_ledger_hash": [ "Ignore" ],
                "blockchain_length": [ "Ignore" ],
                "min_window_density": [ "Ignore" ],
                "total_currency": [ "Ignore" ],
                "global_slot_since_genesis": [ "Ignore" ],
                "staking_epoch_data": {
                  "ledger": {
                    "hash": [ "Ignore" ],
                    "total_currency": [ "Ignore" ]
                  },
                  "seed": [ "Ignore" ],
                  "start_checkpoint": [ "Ignore" ],
                  "lock_checkpoint": [ "Ignore" ],
                  "epoch_length": [ "Ignore" ]
                },
                "next_epoch_data": {
                  "ledger": {
                    "hash": [ "Ignore" ],
                    "total_currency": [  "Ignore" ]
                  },
                  "seed": [ "Ignore" ],
                  "start_checkpoint": [ "Ignore" ],
                  "lock_checkpoint": [ "Ignore" ],
                  "epoch_length": [ "Ignore" ]
                }
              },
              "account": [ "Accept" ],
              "valid_while": [ "Ignore" ]
            },
            "use_full_commitment": true,
            "implicit_account_creation_fee": false,
            "may_use_token": [ "No" ],
            "authorization_kind": [ "Signature" ]
          },
          "authorization": [
            "Signature",
            "7mXAxX8GG74Dvgf8t4bdFDuiv9LnXeQmPcev9aSyZKxgsJNsSsJBz92Vqi7uzarkj5nwj9ngVbcya5cizm9af1G4RU6JA7q4"
          ]
        },
        "account_update_digest": "0x324D57B61E07061A094A9E064984738480D8D3BF336A4CD33993A9FE6B37A823",
        "calls": []
      },
      "stack_hash": "0x3C28388F95EAF826FCC6CF06DBDD4A2E694FA7C5A281E0A623560F3A5BAF94AB"
    },
    {
      "elt": {
        "account_update": {
          "body": {
            "public_key": "B62qkb7Sed1VVsogq7qXzi79JNx9MkcbRihwwuSphUtBiEFPNTQfzNR",
            "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
            "update": {
              "app_state": [
                [ "Keep" ],
                [ "Keep" ],
                [ "Keep" ],
                [ "Keep" ],
                [ "Keep" ],
                [ "Keep" ],
                [ "Keep" ],
                [ "Keep" ]
              ],
              "delegate": [ "Keep" ],
              "verification_key": [ "Keep" ],
              "permissions": [ "Keep" ],
              "zkapp_uri": [ "Keep" ],
              "token_symbol": [ "Keep" ],
              "timing": [
                "Set",
                {
                  "initial_minimum_balance": "0",
                  "cliff_time": "0",
                  "cliff_amount": "0",
                  "vesting_period": "%d",
                  "vesting_increment": "0"
                }
              ],
              "voting_for": [ "Keep" ]
            },
            "balance_change": {
              "magnitude": "0",
              "sgn": [
                "Pos"
              ]
            },
            "increment_nonce": false,
            "events": [],
            "actions": [],
            "call_data": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "preconditions": {
              "network": {
                "snarked_ledger_hash": [ "Ignore" ],
                "blockchain_length": [ "Ignore" ],
                "min_window_density": [ "Ignore" ],
                "total_currency": [ "Ignore" ],
                "global_slot_since_genesis": [ "Ignore" ],
                "staking_epoch_data": {
                  "ledger": {
                    "hash": [ "Ignore" ],
                    "total_currency": [ "Ignore" ]
                  },
                  "seed": [ "Ignore" ],
                  "start_checkpoint": [ "Ignore" ],
                  "lock_checkpoint": [ "Ignore" ],
                  "epoch_length": [ "Ignore" ]
                },
                "next_epoch_data": {
                  "ledger": {
                    "hash": [ "Ignore" ],
                    "total_currency": [ "Ignore" ]
                  },
                  "seed": [ "Ignore" ],
                  "start_checkpoint": [ "Ignore" ],
                  "lock_checkpoint": [ "Ignore" ],
                  "epoch_length": [ "Ignore" ]
                }
              },
              "account": [ "Accept" ],
              "valid_while": [ "Ignore" ]
            },
            "use_full_commitment": false,
            "implicit_account_creation_fee": false,
            "may_use_token": [
              "No"
            ],
            "authorization_kind": [ "None_given" ]
          },
          "authorization": [ "None_given" ]
        },
        "account_update_digest": "0x1581BF4B656B5D89E65A7B9322F460D9AEAF08ABDD62CD6DD6D6FE1EE266035E",
        "calls": []
      },
      "stack_hash": "0x1C66CA0E7429D1D71E51BF1A5240D5A5C712DB9C4B7C31034A7A0115B612E83A"
    }
  ],
  "memo": "E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH"
}

      |json}
        n
      |> Yojson.Safe.from_string |> Zkapp_command.of_yojson
      |> Result.ok_or_failwith

    let zkapp_zero_vesting_period = mk_zkapp_with_vesting_period 0

    let%test "zero vesting period is error" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command zkapp_zero_vesting_period)
      with
      | Error [ Zero_vesting_period ] ->
          true
      | Ok _ | Error _ ->
          false

    let zkapp_nonzero_vesting_period = mk_zkapp_with_vesting_period 1

    let%test "nonzero vesting period is ok" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command zkapp_nonzero_vesting_period)
      with
      | Ok () ->
          true
      | Error errs ->
          false
  end )
