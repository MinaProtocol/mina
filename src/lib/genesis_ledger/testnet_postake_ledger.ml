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
            "tNciTDiJziUovrKA4KKs7wN1XNhV8BW1YUvcyoo33RdrtPa5fKSKJSqFTgo13aNscVYTBa2kRmPnNGCdsuAqsSw6YJSn1GKVuqfpTDxXkifm6PJoVmVN3Gd1vBPKzdpeyuTBULfwsjmFxB"
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
            "tNciGGG62uN18dV5YJrr2SyGWsGbQQhBn5fSEBJ5967KBikntN6hhnCw3Zc1aQCWi4FQDSZMS1d1aq18iKUVnJdDi87ZtBsvgvS1YRo9rWFyX3pUxeM7mntZmA387gztnXT4xfqYSwSh3v"
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
            "tNcij94DDKfuVRL2VrK9HQVeyJPwFK3Sz6bnpGWgme24Cqsgup1cpfb19XKEfkiUmRrUJ6CrJ8C7Bgz1w6mzeRvQ9BXuTsKaEc1yvuJUoDioGVXpuGowYVXw4KC1mG6RsqPYF4oH7iWcHY"
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
            "tNciMTgwisDWsms9pEiJvbRXWpCnp5vFQRJd417w1aN15ofzCEFQA37JC4yEoNLNw9MxP12uZVv4Wm5mcwCUryD6zr2DpZGiaBvrWikHTreYMbE4BViMB9d7BUGxLExtoC8cc1LjQFXPgG"
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
            "tNciUfrbXAYtEfcMhW8nYdh9DsFfGenEYNgqRq5vmzBnRgaQd4fDYVEt8VhfbZGQc7brDWCkvNrUdxbfbV9mc7pEN6GG6hEkqNAbXuz3YtKtQPLefz8YMcbLhdE1ninWdkym5ytaKNteCa"
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
            "tNciaMga2fcyoTSo4Jd1UfexzTgt2v7dcCw9RQgMTPyS1JVj7YaVbL5NkhoEN3BobJAo8nkuD7FFW6GyJBYbbKTyTDadY51GbEnijZbHG4a5sxvRj2vGPyrgTvZBdTjeBGW8Ug5KYw4h87"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciW2rBoTssVzvrwEc6CkRHCZznKP94ZfAPvZP3pmAjhGBofjvZiom22pBjFNWoVJA8PAUcyYdStZHnvYYd3qyVqobzWiBFib7zTkrnRSGR7yyW5rr13JSZjhSgSL3hk8focXn2mhp2HS"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcim7ShoVZujTkrjN2cZBmLRXAJ8AimCw4RzWpCk9nhQSDBfHRSacUhGjvhT9GvDRS1EhhZFUYtSYKTboHM1iFr8LUAWcP6YEeezRQfR5Z2Szg8dRC1JUHcv4eqk2ArNeQpv8cdsRtnR5"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciEbdy4xtgN7q6XQzzC4Y8t4jgSrVarMvVt6CHvPF1LMS2fCRtLbwguwvv5uhL5xCmcRpUJWHxcBZ1bDq1Q4m1W9tat4fFFfAEiGi4hpd4kuseK4upLpxWzCtjvcXbUbzjW1Exj2562Z"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcidBm9bgZGojYz2K7ExcbdZeYu9nSaC6DrBo56fKFTTKxfkHCx9fQZF2gkb3FXJUDr83gLLExRAkNRjvwCoPozjUrzQ3UNguciejRxAMBHmDBdzGNN8evfid5gfdaG1owpCHgC9cS8HJ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci57NMPonWC3q2TeJFehWv1jcrEdZ1SNUuRXYQHyxhZHsspYz8fJvDeiiN5VGt38jWkbwCcp4YuvTgQM7KYsx5P74MSz8ZetRp9x81XHYENtQfkTN5tFBkosCLtLGug5Ysb22QMec1bE"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4SdujNw8vhbyw1cNgHzJng8NrwXV9oBnuEQaBEtGMBqgjttjj3aF3a565MZ8UodnfHZCVTTmPBgRxbUxAinjFuMUvQ4gupZAmahgMHJ6TdZcuB6LiQsiCYfbaHAJyjUox4iaYugaUq"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci46sQZv6UJPTxKDgDURdg8Ws2E3j93emL2NVzbG2qU7cHVEtfMc4UQN7knyUddhhvakrxWKwhRu6HBVJtZp64jXgfsiARn3EbT5xCLLQ2kdnRUBGJNuBpm16agzVdq45pLQMUj2kapX"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciCpHoXJRiWYSsx4HZzMNJxRYmHt5yLJbF5fa6Yv9fR1m99a9KfgEgaFmtSkhbJ3eq2NzwdeHMAafGCAYjeKQ8tLoF34e3vPhtW9nYiEqJUJuZEsPZE9RRQWqyPuMPFSZdeqdj5dut5H"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHfFFseNADZo8isjQZHWgkJ1rv3t3QbQiyeDk8ak7qQrLWz2TJ9qUhWjCdgMMDDte9VDacLWZ1cUaJZeq2xuFuXPsEG1qhEk39NStb17g3o9hMMep1URp95UCiBAPEFUpvWQY6fWvSB"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifuofYRrtcuU9qkfZBs46GRuhWV7qAiTrsR9P63F9mC5DQgex8xp68prC15XAfU2XpF9K68ktFJzG5bePhjeT366G5NwihVghive4njYpwex1TrchLwmGHLmxbVvW8ndqDcHiAKpo8f"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJ1v8V8LXgiF1g57nqcJqgsBqiT62ACWwVFoaVYuZVGky8JJe6A7QQaotU9MqQ2QwLyHV5V7HCPTR98MLAZsD4wg4LTJ2ZzsBLwr4saSoooGpwkoSvbFFUu1cvh1NtHGosbLqK7bGKB"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciULQW1LuaNMNNLDGkoA6Z69vgSrhPTyfMzKvq8NRRDN58AViW5gi53ypELb2is4Cy8P3neAzsXa9Kga4gyGAk8KKhQpUaJ7KEVo82PiSFEg3zJsVFowg64RmzPTTFgHsHg1sBojSuni"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAAKxZ3zCZq36DYckDNCjwRRjbJdRNGaXXCasFJ4LX5ucuDPRo4CJ1T2V4kJ5NXrCGA9F7pHtWSs4xqWZ1KaHrnVVu98JXvuhPeVaerG4iPfWMmyY33zJiSBXvmbFoGx97T29snEVuk"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciji2QpPHeyq8ztvXv9RH9B5bTgxmSuJLkKw7RMJhVProxMuog7NTV7yKRN2yAycHHZ9C7rGe1BMgSfBtyXaqiGnw5cS4q6aNr1ggGcbFwwPhEsTscFCToYETNK1BriMQscn9X6NLU4A"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQraAWCEhvPvz1eiDHzK8cmNFKVh6QEtmojaij3v5PoDqD2ee1hNx8VxoAdy9PqaHYAc5YeqwYn47f3tUr9Mx3QFK3ZUeTqswgSFsYxKRLhcQd7bTRcUM2jpdLNe86md89TjbtKRhQ4"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciE8vyx1iEyArdxgV6LvTakwpvLLcLcsHqUo5RTn9khnPviUcPvJK1fSA2XwM4F4VgQ3PYmaMLjcaZKUhSsYzvkcK8sKFsMgXoyM1MExbKjoGUzwPoYadzWZ4SqmzcSF4gMMWKfkAbZ8"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciMShTd7ZTUvGL8fV14gqxH9eh7JcsUU69QnxW8hsGtyem8ecqeayP66uBDAiwMy1BV16mPVe7JKa51ZA82PtxKDDddLSQuVxHEt6PUcBcgFYBSmknaUASjUFLoUsf2CnnqTA6k7C85G"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciMW33Ts26Ri2jt6ckDHDxLYptfHFfxsH2H3vjv2tBvuPsNRM9a9sj7Zigk78QpJcUyoimSyZBixwHUpqBaDbww2uLf3ccUp6jKDA1aQ5jcWHWQ32qN9pBVw3y1ERCX1ijAKgRFQpt3g"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcim6idF49PzYpS3bRhx11Ggkm7CuCCL9JKSboj7JcYme2eG9yFgkPq7RkAiau4jt5EF7nZ698SpcSywjD9FcuLFhZoqPrqv1dkJNJ3bXjDqBkhfbSJ5KTioFVx9q26D6jJeBbnwUsGMS"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQPgJmo99zZSJX8fTQmu3byYywr8jvSs2XePzwtPLLYqrH3WSja8rfzL7FhFdENmTC3bTGqf3jRHSeSGoWCmSAkKfdHgAfgZA29JwjWFDp3rVTusRXY3jmTNzdwy6A1D5DP3SSP4NxM"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQn19op23GGWjoLK7d1VULggGziYnkrunFRSgHUWtrpoVuyjC7R2KR22pp7Q1HQwzFk39HpngP9bLxkbTbQmvxJLczvK4NK8XwX4rEpzuSz71GKkxJdSRZ6kRahFu6yUEUffRGagc5g"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciboVmZqK23AWjdWiCbBi6WhSc9H7kPLT4WVquvjn1je5ur7hByz7E57GbyZ3TjCVa5PVo7iBQE4LDFJZ9UGsATJKazc1kAXwPNASUTsqv7tsRP2abaW5but44nW1McdRvmMCGLEUcCt"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciX5i56xu94c1tivCChEGNg3neSLrHKswwEsAo8QsaxnExv2xFix8P7VxrBTVt8SMxKrAPNzMYpnGkvDMvUxeSULCu89fZKSyLK8ztTGe7tBQ6jycPjJdasYXSSUpNhWDVm6Esfrj58J"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci77AGBjtDoTCMr2wW5T4vLJdxUGB4ri8j9B2duY6TF8r4PVamFi3tq55n7CBeitb1yE1pAELQNHgNwMx1DzocxtRff8dpbEEdx9U4EHWLP1JBPyFN96sUjrnQv2sXgkX2Ww3KYKbwfY"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKu2s74n6JTSZTpyMcZ7on2pNQvizz7RnY8gsE23ThH61Gmsi7vxmECLjARzHCkXQQdZTYM7Ufz6xW3jdkGBdAvbLzj2gKvpJFRB38qUW7t1UWti2VSKTaxtRmFtCQC64o8xknA3xBk")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci7SfthkZX6NWG1QMBWur1KxyS4ZZYkFDzbE1FBmDu5xwBDYYpbSVwd1WZnya6rwUECMwtiaq7dM1EDa7uWueY95foBY6UFxuqt7UdqxP66qtL7LFnf7Z6QykCK6v7Y8iDhyZSz5uuyA"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYRhU3FBL6certKF3AgLDLU3SEpmoNxbB47CCfuJ9Qk93YwJnHYotS6Nnbi31cxLwDQrWxoZGYee5iBbip8D4ndy2WRxTGTwXNWeUng1b1sFjrcPndLBaF2ZnbDjaiL8ZrQj4znMDUM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcijXjHEfbR6womyFv4tsPvvqwrbrCPRT9cgjq1yafFFHk1RwA2umibuutBVcXyC8XcESaHwi89HDv29D7wYQZp2WhAuLevVohTke5NxZb4RGV5tfFeMsgCxyPS6AXgmKifXSwYMvzUiV"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7WwZkJiCwmSdmyiX4V8kmJ2V6VZsvZBseUeKGBH4eFxm5Fc3tCCZYKmr3Xg6x8gRtvk3uZDBTNB9jh9sZccsu6H7LdLYUxju84Rsmu591mP2Ak15x24TJhMcW9jWVN6Z7wEGNrEHDx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcify7N6bJ4LhqUVQnVpk41KmffuWxtaDVcywzyQ7yA6BCmJbVQmKnZifcLbgpsDj9oe7W2awTt5RNyqxDDTtTG9RQDGWhKJiZ2Rh4X3NYoJXXattREyhr8LzVsVzKjmMErP14Ai5Mctd"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifNhAqaXVVBgHaGeirKCeeUWBULwqmxxHj2zKWPstWmdXaZAD2KLPEqWDqhH61Sca2CGXEbqqnmk9TSa3bZJk4Af9ZEtHC5QB21sV7KjjsbtXkdUMM6HdbmSCuFDLnx2NezruUZkJUE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHUDHuaa3Y2Jw9Cib9qsDchChdMLACRHyfSCsvCNRb3qHPhpH4vBV8AXE2gzFXuJWQvHcdiMuCi1zwBqbstjpe9ZHq66THoVKgpJ3s3VtrJnVxHo9GS4vpVGaLeLDLAoadsHZA8dAt7"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciApF9QwjTVChpyowq8fvy1auQnAfYp4dktZYH6kGApsWRTq1ZFq4CdzZpFpaPx7Gxbf4Wg4fzBGDC2f7xuriKqeeR4Cj3kWnAxFAwPXKCCVJa2TuDPMkRd3XhU1qUq12ccMHEQcJbLz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4TdgcJLiCQyNoYfRWDXgiMaRo15gcEbB3ApA9wzQSM8C6URGDA2akxgNd5iciHbTCmxJnuoK3Tg5Jj2L7AaYePcGvRDfHPKiTroBxX3HTfyeMYj6F1rvjBeenLTAmFQ6fToCbVnY99"
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
