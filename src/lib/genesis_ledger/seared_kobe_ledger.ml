open Functor.Without_private
module Public_key = Signature_lib.Public_key

include Make (struct
  let accounts =
    (* VRF Account *)
    [ { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJsZZgAKgcuuqtRs8cb3SDJAfTdwpbAdg6aNnV2WZXftd2USKNFc6VPU7KtFZD1JNnCzWq3ygaioNNxqw1d6DW4KyR8MhNthdLDQMYK2nwz8zeCWUm6EQpREnvQDw11khpbKoyBX9uJ"
      ; balance= 1000
      ; delegate= None }
      (* O(1) Proposer Account Pair 1 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDky3tTyWUdf1iccjh8zqga1yATQQ6r5Q7qdbtaVHntT9ncGsgRfHiqHsJsNiXUSzSTDyq2FRK3eJC3XNvf4KBRy7KELNKxQCsj7ycgV3XxPydzALPMmjFJ4v7mASXLMYYaAK6Dkqk5f"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY"
      ; balance= 1000
      ; delegate= None }
      (* O(1) Proposer Account Pair 2 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEHktzZep3DHVJJxvvtVD91ZoSvoLgtxAL7fCMGZC1Qtdso28DuuossMggsBgJkbhptzH2cFuQ7U5n6FaZraxA4sB6ex3xDHF8gEgdNYisfAg5n7eHUz4AAikM866fc7hCk9n7wrwMQj"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ"
      ; balance= 1000
      ; delegate= None }
      (* O(1) Proposer Account Pair 3 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDeLpBdTppcxxoxJzgAQFpmzzMkNjWA9bhcCLDDzkd6sR4y8rhpKfXrfMgxMviNK5ncc7UVx4effUxpNNqpwr7SDtopAin4dSb4wkDXRAax7dgnvTe5p7sp7DSmKKYPe6Vp9hEq1En9i"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq"
      ; balance= 1000
      ; delegate= None }
      (* O(1) Proposer Account Pair 4 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDmQzS1Vy6TeTND8cg1h9Swr5CJNTa666Yxj9QHKAQ557PP2HebGX944HQ71usJmLYCXRPXy1X9RRs4eDxwNFf5koHMsBYjK3MSsBMFD1g7VuTXm1tVNze33VrUbDdiTuWecdXBnMS9R"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW"
      ; balance= 1000
      ; delegate= None }
      (* O(1) Proposer Account Pair 5 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDx1Ct9JvFYHbwtpggvsMgpZGn2BoG3ny41r5CNXhDiaYcdgjQLYTrrmH5BEAqyvTtvbzEeQFCGKcNUp9HWPyy1P1DdXTHwnPsNLyvf19LvaBwzyBZxQqPQNp6vSF9XRULmJPLGkvg62"
      ; balance= 10000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV"
      ; balance= 1000
      ; delegate= None }
      (* Faucet Key *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE67M9Snd4KF2Y3xgCQ8Res8LQxckx5xpraAAfa9uv1P6GUy8a6QkXbLnN8PknuKDknEerRCYGujScean4D88v5sJcTqiuqnr2666Csc8QhpUW6MeXq7MgEha7S6ttxB3bY9MMVrDNBB"
      ; balance= 5000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
      (* Echo Key *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDk6tKpzhVXUqozR5y2r77pppsEak7icvdYNsv2dbKx6r69AGUUbQsfrHHquZipQCmMj4VRhVF3u4F5NDgdbuxxWANULyVjUYPbe85fv7bpjKRgSpGR3zo2566s5GNNKQyLRUm12wt5o"
      ; balance= 5000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
      (* User Stake Keys *)

      (* Offline/Online User Keys: Dmitry D#9033   1 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEKGSJcME1Y6DBvKW8Lo7V7zGg1oTt47GQJbKwiJUqoxGn1q3dpyqVPxmv36bGjjo9pWqmYjxGSqyMJg6miSQ9Yh5ByoykKFpYQqnbxTuSzyZzjDnTiUfP27R5hia6aL2e6KqWTM4oN2"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE3oXHbo5hLxj1NfDrkgTgtYdVodzD8toEGpqqBgmizZR7UC7rEB1Eazj3kQQuBXsK6NdpVppWQTmXcEupLEXBHXJspUwCwMLxrJAFATYM8LeGSeGtLVtVABBXwh8GCSowW7rXXYugAU")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE3oXHbo5hLxj1NfDrkgTgtYdVodzD8toEGpqqBgmizZR7UC7rEB1Eazj3kQQuBXsK6NdpVppWQTmXcEupLEXBHXJspUwCwMLxrJAFATYM8LeGSeGtLVtVABBXwh8GCSowW7rXXYugAU"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Kunkomu#6084   2 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE6W4TWaQs7mfKV4RQzwgeVJVJ7QsGprCSW2CLxJsabQKCSiS6RbHq7DFrPcS6BL8eMNnZws1mxdA4piFYRpS6NE7MXaiSqsi1p1HVmJ8gFqm1Vjjd5nFtiWs7SYqY2P8UuStBjeKsV5"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDx8htq6yao9NC7SnwGh8KGGs9iwtDy9HfYHk512hH2FVj8EPxczE5dTp4yZ6Dee9S5BP2XbSFcKUeDKFeQNMjraEV4iQQz8xGdsgJHAFgrvU4kPSw34KoJchZQYma3EZKbghwbT2CeU")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDx8htq6yao9NC7SnwGh8KGGs9iwtDy9HfYHk512hH2FVj8EPxczE5dTp4yZ6Dee9S5BP2XbSFcKUeDKFeQNMjraEV4iQQz8xGdsgJHAFgrvU4kPSw34KoJchZQYma3EZKbghwbT2CeU"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Alexander#4542   3 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDwgDHFQWmV6EsBLzpN7AnrJrwsHGvGWy216VvzK7vpHaLfxo5NnzQpDv8Wn3FsWfE7BoUhHNZVHpop8X6mMVisvH6LPUMK8EdNbFLTSdPUw8KYCjrXS4x5Q92BR8K2P7mpDSVp1ubq4"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNENBrDo1gvbHXtkhsF7gK1x6kdFB7nQYanQWPvSXxE9Dwyx8HdzuRCRRCWbMA2dz2obj2AwTzy6Vp8Q4uTKP9YLEG32fvzgqJmtAVqxWusCNwenihRKSLjXyzgVapdhN9tDPgdbe8EWN")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNENBrDo1gvbHXtkhsF7gK1x6kdFB7nQYanQWPvSXxE9Dwyx8HdzuRCRRCWbMA2dz2obj2AwTzy6Vp8Q4uTKP9YLEG32fvzgqJmtAVqxWusCNwenihRKSLjXyzgVapdhN9tDPgdbe8EWN"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Kai   4 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDfpJa5LU4DoUKN7aAziZ3NN9gJHR65XLSvpv8kuo2PLYP9HbwL4jtfmnb1eWNqWLeAjPGuZxwYRTWH1DN86S4HhaJENKUt64wCRoE42TdBhgvzttWP4TuuhJrT36KUu6ab3E67Mumk6"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDgDbHfQZwFA2D53bUCtAheozMs4nRFP1jxfdhZsMvBVDGro5PeYYrAL4NUmqyVGgmxS6kmjebSJTVt57QPwwy8GPQzoGGjYo67mgmUB3if2ZYT2mCe7od7YiQoFG9ccQsnkarxx1eH3")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDgDbHfQZwFA2D53bUCtAheozMs4nRFP1jxfdhZsMvBVDGro5PeYYrAL4NUmqyVGgmxS6kmjebSJTVt57QPwwy8GPQzoGGjYo67mgmUB3if2ZYT2mCe7od7YiQoFG9ccQsnkarxx1eH3"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: _pk_#9983   5 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEGqfiJuZhPFGPxgPXtgSQef2whTXwrvTG3tQpezmfcEBikb7dZ8ktgvFNWQFyQbavA2aicR5TeguUC1AzUfnvbf1f2EQXra4v49WEMFEay5dZd3YF7UfjdJW7gmPsnY8c7YdVup1vcX"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEL3uRAqs55Yf1dLch1y1q2Rr6cTzF929N4nG5K5q5mprjGah77pt61dpKXLp6jm51p64f3QUibTFiNmXGL8mjVd1aUuWqhhedG9PZ39v5mMBk3yDpDgpovtDYhZXRUyAznzwzDTD9LA")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEL3uRAqs55Yf1dLch1y1q2Rr6cTzF929N4nG5K5q5mprjGah77pt61dpKXLp6jm51p64f3QUibTFiNmXGL8mjVd1aUuWqhhedG9PZ39v5mMBk3yDpDgpovtDYhZXRUyAznzwzDTD9LA"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Prague#9624   6 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDhnP4RgG84HtgRER61QdCPxouKxp9jt7ZWzDsJx6kVngUGTzQGcq8pr8ztARczE3NSWFv6QWZoRbrzjPhkTETZ8VSHet4MVaKKxAsAuSpihwsRN2ftasep9Myodz3N8gJpDxW9T8Qe8"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEJC1j1xYpY7SdUEurBEyDQpPbCnAYefsqmCcRbNx42VWaGq5GsvsxRQuxVuvH3GmLVbhSPuST9GWBeLEB8LGP7QHQjAUTpLkHfdW1GUV2S4aQQH86ut3BRx1q7ZaKijrYpoQJN7mn5p")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJC1j1xYpY7SdUEurBEyDQpPbCnAYefsqmCcRbNx42VWaGq5GsvsxRQuxVuvH3GmLVbhSPuST9GWBeLEB8LGP7QHQjAUTpLkHfdW1GUV2S4aQQH86ut3BRx1q7ZaKijrYpoQJN7mn5p"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: davidg   7 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNELriQwiMWBrqczC5xbg1PtP2i2AMJsgh3gy9JeZAdeaaw9X5BsRgBvrRFbVqKR5SfV2QxMEPhQ9VtwK2qKSr2Z3ruWCEQYNjNBQYrGHWuo2gAFXkvc2HvTVLDJcXKP3s369C5psi5Ug"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEBTzm5HGLMM7intuUMzUx5UBLtXHTG9oRdvG6rS9QJkgkM8EgqAiVLZyXBSUFevPJcYuHoecwa4qgwX7vJV9i62bxWDgRW2S5tozk5xZSg6NJpXGvYRreULAuz3WSP9bJNTQ5Bv77uM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEBTzm5HGLMM7intuUMzUx5UBLtXHTG9oRdvG6rS9QJkgkM8EgqAiVLZyXBSUFevPJcYuHoecwa4qgwX7vJV9i62bxWDgRW2S5tozk5xZSg6NJpXGvYRreULAuz3WSP9bJNTQ5Bv77uM"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: gnossienli#9767   8 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJ8dj46ZgXeC6ZPcWq7CaFaYS6tcXckQjdo2Rvhkzi83M4giD5foZVwVi74vtmuEiwPbQWxaf8mdd2QzFjHk5XrvRNbvUivBFvDP52ktUYM7MrK7j3HQvPaHyyC7fqFZ6YwgL1EuxVb"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDuujVfh2R9UnWUZHNGCUYuTLe1qqVJ8Ak8E4TxuzLiUoh7SdPpYJGtfj37b8GLNMA1wv5QRAyissbNmXCdwFFubCZhq5cnKYALS2NKajPgZQahEF2yszL6xLSTSt9PPV65kh657cSHL")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDuujVfh2R9UnWUZHNGCUYuTLe1qqVJ8Ak8E4TxuzLiUoh7SdPpYJGtfj37b8GLNMA1wv5QRAyissbNmXCdwFFubCZhq5cnKYALS2NKajPgZQahEF2yszL6xLSTSt9PPV65kh657cSHL"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: LatentHero#5466   9 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJN19JQNNBfzm27jLuJUEXwGdYwHhLi64dDL4HxujNFhdmdm2Fh2UVuBsJcG1owhNWzQD7rFhuVsQt24zTMLV47JcfB5UphaqmbcnGRtv1AgfjicYgPCmCPw4YsbFNjqfb9V8uHJGUK"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDtia5EP7aQqzF6Fy2Pykbmve4eoFphjr1nk9AvELFNuHmyvPVh9X1JNhbEcFYUR6YrVgbvQ3JuQ7HGtNJrBHfjQfZFDcf27ywqXS3B3SsuLqKcbUhY8veui9LQEsu6YNKXq28EjRDri")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDtia5EP7aQqzF6Fy2Pykbmve4eoFphjr1nk9AvELFNuHmyvPVh9X1JNhbEcFYUR6YrVgbvQ3JuQ7HGtNJrBHfjQfZFDcf27ywqXS3B3SsuLqKcbUhY8veui9LQEsu6YNKXq28EjRDri"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Alive29#9449   10 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE7NJjpCQabA5ho6rQMUd893pub2NThp6kPvBj7MgqRpqoComJkyBqcWSJ8m213dRtwKHmhdURgAbe3zSGENY1PowSTENd3LrKff4YNdGH6G79yg2aFpa5qdBjxsW4CfduQPiAxw2ZVL"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEHvb7ZycsZkov132aFxKLzyWRrH3UzBx1fV1UJKBETZnEU6g2TktDWVbAkc4aQHvYC7nnsFxH93uyWaqvxPCzEyUqFccBij54sGSwvshuLDnVxA1T4j2zQr8gZr9ZfhGzVBVB8ornDg")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEHvb7ZycsZkov132aFxKLzyWRrH3UzBx1fV1UJKBETZnEU6g2TktDWVbAkc4aQHvYC7nnsFxH93uyWaqvxPCzEyUqFccBij54sGSwvshuLDnVxA1T4j2zQr8gZr9ZfhGzVBVB8ornDg"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Ilya | Genesis Lab#6248   11 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE1gdBr5VQQV6ugysw7TQRToYLLQfccuGVTvcdiURbDe7BwmeU6VkT6FfscQRomUiN7pz7v1uyArdrb3NFHhJz8bNYCniSm9Dt8wtrsMrm42xenbgwxVQXdx5RBkXzvV9pzNpQv3Mkqy"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDzHRJo8tJ4tyZWAKxhR3RE5mD4wYFZCeU5mVoy9c5vUFz2wcxfqfK342gKtzdAMHcSP7Vxmy1E62ByXqCHgw5Nu6EWheLdZMqupxWneEPuKvhHqmyB9oouHqo19TCpcaaiB7bZLCmbZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDzHRJo8tJ4tyZWAKxhR3RE5mD4wYFZCeU5mVoy9c5vUFz2wcxfqfK342gKtzdAMHcSP7Vxmy1E62ByXqCHgw5Nu6EWheLdZMqupxWneEPuKvhHqmyB9oouHqo19TCpcaaiB7bZLCmbZ"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: aynelis#8284   12 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDgfpK5icfvpYezakgW34FC7tb52f7MKzbuBkTtXNTao491VtJB8qvyHsmho5VNQL4K1qamEjcVN12xC8hQJfs4mRpaVbwyY51B819XhYkADFt7uinfYtC3PTRvHHqbKMvN3okwvGG2S"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEB1WW3Wi8d5ZiNHc5idjaowcN26o7Y6CGVsBmpKV4avzsoZJ6eDWxL9ypxTVCba8H2C7SHzt1gLiFC4xr4ig2Z5AzY4sx55HimwbWrNibT7JbgiZTwGPFLBx2Gx6xoeXksViocERUQd")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEB1WW3Wi8d5ZiNHc5idjaowcN26o7Y6CGVsBmpKV4avzsoZJ6eDWxL9ypxTVCba8H2C7SHzt1gLiFC4xr4ig2Z5AzY4sx55HimwbWrNibT7JbgiZTwGPFLBx2Gx6xoeXksViocERUQd"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Stateb#7862   13 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE5X6VkGQCMZuQ4pMt6C82SdF8HBD5hjSERXobTWcigZRmV6ojipWMPXCNbRURHK39uhj6hNFyFnSA8wd3UBUMditpVXdQkcwFEuGukecxXLrau39EE46dkmbMLuf6xUNMbmQ5Qz4uZw"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE9VLqu6SPbsc8jBUxadqWQ1oQ2jEgEoGp8Jxg9fQHWFnBHryJxFNT77ehMMXfb29C6WP1CZCYFRGezNBfp8Nvq19JBASxkMuUvyU4MrrFTKL7noQKuCtMWzNjNL8FuJbAKFk81d46XT")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE9VLqu6SPbsc8jBUxadqWQ1oQ2jEgEoGp8Jxg9fQHWFnBHryJxFNT77ehMMXfb29C6WP1CZCYFRGezNBfp8Nvq19JBASxkMuUvyU4MrrFTKL7noQKuCtMWzNjNL8FuJbAKFk81d46XT"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Gordon Freeman#4502   14 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE6qLbWAcBTYNHydKv1bixoCLuiuXjAGGSYbkFeJ1krnXpByHwo482EPLpG9D6pMx2KpgJA8ScBVbKZ7c8brt147jZkVKtRothgen6zN4X4jizG49fSjFHXVPXEiq9ak8nsk5q97Meii"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE6au8Dio6FijiGKB2vzW2o8P2h3UKm32pyJWr5FXh93XcQcqZ9huGJaBbcax4FWG6VsZmLFiu8bhANVUQn6FHkY8UNAv4XBakirXWzPwGKsbZzAnLpqNQRPmTG4WHwVG8ix8evLiwEE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE6au8Dio6FijiGKB2vzW2o8P2h3UKm32pyJWr5FXh93XcQcqZ9huGJaBbcax4FWG6VsZmLFiu8bhANVUQn6FHkY8UNAv4XBakirXWzPwGKsbZzAnLpqNQRPmTG4WHwVG8ix8evLiwEE"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: GRom81#5825   15 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE3Z2M53pHMQwULbDWCAJy7fyoH88vY6WjC5qtLxKwjN8pkrFUZnkZ64yPma4QGD7rXteycYzy4FQfxnJiBsoypyHWLxBjJppR9BxTTU3FMe8uib1UMmzJRts3KragQtw2z4mdwcjvqU"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsq6wRPFjd57rheXoqNMtLRGSux2C9JgVrBtB7CNE6cHRMpFufweEBpsXRNiGx1HMTQybZSdpQ7KrhYZUNiDgA4yfnzNPEmuwkyfQ6nhqs1Ss72mbQKUUGnECeMtZC9a6uqzfCYz7kR")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDsq6wRPFjd57rheXoqNMtLRGSux2C9JgVrBtB7CNE6cHRMpFufweEBpsXRNiGx1HMTQybZSdpQ7KrhYZUNiDgA4yfnzNPEmuwkyfQ6nhqs1Ss72mbQKUUGnECeMtZC9a6uqzfCYz7kR"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: novy   16 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEEokh7UBRsPwMwoBrafHraST4GUX1LuyPTPBMZrw8Q2qwupyD3mmWgUPCaiPw1NwSUhuNiPoqV65JiDvnvNLjfU8TTzKTWdAAK8uyukiGjea4iApyVX3TrkCsFouf7S6woBifyi9Acj"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDgtouu6VruaotDap9w7SWqZoRcVcTtA61Gp6TTK7VmeZM3gtJsVGzyecAK1VkzxWcEEYgJqtfBfvZEvmM2XGQsumWmAERbXq6XHQrcXoxyWSxbzxebMPVxiJbJGDvzJj4VCnjDvDzjo")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDgtouu6VruaotDap9w7SWqZoRcVcTtA61Gp6TTK7VmeZM3gtJsVGzyecAK1VkzxWcEEYgJqtfBfvZEvmM2XGQsumWmAERbXq6XHQrcXoxyWSxbzxebMPVxiJbJGDvzJj4VCnjDvDzjo"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: ilya_petrov#5431   17 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJgipgTE4c13SvUnoFsaJS5WjtnnjeJHqEyHYuNKwyaUgwprKbg7ThPxcbitqimj34xrHfNvd6z7ekHUQnXrSyKBatSVdUi7zyCbGd6LUb2mgoLRV9QMiXJSRtJFqurAPLbjEgERDBw"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDhVXjumSA4iVQD48uPAHa8EkbLGNCPrBx2wrJSyVGS7f3v3MrpMPswHS9CQwDH5DKfuBzQrje6H7PSP52XJSnGeWYrHKhXNAZ3jbgFnzxWFg6j3XgqgDqePxvsgpbHFY1PAeoVQ2TgG")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDhVXjumSA4iVQD48uPAHa8EkbLGNCPrBx2wrJSyVGS7f3v3MrpMPswHS9CQwDH5DKfuBzQrje6H7PSP52XJSnGeWYrHKhXNAZ3jbgFnzxWFg6j3XgqgDqePxvsgpbHFY1PAeoVQ2TgG"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: y3v63n#0177   18 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDkiDTMKN8JwTEJVixGsBbFW9peZYjAmnAqW9Ens7zZAaDVoxDZbJqUcwCr4762xQVZgJWFHSWNn2QMwDMXSVCMWotbtRUTYGPfKr6SLTsoaUFhuGEUTverd6JEmx4roYanGuTEHU9uG"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDiGoS4u8WqFTCQjsSffhQXgkeP12HFXj31J4KykSDKFDhUccbwVJ4dQz3QGSggi8pc37jVdDk5XqsaFnuobTfUk8eozZDgoTXUyAgj9T1BTyhXKDQ41PajSXj4gFasPFc3v8KCics9F")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDiGoS4u8WqFTCQjsSffhQXgkeP12HFXj31J4KykSDKFDhUccbwVJ4dQz3QGSggi8pc37jVdDk5XqsaFnuobTfUk8eozZDgoTXUyAgj9T1BTyhXKDQ41PajSXj4gFasPFc3v8KCics9F"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: GS   19 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNENC2dGBRkXn7evymM4hBCAdWhRYdCJroUH7kQJDVVGMa9UzzmjsHxkggENCV16p8iuGp3gPTN8nktK38cQuWWSqYNQkPVrqHvuLi6DSamvNM46C2FjBF9CKT5k1baa51rHYC1q9ZQbt"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDzxL5LEEt3oxSyMm1YnMZj2jj7FCtuLWLprzU9ym6Pnb7etmqqPYJPLjJJF1mjmjQsbK9ZGaZj8axGx2buMmrJ5AyGt353C31JMY5EsFicDXy6sKobAU88YW1TDwSeLtqnRWPepvoLB")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDzxL5LEEt3oxSyMm1YnMZj2jj7FCtuLWLprzU9ym6Pnb7etmqqPYJPLjJJF1mjmjQsbK9ZGaZj8axGx2buMmrJ5AyGt353C31JMY5EsFicDXy6sKobAU88YW1TDwSeLtqnRWPepvoLB"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Matt Harrop / Figment Network   20 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE5Gk8Qo4SjNMDtnTqowFBaUkFfWRwkTYAcgbimkUZYKGcjCJ2c6S3JsMpBba4JS9yJHAtLqiHednj5CFQBvLyiec5aRv2QRzMryz9Po6nTUzSvnR6HSkcwizz2mUbK1cqPadnagCsCM"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDvmBHKXyD37nDY7CTRAuC7rCFsEBWYmF5rRefDwWv2dsYysQdiC7XoK3u6Qd9GVSE7aetMYnLcfDSJVnCzBGeVhBvbLQgoLyyMwFPznPiwZpkzX5trqsp8iPi5GHopFeoDv3evt2EfE")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDvmBHKXyD37nDY7CTRAuC7rCFsEBWYmF5rRefDwWv2dsYysQdiC7XoK3u6Qd9GVSE7aetMYnLcfDSJVnCzBGeVhBvbLQgoLyyMwFPznPiwZpkzX5trqsp8iPi5GHopFeoDv3evt2EfE"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Tyler34214#4119   21 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE19E91Hwtez8sGyg4wWDUofdvXgqmDjGCF9R2EnruGedMriSM8HAJDfDeCSYhrUDrkh5LopxYSUE92LADCbSKPqcnRbeZ6U1ZCmeDJFBda17WCid5U7PoAj7dqggaec8oDz4a1phSiX"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNECCk2p5Zt72YoVYjoRYhSQbnHHDVWSUYViYiBPP6NTWYbxLZ2xXP9d1Jj2sjjCiMaRRmFzxKTj6jVftsVMvP5Nuve1dgZ9suZeJwkvDsM1XiFKmLyytYNMpwoVtzyeBSgFK2JQWMHjb")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNECCk2p5Zt72YoVYjoRYhSQbnHHDVWSUYViYiBPP6NTWYbxLZ2xXP9d1Jj2sjjCiMaRRmFzxKTj6jVftsVMvP5Nuve1dgZ9suZeJwkvDsM1XiFKmLyytYNMpwoVtzyeBSgFK2JQWMHjb"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: whataday2day#1271   22 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDypcEGJXZZTnLALiNfwjFVcGfo9iSsBtstXYfgvAduytLTcuZt1xasa7Xq9zzFERA7t8H6TwHLP9fiBoqPAUGNzF6GDQTaw73pL8ZQQLpPf3M5DKpZhJj1cfHyfFii2aSnqv8H1pPPB"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjfWWKZALACQPCLFaTGoAtdDoWEXeNuYRZZWChC4wbSeUb5tVn3UiSsVKt913A7btERefMS4GoEMkQWTs4TsGh21as6ecNP2HKfW6foxmXhwscDKdUEXqZRkCXJvNfz8wBjNXJcHaoK")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDjfWWKZALACQPCLFaTGoAtdDoWEXeNuYRZZWChC4wbSeUb5tVn3UiSsVKt913A7btERefMS4GoEMkQWTs4TsGh21as6ecNP2HKfW6foxmXhwscDKdUEXqZRkCXJvNfz8wBjNXJcHaoK"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: viktorbunin#7847   23 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDx4htbjDvrDc4HhvPJXME8rmuyoqLQAHRmf96EB1g1B4j4hWA5AG4bXnm8KUCRZ82pohj4wQW2AUL9zqL7UvSFMLtVm4UkNsP2GMYUXieNrsNf9V46sLrBe2MXEend72x2mazLfHNh4"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDrTpvEu3b5DvETffLubWnxBkGCdcJnoDeyW1X428LbkSPUFtn6KvWECH8LmRPP9d8bGw7QZtXwbtw7aKw81WKfkiizU4yrUiZzJcDRzCWmE72cathagoY11zgLDSP7YifyufKFvJr3e")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDrTpvEu3b5DvETffLubWnxBkGCdcJnoDeyW1X428LbkSPUFtn6KvWECH8LmRPP9d8bGw7QZtXwbtw7aKw81WKfkiizU4yrUiZzJcDRzCWmE72cathagoY11zgLDSP7YifyufKFvJr3e"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Bison Paul   24 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDfr8Xqq9BU5RcFMxbJkUoh7BdRBUbZCe31HZiEunJCFxHKePHwSKrF83EcMKEzTHZ1f9chtf5KPqo2nHo5pEwCDVecb9jru8VEA5LnWAe6V3n64JL3YKbvfuhpoDAZVgTMavX9GncGF"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDmhmmnf6r76h7rxQGfFergEYbjN5EEdAtDXdMe5g9v9ayYVzcs1Jow1iv2nB29G4FMwwBpJPtcP6kvvjNVaTtFKs8dbF3p8C34ry5yq1x7bsBX41988w62D75fWJNCN4bsmxtspdaCB")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDmhmmnf6r76h7rxQGfFergEYbjN5EEdAtDXdMe5g9v9ayYVzcs1Jow1iv2nB29G4FMwwBpJPtcP6kvvjNVaTtFKs8dbF3p8C34ry5yq1x7bsBX41988w62D75fWJNCN4bsmxtspdaCB"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Marius | Ubik Capital#9009   25 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDw5kxRqLvYbHasqHTuFFn7vzQEquf6FTe2yUmrxYzqZrjuuL1jW8YPU1XV79dmDHiXhaL9dMWAEGsAG8jKJ5B5HaahcnoEBg9yF2WDSBjgPPgXv8uA2fbmoQjhefTriK3MvvPbnhVrc"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDftGmTyYSThU3vsgXUAKQsREjopAj5MyeheBoYK8QrSgkcx93qjwo4Nt72N9UEjz3p5ye1zRVdQBbbVc853rpQHgaGN6L6oRSodY5veGmpwKaJSBXvzzDVuD2MGWKVeBJgXqpcK8RUz")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDftGmTyYSThU3vsgXUAKQsREjopAj5MyeheBoYK8QrSgkcx93qjwo4Nt72N9UEjz3p5ye1zRVdQBbbVc853rpQHgaGN6L6oRSodY5veGmpwKaJSBXvzzDVuD2MGWKVeBJgXqpcK8RUz"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: WS_Totti#4641   26 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEGL9Aorv8GQUD1V3Ac6bwZNaKdxQ7FaWYZFEjQCZTRphTeiZASFgbV9kfeSBaRMSvboWgijFXucNqmv1PMgdJ5vrsJF4ZftqJ92C4zYd2ootfSbLYSKASdVL539SCNAdXxdbtv9V8Ya"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDm5CdY1jj2B4EqUGDCE6WUyh4CbK499t3kcKK3wxSmbhNUjSbitwFWzUVYxmqMX7EBJzapFYxB33seu7C3ai5oWUgKLQesdxmxyEfbmBhVELZK29LKojLcDf67Fm8C6bFtoZAxgkxQA")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDm5CdY1jj2B4EqUGDCE6WUyh4CbK499t3kcKK3wxSmbhNUjSbitwFWzUVYxmqMX7EBJzapFYxB33seu7C3ai5oWUgKLQesdxmxyEfbmBhVELZK29LKojLcDf67Fm8C6bFtoZAxgkxQA"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: Mikhail#7170   27 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE2wuTgT9yk2jN4127i1jfqacFuQWN9o228vZEKRXU2erMsRnnVTkZQSkHeZrZreNwsbB1eBJXzSkqhPAJTfwiDSKNXXCgurMJwhWg3WsbaF8yErxaf97UQuJm5qr7GmaHy9Enj9fjxC"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDetSonXJbJ2D9Cdi8psYknDuaGyZQ9eUC34zSrfFmV3H4JZtkbB2xhiCkY9AtuDQJwRvV2zFhLt42zS27gx5cpZF1pqVTpkmb2wSHPjiF117TjNu5ohsd7V6WwjJ3aeDUTrGVjRbs6B")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDetSonXJbJ2D9Cdi8psYknDuaGyZQ9eUC34zSrfFmV3H4JZtkbB2xhiCkY9AtuDQJwRvV2zFhLt42zS27gx5cpZF1pqVTpkmb2wSHPjiF117TjNu5ohsd7V6WwjJ3aeDUTrGVjRbs6B"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: fullmoon#9069   28 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE2ZrFWdr4UJhcdx2x6T71fm92MxH8rwSS4enzHgsKU2dvkBVkTdCj2hecj8YoXyMkRjZMo3NuxYMGzUuiRXb7h1F3WWfpe5KmzTkukVt5Mk6fihVp7w7UL5NZYbCvW7LEx2tZmXSzW2"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE4ogXK7oM1QSUiueUQPcYkawNqyMekjmzg8azroWAPLbZAANxLBrYtYMHFVqjFvXNiVSbdnjzGZxixeePdgaALXQcNPhEznMzGgmm1geqynU9Hyxj6gd3icDJet3wHDBLCKsgGVQFFe")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE4ogXK7oM1QSUiueUQPcYkawNqyMekjmzg8azroWAPLbZAANxLBrYtYMHFVqjFvXNiVSbdnjzGZxixeePdgaALXQcNPhEznMzGgmm1geqynU9Hyxj6gd3icDJet3wHDBLCKsgGVQFFe"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: RomanS#8785   29 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDswTrTqKf9M7K9az384ersGG91C9tvD4GXU8VeSJCCZJbLibo6iM87EeBjrQVEmnkVC3Ev4QKvrq4X6reHKvQVpEc5z1icWYVTVV4nUYHNVZjgNjr1yHJBM1UP3E7aVEiVmPySuwdiU"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNEAq5uer5nTv9VYkE2YDJLxXUas342xjxdaXjEYUZfzGoNwxqv1rEUBdhRHgTyh5PUHjq7UstsWPNtSynUqFukxzdUkWa5Q1QpiCxV8vW7d3hHvbiegcGZHFiwR3mnN4Q5yAUfCPMEGB")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEAq5uer5nTv9VYkE2YDJLxXUas342xjxdaXjEYUZfzGoNwxqv1rEUBdhRHgTyh5PUHjq7UstsWPNtSynUqFukxzdUkWa5Q1QpiCxV8vW7d3hHvbiegcGZHFiwR3mnN4Q5yAUfCPMEGB"
      ; balance= 1000
      ; delegate= None }
      (* Offline/Online User Keys: tarcieri | iqlusion.io#0590   30 of 30 *)
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNELP4zZ6xUtJhypJrLMUadG6vhFCL7eLgSnGaQj8vQafzLGTB93Nutwqs6XDK5zZAjete48tGYy9U2frXEeuBq2X4pCno6Xiovvp5Uxi3GFyYYn77DCQvf6wwWdyHRS37F5v8suywUkJ"
      ; balance= 2666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNENEjBATBq6eLjfgc8QP23ePgyfQkYcdutjNysgH57Ms1QfXNo6qusm1eEprszssinm8v1fsPL5ZiNBeKf2FTJGNAyXHsREryG2xDYGRmQUWYm7aFcMMAPLZpASXjGmYWMjKFGFMgEuf")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNENEjBATBq6eLjfgc8QP23ePgyfQkYcdutjNysgH57Ms1QfXNo6qusm1eEprszssinm8v1fsPL5ZiNBeKf2FTJGNAyXHsREryG2xDYGRmQUWYm7aFcMMAPLZpASXjGmYWMjKFGFMgEuf"
      ; balance= 1000
      ; delegate= None } ]
end)
