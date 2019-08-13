open Functor.Without_private
module Public_key = Signature_lib.Public_key

include Make (struct
  let accounts =
    (* VRF Hack Account *)
    [ { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXRzP5ViAqK6TbwfBhNkuppA2XVatF6uEvWNrrh6eBY7hsYbQfQTBkfNjpQZuY3s4jU5LYD3ZBhM2z4mbvmHeHQvCHqe7vwr2wQH4gJLSv14tf6iWHyoRWHZ4XS2s6oxzBFW3xB5Nvn"
      ; balance= 0
      ; delegate= None }
      (* O(1) Proposer Account *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciTDiJziUovrKA4KKs7wN1XNhV8BW1YUvcyoo33RdrtPa5fKSKJSqFTgo13aNscVYTBa2kRmPnNGCdsuAqsSw6YJSn1GKVuqfpTDxXkifm6PJoVmVN3Gd1vBPKzdpeyuTBULfwsjmFxB"
      ; balance= 100000
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
      (* Faucet Key *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciczxpMfZ4eW1ZPP9NVK2vxcm9cCHvTBWMe8Nskn2A25P1YqcdvFCD5LvgngraiCmAsnC8zWAiv5pwMYjrUwpMNYDePMQYiXX7HVMjrnB1JkEckyayvsAm2Bo4EQBWbHXD5Cxp65PZy5"
      ; balance= 100000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcihXwbnb6Sv3MwW2rbhXDS4TNSn75tnDZjzUKsjgFSmVJUycLFftqnSZmikKBKEo7KHeLviRpsZw3XUh6zDZwtdH8zk9mhNG6ydL8pqrFM5FdkeV9fYdtvysVC29PSKyb97vK7jkJB5d")
      }
      (* Echo Key *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUTDQupJTEjEgFefiGBYuXNF8asTBSEimH2uBjkmq1vMEDMnzQyaVF9MgRmecViUUzZwPMQCDVoKLFmPeWG9dPY7o7erkLDFRWnoGpNGUk3H5r3rHtyfrG17Di6tx9VqQMq6rehPmAu"
      ; balance= 1000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcihXwbnb6Sv3MwW2rbhXDS4TNSn75tnDZjzUKsjgFSmVJUycLFftqnSZmikKBKEo7KHeLviRpsZw3XUh6zDZwtdH8zk9mhNG6ydL8pqrFM5FdkeV9fYdtvysVC29PSKyb97vK7jkJB5d")
      }
      (* 
        User Staking Keys 
    *)

      (* LatentHero#5466 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci2apfQDHNoaGXnBZ4TM6XDTTrcMGNe2BHK7XMWMCZ9KoXbW4MPw86dmmsgjRBNTv62AA7HvEhGH7CnjJYCxfj2KJ52nC3UZrfLW8qSzbCzuFNJThCc2fx6vbhpBSSoMKVnxTEwEvpbU"
      ; balance= 30000
      ; delegate= None }
      (* Connor Di#2159 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9ViV7ieBUu73BSGmFp8z6QdqvF3jpAy6sGJ8eCkk9TCeFBKSgUvTxZbdjELuSH2jUWzWUyhr35u1sWQc3HuiY56tJGUdXXM8tqTw3ZiSrHBCfLsn6oXDvyTPEfP3tZuD7gDArb8Ytj"
      ; balance= 30000
      ; delegate= None }
      (* whataday2day#1271 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcibAmoSQqiZYTEu52LPV3KadPQJKZUVpQe3ji3cdGMv8uB6ByyhMsfTnCYdKxUXUNjFGMdyW7dBVmDpFEFdjxVGpekAKfrsHc9Pbk8pXY2MCLQwNqgBbWHcWWyqhVjCdh7X6zVHSu87A"
      ; balance= 30000
      ; delegate= None }
      (* Ilya123#6248 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBmRsk1JiErGuurp5bHUKhahh5Yaca5WEUnVh8HVGeExtSvSbB7rASzDDrAubB43CyUSQWhzy6sZgZeEhVWdTGsD2RYJBJpknztjDfXSBM1N5NHn57sTW4sdQwc8ZuB7LtzDTrLqYN9"
      ; balance= 30000
      ; delegate= None }
      (* Gs#7698 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcie2fiCzTmpwYyP6MWttJcSza3wstdzouqteqjUG4QuhcaTUhHpjzE7Uv3vqSzXBMTDKaVXKSYzJRbAZX7GEJYJBMP4DNcXmJ8utLtDotaqXuvaG84EZNNT8jUzecRDMRkFVcNeFP6yM"
      ; balance= 30000
      ; delegate= None }
      (* garethtdavies#4963 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciEahw4NVYiKpEMQNbRZbwr9yM3M2pQNTTQL7CnERUF8y7dmP3vyf2dYuxaaM9ZP3zhuZPZe1NVa4ydMN6vybita3LnKLG7WVdMdGeMvaFNAH3q6CVCQpAwdFFqJLnY2wLUW4eNvz53D"
      ; balance= 30000
      ; delegate= None }
      (* boscro#0630 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciETC2KsFB4SwsPsV8cvVZYPgfioD3DFd5SFqXBKbp7thEkyZuurPGHn6k7SbLyfdb9CtzyYuWpzna5zERJBkzjMqgXDxn1W6QQP8zDMwGou5461RwJFCcCPemMEN483pwfq3bFRFX5F"
      ; balance= 30000
      ; delegate= None }
      (* arfrol#1015 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHr7ozwggJExjEBtt2y1YUiyL6S9ifXQ34X8CTukmr4FSpu66Mo8TxNmeXhnkuibkkPL6cYDDJ8gznP6Tqq7usyJGRm53uuBpRdagYcKbNqkWJj1gB8yQBxy4SPX2EFvkygV5np4GiZ"
      ; balance= 30000
      ; delegate= None }
      (* OranG3#1415 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciijuJGbjBr25StVtFXbJn1uim1nxw6fUzhhP5uYaFRVS15pLtyPRdjVjxLGGUQSrdPvDfp77kQWBTzVM8WuivVZDZvCaT2959pc3F8Dy6svUafgibzFgXA4ei1Ne2W9MpvLqE3uh2U9"
      ; balance= 30000
      ; delegate= None }
      (* y3v63n#0177 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcikYgqmmqwFuvMpsaNxNppNLgGG9eNXHvxuwvMNWerJTk41hVPKsQa28mEyCqJkk8xjgddB9eCsF2YKmFLJG5p42bvnZYmjdqz2TPXXhRRWDbpfx8nTJnS5p6QDfy76MsWGnndZ8jAiw"
      ; balance= 30000
      ; delegate= None }
      (* Alexander#4542 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcimm3CnFATS2WUL9WJuGv8nXzsRTLCQCcuCbAAoixT5KeA8cUhTkddcyEBikG4baP3MMUMgTxm2R2L9C3HMcWA626qrRDZXgFVX5nvZeFPH7WcMdVmN9tSrvrLB6YPig3XHeKV7Hu9rP"
      ; balance= 30000
      ; delegate= None }
      (* jspadave#2548 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciNCQRSPRxThUFwCyu1GTY1eVp1wpkGRfL4hLAmTdU7cqyYR3XtNfhMpkWcLTgu4CLQztQP5eSttRvF5TCHcGzHz59wzewPMCJheUwaLgYvyGka8sBhhKFHv4R3DZaM2tY6r7bAGezE5"
      ; balance= 30000
      ; delegate= None }
      (* Dmitry D#9033 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciPt5taz5rze7dF6TZSMUYtWzwoLKRfQxgCi8tT35HGsama9dmGqAZXNonv8m8dnbRe56H9zT63kVBSxTHjbeU5egZcqTFMpsCbCvV6sbMq44X45eguHSWhPtFodqfR7fPWXSLqFFBku"
      ; balance= 30000
      ; delegate= None }
      (* ttt#1591 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUJbzpyufFsDxqyU6qnefMRYuem2dWXF4eEYaRW9UEnHzg4ekugrTcD4trgTkgiLj74bjbYGVgnEeqrsVrMLf3ePQ3Lp36bXYnoMKmZMk4y18HmoW5RLf4BXnobrPNmBSJgtFehSZc6"
      ; balance= 30000
      ; delegate= None }
      (* dk808#9234 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciV3pfTJBvUPQNZ9FTwe9eiWFzE9G4mzES6xBTyRDqst1nEscfLpo9y3vjZeesXqNS8C3jVWNwD6y5XBcu2jGnxK4hcyMZYH7s4boJdVaDRr14TApTQvL6ssEkBxRheud7ffYEAdUE8X"
      ; balance= 30000
      ; delegate= None }
      (* Bison Paul#5103 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci5rMix2suHxxTjccwJATuimMm1Ynnf2kfY8m3HzGcv4nPzbREtUY2V9Gkus2711WManzgcCAFUB7cyz7Z7yuWvbncQm6CSpqsGxFDCHfxAJZ6Xo3Fihn8dMxZt8s41sXUhYo4u9aduM"
      ; balance= 30000
      ; delegate= None }
      (* ansonlau3#9535 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXsYTybpwd1Fx5Sz8hqDwoaGNPSP472U28LxW3kCKMazUz5LeZRMKDLeYUfvpkKPh6h9yGT8kxD8CSC2XY8u1JyDEnWqWAGfWB9xcZAshRmUzyygYsQbGAVrJesn4oKvdQD1JKqDeV4"
      ; balance= 30000
      ; delegate= None }
      (* turbotrainedbamboo#3788 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciEP8ZgZNUzcgi8VpMjMxKbg5yEpMEgpLFETgVSvVuaQ1x6m8imvHu13SodyUv6naiNGNcRsmDUFxQtqcQAYGCDR85wER6yqfS2PJ8Rdm7qyJmwxa4zDyWoYuM3hTiFcT8qzeMG71bzp"
      ; balance= 30000
      ; delegate= None }
      (* Hunterr84#7710 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQFukA6prhQisFLk8Xyp3tsW5b78vZzAThNNTzeWdbiNUVMpxtmhXf38pxTQ37f3wS3a9Wzx2ComAGykicpXTFd5fZoz3iadnWB5kJZ2saDZ1PRMxVctdx52sJahksWAB9KtMU2ggTG"
      ; balance= 30000
      ; delegate= None }
      (* tarcieri | iqlusion.io#0590 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihEh77DbibdWrdGgTsrhSb3ccUm2cGGVDRitpxRKXjTP9f8KuxBoes9MBTxRH7rzoGA3Kzs27L2gmrBEppPTubX2AgN9GkBJ6fHGWBKyB39zhaemjWQFjdG4YZkGrESp7ZxNd9r2n3S"
      ; balance= 30000
      ; delegate= None }
      (* Prague#9624 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcicURZNZtRPB3Lv4pbifuBTLy1CPeiH8W5YPed2GKErk1HYTucRz5BBobocg9YwtQCW4dUBhQ4Pb7551TqnT2qeSPZGhzmhqFzfkycCS3bq3Faka28n54zugUKdgFYksy1LSxk9ybg1a"
      ; balance= 30000
      ; delegate= None }
      (* Valardragon#2546 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJLLxyzdcixvWK4RKFxMt831ubHBVvMFLW8Q6umwnUsaf9zYpJ1CMDr1ussRnfEDwao7aMqPjsGsChtiLhZnJhL41xWh4pppb8aRit7E1dbX96Kkq6L8Nv2T5hCQMoDr2p3J9oCy48U"
      ; balance= 30000
      ; delegate= None }
      (* novy#4976 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcif2qEBiXuVqprvkQ22FmF6cTzRfPCXw4LWuejQ4u3SDshB4bdz3r4ZmmShQhZVbeN7x7JpqBtXjcUd6VzLQfxTjiZcvcTkEiCU3DUFCdEoLgK8JiVyWS2hbFCbRohpTSXLNMpdwKp3p"
      ; balance= 30000
      ; delegate= None } ]
end)
