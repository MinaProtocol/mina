## Instructions

### Starting the daemon

* build a snark-enabled coda executable with
  `DUNE_PROFILE=testnet_postake_medium_curves make build`
* set up environment variables to pass the appropriate time offset to the daemon
  - `export now_time=$(date +%s)`
  - `export genesis_time=$(date -d "$(_build/default/src/app/cli/src/coda.exe advanced compile-time-constants | jq -r '.genesis_state_timestamp')" +%s)`
  - `export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))`
* create a configuration file `config.json` containing
  ```json
  {"ledger":{"accounts":[{"pk":"B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g","balance":"66000","sk":null,"delegate":null}]}}
  ```
* add the private key for the ledger key to a file (e.g. `demo-block-producer`)
  - `chmod 0600 demo-block-producer` to set the expected permissions
  ```json
  {"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"8jGuTAxw3zxtWasVqcD1H6rEojHLS1yJmG3aHHd","pwsalt":"AiUCrMJ6243h3TBmZ2rqt3Voim1Y","pwdiff":[134217728,6],"ciphertext":"DbAy736GqEKWe9NQWT4yaejiZUo9dJ6rsK7cpS43APuEf5AH1Qw6xb1s35z8D2akyLJBrUr6m"}
  ```
* start the daemon with the given configuration, using the given key
  - `_build/default/src/app/cli/src/coda.exe daemon -seed -working-dir $PWD -current-protocol-version 0.0.0 -block-producer-key demo-block-producer -config-file config.json -generate-genesis-proof true`
  - To use dedicated configuration and genesis ledger directories, add the `-config-directory $CODA_CONFIG_DIR` and `genesis-ledger-dir $CODA_GENESIS_DIR` directories
* import the demo-block-producer public key
  - `_build/default/src/app/cli/src/coda.exe accounts import -privkey-path demo-block-producer`
    + Add the `-config-directory $CODA_CONFIG_DIR` flag to match the one passed to the above, if given.
  - `_build/default/src/app/cli/src/coda.exe accounts list -privkey-path demo-block-producer`
    + This should show the imported key in the list
* unlock the demo-block-producer wallet
  - `_build/default/src/app/cli/src/coda.exe accounts unlock -public-key B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g`
  - Equivalently, issue the GraphQL mutation
    ```graphql
    mutation Unlock {
        unlockAccount(input: {publicKey: "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g", password: ""})
    }
    ```

## Build the demo client
* `DUNE_PROFILE=testnet_postake_medium_curves dune build src/app/snapp_runner/examples/credit_score_demo/credit_score_demo.exe`

### Create a new account to attach the snapp to
* Open a GraphQL client directed to port 3085, or point a web browser at `http://localhost:3085/graphql`
* Send a GraphQL query to create a wallet:
  ```graphql
  mutation CreateSnappWallet {
    createAccount(input: {password: ""}) {
      account {
        publicKey
      }
    }
  }
  ```
* Unlock the new wallet
  ```graphql
  mutation UnlockSnappWallet {
    unlockAccount(input: {publicKey: "NEW_PK_HERE", password: ""})
  }
  ```
* Create an account for the snapp public key
  ```graphql
  mutation CreateSnappAccount {
    createTokenAccount(input:
      { fee: 10000000
      , feePayer: "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g"
      , receiver:"NEW_PK_HERE"
      , token: "1"
      , tokenOwner:"B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g" })
  }
  ```
* When the new account has been successfully created, it will show in `_build/default/src/app/cli/src/coda.exe advanced dump-ledger`
  - This can also be checked programmatically using the `accounts` GraphQL query:
    ```graphql
    query FindPkAccounts {
      accounts(publicKey: "NEW_PK_HERE") {
        isTokenOwner
        token
      }
    }
    ```

### Set up the snapp account
* Generate a verification key using the demo
  - `_build/default/src/app/snapp_runner/examples/credit_score_demo/credit_score_demo.exe verification-key`
* Issue a GraphQL mutation to add the verification key to the snapp account:
  ```graphql
  mutation SetupSnappAccount {
    sendSnappCommand(input:
      { snappAccount:
          { balanceChange: 0
          , publicKey: "NEW_PK_HERE"
          , changes:
            { verificationKey: "AQEBAgEBAAwBAA0BAAEBABMBABMBAgECAQEBlKQozSdFYRZAgou9xtkE9wsDxcuTXfmpdMJvEMSoxhnAxQanQMCSpZo-EV2JH7ShmM24SYWfgmuvEmCVvpW6PgEpC9z2seKz0KrYGkNdoY80XhfbM0T1YRuRssTt8-nvAxwzUYqsAd04yAiD1GEmkViL9sTO8P9vigmmza7juEcMAUwFh08MVctnuff7g48wilorPdQicOh0FBIExUl5uC0OWtOCbOhKQ5qTmUcfpcHR-tiE4BgCXk2SQiYl9p3QuQgBAUIlCiPTq9F7a2NkwyjGuIfoKaR2u0OQo_VvbnmE6tcd5-Swj-9z50kb3RzLoe9ecVfHGeGHTjN9ocDBt1TfoyYB6XQuFaG03W2yrgxmL2r_gzrRyTd4ZhlRA-rumXrR9BqaRrHVBTT30FqDujwhbAaEkQsg243xU0S7yc0JzyJXPAH3VJJA4HDu2GbEmc1b-CnPANzbH5IxxwN82w4oyoODPAl-zsmVOneoRNXVwwu8Dyt-tsdNZ0cjCANqcZjDCQ0cAQHKLTyieEjJTuxwVv0ptyE-t8vkEZWceJ_gw5txEsL4LlwIaRBpUTZKODMA14GhT0Yib6JO9S78Rw9vFCcEWo07AUGrMcZXqx6ZQ0jhNS3IlWj1Hq5RbXpefBBH8vlYGbwDOsNzx1qGOcpWl21O18EgFIGub9ZgIvF2DggCF6SibT4BXLmq6AkUAmNBztEKP6ADsQXphNjXHq-4r509QpjG3jTfVLhWE7rxFUYqTPVQ0cVX8gfvfFfzEUVKDXG5FRN9IAEBRGDTgYYe3idL8oOEekLz69zqzFzJ5d-F33aok4z6FhFzfPzBcWyNyU3jxn3exxKI-lzwWror2h8dwAjULsUmNwFoPwv7jnATWm_StixcyY_l2G7gE7MNt9Sv_ihUU7-zJVrT-UbAzyIThfWsCKutXH2a7SH2FFYvXDDPkSMgHM8sASQF5SiiwHez7aiJ0Te_oX_EbH0qp0T1ylFLW5bDl7gq-uAM4htdbTZx5TfDl8N18K9hY-6Uk9wrOg6KIWOTMTM="
            , permissions:
                { edit_state: "signature"
                , receive: "none"
                , send: "either"
                , set_delegate: "signature"
                , set_permissions: "signature"
                , set_verification_key: "signature"
                , stake: true } }}
      , feePayment:
          { fee: "10000000"
          , publicKey: "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g" }
      , token: "1" })
  }
  ```
  - The `verificationKey` field should be replaced with the generated verification key
  - The `snappAccount.publicKey` field should be replaced with the snapp account's public key
* Transfer some funds from the demo-block-producer to the snapp account:
  ```graphql
  mutation TransferToSnappAccount {
    sendPayment(input:
      { fee: "10000000"
      , amount: "100000000"
      , to: "NEW_PK_HERE"
      , from: "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g" })
  }
  ```
* Lock the demo-block-producer's wallet.
  - `_build/default/src/app/cli/src/coda.exe accounts lock -public-key B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g`
  - This demonstrates that the client isn't generating a signature in order for
    the snapp command to be valid.

### Set up a wallet for the receiving account
* Send a GraphQL query to create a wallet:
  ```graphql
  mutation CreateReceiverWallet {
    createAccount(input: {password: ""}) {
      account {
        publicKey
      }
    }
  }
  ```

### Generate and send the snapp command
* Generate a proof using the demo
  - `_build/default/src/app/snapp_runner/examples/credit_score_demo/credit_score_demo.exe prove --score $MY_CREDIT_SCORE`
* Issue a GraphQL mutation to send a snapp command containing the proof:
  ```graphql
  mutation SendSnappCommand {
    sendSnappCommand(input:
      { snappAccount:
          { balanceChange: "-20100000"
          , publicKey: "SNAPP_ACCOUNT_PK"
          , proof:
          "Ad6huk4wPCEcO1VREu0lTB8y8XGKcWTqX-7tM_9gvYQu0yo-WF7MDBgR8e3fQp8aVKPd9I1eF36Gw7t8NBADYS78ezCUIIKer4j8uM9kl29vBEcA_Ac70YvB0RCU_OEaOfWyTdqbAPxuLIzjx7O6c_wI8jBtxL4GxQD8Yogfhz0re6X81cqbO1d_BiUAAQD8dOS8nc0KH7X8HB45VSJ2-38AAQD8m-cULGdWQ3z8IdjwAmVbs_EAAQD85UZuY_T-4XP8RN0BEgq0Wl4A8ulds-c-UIZ4QAc9mKp2-lJKNVm3EaK8SUCa92IxByANOmt-Yet14uZWRBAoez7rlLIK5WKaH8WESki0Ny43LQEA_Kwcm0KTnP-j_KKpvzHq9zOoAAEA_NxTh_naEaD1_Br5-yVob5yXAAABAPxyk737TzQe1vyRQLeuYxweFAAAAQD8JM8f7Ogs2ev8U0oXwtRI4coAAQEA_LnfdpfKefmg_O4UGbTPcc5EAAABAPwohJXy_pRTsPz5CWCn0BvgQAAAAQD8B9Nc_jtFuWL8q4wFdsdbe5UAAQEA_BYELEXOUFG9_DgAIC9EcZGCAAEBAPylR8E5fUzCdPzWO_S4OPuSWwAAAQD8Kg8yiwh1OcD8_SB1k6hS0mcAAQEA_PM0BIoUZ348_CDgjwtPkKfRAAABAPykNqsjjzDjM_y-oShfOBLC1gABAQD8ychtSCqXFL38rvMd1pCe7swAAAEA_C_JbeagFHOY_ACPmrtIxTWgAAABAPzq849KkgxgZPzw7JgpJFwQNwAAAQD8GVEsSdXQYuD8CI8-7D8mJ6YAAQEA_PAsZVMBwl5o_KE3boma9QSDAAEBAPwfL1Uz_83RHPwz12j6WR6rrgABAQD8-rm8FLB608X87FDjtXze_i4AAAEA_McZIS-lFL4R_Lqd2LTWJdw5AAEAAAH8IIvbCO_vF2L8O5ZEDXY2_NH8owtVHOVgdCn8bUtboLWpAwYAPRo4H7HBzM5UDq8E0B6gaX9yRGRmdE8xs37xMqx4jRtQtGOIaKEO2gDZ0WxgUBMB2WNsKYxYO7B3c7XAEyYWHAEA_FpHr-Xg0nWU_PbSw64Cp8vRAAEBAPwEfC359g94vvxU4vsykVg94QABAQD8E3UxuBK3cMb8CD5ImjPMdRYAAAEA_NG4yrGisMFI_M6xccDjBGYbAAABAPxvv-asybOCM_xjGHb5WEOXeQAAAQD8l4eI6QYrOt38x6FEKUDmet0AAQEA_MufnPQw5ejG_N2coM1lu90HAAABAPwTGmmHolksU_x7b2UqsLwhqQAAAQD8iwcQj7F3nOL87gxr3wBfXPgAAAEA_IecsActp70d_KAmX-nilxtNAAABAPwRX4BWfHR1nPzo8c76aWP-oQAAAQD8TWDp29-KK1z8m_cQ8oxxjFoAAAEA_Ehr4FFcs8Ai_O1tqUBzi4imAAABAPxuZHZetdcHkPwSjk7bOYvGwQABAQD8ySs_N17jRUT85c2M_BXHQJ0AAQEA_E6qvEuEgphC_Ly3r9DXJ6mXAAABAPx3bv3_Wz3KmfyUQlwVVWrm7wAAAQD8VJmXIXGyfUv8QMiTYeCiH5UAAAEA_LNHB7K-zNEs_B0CZPI83tFbAAEAAQD8Wkev5eDSdZT89tLDrgKny9EAAQEA_AR8Lfn2D3i-_FTi-zKRWD3hAAEBAPwTdTG4ErdwxvwIPkiaM8x1FgAAAQD80bjKsaKwwUj8zrFxwOMEZhsAAAEA_G-_5qzJs4Iz_GMYdvlYQ5d5AAABAPyXh4jpBis63fzHoUQpQOZ63QABAQD8y5-c9DDl6Mb83ZygzWW73QcAAAEA_BMaaYeiWSxT_HtvZSqwvCGpAAABAPyLBxCPsXec4vzuDGvfAF9c-AAAAQD8h5ywBy2nvR38oCZf6eKXG00AAAEA_BFfgFZ8dHWc_OjxzvppY_6hAAABAPxNYOnb34orXPyb9xDyjHGMWgAAAQD8SGvgUVyzwCL87W2pQHOLiKYAAAEA_G5kdl611weQ_BKOTts5i8bBAAEBAPzJKz83XuNFRPzlzYz8FcdAnQABAQD8Tqq8S4SCmEL8vLev0NcnqZcAAAEA_Hdu_f9bPcqZ_JRCXBVVaubvAAABAPxUmZchcbJ9S_xAyJNh4KIflQAAAQD8s0cHsr7M0Sz8HQJk8jze0VsAAQAAAAAAAQEBpvnNM87NbW9K2qBUUapqEyonjwwWNUDspQPXJUr1uTcBAdPBJ4bTSilMqMyh8k_Ks3JAgjPAemXoYjoJyN536gAOAQGBvXXGchUK4Qq9Qcdw85MWBaVgrzwS-IJd2zzt8dMXPAEBat-PpIUB85Sb8hEy4kqXSOu6MvjRaoeiYixCqaI9gR0BAfokzBb6SIfFf4XjZuN6whmCRrFECeBIxp0SeplEhOU4AQHTs7I95Pxgo9KWAYD3pOnAvt2FPzwFfBgee1Qg5bpgNgEBAX9FhwEFL84cBwmXx0Px2szZWhY2cnrbwIxRm6d6th0xAQESffOLYwgXbNbPsx2Xz81AQUeUFoSk3ew8_uUJsmE3LwEB7IY6hhvq_CUBdZ1q-im9uiQ2NNvhML-0OyvALztzezABAQHV0U3mIrThodKv4oluWKLgteDbI2d-SmQU8XugUxFgCwEBt8fdMfF64hq6SJPO0plPIRViGp3i1SPXPtaDk0mLaBEBAWeEMGNFn3S5yrxVu8w_KORk3YnIe8iIr3DHpWvjJUIwAQEByNYIUzO66t5wswrVHNq-QtP5I98EvluFo2Y2QR95_zsBAR7_MZl8kMbrUgoyGHXS8HV77ey-wiFChZ2irLb9fTUoAQH2hqG2vGvGc0n3J6EfY0bHz0PxuEbd76BtcoE1fbUFFgEBAcRxiiJjla1g5YVafy_X0CatmVT0Lm_QqAeYOBvoucwoAQFW3-IAT8LuJMgfQbJwgNuE2Yep-u543CHe-JI_gfIIKgEBUjd6sEFyzmp3nSuAtfiGfwt4Bh1Of5MofI7XQDTtNzsBAbHWfzCm8qqp68HukElwK-85JSc-_eh4lAAzGKwHuaEvAQH0AtXYEswiOaAWsNJNQ2leIwdDfRM6fMIirQ4od8ZpGAEBMB8ixsqS9NW89uD1OQkpZjtgjgHxfE3Eh9OI86rjUREBAQFedOOAYnNp2-Kuh0Qnc6zs2ng76tFg4BxEw0DFN4HADAEB96fudSFNrl7abv5S8MUnZ7_N7QqLdiGbmtJsn-8C7y4BATSEUvV0J-6cCDrEfKaFCpX1UiPNNwKsWlZhENREsIYOAQH7h-_H5mdO7sRbbgdgum_HdjIMK2x4-Uf6ovllBuCfIQEB4t7Ix91I-CBHJak5CkR_gnCbW0joNCfHprAfNkIFBScBASp3HklX6BAtxc2K6cUcJtvMJ-9D-7k6JL4lA4ach-k8AQEBna-v2cLKrOQBohtCBuwH5rLD6o7uMrILM2-_R_qx4SgBAZCGNuxaG1AgaAnZplxgZ629skQHcj4clxvfglSVad8HAQFJRMsMbkd7yA0j3fBHJtV1teIh5tpd3h2LruHSy3g6HAEBATBLbteMtwKsqll5X0JB9e8HfGcxgGHZirhNKkV40_IYAQE8esdJnRolrdBbCDSpDl8Ob5tPAD5f28FH6VVvr-75HAEB4TkY-N1G6KsN7ujcn4PrncvkpFSZmGJCZjMGCCDjOAwBAQElsH7CHiH5_V8MLeC_xpWapmffbOY04uZS6iZXYfrWFQEBqrB-ZkyEVwBqMRaiP7CkgMP7ce5QpQWhgYFi3PW8vSwBAcmwrchXzATNitKcGJjZ9TYp4U81gorTpuexohMMgg4wAQEBlTua27i7wvmZWbpFa8jTmrfkguOjAGEP5ifWGuK_mRMBAbcH19VG0R5g8qznfvYyOZ0lv1f-R9_ZV08HSGJT8ZUzAQGtUbtiMxVVnD1LHhLdLma56Wgj1or6S5fFMYLWceqmOQEBqY2jMbkHsrfynQ8YTAJVhn7agNieONYsOPIEN-epnQIBATqsFV7cNuTxDi0IswKepiaIi1WKO1E9CY1A7s0lpyE7AQFU4V-kz63NjHKs31-T_1UH0gBSXpAd307e5QhA2y67OAEBAe0s8Bqie04U2HY-HeXryfOUQs67c5srZ6NjJQ1nWiUjAQHNnIrbpLBOZmpdZGdBVB1CRQc2wCFdw89NdPqh4bVtLwEB0q8-pwM7PzNo3KSovRfj77wLbl7ucOJS34CCNKJrtywBAXQyktSETIvl5UakfQ_lb9l_810qExE4d1F1RVbOjGUJAQH4EPQbjemPtn0GRlY-krdd3PrGXYUV5zwNuXUH6eipPwEBCAKTtT6Ok2yGMMYyGTGGoFNTL1D-9Fd-DtlizG8SIyUBAQGVxgnfsl5ZtfBNu0S0Je94AXjeC94Did3EXHePSw6YEgEB4VazRSaviowjim53wZqvI9JJ6m7Cw9dhKKX-ekHjuiABAVLcgkM8euxDx5aQI5S2WM2BQ8xlRXC0nFljaMXxfT4CAQEBck-yD9qv0FdO7RCiM4TOSXr4Q0ma8lReUGP-NsJPTz0BAdMopDiqZKLXZ0dFqyavY08qRdgSlqfx9NNS3Qiy1dQ9AQEuE4XKlPOW4VFhiaf5wx9cqcN3IUf2LwVn4ASm-hcOAwEBAW6lLC2s0X_yGs9W_6QY0mHXVWQ0VG1NRZ7ElN2Ka5wuAQGcQfFP5thiHpEpGUJFaddIbwD0MwD4vlXKrzpVHDHXAgEB9KcuNOG5KHCz3tRTY0y65EVgdvpqJzNQ2HMSBiTXexsBAQG0Wt3xljvsarpT7w4Taw7lOa4_NjzylTtcGTIoKa5pDAEB_Cfde01rI-ukR5V796s7DZ0sq6m31MrVEAmZuEF29isBAceKuAloP11PL9AOrN0v1XELVJ6JWce20FcUji_ZrqUWAQFy1mSayMkyXvAhEo-xpi-WbPnbizEcxXqavFcR9leYIQEBwLPIn9vcm2tEABdtGHzbdV-x6nTCj-71rK5eH33i6Q0BAZ8pglfhmnzLVKUfRUBU_GGIiDqA_jbOpQo79IXYWBY4w-iju9WpbdbRBsN-oAZ5-rwAfsofbAFMs1Vk7CDrqT5WKWZLNqnGJiv_SGKvWYNwecor4-HCmXZH1YOs6LSLDi2OEDEefFlPPFjepR1uO9ddPd-Qy_dNzMOG_GlfbhgQAQEBAQEB4P8_x1PLH8Sl6WGMC8skTY7qreITnBuosN5igShD2hg4WxEcJMq-aqjO18U7V5zb0yAd64mxRdMl7CpGXrZvMAEBAVTeaBpYrRGYq4r9A6pwfTVw6u4EzSMnFwMqQ-wsdtIvHrcnHfo5xK39RBo7k-1rO6FLtfxTwD5jadb77YGP2BYBAQH5MxfulxjIVvDEVRVDY_fAbY_YUwusV8rDKuvXHGwQEdF2TwspFUhw3QkS59YhkMuwZBp9hlpCHaZCGNDQP08YAQEB7gBfX6xIESROUzyxLFtRQXa51Q_nNcPle4gSFunubS0lHSp6SzmCslbvMqREDTsYLZx9ygg1Six4QT6jzgyZMTJj49M5-7U-Uh1tJynj1nFq4hf3q1Ipg6RmAXFm4SUbksYJuo2GyhcV0ROQWDtvA_DS1sjn6oSV58ZlH3EPhw0BAQGWEiiCkiZhpZWmygLd6gTwG12YTPDpLC7eULrkYIcrGjhrcdz4j4_FyvKze7Hd8Cd737SyxsXhalJHi_RVl4g3rqLvirQafY9KKCMYpPpO2ryv6a0FnPW9Q1Tomr27YyoBAQFAsEB1Qx0pbUvqSaZ05t1k0fSkok_IBh4DEpWf7xVaLS0XK19VpzlIitD3-n6h_TeYEwe05J1e_x_aZ0j2jnc0ZsoazjFhurMgwL0PY2sjjb9vwI9G7aSLIzuqqz6FHh2Eowzlq9UonKQPxZDfrURdaIXNM2fFSPVNOGyMEYmuMQEBAZfSwqpgNKKBhwAJnlc79zCDFGYM3imnfZ7RZZFxHdsNJBqY9AMKHyhx5W1jkKPW2jTQeuBoX1nDYwXIBpTouTAhn6jVfwIxTXO-_RzrkisXsmiuQ9djl4wwKNwCZ78wJwEBAejTxmj83ELFoBCZPSAKqPpPm03-VD-UxCKYkMSM8KUu7LCmr7TWnvPDeAcm0mrkiiRA2acoE2Y6tf9xhAazXx5wjbWVA9gSBDVvdrs1_fnaz9BQveFz94ECe0Wt3vCpOnBgwbD-aGCTpHgS51XLA7Ck24HV6U8clyCvMiCKF8cmAQEDx-PK6mrrgFsOSKFrgKsW3pM_u33C9wgKjCck9neW7w6FO9mB2f4gQv4rIqo0Yr6eW4YLZeqOVDo78jgHilMJLKut8sAluZSzGrpbGyO19TNcjaTpAf8A6wR0yitVwZ8lMlXeVTWZiefW8fvr7Mwu2yyarIMoSpK8FM16pDR3XDG2gu7F9M_f6dD-eYqZkwYkDGjTXSpZ9q9ObsL0VKV5IttakvZkZRVgOzEPkLwve6EcYcbEyMNGIM2IdVjRKeE8AQEBExHpnxlVbSt7EMs5kxOK5jn-QwyXcs8GU2kevp2H91Mb8tdA70BlnYPKLoKr5iLqzJ8j2GG6VMjTtDlvvKArHCIpn0KwHBLhjFzzp3ZlGCBrDRSHXbNKbH4q-TO9akyGA3olaQ_JWvIrE6-Eklbg9D7dd_bb3ahFXy26zGyrS9onRx_SF6JQIE3n4Y_T5zd96XOmxAtl-7dZWaMTEpRZHhLLPM7niX2PsxHOrreuRkwDukrW6Bg1o5WUBqD16FcIKJ6p9fr1vkjhr7nzya-GQ7ma_p0_cLOKFYEc1q4woZUcQWbRQrgBKWpvXf2GM0pt9pEPM6RHCj5EqXhReDNJIzr8rXvskgt--jFz_IdVnUn7nTkQgXr9WPh8rLrSXAcDDVq_-3qLV1V6A_9rbTEJLoL17TxFK-6YcdqLqdQxo64Qf6mDN3_6VtlSXzCN7deRJO9L2S5xAOFAQpHRrkMs-CNJN-6zLwM-CS37IA7obXwb6pEyP-fmCJ9_daXQTjWhLJeMkAWM584L278HKKdLo9guenq_8-s01WwvckYlACkQjCA_UXWXcSf6XTmXbIrtpb7F_WyltV0aIK1OU5VfxxhJV1VZL-J46zyVuYhhBvrFYrwX0YqOGW-1Q916QugZHK_1h7S95kXxNP8j4HlVnRD1qoerlOSOYihbbf8l8kYmfHHAX7hlIFaawExEN-nUBJweM6_U_m56zvvtBjaYdyJERnNg3gPpubrycDqt-DJaPgUI1GRZVlUR9cjY9-WTDkdIRviqCODNhx9RCoQqCq6yYrBBpmFvDl_5Y5t8Y_wLAgsfTaIS6RWKEGLbxVCW-xoYeYR_3ewoiQ1gPObtVyGJBThLfC2aOzgc2b1G9ppdzuBx-apBevjLzYgx0JapF4ubmckiulJDLfoYgWev4ey7B6N-KA5lPyGLt43VaYEjF-59bpRy_Bmdm-9Yb8BTxMfX6txn0HkYfoeroj1rtwLIN1A90FVBH_SSIYODdWW_y28Bwx22p3LtpCa8xXByBrAxEbUiDP7aGFp9IMqWcMwnzXKDBpU1Hpt688QO1mAdtXQVFkSwW9kmyogV4qgQSARXZTh8ZNgd9AoEUsbY6DtKJ3AyVDQ2DVjov7GzV43R2YaD7Sc0OZSgVHw3Q3WbDmL9v5RnoPIRCt9TXfAnlpfJIH-MROMh5FbO1ns79pc1FMRkfNHxLURAa1xd82OPdX_ZX97Kq_XSqHqixteAjCcp_YqVSskXz-Zmj9UI9nMUtCtl8F6R_LFmR8pAd2JcKn9ieYoefO5U7APYnUuWsp164ceqfXvSTy7Q83P6aUEbatBUudAg8bH44eNyFAfBgrD3xt2ncxGYInSi0nm2xQronhWZr9kfHnFj_IYir8r6c-sLHuiMRodtOG_-bD2KOhftcpluJ2SilbkwxmeiU5YTYFEOCDKrQjfj_qEzxZkV3dKBwQJgmNVCVp0voduG_kbav20sWL7L31ShKuzxPzceK-T7np3iN3NNQzwuYR55b23X5GmTICs8nyaYNukrGqCDkQSYFzwakPh3ymksVOf0MEZWuSGWJOubNwxGPdIIVBLE2k1bBvGu9HSqVE18zghJ_a519vzUwfhJGitZvj9bpFEff5VHIQO0C-p2oq_Yn4QJ3l7deQTc2jw-UVvHA8F2qzIpHes8I8MwZCGKkoFN8yK53NB8wFKW8hvdRHkhmAkrnHXStfCnJUB1mKVBdO6Y2JaprBBau6db7O9sChRiRP0zc1_fXSWtfXchqbowMoyU0shLyCfZCYjFupKCPLQXH_V1592Zln7_yJ7Eas8SrPbe9VrXT2NSHaXIKQojQmHtF6_FQQiFF19dRLHMvliQ2r0qNJKbnBgOBK9ujxpKqHC-IMJnzgtbWe7zj12K6Phe0-Xhv73eY7B4Aa8SO6jG1PPKdx4wfJys2blmd1Zy9folUMAqEY7DFWldFfMTnvbLHhL28Z5N3HV3SWybdOSXMSWjKsWdUgpS8tTQ_gYP-bWxHkLlFYAL_snZR1EzZ88bBnxq1uvzHMEeNxQYI5JUV06YYOhYyp4swHsVdxG7esfvhp8uPUnbVr5bg2A0xAJKzUC_bPEisZn8-9MaW39lWn8aW9p8PTke6D8bMg_9kyV7mIWY-YuBLGN9RpETyO5gqjQ9H7JtkqdYsN_YLDeZ35_GEQ5U3QZsqh-RmztMgtp2PnmjC1OWNgnVyh0mPTeQ2vrFdfc1BZY0DkHMCK_ZAcgxAnWNgZ1cCmKPfwIwpx9RXBcGJifUnYkG9IhsV-8mlG6PfEZXQgE9-EB8DwO1wZG0zoDF5Z_rIw0ZA3I5H_FzRTUb39md345A79I4rkg5QvWIO3HLIrl4YlamTmR59t9zjizsWJnK5uXETQP4xVMy1jD51esFBbp0d9TW61R8KliCj2aD0WO4kg4gO87TFBJWotznhV872TtAy9Bo0eX1w8GjXOKRiLDMtbQJtx4DU8MgTJBQkhZKvdrRSMMDDz5ICEIUfdgiJJtgxwlgkMrlNLC7JEh7fZjQi01eOp9MiQFdBLKn-VMNOJGnJC1dWs4oFI-eQWimt9jFfg4d6v89YYlPcR95nLRxWZwNEBs0V6sCYVOrwElNVQcPk7yQvJlvWOYy7TX5g8c8qSGXRKSrfuI0HlnDDHIC6tGOtC5CC6MO8fmNkr9IBEPFK8U_ZAwpxjrqy5r_DlyhVYYBb88u-KO5UD5PtX6G3oUzAAGCZDSBSp_ihCxHAw4PQgt5rQKJ8fBFdJpIuvPsLykCUsxVD4x3TgZTAeiTrcMo9NGWSvmSdUF0UdgeD_WbEIoRTkR0Qo6yd772G7bJiNR0Q1IReKAjkU_xOFYw-coyWM5mdPsdFHBlUAhUGQ4j82grCw8r1KZSeOUmBQHaGBNR7vJfwmnZmyRpm-Th-_BrH5j9tSIkX7JhvfRK63PPDdriD6WF3O-aejw3aX8S_aGxakWE5289IraGQM1AHhcVTstDZ0oKjlLd0CgaAYCwho2YcUJyMsCMZKnd881qdTondEwv5WAz30j-_9g8ZU9qrvUq3IUykjfj2kF5KfO8JvGHkQ3JkivilhIO2o_HMwm-kPpvj4N4qPSR7PPlYAo4ofeywVtAQ_yPFTQ1ioymEitT5tc5m8NCAARb-9sc1xpGS9iWFD1OdilSUlq0VHa9VqJQnMrlEicL3MCM6YoXIygAm60-lE_rPBOR9JEXd4r38Oy9wJTty-AxPz4YeyctnogWbSlgI_AEaiyHRNOQ2BV3dAJTz-5ZgYVwX2x4-TrL7EaDdKpPU_2rSeKMjjv5q2kXuWLKS9bkvCmUmIG3J01OxE0Aasvsl8SpfZ4660gYVsoEmkTYldDegpMeZD4oqmWWPwqMnkegfJaGQ2tZ0ivmFBKbVN130EC53ThJKBPmZGXJYlKushdkzcDbDdodsgeSlci5OBq-HDJ4IgjVPIXFLokksXJP_YujI9h8c77qpxoj4HIjUiJL1R_QG_M8AQEBdtOcA69R42UpWTPnURxqncj5DPqJG9jdi2ECOM6yCAcBARf23sxu8PJawtXm33vsUnTLcK1nGWpUZjiPJl-AMKAJAQEjNqi1hIRzDW5WF_0xYMwM_bQ6R9EeIDoxlGSHDJ79GQEBLhq7diTfa6J4mwXIDjapqb_J6S8xZ4CZlfAmpmsaVSoBAZnG8M80tvpDciNUgjUE_lKIp3Wa1u0XOvhechXfypk5AQME-WAXjeLQ2qnQLTIkSZf_NmbMo7AG7XQbxWuWCj7QESdawPt90HhNtg6hciOkcS6D2rCtqn4YqeDMiFDWpAAdAVyOQmQ8Yn4jA1yX41K3mg97AcCkJlch948PvZO8AyoBAQGMXkDJ_LSsbWtkpTF8duEeOutGGNa9IPUKpKW4DtngLQEBO5RTqf9hfB-xVMDItRypgg7pp7OAXi8CWk1GIrJJoDABAQtNRBdr8kjJOAiqKW9-18aBbdi_VYVscWM_aaMHyHIfAQEBXYP4HynxPK17-GQllZ5mmpqKfxcBlu7rGklMHQIi9iUBAWoZP5trY0Kp25rIvhK2Ib545JUS_MZP7STJ7hThoaQeAQHNCWHl28Ypxq2zFMtB6EHZH-2-yWvDnAB4k9K59IP-FAEBAZ0wZWWio0xcg4vH-FgPytjjxpbjwTdXH2l6Mt7XNNoDAQFszP7tJOVa8U127yKlIIkGO93ujW3sxY6a0EtD3rk1PwEBX3zceUIBDw_dzA4SQrGdCh3MVgvz0-R02hvbTI0uPQQBAQHkHg8NI4L-iH-JOjQi6e10-VbOi0285bLawo6E1GyjEgEBT49ryieFN0GIN-GGEiV_UsX5I9pBA5jC_zKzTLmHJRYBAb3ZN70HNnNNEQM0TbLdU797zYY2CgsJzd8MBs5T_mkOAQEVsWwXmQE3SnCj2-_zZoqnzByTQj-6mMhhCcLWzKY8BAEB9RNRViEzhfJtULxCojLExn4IFEdKKzjwScStbgtiDSUBASLUr2zzUi2EDbdkPuVS0gfRL53FAXYojZkleHBVsU0kAQEBFckoPjhIJFTqF2TwrwsF9ilfEjAJyj1oYpp9FNd7KCoBASL8INrM02r9UcbHNdVWbTSVKr97HWeorXT-XFqJe8wfAQHr3eeqU4fnxaLgaF7Txp-XTLGeI2x4wFrn1s3pXDzuMgEBaqw-Yogg2kFcUghxDlRmmTRBYsS8Irx0BKIhDN8IDRwBAXHzx_OoDft22p6V2Cdjg5rUGSzKLsF7C4Q2joxnJx4DAQNDFTYOZaccoDtVq31Ak_A5URwwXFeKY07FAdf0C6IpPgONjNqvM1X0YGu3JDEy7OZIFvFC7j5nH3Nij8gJUC03dUJrKDLazFTZUKFJjmpE3WTYH5jUrimou5JekIKiOx4BAQECnuqOrhKuUf1cqwis7TLLR71AL26eMFx0lH4tA0GCJAEBKiR_ekfP6ysJFI9m0fwz2M4YaQ5ToBuBAa28eNpfOi0BAVySfGeMcziUDEnnqE1F1Rp-9IP30risaqHJMSsOeMMiAQEBJ4WC6pdZx0yM1j0QelFc74q7TFZZoxD8r8V39IByiSwBAR9MycYeVqOJz6wjBafYiwVXRI777zQXJ2RT5DZn9CUxAQFq9GCcjDxHuDT8DTAQcINAxQrlFcZWalkPaDJ6HhDFPAEBAWw8xrGOV-A8ugBvUM9b2EWulpRa-14plUhD8iixPGMAAQF8XDvD_MlyJYUPGytF_dTd-pYdPAEmQsb3ELDW2oRiPgEBtNg7mrqqAVEPAGEIjNXkP7qagaBDV7iBIcnFCOci9yYBAQGvMIXcMMEajp-_9bcSzyxg2Yb1eAcLzydtpdf7AxI2EAEBNjt5leeuyNruUpCQUjGnbcoxQud7N2ny5qkkXhw36RwBAYg7MFWLRq4hGSJP0Rr7JgQcFOHilcc_qw_9eURDdxUyAQHTfb6enbLn8lzm40UW_0-O3KvwOBBp44JBzbeH1OfzFgEB8PiiDzz7i9GrYMrYImRUI6ijUunkbSRnr5ymnzXyDy4BAaCSBg0eh9RZO7US20B1PKec8TeFW9-zq2vgvaXr9scxAQEB3sSs-sRrNTr9u-GOUtzb92ThHF3FEaSEo4JU6JbHICMBAV2e3yIoPictJbENvj_ooYuwHIUtjFoyP52mLB81duY0AQE6o3NiJpNQsSvoP6mMae9NrkK3iAPDlHDiB6Ve5BBBHgEBzqbtXE7DlwVKHxPjbDHY3YHka-crvWBWabqYckQhPgMBAfnnZ2btjS7ZGN_HGkZYRf7OxhLs9lU7kJJByOpCJkAkAQN13h8sXinp_yBSObSVWyKSUsBqmNAu0_lc4qTU2NDPNnY6KNlU2g4Gg2cIZPOD0pyT6ZVzZ7sRlRWZmr5JKAoNQxyqzLHasu2rbwGgMCO2FPM2Nm3EH0o18M51ajpOZzIBAQFHpwIKrHK3iYsLBl7uYk43KFE4sOE2quzWFxYXHPBdCQEBgRYsyCcUU36qRotDce-s9-xHPcqKezXtwp6wi-m6HCcBAbBYZrSCGA_TJaW0yx5HESDxkB3boSBdvK8u7xhrzkcHAQEBOgrLn5X6kNzJA_4nWPEuvW8dDvUWkUrFCxF5L7yd1AEBAeWiVvCMho7H9njEv3drfxrYkwOc6IxJwUeMhRCVZBQuAQGAO-mXsUD8WXo_CJY-4gzl_Se8cVyDZVm5TLXoisG6JQEBATobwd0gpLWoXZCxy0jFKhA6tcoqFcagOks5ODK0zkI0AQEVRN3cy-hD95SeQsUcp5wj0iXovNwYyjt2Ng7qiUC4IwEBcIOOgB3qIHVp3NkOtW8u8ePdqKxWA09oYxrYwvT9yy8BAQErJ2RsVgcFdsswAdCNfwZrJAmuttUU0VQb06gySFX6LgEBOy5ZLj1prAYXvOeJN-KmAy-Z6a9Jwcoj-SM3OkvMJDwBAUYP8n60_7zWEVfOOubMSU-lGAiDjDULt9VdeOTgpD0FAQFbz-RE-mgwo8R1D2GNWZhl7yWKhs1Vxin-_zgDwLtYKAEBp5zy6xpMl2v7Sg2GzGL1cBjXLipiR3fwHfy8RUbmtRIBAT_Vvj-e9CWJ49ZIKFOlVBQn9r3nUdGfD_fQ1uP5pwcF" }
      , otherAccount:
          { balanceChange: "10000000"
          , publicKey: "RECEIVER_ACCOUNT_PK" }
      , token: "1" })
  }
  ```
  - The `proof` field should be replaced with the generated proof.
  - The `publicKey` fields should be replaced with the relevant public keys.
