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
      (* User Staking Keys 
    *)

      (* LatentHero#5466 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciPrpmzWhLGyXGinWUoBNbRUT4na1m55Qc5sqz7BB2oNSWzkzj3MGFThNfFXvZvH3grZanj4smMvDmgS26Echn64BjLUqNDQRz7sseUr7VieBqmjCLQZRzTvNjP6UGTbLG94GhGBiEbZ"
      ; balance= 20000
      ; delegate= None }
      (* Connor Di#2159 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciS3X51gg7BNCLwEd4K3LhN9BUQGbU34VHWznrLkaz2uQhQhScztzKvMuH9dhX5MX6PU9Grav4HsRtWKxjEBWq81PESgzGpxDcNQg5Kk6kij4TMbuZAnrgJtYrjkp2ExDKVtR4VrRWLW"
      ; balance= 20000
      ; delegate= None }
      (* whataday2day#1271 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciFDFuaseQWjeyfr7hFseqQch1XN47CffuzxakHdfTAvqMko9NPHksH1GD2HW1jR3ehTdfLXcbVxJ6xRmheze86c8z6aetkc7TwkA4Eu2nJ4fRnwsWe1qr1XEKvMreWHYzuFuo9mpTHa"
      ; balance= 20000
      ; delegate= None }
      (* Ilya123#6248 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcicNArpuQKzfokRasB2Mz7nFaSxnF2zojB43GZcN6pK3oDXVGUvJ8bxTW5rcB3b6UwTorUdvo8dV5R7dd25SVvErwhuF8KtmFBsG8Zu6visqrNVN99Y1QdUjZByLLz1BZbnh1yGcvHXR"
      ; balance= 20000
      ; delegate= None }
      (* Gs#7698 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYjrq2YuX6Msb5s1QxUHDMdJgXKrsSQybG9tPzf6efzfARe5C9QYtxaqShy8THYXNx5XYUwED9citmKe8dM13PCbkbtz6Ydn4NB9rcX3V8syw7vsGkcfBLdF7HQmuUacK5srpFr1Hsg"
      ; balance= 20000
      ; delegate= None }
      (* garethtdavies#4963 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciEHZuC9SdpdKjG3cLw8dpdKUdXpbrqkhctcE422NyspG8G3ddArHJupGvV591mRKd6hEMBoPNPNRZMSjyN1S8Jp4jD8zMyHSzvsFhzKhqa7Q3F2a3uNmNUHp2rtVsj3HuLt9Zw3whHM"
      ; balance= 20000
      ; delegate= None }
      (* boscro#0630 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci7NvTGz8AVngwkhhiC4ES15Hgpx2yt1vehEQwuMfFAeXJ1Vy9bdhM4goQyAdHLrKmCxKf8QVPjY4cDm4QpZo8tsUJSqYRXU346wL2wm8pV6UhqRPgsErz1Y1S79w1xeyVQPuQRFmYGf"
      ; balance= 20000
      ; delegate= None }
      (* arfrol#1015 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciFm9gAG2hMPj787P3RyJ4irvEk511Lw9TBMdFum1g7SSoXGuXwmcdTUF6Wt9qDe71U1PV9FeRQT3y6kuzzU2TEbM69XQqFnNHtMmLUU3L2A3auafFhXReHhoQpxtrU7Azea98MywgQS"
      ; balance= 20000
      ; delegate= None }
      (* OranG3#1415 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciBNjgL24UDGk6PfqB49S5sZmkPrmzxKjJchk9XAiFrd9TWxpyFSsxEVpXeVTfAkfYXndZU97512YpYbJXKVp5TTcXjKen3f1MZQrjW63MhrP4L3cGq9yYv9b7uEs2wDfPq7j83zmY2e"
      ; balance= 20000
      ; delegate= None }
      (* y3v63n#0177 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXsQPVDeVq8Ss4ErRgw1fy1BRVaAihQho3i6L27DSXz32d5gigg5sT2nVrx1pVkZhKf7aZy5dBvm5miWETPhr7DNVcEGUetzD2H1kfpov6CXkuUbasDLPvNsHNRJC3WbSdUhyHFDr1d"
      ; balance= 20000
      ; delegate= None }
      (* Alexander#4542 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQfhx9aXvE6VXAvZ7i84S8gwP5bqZuHam2b5dNacGGz95wVpxkQ5msDPSUvh5VCu7r1UMQ7Dq6oM1LADuzyYKaBV3J2ZQqoe2NF8rEujNm4ivkNhyhYZNf5f4TKaM3M2W2QLyNydGZz"
      ; balance= 20000
      ; delegate= None }
      (* jspadave#2548 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciCJB9Df2QdurcjSpKEJDuFU5sBphMCmjSr5xVPf77V7Pq3HyuKqheWiz6pekZjdhnBMTxYrfttMoiA4tzYPBmTwEN2bZKkhH9hcHa28eEJFZdiSryZ6mCKyniqXYhAxzKUfSXAKwQWN"
      ; balance= 20000
      ; delegate= None }
      (* Dmitry D#9033 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcierQsb9iynGCgJi7KVcot8nDtdrLKv5b87khjZmYBoENe3JXY8KXamVVetdLxUra4z75od4thbP5FHfY3YhiUdRpbbwpAJoBnmkjmesop1Ymm9Vfmkryr1cih4DDXtaGFGK9DDnkQ8J"
      ; balance= 20000
      ; delegate= None }
      (* ttt#1591 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4YLE3EHdS87iPT9YKwddnpLranPxD1GTk72jXkcoFTv4EFi9x3Bsm9jyyzYRz2adTFDxQYgYciAYh3kUiCduaJ8HD1ZA7tDCax1JwCaqDnhD2N9QqCJwmNC9ziFidbJCFXoMnpLxHt"
      ; balance= 20000
      ; delegate= None }
      (* dk808#9234 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciDTHGE3FVLwsxapaMNw8V8bcE9JzsYxyMNhocphnbcPELPqztQxySfMxsQFuxgZQuqmCcziZvjugwPqe788hZNwwJ1aH7yPZRGZs7rrkZwafgExovep3KHbcpLFTxcuMd1njGd2YQti"
      ; balance= 20000
      ; delegate= None }
      (* Bison Paul#5103 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcich3ffNKczz46hLxizLibp1fwVQmiD7DsdrBvZi6v8fVDmthCrw61EYZMrqmwRQResszPfXgrgJ8bE5qzMkVxDxTq4Mu53naXmSoKimcL7S3WyDXSKECSVzmnrfd8LUNbmwRpf3aJ5j"
      ; balance= 20000
      ; delegate= None }
      (* ansonlau3#9535 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAPwzid8C6CYV3MPvFBdwt3S3QE8566kFsQLgiUwhgMMymtUPdUQeaTcDnXnXXtfCKiT3R6Tnsc1cEL4eJn8vWjTYu8wHeSvusTmVnWJnAcqtxMw5WebmMNiwk6u4eidzStCUqT78zM"
      ; balance= 20000
      ; delegate= None }
      (* turbotrainedbamboo#3788 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciCpdJSg9REVvdSkUCmRASCniSgvgrrmr7rEutaxnVCciXbRzt8JPFRN1xJCrp15jwpyE8r8ypZ7ojAPyKXerfNywR2HgYpdNRJf6YSJRJyxh7MokAqkVDY1ggWeaYU7CVK8ecv7WxKL"
      ; balance= 20000
      ; delegate= None }
      (* Hunterr84#7710 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYm3GuF65WUwyySe2mo5KitMEiDuurGAqRHuKHfKXdTtqsutCg4M878raPGLnb8QaUAEYxJ9SeUJsDHZY3hN7eGmrdUKfoHsH5QELofe6JfWH3fJMqW8fuCa15DNYe9PYeLvUeUTH5W"
      ; balance= 20000
      ; delegate= None }
      (* tarcieri | iqlusion.io#0590 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAD1jRkLg3V2826akbLpF6YCJehWtVE56Vd5DjbyFxrmxyrY7SaNnzAGhRiRxAzm73TyWDTtQdoBKmNvMRRoigNG2TKS6tZ3W5MUQGKHUKut9afPnFTd3UWRWyfDWma4YGcx5bRB8Eg"
      ; balance= 20000
      ; delegate= None }
      (* Prague#9624 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQ5nHMgNrzAWTkZx8Nc6fZVGTJ9xg9HEqGVE4SDoBXafsMAqbw5gU2Fx8Eq1ZNAD3YyxqqtsYdbrTm3kbMG3kGfX1D6WuQM4ZoeNDU6bHcMGF9MT9aM3d9HXWbFNf6XFtGAPBTJ8PHF"
      ; balance= 20000
      ; delegate= None }
      (* Valardragon#2546 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciVsqTqnnbXb8SUBP2o684NYTK9B1sAA4QvwYXSaM1h8ytBXm4j4QAVeo4326H1Pck6zixWLvyVeomdzxGimZJTeKwu74CvpMPtJXKkP9DKb6FKwZhNgxwRUe33X9bQhrUJ8wJy6n6fZ"
      ; balance= 20000
      ; delegate= None }
      (* novy#4976 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQtBECmmgu52BDF8ooyFTWBSWunCMzWrk7xepueUE2fCQXoM6JQn8qb4nBgPCgf9JEJtEZGkTVV4UCdN48PqJwtxcJnx93Fb3H7Tbjn5bsNGd6WAL7BVrnDAJWvbEpB3D2Vw7DLXDQR"
      ; balance= 20000
      ; delegate= None }
      (* Matt Harrop / Figment Network#7027 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciVjQuDsSX2DtDC7Kwmf9zso2uBfSuKqgFCSYjVv2gEg5itVr8PYHoh6mF4x1vNJ7iB24iTJyT7AJ9UjhxiCGpx7JtJPsQQHaanhuFXDjHZyJbc9ajSfNuahYEH6GFA4sJqjoacrmx6f"
      ; balance= 20000
      ; delegate= None }
      (* pk#9983 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcieYtciedQwxZ6Yp4MfGv7UT8opJtGyXfJR3SfUfd3KyNFaHcg8snLY8hKqM2iKRouqfnf6Zf1oUx5157FbwyEiHVsK3PzdNAqRNskLkmethEvzXmYuRjUnz4o1VWL7njLGzF79bRGju"
      ; balance= 20000
      ; delegate= None }
      (* TylerTY#0202 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciho9dMeFQ3FkZJUgc6aMA6T3oVeaaHWAsY2aHMvezdpk3Rv6Y626HXrxjX4a6L95BceY2Ze4uwdtFXBhZKrHcff87CTyz7xWrw8EWTuSzazxMUfCsGqFN7SCgnhdxyFmfvd7aav4grh"
      ; balance= 20000
      ; delegate= None }
      (* "Ionut S. | Chainode Capital#8971" *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciQsSmjndcQuEt2SsbVkf6qg8wrjc4PahkD3J5ikFsp6pd3QgEB4HuNmoDRYxuJa3kNG8RDm99f5x5Nb1Zp8xRkGvfiEKsc4CaUw7V9vC1QajBWP2hhxWUwHERM9XaxLLgvRsuER7umy"
      ; balance= 20000
      ; delegate= None }
      (* TipaZloy#4890 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciL4BcLDtz48FL7arqCw59z8Su5LQkNkkRZ2UCySPjym42Rba8pRS74rmE8jHQpdEFs1ppqvFaEZoYMUBGQsq7Kwawr6BdhKVoVKrFjDd4Ca4LPJ2hcgoTqvh7ZfTc57b4Qd2qto8QqX"
      ; balance= 20000
      ; delegate= None }
      (* PetrG#3328 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciLrdx8uABxWye5VBEvh132bx6x4AZUcSUVjzn1j92MdgwW8VXoHABr43NyZkzTcfbw7aH9ahZ1gWaNc2dGEVsoasxBH7H2pcfD8tNbc4MgrmmV5RpggxBa756TJT1Myx5pFd1g2Gw2V"
      ; balance= 20000
      ; delegate= None }
      (* Ilinca#5351 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciNBsVA4vhxBtZp4bQM3gZsWMr8be6UfmNRRvNqHjRrATsSBLe8XaUUnrT3bMY97kix97S4kBcpNsBiBZdLggsr7XcktkpziPdkFHfDNjALASU46n1Vq64x5rmgswroJ69B6N7Yei4Sz"
      ; balance= 20000
      ; delegate= None } ]
end)
