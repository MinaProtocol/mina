
open Functor.Without_private
module Public_key = Signature_lib.Public_key

include Make (struct
  let accounts =
    (* VRF Account *)
    [ { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXRzP5ViAqK6TbwfBhNkuppA2XVatF6uEvWNrrh6eBY7hsYbQfQTBkfNjpQZuY3s4jU5LYD3ZBhM2z4mbvmHeHQvCHqe7vwr2wQH4gJLSv14tf6iWHyoRWHZ4XS2s6oxzBFW3xB5Nvn"
      ; balance= 0
      ; delegate= None }
      (* O(1) Proposer Account Pair 1 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciTDiJziUovrKA4KKs7wN1XNhV8BW1YUvcyoo33RdrtPa5fKSKJSqFTgo13aNscVYTBa2kRmPnNGCdsuAqsSw6YJSn1GKVuqfpTDxXkifm6PJoVmVN3Gd1vBPKzdpeyuTBULfwsjmFxB"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcihXwbnb6Sv3MwW2rbhXDS4TNSn75tnDZjzUKsjgFSmVJUycLFftqnSZmikKBKEo7KHeLviRpsZw3XUh6zDZwtdH8zk9mhNG6ydL8pqrFM5FdkeV9fYdtvysVC29PSKyb97vK7jkJB5d")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihXwbnb6Sv3MwW2rbhXDS4TNSn75tnDZjzUKsjgFSmVJUycLFftqnSZmikKBKEo7KHeLviRpsZw3XUh6zDZwtdH8zk9mhNG6ydL8pqrFM5FdkeV9fYdtvysVC29PSKyb97vK7jkJB5d"
      ; balance= 0
      ; delegate= None }
      (* O(1) Proposer Account Pair 2 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciGGG62uN18dV5YJrr2SyGWsGbQQhBn5fSEBJ5967KBikntN6hhnCw3Zc1aQCWi4FQDSZMS1d1aq18iKUVnJdDi87ZtBsvgvS1YRo9rWFyX3pUxeM7mntZmA387gztnXT4xfqYSwSh3v"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci4GbJQMkTxsoZyVtn86HtLYA6KKxcR1ujoy9da7QWzw7QZgiL7MTxXbb3cxDx7nRpeFBBJ7m8SSVRR3Ua3tbiDAiARBYW6x7DFf56jTNjAypFbq69FvJsKBubKb5GhnH27qR6FjJeEA")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4GbJQMkTxsoZyVtn86HtLYA6KKxcR1ujoy9da7QWzw7QZgiL7MTxXbb3cxDx7nRpeFBBJ7m8SSVRR3Ua3tbiDAiARBYW6x7DFf56jTNjAypFbq69FvJsKBubKb5GhnH27qR6FjJeEA"
      ; balance= 0
      ; delegate= None }
      (* O(1) Proposer Account Pair 3 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcij94DDKfuVRL2VrK9HQVeyJPwFK3Sz6bnpGWgme24Cqsgup1cpfb19XKEfkiUmRrUJ6CrJ8C7Bgz1w6mzeRvQ9BXuTsKaEc1yvuJUoDioGVXpuGowYVXw4KC1mG6RsqPYF4oH7iWcHY"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciedhUUQQ2db9aZYhLjFTtPenzBTJsABVWemDeevGcfn2XvbaGpUDcoVdKxNRhfSEaUJCrN6iCht2zsRUH1yRnWpTfLA8CtC8yCDDrxvLNzRuSSrGMvzYEX5z3wt2SdmqJVVfTJaqNSu")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciedhUUQQ2db9aZYhLjFTtPenzBTJsABVWemDeevGcfn2XvbaGpUDcoVdKxNRhfSEaUJCrN6iCht2zsRUH1yRnWpTfLA8CtC8yCDDrxvLNzRuSSrGMvzYEX5z3wt2SdmqJVVfTJaqNSu"
      ; balance= 0
      ; delegate= None }
      (* O(1) Proposer Account Pair 4 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciMTgwisDWsms9pEiJvbRXWpCnp5vFQRJd417w1aN15ofzCEFQA37JC4yEoNLNw9MxP12uZVv4Wm5mcwCUryD6zr2DpZGiaBvrWikHTreYMbE4BViMB9d7BUGxLExtoC8cc1LjQFXPgG"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcibGJshuL8dqvQitNyLfndYsrLRffYBfqYS8CsgnCyUMdD8MEmzLPiZ5f3Sv7i3KAYCJygNMvQCULHuZBXE6swQTCfMiHvkL6eG4cmDBQ1NjdRjVeqMEv5zEW76sxduKbVG26LExKYj8")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcibGJshuL8dqvQitNyLfndYsrLRffYBfqYS8CsgnCyUMdD8MEmzLPiZ5f3Sv7i3KAYCJygNMvQCULHuZBXE6swQTCfMiHvkL6eG4cmDBQ1NjdRjVeqMEv5zEW76sxduKbVG26LExKYj8"
      ; balance= 0
      ; delegate= None }
      (* O(1) Proposer Account Pair 5 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUfrbXAYtEfcMhW8nYdh9DsFfGenEYNgqRq5vmzBnRgaQd4fDYVEt8VhfbZGQc7brDWCkvNrUdxbfbV9mc7pEN6GG6hEkqNAbXuz3YtKtQPLefz8YMcbLhdE1ninWdkym5ytaKNteCa"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci77WCk8buqGTyrQb9ehAp2fwHe4BUjN4kTGZVvG3mPUhntKKDBf4NMiR2GEuVwHaD28KyhP8zqVXtfAv66h7D3TKE8PTnNnsA154GDHLodnXT6q25a7mGanZjSQwhGcAVChjN4bGw9y")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci77WCk8buqGTyrQb9ehAp2fwHe4BUjN4kTGZVvG3mPUhntKKDBf4NMiR2GEuVwHaD28KyhP8zqVXtfAv66h7D3TKE8PTnNnsA154GDHLodnXT6q25a7mGanZjSQwhGcAVChjN4bGw9y"
      ; balance= 0
      ; delegate= None }
      (* Faucet Key *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciczxpMfZ4eW1ZPP9NVK2vxcm9cCHvTBWMe8Nskn2A25P1YqcdvFCD5LvgngraiCmAsnC8zWAiv5pwMYjrUwpMNYDePMQYiXX7HVMjrnB1JkEckyayvsAm2Bo4EQBWbHXD5Cxp65PZy5"
      ; balance= 5000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcihXwbnb6Sv3MwW2rbhXDS4TNSn75tnDZjzUKsjgFSmVJUycLFftqnSZmikKBKEo7KHeLviRpsZw3XUh6zDZwtdH8zk9mhNG6ydL8pqrFM5FdkeV9fYdtvysVC29PSKyb97vK7jkJB5d")
      }
      (* Echo Key *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUTDQupJTEjEgFefiGBYuXNF8asTBSEimH2uBjkmq1vMEDMnzQyaVF9MgRmecViUUzZwPMQCDVoKLFmPeWG9dPY7o7erkLDFRWnoGpNGUk3H5r3rHtyfrG17Di6tx9VqQMq6rehPmAu"
      ; balance= 5000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcihXwbnb6Sv3MwW2rbhXDS4TNSn75tnDZjzUKsjgFSmVJUycLFftqnSZmikKBKEo7KHeLviRpsZw3XUh6zDZwtdH8zk9mhNG6ydL8pqrFM5FdkeV9fYdtvysVC29PSKyb97vK7jkJB5d")
      }
      (* User Stake Keys *)

      (* Offline/Online User Keys: Kunkomu#6084   1 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciZv2EzZrexpBzTFxXxBPxGDk56KQj3Pts1g73JuXNZhwtmfqwMhFV73Bw49YH4CTbgETsUFwZqd4wXaEWx9bDyvnqSTuZa7mQyzQn9U7eVJgEW7NyFMepWBkaaV4eE5nSvq6HGBbGTB"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciAoACsWLFCReN19uE5jddWNYELLuRrjQnuHQxdCtoFWgsm5Cs3Ku2jUVpGSZa1az1F4dB5NrcN35egrjsYbo7zTubsKJSukp42p1dvHhxDmNpx6BXSRfE9FvD8TH6hBtA4SLP8yxW2k")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAoACsWLFCReN19uE5jddWNYELLuRrjQnuHQxdCtoFWgsm5Cs3Ku2jUVpGSZa1az1F4dB5NrcN35egrjsYbo7zTubsKJSukp42p1dvHhxDmNpx6BXSRfE9FvD8TH6hBtA4SLP8yxW2k"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Steve   2 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJWzo3x3wHXNAkwxgha9Ndb8gPBjLiRB71hdj8W2yDESiZHkzJxtQdqiStmvk9RvmhJFoynhAixK5gvAJq4NYztpkhLbim1zUBG9m2yeLWHspzfvPfQyJsHgoVV9aNmig6kvhM1WBod"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcikazABMLro7SBthNARSwFnxvefKsH2pPbFTok4x2fwi4fSSTKky4iV66y5CXvWtjWGdWst18263vWKY1Qof7nwLDLZ73gyewZiJyDNRQZ2p5fFB9DkgX1xaDriRgfqvv1sVizbbrC1x")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcikazABMLro7SBthNARSwFnxvefKsH2pPbFTok4x2fwi4fSSTKky4iV66y5CXvWtjWGdWst18263vWKY1Qof7nwLDLZ73gyewZiJyDNRQZ2p5fFB9DkgX1xaDriRgfqvv1sVizbbrC1x"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Hamish   3 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWHM1jJq2buwdmYyJ5a1E3FRvZHGJCnkPXtCQQ92CRhnZVjRsun983fz7e93zfby6pWKjPm3FvhJMf42Cjzh3gdeQ1nKfDxNtTbEH5uDbDkBCFzSBkMk6128MR6JUbdg62Cw5x6Mm61"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijNop4osFfnFjMEFriffM9bJW1yrMun5Dho4cqDuMhpR3mHES3NaY2WEVa9DhxR5zaLNe9AfubN29BpxFV95Vtapv3vJhQRAGVGBZuSPfVeCVcChXYfHsBH5bA66qQCZP4B2KTpGnzY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcijNop4osFfnFjMEFriffM9bJW1yrMun5Dho4cqDuMhpR3mHES3NaY2WEVa9DhxR5zaLNe9AfubN29BpxFV95Vtapv3vJhQRAGVGBZuSPfVeCVcChXYfHsBH5bA66qQCZP4B2KTpGnzY"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Sandor   4 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJmdLFT3GwtNmBZQxvLqj34AXUWNNXKs8hvX8VfqdfT8y8radhT2C9E77opK1L5dMUwet8FMYxjD2jdGaBGKbSSJGtqonmLjmg8ivzcDgxSZeY7CXHmokcTWUTK4wFMh6pxL39NNjdj"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciUZyFPvkD8MR97mbApQrsZgP1PBwkqNoPg9tk2YM1cojmvozLbJKoh5kuHa84CxpLShbC76ptTkowvHKBQT1SPd1sv6unVq29btMHfobtiDmD65z739quomGpWwsQhmzpzXMxzqGbnh")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUZyFPvkD8MR97mbApQrsZgP1PBwkqNoPg9tk2YM1cojmvozLbJKoh5kuHa84CxpLShbC76ptTkowvHKBQT1SPd1sv6unVq29btMHfobtiDmD65z739quomGpWwsQhmzpzXMxzqGbnh"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: bgibson#0713   5 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciF1qyG6JV2NRAH7jt9dW9XngNRe9DS2DMwZin3v8tcrnSmNhZFpaE6zVpF35zufsA5ENeYxhj12wky7h1YUiRx4TxLRna3cXsahfzDfjsn4qZW1Lhe1fKuDmEQYG5mZbcbQRnphjKTo"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKYpcyCnugPDMzK3YJDsSVghdH2rkCmqhbxcAV7a7UXbDSSRLhsoRnyZ2JTT1fDsRMbKcX4pGPteXUQhRuKaDC6gwV7TiA6oXQr3SM4UXu7z9za3aBtPfwWzr8PCCawRrxpTbSysZ1T")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKYpcyCnugPDMzK3YJDsSVghdH2rkCmqhbxcAV7a7UXbDSSRLhsoRnyZ2JTT1fDsRMbKcX4pGPteXUQhRuKaDC6gwV7TiA6oXQr3SM4UXu7z9za3aBtPfwWzr8PCCawRrxpTbSysZ1T"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: hanswurst333#7586   6 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWkc5VQ1wRa6dwESPk6TSjjzuh3Uk5qaA77fVUjNLBnCYR9FBUYAEE9EogwGqNjW3ag7kv2wUyV5Ggko3MxWfaVyoZTYP6eZcN68T7FZ37H93W55htyiYb7fpMEWWx3UAAjeGdxBozz"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciRhDBDMMk4E3zKabEapo61vRYaqs6XgFvchuBt25qdeEKj7WvsaCPHb9T9xMwYiYxfiEgKf5WCxSoMf3dN6i35P4swLaqSaC5FYTzvwuPENsjcpuYPfsvgNbkC4B36f7HacGe3FJU7Q")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciRhDBDMMk4E3zKabEapo61vRYaqs6XgFvchuBt25qdeEKj7WvsaCPHb9T9xMwYiYxfiEgKf5WCxSoMf3dN6i35P4swLaqSaC5FYTzvwuPENsjcpuYPfsvgNbkC4B36f7HacGe3FJU7Q"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: LatentHero#5466   7 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci6cxzpms8MQHcLpto6EnZ1yGxkxz51SwrWZKAoBENdwWbvTv47Knt77hRz81pFBFvH3XwptYfGerQoqG2asJwVSHSx5SohLA5ahaCimKDJndVT9YtjKsMBfki51TwpQQdweaCzZwDpC"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci2apfQDHNoaGXnBZ4TM6XDTTrcMGNe2BHK7XMWMCZ9KoXbW4MPw86dmmsgjRBNTv62AA7HvEhGH7CnjJYCxfj2KJ52nC3UZrfLW8qSzbCzuFNJThCc2fx6vbhpBSSoMKVnxTEwEvpbU")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci2apfQDHNoaGXnBZ4TM6XDTTrcMGNe2BHK7XMWMCZ9KoXbW4MPw86dmmsgjRBNTv62AA7HvEhGH7CnjJYCxfj2KJ52nC3UZrfLW8qSzbCzuFNJThCc2fx6vbhpBSSoMKVnxTEwEvpbU"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: kunxian#8711   8 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci84ZhxVMZkZkFKNpi5VvSnNo7sm6LyaPqTdh16g478yeDigjdzAVmw15vm5obgxCy3CHU13WX4Wt7VdyGHRsR4DvCP6CYD3FuHq8kAPWAamKLuVWvo6yfB7jJZYqZjBScnXp46wmbMz"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci2ggZBVKwj1UosYt7KRNW9GXbDHVM3U4GU8EUt2z5rGTsqnP3mtLAXTdQQcVzRW1nmEh2pnFQNg4MSoVPrYNTaBVqGX7QQJsiDS1z16G4pJPzkwKjeDpboH8vRMzeyGgvqjMSLQLPt5")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci2ggZBVKwj1UosYt7KRNW9GXbDHVM3U4GU8EUt2z5rGTsqnP3mtLAXTdQQcVzRW1nmEh2pnFQNg4MSoVPrYNTaBVqGX7QQJsiDS1z16G4pJPzkwKjeDpboH8vRMzeyGgvqjMSLQLPt5"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: masupilami#4665   9 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciMzHZnSeyuCV1fopXwLwrDZv63RZcorZ5kLy4jmzBNedudaKa77qEXEDaCS1m9BPxnM7CpJX8DorSEqnAitjm4qDNWNHbX7zd3Fd3EnMtjVtQeLgRTX5nyaxXq146PmSqcCHuAHtbp1"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci2pAN18umqQ3Q3MJJqt7vGrYZAFE2pnatBoiZ1HTtf45YQ1tANhiRz5DLvR6Gcou682g1UWE2aTAHn2EbBYRmpg8Av1Nm8dc95b4ZaWMLNHvvJYaieK6MZzBfhnaNYjouwauTNLqFcM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci2pAN18umqQ3Q3MJJqt7vGrYZAFE2pnatBoiZ1HTtf45YQ1tANhiRz5DLvR6Gcou682g1UWE2aTAHn2EbBYRmpg8Av1Nm8dc95b4ZaWMLNHvvJYaieK6MZzBfhnaNYjouwauTNLqFcM"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Alive29#9449   10 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcie4QP81eCZ4oHWFaXBUbTJTAEusBkakARrZwCT2aDFAW4xoY5MbX9BjqKB42JpchpzQduLKAxUsvGrWXxy84DPYCmCm1mSRZx9PRXSt3wQSRNn8pKXAsgRoozu8YueWEcJAFB3nDtLQ"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci3Rj5qVSz3Nud3PgUxfsubMeNtESCJUhvD925hJvtjhCYm5op2Tddp9BR7MZjqqttABQaDSvC5CajqYnPMv9BSwHyX1qtDNyjxpQTVthp2kk6cSoKf17B3EeEwXtNosehmeGwg9CJwH")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3Rj5qVSz3Nud3PgUxfsubMeNtESCJUhvD925hJvtjhCYm5op2Tddp9BR7MZjqqttABQaDSvC5CajqYnPMv9BSwHyX1qtDNyjxpQTVthp2kk6cSoKf17B3EeEwXtNosehmeGwg9CJwH"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: nelinam#2318   11 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBXRkR1C1NrFPy4Jetgvxv79TBxFnyEAVXBHZAYD2cqyQQ84MEf9M2DWYSyEdTqYtNht4f8MBenFMBNQ3YXcjBuUvc5gUqgBRnFzW5W6Du8uSeRcHmZrNeQn5QJT5S57SwBFQHdD1Zy"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci3qGNk3iMgvguwZaiscEYL9PmRcbcYL5ajWD1Y2VdvGGJ5WwdfCGuAMgSn7Mr7wiWyJ81XQsxZHqrC1TkuRqjgGmiXVZSDLtPA73FvLq3P9fjhN6L6jnwU3UHwgy2VtzMqEFU2EfVzx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3qGNk3iMgvguwZaiscEYL9PmRcbcYL5ajWD1Y2VdvGGJ5WwdfCGuAMgSn7Mr7wiWyJ81XQsxZHqrC1TkuRqjgGmiXVZSDLtPA73FvLq3P9fjhN6L6jnwU3UHwgy2VtzMqEFU2EfVzx"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Star.LI   12 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciSxoX9ZEwNNHjvP2LTCUvRe9waqgpGxjMNLM1uwvp2nctVFJRWwUxqZasYWsPjpEqUWLh9jo115iHsCQt9YQ75GCpeUxvNDYCaqYPGSZDzCH2ZP7LAVsZChaCaN1DgsxhAJmpRW94tt"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci4dpqGY9UsWrCNPJEua6FdGyk2KFqBC8ovC5EdGZ8gUiVQcKw8tdVEBma86yGiXY4gDFdwHJSJuCnzn4ZyH9CEuz8FoGnRgpzUj5UVjMR62GDB2UJNo1B5qC2gLZKK4bXRc9XU1wkqT")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4dpqGY9UsWrCNPJEua6FdGyk2KFqBC8ovC5EdGZ8gUiVQcKw8tdVEBma86yGiXY4gDFdwHJSJuCnzn4ZyH9CEuz8FoGnRgpzUj5UVjMR62GDB2UJNo1B5qC2gLZKK4bXRc9XU1wkqT"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: GregMas#3358   13 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBgpdge6637y9ZGBMKArAjSrJBTbW6ofXnfoyfZhjP7wwjgFADEJgAks5SYJLCbHgq78ZnJJiAGcW473epX82ChmSSTBKFwRdD7mGXw2K4KFBFscHFnR4hX5RLmFwkqThWBkYtU4fu5"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci66YXVbXh5bMcyvZ6BhAb7YVeFhQg1a2VdXY8EKuCHQ7jYqFZYjpF7QEfzW3CZytYTtXKgF9eV6fH4SpUanFboMZiz4BAtCoAx2f6DXjofruZTikvirpN8mNTVoyiNVVbuowLfN5Dh3")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci66YXVbXh5bMcyvZ6BhAb7YVeFhQg1a2VdXY8EKuCHQ7jYqFZYjpF7QEfzW3CZytYTtXKgF9eV6fH4SpUanFboMZiz4BAtCoAx2f6DXjofruZTikvirpN8mNTVoyiNVVbuowLfN5Dh3"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: blacksausage#6065   14 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciK8JUML1qjxzpJnBK2VMvi83WPR8wkJgcbjNZ9eaoLeGLF7eZWPZuf1yAGx4G61Fdxx38otJA6G91XHBhsQ2y8KRuQ2wtbmiswWSZKhi5YPVzqrqZhSbWu9ZYoVmQok5TcDy7Hj8nNe"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci7iuDyJDhv6ZYZLJbHjgEaU5h3s3nsKvJppxibw64St1nhXcjaJAvWmK4WPKHEKtqQiPw5giXsrimmfFDqaFuysWe8MXsNCsvdwb4bTQZQrCnNogjQGwZk7v9zxdcjUgQ5XPp8fUruj")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci7iuDyJDhv6ZYZLJbHjgEaU5h3s3nsKvJppxibw64St1nhXcjaJAvWmK4WPKHEKtqQiPw5giXsrimmfFDqaFuysWe8MXsNCsvdwb4bTQZQrCnNogjQGwZk7v9zxdcjUgQ5XPp8fUruj"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Vadim#5310   15 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciL6CGFZ8zeXqsAunVFAih6cPSAQJ6DoSpRa3ngnLbv2srznKPWcE19cnTfJ5XiYHwyHDnmyfuG2xgVo7efm28saWcg3Kvf1VgYvM7hbqDP3kHD9NWcF8HdwskCitoLpQbnajFBgvA2a"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8R29YXciQt24pgDQFMdG9KCW6bFEqpqWf95DeQL5fTKRHtsyLxW6r8wbXUHjmrBpCVtcP5iGa311vnHVkxVnEt7zrp6np9Ca8MGUchav5rimg5Sw1je6vJuWTFL81HmAVj8pPfHw4g")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci8R29YXciQt24pgDQFMdG9KCW6bFEqpqWf95DeQL5fTKRHtsyLxW6r8wbXUHjmrBpCVtcP5iGa311vnHVkxVnEt7zrp6np9Ca8MGUchav5rimg5Sw1je6vJuWTFL81HmAVj8pPfHw4g"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: ag#7745   16 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciaBZwjQMp4gGtHyMh9vAunoLm2aWikXCJPZZz8mMVS3VBj5a1HsBoza3mZw3y3jDNa8utRrCXUpkxoTRsZvEAi4GR9g9jwfDuUeG2dPxFJzVsgVR4rwWiYCqtQE5jmGMxfvqTto1ED9"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci94fKqmM6m7riLhUVc7XaAdYjRZ5YQmC1ZcYtzo6UzYVed4jc6bWzWnQuKcKDy8GumF9U4auf3pHtY1STt3X1pcKoQ8edDhnLH6Yceg3aaG8zRfXemB1UaiZhbCWZri6YhgwnHQrVNw")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci94fKqmM6m7riLhUVc7XaAdYjRZ5YQmC1ZcYtzo6UzYVed4jc6bWzWnQuKcKDy8GumF9U4auf3pHtY1STt3X1pcKoQ8edDhnLH6Yceg3aaG8zRfXemB1UaiZhbCWZri6YhgwnHQrVNw"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Connor Di#2159   17 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciFU6mnVsCV7tnWT6RvncZhP7C2GaBo6RmwUsUVJrqa2rHcXg9J8ef3TZcwSDLLe9n5CNCA46Jp4AnBcy88atRh7EU1L1gkJp8oj3NQke9e671zXPyWq5fSwUmrKbkL9okiL2tpszr7U"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9ViV7ieBUu73BSGmFp8z6QdqvF3jpAy6sGJ8eCkk9TCeFBKSgUvTxZbdjELuSH2jUWzWUyhr35u1sWQc3HuiY56tJGUdXXM8tqTw3ZiSrHBCfLsn6oXDvyTPEfP3tZuD7gDArb8Ytj")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9ViV7ieBUu73BSGmFp8z6QdqvF3jpAy6sGJ8eCkk9TCeFBKSgUvTxZbdjELuSH2jUWzWUyhr35u1sWQc3HuiY56tJGUdXXM8tqTw3ZiSrHBCfLsn6oXDvyTPEfP3tZuD7gDArb8Ytj"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Codonyat#0002   18 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciTy1Ks6BoBVoj5jgx4cqhB4j6kTn7UX3y9sVM3HMGasHNoqkE2LnQgKAdxPJsCEvBYRv9pfue3JSzTBdNxnLkS1z7SFthzQi9VUPcD73H1A5FJ8K9DZFid4unsR6usxrJRKquQKibY8"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9bk98Z8c68PcRkZGTvAmkTU4ACZX4JcWNAr6Wd84MyKPjuMaF7mRocxJKMZ7Az7EddLq3WqU1ZVCYEopWppkBZwH1EZ6FPfRWHDKQ62dZw6hW5hUAS7sgXvy95WfrL3xoWVthF8DYh")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9bk98Z8c68PcRkZGTvAmkTU4ACZX4JcWNAr6Wd84MyKPjuMaF7mRocxJKMZ7Az7EddLq3WqU1ZVCYEopWppkBZwH1EZ6FPfRWHDKQ62dZw6hW5hUAS7sgXvy95WfrL3xoWVthF8DYh"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: garethtdavies#4963   19 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci8DTLwyaoQSiqREtKjHaopKKgGxVvvS8no5csGm6o2nkXXumnUHYVNT5gnhiALZpMHqVfXz5Zg3Mbmja2KBtJkJ39FesmrXBZuELiHQdBBdbURjXEZURoSSK3fa4WpQg2hyj1UWiDDh"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciBBcEcajd4AFCAiSLWvwg9X3fCUT57X5h9UhVuDhh3UrZ26nxCeVEzjFCN6uVhy2CFSqUjWqGsZ2yQno64nqE6SWPbqVr1WX2JiBQ23mBCmtkViPxCQUdq2EJZPyMDx6tWbazW2xgYo")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBBcEcajd4AFCAiSLWvwg9X3fCUT57X5h9UhVuDhh3UrZ26nxCeVEzjFCN6uVhy2CFSqUjWqGsZ2yQno64nqE6SWPbqVr1WX2JiBQ23mBCmtkViPxCQUdq2EJZPyMDx6tWbazW2xgYo"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: OranG3   20 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci8z3h1J2qoUz1er88k4fKwuUUjBdiJRviaSiz2A6YB8HHEPDeaPsNomNgsNjzjrwypSDe699QHSipyhyvgxqrrkVUCp3yigmAhekZMg8LkYTC4Zc7ZpC94k6A5AvthiNN4a4orkNetE"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciBNjgL24UDGk6PfqB49S5sZmkPrmzxKjJchk9XAiFrd9TWxpyFSsxEVpXeVTfAkfYXndZU97512YpYbJXKVp5TTcXjKen3f1MZQrjW63MhrP4L3cGq9yYv9b7uEs2wDfPq7j83zmY2e")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBNjgL24UDGk6PfqB49S5sZmkPrmzxKjJchk9XAiFrd9TWxpyFSsxEVpXeVTfAkfYXndZU97512YpYbJXKVp5TTcXjKen3f1MZQrjW63MhrP4L3cGq9yYv9b7uEs2wDfPq7j83zmY2e"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Ilya | Genesis Lab#6248   21 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAp25cKbbdJiSWFWW1b5A8AGhfiVz63UFdBkSqNDn6Ehugsq9Aq3p28uvCt4KKm1zGbePRjCmBjT3BoJLZk4HXTqvNQg9wr6Pxys4CpAA3wPStQnSaYMpkTcVeUUNiMvMYDRMbtK5fj"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciBmRsk1JiErGuurp5bHUKhahh5Yaca5WEUnVh8HVGeExtSvSbB7rASzDDrAubB43CyUSQWhzy6sZgZeEhVWdTGsD2RYJBJpknztjDfXSBM1N5NHn57sTW4sdQwc8ZuB7LtzDTrLqYN9")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBmRsk1JiErGuurp5bHUKhahh5Yaca5WEUnVh8HVGeExtSvSbB7rASzDDrAubB43CyUSQWhzy6sZgZeEhVWdTGsD2RYJBJpknztjDfXSBM1N5NHn57sTW4sdQwc8ZuB7LtzDTrLqYN9"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: TylerTY#0202   22 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJmtQt5t4fJLextYEYdw11ed3FfLo2ESj6q1pFJrwmV7bNRztuwaS7N8HCTgd3Jwtw3PQmKHgJgeY5B6z3yPuAsi77AvZwUSJUNN3evQKGrAfymp5LMWqKaHkEyxmUd7G2oFErjtFMx"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciC4yPCG7VCrJhtnik81np3FA8hhHei2LdJ93Yux5GC1FKmdK5UsGASYqkgfBg5SjQKPamE9iPpBw84p3F542HPN4TjQGa1gsewxdXv7XDfbXN8K8z98UmPD7pbLxqHu9K22y6BpTqxu")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciC4yPCG7VCrJhtnik81np3FA8hhHei2LdJ93Yux5GC1FKmdK5UsGASYqkgfBg5SjQKPamE9iPpBw84p3F542HPN4TjQGa1gsewxdXv7XDfbXN8K8z98UmPD7pbLxqHu9K22y6BpTqxu"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Vovan#6835   23 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihxMA7PAfxUN3ceQYioZ7vbQcsoQ6QBkb2guGpYZcr6iDA9v8PrnvVSzzC6rtu8SJTVXdVsy2rECJB6VUbGdbHxbivA8oGJbQSj6TE5gqcRCqXnaCDpzZQJxdRNm2qxGXwVJdETP8FP"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciCS4K5fytmzDBv3j7QAn5JgDyaZNn6Y7aMT3eQgh2uXsSVQHrL1Lg4Mp5zcXXXWqBK8X4UFidVxuaycU1WZV1gvFgex6w7N8oNffvHjUHFhNdSVyRrGo425JLt1EAaEEqNMYouDB1yx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciCS4K5fytmzDBv3j7QAn5JgDyaZNn6Y7aMT3eQgh2uXsSVQHrL1Lg4Mp5zcXXXWqBK8X4UFidVxuaycU1WZV1gvFgex6w7N8oNffvHjUHFhNdSVyRrGo425JLt1EAaEEqNMYouDB1yx"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Alexander#4542   24 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci5WWF1aXSYPZzBkD9oqjS5nbj2jD29CjWfhxTtNWHtCxBFY69CuePfZ4rv7WxBXu3TVMryLjW9e7ZmajysL6iz3MypSchoZVR9oCvf6DwJwaxUqoQhF2h6yS85yPCU1rkm9HTYuDfY7"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciCpHoXJRiWYSsx4HZzMNJxRYmHt5yLJbF5fa6Yv9fR1m99a9KfgEgaFmtSkhbJ3eq2NzwdeHMAafGCAYjeKQ8tLoF34e3vPhtW9nYiEqJUJuZEsPZE9RRQWqyPuMPFSZdeqdj5dut5H")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciCpHoXJRiWYSsx4HZzMNJxRYmHt5yLJbF5fa6Yv9fR1m99a9KfgEgaFmtSkhbJ3eq2NzwdeHMAafGCAYjeKQ8tLoF34e3vPhtW9nYiEqJUJuZEsPZE9RRQWqyPuMPFSZdeqdj5dut5H"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: romantoz#6819   25 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcig578BBUzN5K7DPjEFf53qmPAiPPWULseqXGcv9YjAv18m3PRWgD5iCusbxnrGxjCSPHHAaZppy941gtx54imj1EcgwF7eVoLKsAUdV66GyRXjsc7RcFMc8ykzDFoRgQ2Qv5zkcgxdX"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciEkJqE2UDfVgbWDynNXuA8eXLuSWJs5CGc5Nk6giUvoQQdny7wZaBRyWpZpaBMFXHzG6iiSuwUwVjF1tFfv5GdDvRA4uEwsKzAkGy9Lb25TsiDTTzKeFAgGBZB7LNnQ22Zg4QxYSuxm")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciEkJqE2UDfVgbWDynNXuA8eXLuSWJs5CGc5Nk6giUvoQQdny7wZaBRyWpZpaBMFXHzG6iiSuwUwVjF1tFfv5GdDvRA4uEwsKzAkGy9Lb25TsiDTTzKeFAgGBZB7LNnQ22Zg4QxYSuxm"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: aynelis#8284   26 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci8g9C8HG2H6NMefwpCjXoAjGqELQZM4yPWSDPUWZfuWoTeed2nQL3osy7kStKyBEd47AUkths6b41R98M3CrEiuESpkv2de1KbX5YQULXqLcFVoURwjL55GZ66cHX3CD1SG6gimWCu5"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciF77ppqGax1muPJjj3qi8hCRghumaYGaD9gaMkfcZ6wowhW5ynj4iZsmp757GpzMM7cxkR9ChyMUeM2YBKMtpjpJkbXKYScjZPCzZgXDU2YJpqiuZ9iXJ4zRqvVS7h2UJNFBtApU6d7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciF77ppqGax1muPJjj3qi8hCRghumaYGaD9gaMkfcZ6wowhW5ynj4iZsmp757GpzMM7cxkR9ChyMUeM2YBKMtpjpJkbXKYScjZPCzZgXDU2YJpqiuZ9iXJ4zRqvVS7h2UJNFBtApU6d7"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: LaurenceKirk   27 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXmkQy6yXHXB7Ft2qhM68smxi2NHumGzr656Bwss8ykbeF6M4myjTYhYzm6Ry3Fe8kq6iMVKftvMe7pxdUDxZsPgVYE1g4UoxrNMpLvajWbwvqNtstjx6nTmx3NV3LHXZuMFCgkrDRZ"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciFwEQoGCrAUfytvN3kbDdLn3ueL1S4boHaP1rpb3ydurewsYA1WYoQXmRWAcZRjy2VV9gChawHCgANiyidqiGVkGYL6vwDKHwcABEGUiJcbB4LG3PcbLM7thZyiMfAz2Rt2A77pPkNm")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciFwEQoGCrAUfytvN3kbDdLn3ueL1S4boHaP1rpb3ydurewsYA1WYoQXmRWAcZRjy2VV9gChawHCgANiyidqiGVkGYL6vwDKHwcABEGUiJcbB4LG3PcbLM7thZyiMfAz2Rt2A77pPkNm"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: mamio#6303   28 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYtHF3GUXrGtqL1Y94EGqXsQYMUAKkk2jk7KAHnyKtZuj3D64Y86VpY72H15oLe1TkLuwixTGEexWs9Ap1mss3nfxFQvtxrPs3qRKJcr21hZnV28yHugzPYJugtfWf1AemJyYQDgXbH"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciFwvpwzMVPJDgcZuGDgWLrxHxsEtfNMB1jWhFJL7YRd3baqyDVepnHqVMUcnrmcET44SdoFcaWwGS3zDQ5A1hGreYffWxL6DW4t92f6uW2URbZE8qdy4BTamkG4qqCzhNjEs5evPbD4")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciFwvpwzMVPJDgcZuGDgWLrxHxsEtfNMB1jWhFJL7YRd3baqyDVepnHqVMUcnrmcET44SdoFcaWwGS3zDQ5A1hGreYffWxL6DW4t92f6uW2URbZE8qdy4BTamkG4qqCzhNjEs5evPbD4"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Chester123#9126   29 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXmGJJp3eRRXwYJYwQshzpQHeWj9EVT3WQYEMWyUP7Js6SbCFSaMZx8YXhZ9bbVj3xjCDEpuR855c3EoPr8MPaRgwFMGubtRSMjU9cW67mRsXPkpyra8AKP2xGyGVKXchvBjSBJTSJs"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciGfaEEdEkMpENBzevtcsuNPkPd9bRkebsLa7t63qafMYu7k7CSeqz6C5XmmjoQtPKsTR25ZUmwBBz79mjAYAMMxszSmhc41o2cv5fHfjKfdr2khrkN5vtVeLUkF9qzycT9s13zqBNBL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciGfaEEdEkMpENBzevtcsuNPkPd9bRkebsLa7t63qafMYu7k7CSeqz6C5XmmjoQtPKsTR25ZUmwBBz79mjAYAMMxszSmhc41o2cv5fHfjKfdr2khrkN5vtVeLUkF9qzycT9s13zqBNBL"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: hulio   30 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUtKZCWKNi9EhVThjzSePq5GoagjUUvVZJ4Bo1C9sDufStUJ1s4XRrojrQuriGcqtdGx93gk7VASNXnN2gbrRWGci25qGShcrvez2dcErKiE2HiEHvbzpFfVjuu39KPq29SdtX7htV8"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciHsy63h3MFgz1GwHuippdzZAJyrf958dxHhRCAUGRAon9Rb6rrX2xBygjG5ss8cKARpkD2xEhJWJzh3vkyMS9QU1o3dEMmRas1D5Pum6N24ffnznPuXNk8eG42c4VvxYxWB4xjSLJmB")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHsy63h3MFgz1GwHuippdzZAJyrf958dxHhRCAUGRAon9Rb6rrX2xBygjG5ss8cKARpkD2xEhJWJzh3vkyMS9QU1o3dEMmRas1D5Pum6N24ffnznPuXNk8eG42c4VvxYxWB4xjSLJmB"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Agulbek#8218   31 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihjWYAB6jrDv9bPcphwtG1upo8zmjSdt12NfcXzPyeWuchaDjy6XQZTHp5EDjgKh9ShuXouiLoLNe5vgHmcGmYuqEywTs12PNPuK38kfjyK8FTH6ER8LEWe1XVx6dDZte1FUM5DPCVT"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKViQguhg2A9D9SLeNvjB3aUjfFEaVuTX3Y3ZPSF3WZtSJ1HtMgdriZBzppCD4g95u8Nw6oCvne56qtkcc6K8eYrm5REWqKbGsRSoYToy6TyCp7aeyjNrsiE4PzPMVRAkcgYoNWP7Ea")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKViQguhg2A9D9SLeNvjB3aUjfFEaVuTX3Y3ZPSF3WZtSJ1HtMgdriZBzppCD4g95u8Nw6oCvne56qtkcc6K8eYrm5REWqKbGsRSoYToy6TyCp7aeyjNrsiE4PzPMVRAkcgYoNWP7Ea"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Stateb#7862   32 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci41Yf14H2TnnrcxsuZg23MSphBwZ5ro1vcJHoeFJQbMtcF8ZuEZpocxuX9JAi4R5V1iwf23cRcMDGJFSdDoeo3p18aSz2EZqbMmR6qaqT4msiuy5pmYTpLxiwN5eweaitM88uZgxYfm"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciKf7FzWUwWXN1FVzHapvbPyGUG9qDthXKLnzHRCWzJ2dqrSdi2yTPPo6QwSfXpkMaZ1xvgLqarjhh8xQTQUduvew2x94i6xS2E5YipmHQ7KRQGNiAS1eBmNdaUUktdhYyYVRiM52mvW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKf7FzWUwWXN1FVzHapvbPyGUG9qDthXKLnzHRCWzJ2dqrSdi2yTPPo6QwSfXpkMaZ1xvgLqarjhh8xQTQUduvew2x94i6xS2E5YipmHQ7KRQGNiAS1eBmNdaUUktdhYyYVRiM52mvW"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Q.Margo#8900   33 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcia4x9VPfkHG97znZai6aFAzfz5VAgExqejwdjX4PhYLZfT4aLfwkAeE7fCoRsFspSKUzMXZxZ7E8UaBqUpiW7KwcoZ8KYzYbBzDxgVMDoCsym6MYnKT9BtfVEW5kopre22YRbLaoCMf"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciN3JM45idr84C8bjKXJXbWCQXWRSuDYq2ZZg6HbtT1g6dgvwBScPc8WL26VdfWzf7okUgaFktd63KtP2zM7X7pRgNDhBXHaEseUJ18NSqzuVdgtv1X5YBJivS8i2masYzaUszVdjfzJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciN3JM45idr84C8bjKXJXbWCQXWRSuDYq2ZZg6HbtT1g6dgvwBScPc8WL26VdfWzf7okUgaFktd63KtP2zM7X7pRgNDhBXHaEseUJ18NSqzuVdgtv1X5YBJivS8i2masYzaUszVdjfzJ"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: PetrG#3328   34 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifbmfeqnED4prAbPrHGFczw6CZ3BeBuiVfUpHNSF7fTGvT3CT9bWy5WB1v6VVkxRZuszYP7SDbArV3kYdLxgtWHFsCbJUzvQNqbVrdvSn5LUPQ3Zfx6qr1JWDKCWvRcMJSBA5kkrZig"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciNB9392r2f36EgyqACw3aED1HYu4sJQNQnws1dTPiaPofmfW35jVqqtwLMEEFYrG4J6HF1wFxgpmfJ6cYf6YKcy4vfeyhinSTS34ZcAWDF8pFVh9keW1qEGvg9V9b69x38YMUVThCX7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciNB9392r2f36EgyqACw3aED1HYu4sJQNQnws1dTPiaPofmfW35jVqqtwLMEEFYrG4J6HF1wFxgpmfJ6cYf6YKcy4vfeyhinSTS34ZcAWDF8pFVh9keW1qEGvg9V9b69x38YMUVThCX7"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: ansonlau3#9535   35 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKo2iNF5GKaN8ebbNRNYsZmVAfvTzfwD9uGH5D93EUzXWEzkkGx18dbjarFFszNHW8zs3U2G8j8tiiZheRSP1uLChL9DSuRhqYhqUqUxxNzovmXiHgmUWgUiaeXuwqrCHW9E3HccKVn"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciNsTaDKWqZFTDkiYNDK6U942iWRRX8FamMvhArgqQzkVMeLvRAt7DCNtJZcZuT4A5wGYtXbjQCedF4yh3JWbM2WEY8CwKribgnjRSbNjX6Hk6K5JxmnrbTyQm8iKtCA7UNxNkiaqawA")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciNsTaDKWqZFTDkiYNDK6U942iWRRX8FamMvhArgqQzkVMeLvRAt7DCNtJZcZuT4A5wGYtXbjQCedF4yh3JWbM2WEY8CwKribgnjRSbNjX6Hk6K5JxmnrbTyQm8iKtCA7UNxNkiaqawA"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: windows#4629   36 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifE7aU15n8qhTCmgE2Gt3iixHXQ6eRGRbA4yG2SiJAbvxaCe3swzfsHrHP9qXyDidPMVQDdi6nzgBCnXBNpUQT1GiKHj6TNWR5fiC2vFmTjcsGU1Wo1ZfCzWk9XhgoDN6fBQLNKoWF1"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciP3S9u596zcmc6Mm2hT3AXXNt2HisaEzkHjrwGXhADYCZaqgRxxw4DUtUx4VtQahxeMEZHN3a2RYmCxHiArNSPSFmq5ooYAhZh3U2dpEn7zK214ycJee1YnoaugMrGcy5TXc3YxA42d")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciP3S9u596zcmc6Mm2hT3AXXNt2HisaEzkHjrwGXhADYCZaqgRxxw4DUtUx4VtQahxeMEZHN3a2RYmCxHiArNSPSFmq5ooYAhZh3U2dpEn7zK214ycJee1YnoaugMrGcy5TXc3YxA42d"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Dmitry D#9033   37 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciML9R6V8zLvQKmr3DaH6c3y1SutJEw2LWNk4pXxifcBuHkMK1i3zeZji5rvzyE3kva1iZzT5z6uMcAtV4NgDnDhcNd2NPYBP4MvVvCxABm5fM5F7ChdJ6cekkk2LZhUcAZZNQfBUgp2"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciPt5taz5rze7dF6TZSMUYtWzwoLKRfQxgCi8tT35HGsama9dmGqAZXNonv8m8dnbRe56H9zT63kVBSxTHjbeU5egZcqTFMpsCbCvV6sbMq44X45eguHSWhPtFodqfR7fPWXSLqFFBku")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciPt5taz5rze7dF6TZSMUYtWzwoLKRfQxgCi8tT35HGsama9dmGqAZXNonv8m8dnbRe56H9zT63kVBSxTHjbeU5egZcqTFMpsCbCvV6sbMq44X45eguHSWhPtFodqfR7fPWXSLqFFBku"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Prague   38 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcim6zKLGfqGxXdnthiMhBGaCP62jJ9gT8w4RGw2vtSY6fTz8CYNcVEwNm473bjqBAeg2BFpcBEJnUM3agx6PKpR69Xb2faCPh7umGoQCNLDwMewKb88XFcxtrFcf4S16VfcDazbGfUrn"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciQ5nHMgNrzAWTkZx8Nc6fZVGTJ9xg9HEqGVE4SDoBXafsMAqbw5gU2Fx8Eq1ZNAD3YyxqqtsYdbrTm3kbMG3kGfX1D6WuQM4ZoeNDU6bHcMGF9MT9aM3d9HXWbFNf6XFtGAPBTJ8PHF")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQ5nHMgNrzAWTkZx8Nc6fZVGTJ9xg9HEqGVE4SDoBXafsMAqbw5gU2Fx8Eq1ZNAD3YyxqqtsYdbrTm3kbMG3kGfX1D6WuQM4ZoeNDU6bHcMGF9MT9aM3d9HXWbFNf6XFtGAPBTJ8PHF"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Hunterr84#7710   39 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3xvyqbf6P7DQDoXnGzhfHL8DSVPALjnvfCUt9ie9Xbzem3HSfWPzSSirGoL9pqWRCcYKxqdw9eTxZd5T3NnL6W4WN4eijcRtLztSz1nHCLeoFiBwubgUAzzagTEXWNVcV7xv8fuBeg"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciQFukA6prhQisFLk8Xyp3tsW5b78vZzAThNNTzeWdbiNUVMpxtmhXf38pxTQ37f3wS3a9Wzx2ComAGykicpXTFd5fZoz3iadnWB5kJZ2saDZ1PRMxVctdx52sJahksWAB9KtMU2ggTG")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQFukA6prhQisFLk8Xyp3tsW5b78vZzAThNNTzeWdbiNUVMpxtmhXf38pxTQ37f3wS3a9Wzx2ComAGykicpXTFd5fZoz3iadnWB5kJZ2saDZ1PRMxVctdx52sJahksWAB9KtMU2ggTG"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Gordon Freeman#4502   40 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciGttZEd5EEAiTHP892S5ziM1JxPznwLmstkNaYRADgpKhNJzYgcJUbmw2ejM4jGjbZ1GXZr2K9NZzoqXYK8XWm2GYhR1eYxzTBnnuNEuSZpqLD9nmY7FLjfMD9sx3r8ecjip53GMWfH"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciQrhuigw64wbjDZZ9nvhZJAbfemYTgUnukY8aCmtjmuUomxDxteHEgtLaXVSNQaf127ShEYCMrxWS4zxNnRye9orRnoyPoXJUhzv5PiMRn5W2SvhUx4krm9zsw62Z9v958qnko9Awpx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQrhuigw64wbjDZZ9nvhZJAbfemYTgUnukY8aCmtjmuUomxDxteHEgtLaXVSNQaf127ShEYCMrxWS4zxNnRye9orRnoyPoXJUhzv5PiMRn5W2SvhUx4krm9zsw62Z9v958qnko9Awpx"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: TipaZloy#4890   41 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciZSwa1q2euDDa8mREyoXyriX6uyPueuNpMQW7a4mDYny5V6tYcHD9oeuVZahVnx5hW533U7LqadEv4YoJ2NnpqNxzshX9zxCcAkC8acPJA9RzJejxrUZVfyimDKsUDv4qzuVM6fuPyz"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciRGY5DkKoeAbMWscZfJF9ZvJZHqEbharXjFuck43gKZkENsD2svkzKBp3ZrvGcoeVC4VDKt1Wp3vkrLXjsP7vTavnaseeRh5QeptFLiijzk7mGgFkgZi7ns53brN7Bk91WmyYPhBUDA")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciRGY5DkKoeAbMWscZfJF9ZvJZHqEbharXjFuck43gKZkENsD2svkzKBp3ZrvGcoeVC4VDKt1Wp3vkrLXjsP7vTavnaseeRh5QeptFLiijzk7mGgFkgZi7ns53brN7Bk91WmyYPhBUDA"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Kitfrag#0272   42 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci7FNA7NmP6VsQHfyd3LgYH8UmPTp2E39HgGftYdnUaU6EQh8nkKEeUZvihprS1FvZbqGJ31XKCmiZvd6kahz5Lz47tujGcLdj5FYuDmYFN671WX2wp8eV1TFopGz8xaajtVRrVoqY15"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciSsa6QA8sREh6vumV3incy6x7iCXixVBYGxwxZCt1WHKFACf5FurfThp9drF1KJDgdtdu6Mo4ecxKD4gnepuFXeZGJ3VNSfHdkw5pdFCvCWniezEMTwtqgbuvyjnDzseKabkj2wfoVM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciSsa6QA8sREh6vumV3incy6x7iCXixVBYGxwxZCt1WHKFACf5FurfThp9drF1KJDgdtdu6Mo4ecxKD4gnepuFXeZGJ3VNSfHdkw5pdFCvCWniezEMTwtqgbuvyjnDzseKabkj2wfoVM"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: GRom81#5825   43 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcieB8Su9zs2cLMY8Ey89bd69k3CprkB59EasbqzVmqz6nXE3CVgVqTchc7rpJr8vbh65sk8kY3TKB2AXsWN5qDzZaJaADivAhQU3bu9PW7rpUKho7wUnv2Kxn98JeozHAtuti7CQNq81"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciTfLMxjUt9sqKSfHFhMRjff3qUm7b4uDXxhkdGQbCNGF85TM7a4NDH2s8LqLZtgUCpNvam7iGu3sKnJXfYxFnpyjNPueww5Q4swM4uHsMmMPwTmRcyVoPk1M5cmgjxtBF2QxERWih8P")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciTfLMxjUt9sqKSfHFhMRjff3qUm7b4uDXxhkdGQbCNGF85TM7a4NDH2s8LqLZtgUCpNvam7iGu3sKnJXfYxFnpyjNPueww5Q4swM4uHsMmMPwTmRcyVoPk1M5cmgjxtBF2QxERWih8P"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: ttt#1591   44 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciLhfhnf9Z6NKKaWqQdKoYJpGy2JRAbzQH3Tu2o7pz9uVL1pMVXTB45CqobiHHEVPQA6NSGoPwVwQEHe3dXkZV1PgTVabYAuX1KRXngaXWojbp6WA41Q1GFyjKGku8hfc9ErkK4WzLVD"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciUJbzpyufFsDxqyU6qnefMRYuem2dWXF4eEYaRW9UEnHzg4ekugrTcD4trgTkgiLj74bjbYGVgnEeqrsVrMLf3ePQ3Lp36bXYnoMKmZMk4y18HmoW5RLf4BXnobrPNmBSJgtFehSZc6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUJbzpyufFsDxqyU6qnefMRYuem2dWXF4eEYaRW9UEnHzg4ekugrTcD4trgTkgiLj74bjbYGVgnEeqrsVrMLf3ePQ3Lp36bXYnoMKmZMk4y18HmoW5RLf4BXnobrPNmBSJgtFehSZc6"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Ravil#6286   45 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXtKxVgXftK6yPRvhFPjtynC8J81b4zJWLgKVh64WfDnCg44WwEH2BBTvDNK3CgxFUTkVYje2U5waUm1nNLngTiEshuJARWK2sB47uJaxRLJpKJ6FVMa3oAy172mKexsA7He9cykcGz"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciUoHEKPAyPrRYHoZzqx1s9X7746TXwFXryeZBn8LcWtnq3sZgwKetAuNqGGkmfgd1AUuVoYeYcmuK1YDpYcUKDvVYgZgqjWhky6uHKFzC2ddLmF9ZMLZRa1j7WoU7tLSvu5jmmXUF1Y")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUoHEKPAyPrRYHoZzqx1s9X7746TXwFXryeZBn8LcWtnq3sZgwKetAuNqGGkmfgd1AUuVoYeYcmuK1YDpYcUKDvVYgZgqjWhky6uHKFzC2ddLmF9ZMLZRa1j7WoU7tLSvu5jmmXUF1Y"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: DontPanicBurns#7712   46 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3yne3QZ8gcphVTidoEwti7KqG36bfWgkygWuWPYp3ZciyKieef5GAE9i4UcUVnZgF8BG4WJQ59su78GdPmKdy2UzP7S6m58wQdJruzZum2nhhYqo66Vcbctoun2yWKmrtDq1pTUV5x"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciVP9vRYnWTbBYqMAEz15jtioq4YfSNVwhQP6mmywETQdudJacWfyXHNnKTRY4UhhShFGZzg3ZAJHbgqcsi6DKPRDpVexSuPnF24V8LrEjE1YBPsn3L8D5fyx11ZhE5zpLW18jbsVmoi")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciVP9vRYnWTbBYqMAEz15jtioq4YfSNVwhQP6mmywETQdudJacWfyXHNnKTRY4UhhShFGZzg3ZAJHbgqcsi6DKPRDpVexSuPnF24V8LrEjE1YBPsn3L8D5fyx11ZhE5zpLW18jbsVmoi"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: novy   47 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciPHXTWpvxQFz8fyTwktu5ncBVM6xvhDt9brbXzDaifYApDXwcqKfHPLxUUqJGTFara2L2GmDnDZfjE3c8K8jJ8NmxFbdU5KYncdS6F2LXK932jLEcY4D959W6wQANGon6HsVvLdqpX8"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciVRxhXhJq78LFxg8acp7VwVSXtJMsQgyyASr9q9vXMcJ4whwawrtz1TZyH8TXHyy68cPatDR5xRn5G2o7cm8kWYMbooPaTVpte2vYsd7pqFDAJ6QAYTD8Ro1FPmzQdvCZHdhdMfdZqi")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciVRxhXhJq78LFxg8acp7VwVSXtJMsQgyyASr9q9vXMcJ4whwawrtz1TZyH8TXHyy68cPatDR5xRn5G2o7cm8kWYMbooPaTVpte2vYsd7pqFDAJ6QAYTD8Ro1FPmzQdvCZHdhdMfdZqi"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: ilya_petrov#5431   48 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciagwsFG7qqattt83RSoeZGZyX4dkfy3d8dAVo2giZi11R554gUNZdByScPMiYjx9bP9UVCBoNrtK4pnzbP1q6Qv3bqFrhz5JFx7ixFFfRT9CLmPyfcEgojoxVuF8EnHYc9M94eEyVkn"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciVbLmBb3kkZggRNUstqMeYKBEVikXtnVufMpEXJkv1hhVj2dfmk3owUraN3xfwk6foz8aJXRsrK6NsiqLNFS3uMBNwnD7uNgou9KqFHvhNNrHLf8MiERTxgubS7SvYpwyV6gNXDTrpx")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciVbLmBb3kkZggRNUstqMeYKBEVikXtnVufMpEXJkv1hhVj2dfmk3owUraN3xfwk6foz8aJXRsrK6NsiqLNFS3uMBNwnD7uNgou9KqFHvhNNrHLf8MiERTxgubS7SvYpwyV6gNXDTrpx"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: y3v63n#0177   49 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJYCZR2bZG2VZ4pnbwzFqtYY15jzmxqnPYaGTuoN3rkxNGXW2SaWz2SJvxmaQF2fVCtNwZrrKskNx7BmuoPxDPW9U57P9Vbn4Unnh85ZT3f3mmPiybrw7Bxu7AoPDqT3oBpbd57i3gW"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciW2rBoTssVzvrwEc6CkRHCZznKP94ZfAPvZP3pmAjhGBofjvZiom22pBjFNWoVJA8PAUcyYdStZHnvYYd3qyVqobzWiBFib7zTkrnRSGR7yyW5rr13JSZjhSgSL3hk8focXn2mhp2HS")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciW2rBoTssVzvrwEc6CkRHCZznKP94ZfAPvZP3pmAjhGBofjvZiom22pBjFNWoVJA8PAUcyYdStZHnvYYd3qyVqobzWiBFib7zTkrnRSGR7yyW5rr13JSZjhSgSL3hk8focXn2mhp2HS"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: niuniu#9001   50 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci2aqFMr25KjZgTp2nEwGiKB1wE6cUwEB7WiaoRKrihSwBZMnxr1ZukYVm2oF3aSmDyM6NLMeGmhTPsRfjGJEEMu96PyHjPW89EVycUa4oQHKB1vQejruT9VvA8YF1rZK2qwp7rtZRov"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciWKYWy8cCkPW2H3L8cRpopd8qzBp1tGbni31BEbAKEnPqp4WTRCZHZ1LsfNAJbsv95Tam1retzxPPQ4wH2tBJ6fSTX9QcD7URQbrcQkexe9LY7jTyjDXzJef6GxnCpWux3FEwkyk1fT")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWKYWy8cCkPW2H3L8cRpopd8qzBp1tGbni31BEbAKEnPqp4WTRCZHZ1LsfNAJbsv95Tam1retzxPPQ4wH2tBJ6fSTX9QcD7URQbrcQkexe9LY7jTyjDXzJef6GxnCpWux3FEwkyk1fT"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Gavin Cox#6341   51 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcikwchuiUi7GCzRG9YuwAz1AGMgmKjtWZdC4cihChVSTe51LTM2oRud9En67fsUNGey7i8ZaR9uwm2tjbyrkLWtwKxK3aK5msjjByZMMvewrgKvse6Kt167dmtYXck7otdygEA4T6sE1"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciWh4QiBS5cBbforNv1pGzT5Fs3bWhYzXzBL9fyDxSGBg6JwGQpz98LBgSA12wJjpCoH1Xa8MNvnFmX3Vti5k9Ex3ZAZWvPb81bbJ18acxHTB2NT9c3weqmnxGue3eQupS7RX4cdSwYQ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWh4QiBS5cBbforNv1pGzT5Fs3bWhYzXzBL9fyDxSGBg6JwGQpz98LBgSA12wJjpCoH1Xa8MNvnFmX3Vti5k9Ex3ZAZWvPb81bbJ18acxHTB2NT9c3weqmnxGue3eQupS7RX4cdSwYQ"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: GS   52 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcii3MYZoyaHZ6QPE3zKvU4chaLvkQSd9ZEFGJ1RUShD1Dx85wkdvojqZwJ4KZrjtLo6VxWicTNqVqH6bCRxK3J1z2QsTaW28jYcAJFu34sY5YRQ5jyJyCDHVH6rtXwo2FnMaErszsNwL"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciYjrq2YuX6Msb5s1QxUHDMdJgXKrsSQybG9tPzf6efzfARe5C9QYtxaqShy8THYXNx5XYUwED9citmKe8dM13PCbkbtz6Ydn4NB9rcX3V8syw7vsGkcfBLdF7HQmuUacK5srpFr1Hsg")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYjrq2YuX6Msb5s1QxUHDMdJgXKrsSQybG9tPzf6efzfARe5C9QYtxaqShy8THYXNx5XYUwED9citmKe8dM13PCbkbtz6Ydn4NB9rcX3V8syw7vsGkcfBLdF7HQmuUacK5srpFr1Hsg"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Matt Harrop / Figment Network   53 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciKFwpeTcLiLQMB1CR1MrxJtvzBXZS77Aek2kDd5sQeD1dHNgK7pf8vLN6PCFinapLFk8tRdZo3FBGNoQ5WVDjh3vcY9sK6cSoLmfz6NbC2JedTCst8Kq5cgHaDH52xeRNn45tSRZSxX"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciaKqn2vMY7JA66AHEP1bupBcsnPYeFM58SorCWL78pGoVKrM9r7j968a9BaqmEqH2hx8UCCURy8op27HFE9auLfesTbu4u7MmRQmsGVmWhMfXSqpTQpmkcjzW7hd4Bc44G32jv2SLLS")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciaKqn2vMY7JA66AHEP1bupBcsnPYeFM58SorCWL78pGoVKrM9r7j968a9BaqmEqH2hx8UCCURy8op27HFE9auLfesTbu4u7MmRQmsGVmWhMfXSqpTQpmkcjzW7hd4Bc44G32jv2SLLS"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: whataday2day#1271   54 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUWJBSLU7TbzVHe9suuPYryfL6jw1Z1oEpQdQaDjZwoYSYXQdgVMsTio9ynopk8Bbqoz4FvnHGnMgQZe9XXfzaC81cSQtmi8sq7zGv96sFcmdSqa7uQaHgcRmqqmrbMcvPZgxF4HXi4"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcibAmoSQqiZYTEu52LPV3KadPQJKZUVpQe3ji3cdGMv8uB6ByyhMsfTnCYdKxUXUNjFGMdyW7dBVmDpFEFdjxVGpekAKfrsHc9Pbk8pXY2MCLQwNqgBbWHcWWyqhVjCdh7X6zVHSu87A")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcibAmoSQqiZYTEu52LPV3KadPQJKZUVpQe3ji3cdGMv8uB6ByyhMsfTnCYdKxUXUNjFGMdyW7dBVmDpFEFdjxVGpekAKfrsHc9Pbk8pXY2MCLQwNqgBbWHcWWyqhVjCdh7X6zVHSu87A"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Tyler34214#4119   55 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciRdS3NWjYF25KRNM5YRRU1Wsa9tuP1uczAECnk8cojcLmnJfgBStv6hAZtC8mzb1u8z7RyLE6De4xMCcuM4eqw7eadSFqELXsGuCZ9KAMnL6ckYJdRvEeNMJU4C1iLQN8UEhEj8oCsq"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcibPYLvy6MvM9XEfm2ECoibzcsRNv7cF5AcGpiQa5zs3bpmZF8DiHkvPvRcr6iGe2hsii6mE5ufXsdCdfZdA51GuuDaDYaVZJwSwcTiYRw1aJ2WMgm3JSLPYUPQ1bTBieQveWwUT45dK")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcibPYLvy6MvM9XEfm2ECoibzcsRNv7cF5AcGpiQa5zs3bpmZF8DiHkvPvRcr6iGe2hsii6mE5ufXsdCdfZdA51GuuDaDYaVZJwSwcTiYRw1aJ2WMgm3JSLPYUPQ1bTBieQveWwUT45dK"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Mikhail#7170   56 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcik4pmdNe5SNkoWP6xJiHDB8fVpZGiRak3vjrjR7iQC2rDyHQyU2xgUHVAQ2jncWyKLsDTkwjNJ29QNBAQpTsQe1BrKSbJ9dBXNevvgCq8qzg3T8mDiBWRmBrTodwHMuDyUXUqkzEdXY"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcibpkA3BG54P75TTHm3A7RYg73AgwYvR2tdjxV7czmq2Gn3uYzxvNFM4tGKjzU7zvb61mBHLhGVBh52yvizXc3PwX3qGATkFCe7M4mu3qp3WKGW1svKxwAfAdvAHrAWcUpS17qUxpZxf")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcibpkA3BG54P75TTHm3A7RYg73AgwYvR2tdjxV7czmq2Gn3uYzxvNFM4tGKjzU7zvb61mBHLhGVBh52yvizXc3PwX3qGATkFCe7M4mu3qp3WKGW1svKxwAfAdvAHrAWcUpS17qUxpZxf"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: viktorbunin#7847   57 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciDWqX4K9uNRbVeQ45gr4mJoVX8HrxyR2mgPpE43uhB8wLYXzjeyKmQPiEyNpdw8CwaD893dZqryUgkzBxN387VnSBk3RydzuZanNDtQcFRT4dsqZMn7KNQwDzN37CXJsknr9zntWKu7"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcicAK1hpX7niq6bv5zz1baLcDobCzG4zSkQnZKNSKi5Wa9Q8hdwhFk6vBS8BH4Pqdy1foN4qC1BrH7XJLfUq6MqqoDFVhhYaJDGCdNyFFw3FMTofVWWUZnnD1GvKqtK6fmB4HuuC1xWY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcicAK1hpX7niq6bv5zz1baLcDobCzG4zSkQnZKNSKi5Wa9Q8hdwhFk6vBS8BH4Pqdy1foN4qC1BrH7XJLfUq6MqqoDFVhhYaJDGCdNyFFw3FMTofVWWUZnnD1GvKqtK6fmB4HuuC1xWY"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Bison Paul   58 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4k4QYN5aL7xaGyDdFum55FEk2gb4HdveYSo8pWoJmMUkSL4FcNzxc4iCXKydm7A4NZgThzAKZNMtQ8bzykTiH8Y4H6UyGqzHXjw6suJECUQYJR92uRZnD2ReknGLSZo5KcegbvQiog"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcich3ffNKczz46hLxizLibp1fwVQmiD7DsdrBvZi6v8fVDmthCrw61EYZMrqmwRQResszPfXgrgJ8bE5qzMkVxDxTq4Mu53naXmSoKimcL7S3WyDXSKECSVzmnrfd8LUNbmwRpf3aJ5j")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcich3ffNKczz46hLxizLibp1fwVQmiD7DsdrBvZi6v8fVDmthCrw61EYZMrqmwRQResszPfXgrgJ8bE5qzMkVxDxTq4Mu53naXmSoKimcL7S3WyDXSKECSVzmnrfd8LUNbmwRpf3aJ5j"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: sashka#7560   59 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci23yobZjV6dvoyUp6H4R9rELufgyjzAHc2AKM5HMY9GTSdFUbUcZb5jJfnFQqMCpN5K8UosHSLeP7VDeMLocoWkrSoF5YANdS8CZqBJyxapNJPHon69w13cxkAHH2c8bR6iiSCQ1qUu"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcidgsCphkdpU2bWvgrBYxkW1SSeT6kSYNRZMq5eeWkoga8uvbY7kQSEPBpBa7ahvT7Kr7NTucUNYchFcUS4KpuW2GMDGSH8Bu2pA9U6jseyqqEJFm2ij5zvndY3gLpzVZJGgbGnVuegD")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcidgsCphkdpU2bWvgrBYxkW1SSeT6kSYNRZMq5eeWkoga8uvbY7kQSEPBpBa7ahvT7Kr7NTucUNYchFcUS4KpuW2GMDGSH8Bu2pA9U6jseyqqEJFm2ij5zvndY3gLpzVZJGgbGnVuegD"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: _pk_#9983   60 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciNW3FFh1H4DoSyDW2yibADC8Sse9UoTMRmvqzs1y7TnxzsBtb9Pff968k2HAbrxb886zL8EjCLBQz7Az1e8FDHyRqPJimm7MSdScwBZkTNLJvjbnEZBecfJx7kPrzqy8x6GYKYnsmSA"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcidjEVHaJdtzPzXBN1zy3cx2s6LMbSYn4amM2GLTbfGv5PbgAuXLj53h3UeCDX8PADP5QQc4rapzXtxE5UbKCGL81sPwQCMsHVbu7LkQ5eUifNRtMjUufCbLLoWKQFRT39bvP2RpTD4P")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcidjEVHaJdtzPzXBN1zy3cx2s6LMbSYn4amM2GLTbfGv5PbgAuXLj53h3UeCDX8PADP5QQc4rapzXtxE5UbKCGL81sPwQCMsHVbu7LkQ5eUifNRtMjUufCbLLoWKQFRT39bvP2RpTD4P"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Marius | Ubik Capital#9009   61 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciZTqAxv2juUxZNXs3FoHYkt65MsofxzQGMggjMjhRQb5RqAtcQWvwqvM9mGWKo5HEfPQkcmAU8xtS8CpKiUjJ9pw4vpgxMLj3Yg3g8GAFTEFgat7oVz84YM5TdcJpPVjoQ69h87bQJY"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcieBGxywDYQ9fJGXeJSxiwmndZpDurxcoSXCY61F27EKFwyhL3yCMNZmRGyuj2tnea8vut6rpjdbVq44Uhz1H5mhNbpxHFFs9FhjtQAKDBDenzNwEaDBNKRZiUanbdbkmshxE7RUxwZJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcieBGxywDYQ9fJGXeJSxiwmndZpDurxcoSXCY61F27EKFwyhL3yCMNZmRGyuj2tnea8vut6rpjdbVq44Uhz1H5mhNbpxHFFs9FhjtQAKDBDenzNwEaDBNKRZiUanbdbkmshxE7RUxwZJ"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: WS_Totti#4641   62 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcie1kcDasFVHYDKEytZGSLUQo68GX4ZjuBRPWf124aZur5m2AVMr8FQomznLh5rc7LGrMbotDgFDSvVDiALGn5FJGRtFBbDdPZzqSZmqean2c13yif7G6DAvPrVBeVaiSUsBvap1p2vX"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcifUB4UFk6GmAq4YuiXERHZMCE2JwGaetvAdbhkCbHQ7f4z7eKoKQaner9hreCBquXkYsETweYoQ4LdgXVBrbZj62GzgsxZqL9zx4SEsyrKJmE28Ks5B7uNnx2ua6g2ufTWPwYFtS82h")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifUB4UFk6GmAq4YuiXERHZMCE2JwGaetvAdbhkCbHQ7f4z7eKoKQaner9hreCBquXkYsETweYoQ4LdgXVBrbZj62GzgsxZqL9zx4SEsyrKJmE28Ks5B7uNnx2ua6g2ufTWPwYFtS82h"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: mcescher   63 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciMkNZmUJGGA4bSdbRjgRamjqQYRGmdzeb5yj6fwvu68s5wtSG2pc4HvDiiFanpiFAZnbBv2DUgJqM5pxcJqe9wtL3JsDoZGGNMTrMbWq96pP129n76d1mMaRjPGdte4JWNXdStqTua5"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcig6xjRWLHxTGWNETuPLDjVy6awD7ZnttgfeKcfmV6C1HYQPVtuMSPhYggVCKNioG8bcgRechNM8sE8BMvSudB3tnvkBddQELufVv3bP1GaZr3awUHrK3Zai2wqjisZAy9JH9Ay6L3rE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcig6xjRWLHxTGWNETuPLDjVy6awD7ZnttgfeKcfmV6C1HYQPVtuMSPhYggVCKNioG8bcgRechNM8sE8BMvSudB3tnvkBddQELufVv3bP1GaZr3awUHrK3Zai2wqjisZAy9JH9Ay6L3rE"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: jspadave   64 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJeD5v2WhEPu8iBkCDfgzZ5RSHMvcsJWD5Sc9tx87oVw8uEFSPV8CY7jwGq2vKZNdjRRXpGGc9v2QgMav1HL2uLEpxd28xVsZ5wrYPsM1ZmsdDmzenoXy9RWDE23uSp9tr5ZpyT3yA2"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigBkK4MhTkATJvbp2RNuwch8RE3w1XxMtKZdBf8GHgqoyrBx7qUuL3aNJsDE6KWNHdzn1RroM3tf6mkKQm979K8JD8PB4Kt7tNzptAER1NFHmnUbKYKgP6cvJbFAnAzU6v1ymRtU1SQ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcigBkK4MhTkATJvbp2RNuwch8RE3w1XxMtKZdBf8GHgqoyrBx7qUuL3aNJsDE6KWNHdzn1RroM3tf6mkKQm979K8JD8PB4Kt7tNzptAER1NFHmnUbKYKgP6cvJbFAnAzU6v1ymRtU1SQ"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: turbotrainedbamboo #3788   65 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcigJN1V3g7zVeh2DXG1jD7YrxULxDVHfDpn4zCbSV4CNWZyScaAE2NFzk8zmNFARb9ARtSThtjttRi5txbivJazA9APiYF8L15mpeosx1tgMqhcUkhMBa2Qsbde2StPkQjv6wJRf5fz6"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigfKwYD6Vs1H6L1XBivTNgxBYRJQgFEJmhEqDfJ1ABtD9iLRfBxqMLMruURQigs1R898gaUy77UzjtaFMn4q9rC7XKayemZnm4vZ8KAKSZLHrqcDDHYevWxwA8yf9gweQZN66wkMNSw")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcigfKwYD6Vs1H6L1XBivTNgxBYRJQgFEJmhEqDfJ1ABtD9iLRfBxqMLMruURQigs1R898gaUy77UzjtaFMn4q9rC7XKayemZnm4vZ8KAKSZLHrqcDDHYevWxwA8yf9gweQZN66wkMNSw"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: tarcieri | iqlusion.io#0590   66 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJdi8h8fQkiK1oWzZJsPydRiGgEiKznpWCB9zeAYhAHh4o5BirhV3ighjyXwBr9TVfqF5y4NLNKavkJRS6EtZy92GSA1uS3XFfSkFcDTQFZj42k9tCVStZ1jUeDVmDmowgXAJvK9q5t"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcihEh77DbibdWrdGgTsrhSb3ccUm2cGGVDRitpxRKXjTP9f8KuxBoes9MBTxRH7rzoGA3Kzs27L2gmrBEppPTubX2AgN9GkBJ6fHGWBKyB39zhaemjWQFjdG4YZkGrESp7ZxNd9r2n3S")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihEh77DbibdWrdGgTsrhSb3ccUm2cGGVDRitpxRKXjTP9f8KuxBoes9MBTxRH7rzoGA3Kzs27L2gmrBEppPTubX2AgN9GkBJ6fHGWBKyB39zhaemjWQFjdG4YZkGrESp7ZxNd9r2n3S"
      ; balance= 1
      ; delegate= None }
      (* Offline/Online User Keys: Mishdmish#8101   67 of 67 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcidFJafLvpNK2jk8ZhEwS4AEr6Rr4e7XgLTF7ZsXEHugn6obJXuaBmErAw7HPG7rxXQD117ATNkE8NNzkrXZoMuwuYVVNrTxcLsn1wuYoFT9bLW3NGF7CSGe9dX4u78EqWkQ57UycugG"
      ; balance= 597014
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcik6XeAF6d2WXKuVb9TRjKV9Gqm2WK2kWVVGoR1VKPMSfLxzYhkH7YxCAVPHBLBwnMKinrGiBCynRPzML8SuMGtqG1mnE398wtYgLor2xMmYLc5PZbu2pimTmrmvbKLZLoiY7JaAUGds")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcik6XeAF6d2WXKuVb9TRjKV9Gqm2WK2kWVVGoR1VKPMSfLxzYhkH7YxCAVPHBLBwnMKinrGiBCynRPzML8SuMGtqG1mnE398wtYgLor2xMmYLc5PZbu2pimTmrmvbKLZLoiY7JaAUGds"
      ; balance= 1
      ; delegate= None }]
end)
