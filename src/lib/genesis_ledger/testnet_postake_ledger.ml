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
            "tNcihhTPEQLJVkQYXXe9NjqWctZq5GXLGRKBh9CVeUMasWMb4imdxPD9r9fGh883Np3XixeGARbe9dCW43RqMt9UZvvmXrAaHDMjuFYyn5UJHg6XwGfyiBBYLAc6PxYMqJfGWCJKDd1Boo"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKoGhEqyU9TSweMiKqpHHjLE9JiDnDVwbN7UUvjccuMW4oEfcomjx9WY4A8BtDU895G7vHjetwkkKUnyBpYskxjMqzMhuT1x46Mb78UgMWyKPUdQNgxuFZG3b6VRhYEvg88mqfNPQTX"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQmDcKFxFtqcy1YV5vm2yUhFzvNf8uLkimPLPndXt1nqrcGuTiVQZkHB7riQfLVqeefCAjiedbt6SFMkgyyR6gwiPLRvZ2kfV5572p1sBaECGq2TxTEWrPBKJg6TbxY9Uqi3EG2phxW"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciA7ABzqCEtpofnxzDBN1n3gL6Se2CF8wVgaU34NiErQebrAMF6nwd6wwpqGqTGWtmxtMacRtXGLapTCH9HuGALeQCwMFfrC7dFo5T45eKBWYjCwguUUScoisk4cQ6LhynLvVPx6R4rh"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci7esg8AWFngU7Ubo3iXBxs9Gs7H852HSgJHLo6iPkZf8y2s7zwN3SD62btaW7uykGySswWt53gdP3PwWJbGE2kjDy5vMj84aPPHsLjTWwCbZ5pxikA2GZThEN6hy5iyHBNFoc3dCsSX"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9gaRbfzhHn2qYWYYT3wAEo1WRKM5ozdMH1aVGT5CoxotdXbGRj4ueeKmCBgkU7t9TeHhSfkWiASxrKxHcp673sGR8mHgbuHNzECAew1DJUEXeEASs6oawTfs5B9pyJic5jaUJuJ4Lg"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciczxpMfZ4eW1ZPP9NVK2vxcm9cCHvTBWMe8Nskn2A25P1YqcdvFCD5LvgngraiCmAsnC8zWAiv5pwMYjrUwpMNYDePMQYiXX7HVMjrnB1JkEckyayvsAm2Bo4EQBWbHXD5Cxp65PZy5"
      ; balance= 100000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUTDQupJTEjEgFefiGBYuXNF8asTBSEimH2uBjkmq1vMEDMnzQyaVF9MgRmecViUUzZwPMQCDVoKLFmPeWG9dPY7o7erkLDFRWnoGpNGUk3H5r3rHtyfrG17Di6tx9VqQMq6rehPmAu"
      ; balance= 10000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3P46ZXFzYT5NVuePtHkrwCiXhyf7uCXKWuUNSANwbp5bbMyBj79oXdRcppE4UiKN3M1Lnmt1Q3i1fCZdeXSLYXinb3dYTbyZyVK1qY7SH3uW9BBAVJjQmb1oJ8LRH3pCg5FEkbPASR"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciV5ff4xHHqR1rqAHpAWapbQshb5iTrZ66uaSKqRk5XwDPCsneRJuHjCYjrdLxWqVqsvnHzqRm6LY4dVXGPBrj3zfB7pX27z5CGVfoaT17Jx1LcYoUM8gTTedonQwZZXXCkHDTzauLjB"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHwh4vN9mpKDbCjWPGhDwUJDL8BFbEY3pacBrjKAhYMrzDVjKM9fCPxrUpKCYJZrQyTVqazNTVK7wYF9q1TK9vp8zrU1SGuvG51uLZqp66i8LJ5PFtqtTDiS2AmGwpQKV9Dd6qqed4L"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciRHJqiqUHxzgvxGBP2Ap6mVNP9sXk9s7iTcdCrYbXrZn9rYHS9Y3eMECLFbctRWHU79gKbUTTFjjZXYdEhSF8xyZThdn9fawrhVR3UUdLw1XMK9Y7pCJUobAKQ2vPN1hDV9fVUy4UUM"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKDFxJGWBdbt3Fsueqo8YH6bgNkhYNTAuXktuVdWBvzpWX6bKbxBsPbHmZeBATouqqLTNP98zUvzxbggJZpWFf34AotrkrUEFaKiioGyaTMjMPR2eBRNuqexRDvoBWfbVhi1U1z5mdu"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifj9MPBHfTPw9UBfTqJdUAf89hF5uXuiqWKmFAcor49SicmwxGqTUpbQ3ER6a9bP84j6Bsm6MfThBHhk5Zo92jgu86DvsrFBHpzV3cFqtndWWK4bdG2d529SpCuJ4uCv15rA5ofVekN"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciPp5cecreavWV9eQ4F6g7Z58xosRCP1VtbCaGSBaSiKhudGCBW6w7iZSXdq7iLjeVFK8uWRxTBUQ8HjBhcxeAo5G9ymbZVW6673Q6FLgtxTA1949GiA8AdS1u9M6JTRxUzvaHv2icCd"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcibcdCVxU2fFADufADPnHL9kFrCjwUpfbVhw3qgGWKPwbYDdMBonv7JTFCrjnBpsZEP48pFG4Cktg6mNtboPoCx1Y41hVizeV2xek8UW4btHUCE1vPz3ahZUidgeRoMZXb6jH1GFTnhe"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKNqinWkk7T3iSda25Y9ydqnSwpkn5KLP5eceiRpoZM9TUt2Mz5BvJ9XekFvfttUPz9NaR3dwvhPEArVe6Py3RjYZk5qocMncPWudSXj4tTnoRZwdAVCxjd8EZb7gZsN6zHsVs3aCeK"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4iaubb8bqWSgHzio5UqzpJfa9wLnE9eCzzBMu4TgBmNDQzyoEvMaG9q4R9qjyoryHrLic86x1Y2YozQnDBxfjmKV6Yu5pLzXepG541gLUKHTbbLMDxmneARZyJfAtuc7k6bmXnzJCs"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihcevkFzrqMgrphqanUhevyRfhECerG2643CfKAnLGK6HZAo8LYgJHucEFzmftEMLERyp2ALbQRL5eK4Hc1YA4wxD2DwBXJKvWLcjgzrymy3YvtNXZxGDPYoCiU9BUjtQpa8nvD7hy5"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci5LGX6xZCLkgX6EgANeYXYrgyqrdekGjWfMJy4fybd7iaBEpBsxQpkAyVxCJqz8QRti5VKfiLAoj88eMNVJMcCiTB8GoirhKVoGYaD7byJ7kCNFMwhrXLdPH3rnnyHBZ8aG3fqiumZD"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciF7PsB92UNyfFpzrvezmpdNtLcm5SCsfS8o1zZcya7yupjVWHyTvr1imDE8XnDJtFvT972hbQTfz46G8t47JidvYK2tMXsuEjtTXYmMfyJJ1w598ndc5rEWGbbi47WAGUW7dtKBn92A"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci6XEVD9BAfjpgEM6Z8bnR4mky5otV31Srq5KL925DJhKRpJwxMbYrze2sP1kmzqqBmVDsdz4Z2NgD9kwx5yRFowmvvxFvXg6mHdFMAmVmoWtbRxFK5JpazPuKScLQvWVbdwRdRtj6zG"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYYRe7GC2Axr4VteHCUUSqsXwTYi78TDf1TV4EmtKRXpbHTsJFUDRy1hYvbjzXXhsmjVPADUyWatA5dpCbMLZbHmKhJaiNmgL6DK3uoMgoQgUn5sXDomn7AYdEu9Tv6RN3Zd84ejBN2"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciTVUTLbc7gusWSviC4X9mSmc5GR4qWsxhF3Aw3QhbUz5rzsqAGJbahdYj1HkYNCtPRDgEspByLx8bTjSTMWD7tf3U7Y1KTQuv4GyiRXYNubPawzPqe7QkboUBap9ez2yRNNBzR2xSCT"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAidHcJSkmnKrnP7NkKuxmcgNcgny266p5gBydX3xQ1EfCpQHuK48Pj4c7aDqcXh8oBeGzyGrwDRzXcXWvX6wTMsgCBJCd9tNUfWxT7n692LJyVLRmbHc7X6UHCuWFQhwD7ptNfruaf"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWVvt5nfSkLxRW7Qc3F2b8VgMSvHV9oG3opkgK2HxAcNkuuM6UwVMycZwcbKL1pKtgNWTV1mJWq5U47HDww5AmLbCU7ZsQSaAccvxUmVLQbA85SPa3zHZ4fjBj7h3VNt9KXgYvYiY5B"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcikC5Sf2EwK3gTE8XPu4zUrsbUq1qCLRLkexQcD5yLSc73Gnt3EQJKVYQq9taRZnjEffvYeeaKQo91KCSajWGBs9iugLrfMXvMQ5sNn7V3q1NGrARHbkECq6GTRgXZcvSdRAWBKeuJQ2"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifvy784hwsvn3SswycZV7qZ6zrszyzjhgn4sEnHNMDFBSyZZLkDCZ9jZRz1uGKUdnYAayNkdUZaBzMR1fsGrDfSNBXLJUg4Xc5CRJazPEvpkSDW3NkXp1pSP2EtAq6KEYELsZ1phnsg"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciU2FojhwXszgPy78Tz8BLsaSY3TYmQYtjuHkvFZU74Mj9zRuqpvJL5NaNStASSg69QzXp3CTkmPv98QbgpiDKhWFc1jhBjXff2T1joxKQLjjTVXt7gRB4ESwY5Rutp4QwwfByQH6smx"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYgDpKK7UpimWto8Bb3tDVCXFKVTrRbhabtsk6DKT1X8YA9kEn6v7qgr2WmknWvWPRRdQ6RvfFNmhGNnbBJHDn9bFonouszq6mwgm9461kCpAFkwLQWMSoxCdAv5BBjgWMnejZkYHGv"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciME5wf6i8T7fH1U4f5XTzP4XhsLgaDJ9kLpuHdy2j9ygV6mLvrFLu6fwLXNpBSqbAbJh9wuKsXyr1VBY4hUwZmt7qJyhqhzFgWauug8LwriVkykk5sVKcWrwzhCaHkFku3srAzE6GuT"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifbMK9hP33uAgqXbHURtssX3uEbQ1JVs5PgRxMPf6KHpEpDoFBb56Dk9wSWNNR8bAinA35ohCzWr3BzuFpUYr5Z6SekeAHdvNZXpusT64w7uvQRpYQbLsWPjgJzZYdjx9392r1zm34S"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcikSGhxjJrWNcTnqVDy2cc4RT3SVvPP8rrdKGbEbRUX3vdUB8Wj6hWghM4wHxoizsf1s33a7k3USwerbfACnBpdufMkagjP7JXTfk8jGbvqgiq35oq16HBFuESQbcPPv6t8M8uqbt62y"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifMcm5GunCLYno2J2QEnS7xix3QWm8YtkYER6DXxgkgPrD76U5rF78kbtqRAMpfAQUV5yz5yU7wah9aZ38z6uNgMMUqkDE2jL7QdMdExUCfwhxyLyPgQNTTX3D3iXRFvShnyAG27f4e"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcicMnGb5j7tDXaBgf2HX8T7eLoprPeLxCoR13H8aTmn1s9ezo5NGvtPSyyRJgBXR9c3x6MYaCz1KsHxN5bh6vJhydqkS9WCCqZf6nfMMdXtK9SuzmokPJHspwKNeFNHynvEoLg91egPY"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciaydsj5CNaktEgshJcA3u859KCfEfYoiAuptx4ng9Cam2jcUXVTUDNYeDF4mb5woDHQMEyS9BPcraYWSPbe4PzKwPG9mWeUMyB6rFhXn7gGP9nnXirTVjvtnjhFBZ3FrQCeWEynCH8z"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4bPwZx6xZsuYvzrDommQEM7j8ViMkNdXLSyQyEhQzgvTWA5qaoZekNbLhvJt3JJBLzLPMYQ1dLxiJhJPuLjCVEewMF6xdrw1yCVGbiP4PLuH5xVWabixQR2dkFqZiMSJ71LBLTvHov"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciZjG9aUYB6GpNKKBn1oqEARh4aXBHXuANdnfhfYsWmKV2J3zUG7oFuPqv4MFGToLmymRDTf2eLh35c5Rz9abcqUiZskYeUDMz2nmbo9JvSz5bwUBLqJ4ZKFEVDyLLbJrpSThhQsAr5B"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      } ]

  let fake_accounts =
    let open Quickcheck in
    random_value ~seed:(`Deterministic "fake accounts for testnet postake")
      (Generator.list_with_length
         (fake_accounts_target - List.length real_accounts)
         Fake_accounts.gen)

  let accounts = real_accounts @ fake_accounts
end)
