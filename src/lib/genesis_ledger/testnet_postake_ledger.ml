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
            "tdNDky3tTyWUdf1iccjh8zqga1yATQQ6r5Q7qdbtaVHntT9ncGsgRfHiqHsJsNiXUSzSTDyq2FRK3eJC3XNvf4KBRy7KELNKxQCsj7ycgV3XxPydzALPMmjFJ4v7mASXLMYYaAK6Dkqk5f"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEHktzZep3DHVJJxvvtVD91ZoSvoLgtxAL7fCMGZC1Qtdso28DuuossMggsBgJkbhptzH2cFuQ7U5n6FaZraxA4sB6ex3xDHF8gEgdNYisfAg5n7eHUz4AAikM866fc7hCk9n7wrwMQj"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDeLpBdTppcxxoxJzgAQFpmzzMkNjWA9bhcCLDDzkd6sR4y8rhpKfXrfMgxMviNK5ncc7UVx4effUxpNNqpwr7SDtopAin4dSb4wkDXRAax7dgnvTe5p7sp7DSmKKYPe6Vp9hEq1En9i"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDmQzS1Vy6TeTND8cg1h9Swr5CJNTa666Yxj9QHKAQ557PP2HebGX944HQ71usJmLYCXRPXy1X9RRs4eDxwNFf5koHMsBYjK3MSsBMFD1g7VuTXm1tVNze33VrUbDdiTuWecdXBnMS9R"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDx1Ct9JvFYHbwtpggvsMgpZGn2BoG3ny41r5CNXhDiaYcdgjQLYTrrmH5BEAqyvTtvbzEeQFCGKcNUp9HWPyy1P1DdXTHwnPsNLyvf19LvaBwzyBZxQqPQNp6vSF9XRULmJPLGkvg62"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDvdJxhHMnaNNgT5WZVmvvNFJHtw7LKVwNsZAVKR9TqDEcCrRGZvgM7b39r7NzH7G4P62HQt8B3JWocvxqpw8sfZm45ccaKn9eshPLvr3SdShbmQNHYNXpzYS6puWsoCvA831yjqSPUo"
      ; balance= 100000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDyEyfcuvCxUUTujmmFLhPd8P8HYuaZPnNSoMzbT4avy4HRpuNYzH7x5bpcX3dSiK8BPmhW4sXzLMRD4rWTHqVKhjC9MWb2CSUwZTKSpHkqn9g9eByPqc9r7J4TEUPoUi6LCsh9eHUf9"
      ; balance= 10000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDwB9xTurHzqdBkt7RXdbEqhLNsaYzXjqWDPeSDnz9FmVDT337y8tdHXepAtdDeoXD2kg5BRHi4HQoTTeTepXx7JwEXN3wwE7LnP8CNxo824crgNLczC8yWZFFwGJdZxFs2cJaLprHWk"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDiGoS4u8WqFTCQjsSffhQXgkeP12HFXj31J4KykSDKFDhUccbwVJ4dQz3QGSggi8pc37jVdDk5XqsaFnuobTfUk8eozZDgoTXUyAgj9T1BTyhXKDQ41PajSXj4gFasPFc3v8KCics9F"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDdpMhCpqdN14EwiQcVHcpHCqSWnxZtf4NQcW5eg1CHXXgp31gncmbUQUAseQmGUE42yaEmJ4iC6nyQkx6QDfMWAzVRAzV72oecStJbG6hJ1fMKJSAQpVTqUX7sPjW6NEJHfjqDFTDrm"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDhYoFAo5VPnfvqJnKAFW9uvr9QEHXt3VMVRLZN66KS8Lc979pZKr4Xvx2sFacPmkvc55vxkzRB5xpfw2cTEdqZXsTEpQ9FFnF6AkB1UDs6bLLPLS4r2BckTvLJdZT7Bx56QxKT7vsmK"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDpsd7jAHMPj6sRtnBTXcuA6aSSErr9UiMzBnxD3VijM7RkzxnRHtf3QEbF5hTX4SQXziKbvab4tcbDALuGXo1uXVbDbKWWh2hHZRT6wdr3fe8ESgRSFrN8PBksstKxAiE7np6JN6T1m"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEFKndXucQeZHKicQU6uyRCbKx7LK9L9tHiDxXsuSF1EbYMrFUQVxVQWvJWWXj3muHb3Mk2ym4jZfS4wjGTcdQSEX3Z6LiW7QYau4CeMkHEymXkKjDoLGcfaYctJmqNW36xXjBueEuq2"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDu4G4zoioyK8MDwoTst3eAG1LqGhYkypcXzJroaZ7HrroUJyMfD9NJtnQiRrzee3eAQjKYDpRxr6doJQFa2yC9XQ5rTvaRUzVX2SRFPpn9PDZAxncCGCUc36xAM631546jtFzteYSmd"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDsz7R4hiB9zvEcAz3JVfcDeJnFWPL1GnqnR8WLZPwPHsqQGkxwN8a2nLqjdiNJW4QZWhQ9wVxkZpqbwpowDoS8grzGUiB1grmCf7wE2ua9vJ5D6Rm9jh7iLAYcyGEjoeaXiWLxx1PXf"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDpmpmeSBGJxnXXM4cYeU8MwW7sKmxnNRgRaXV5fJXoei4pXBi9k6HdFDAtk8dmqH9WUgjQf1eUK9SokZZFFskfAKr96VwN5mgXJhcqSH59VccdJ1WhPrGT14hJdX12KQn4hfQANx6B8"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE58ckSJ6BP9wC68GYCuveaskP9f9Ji3wgnvC4TqgVkNER4ppDUYTENsPx184dZVfY2BgE2J1apCpAjzGA2Ea3WUry1Ec4xt1wru2Q3AwiXKmkTQQan6rzZbEkxkf9ojYWcC16128tJC"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDoVpPW3trubihAs7GgHoP1wZWT5MSQmQMgPc1DjxRK6Gc8k6n8BVWy5BSe8YTzmZKJkZPtgzKVkM8zJw6T7TjfpXBBLYTe5mcQrDEtFYJiWZYwk4F47R1gHmbpg8Nc8iSGGGUfHXesm"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE1UWiabyozoEdMXKVQXGHf1UcjEU9bZiU3GpBFQmGcBk3Aid8vyEWDMZWajDSGNamT3hwSs9zm2dWPvLCpFerNdUNFfGEHarg9ck1SkBKUWoCFEW4nPbz8SZesEMtaG3kVvhfThcCR8"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDvaMxR7Yc1AZeVU2hT68KDMRbMiCE6rcTJmibZRPGx8GuHsLJyL2Chcmg4MWRDmGDmjRZYBEWytpXHBKTuqqSWJGP7yvE4s8kACXzR4zNnwh863CBcw6W2TLFvck8g83QKsAb84z9aY"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDmavWUXc9KhgovMbt7YZdcuyq93ttqYBEc4ZHs6BD4bpXfsccBo2qDtS7nQStGCKoLS4MszPKAphRmjYgT5XaNsAXR8gbMEMF34vX23qx6ShNvkPZEDPCFgviGiBS6fa2yb4FTGtiUQ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEEL6sLHJv54qEZ5292qHdkp19xz9yW1FnVY1w541XFPEPL41arm7N3kcZMdexrN4zH14QbgUb35vXnhQdr4YGAxxFn8T1ZLXD1zqEfifcCoAvcn3e2xEiFgEjdG3Z8LVm7nLp8DaUZ4"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJwDwiHbV3jRY8RWdfNReHZEcC1DzuZDmKac8dVMxXT8H3ohqx8KoKhNYyEEx3ZFfneUL8BMANLzuQLvScSwDJnsLG3v6NjNwK895XkWueJonSNRMgeDqKmhggvt3czSreDu1zfRVok"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEL9kAz7rGNoWZcTCWFB8G1KcZHTTHGm7tsa8fHC2dtc3AgoaEMKSzc9ArsvKnWnTrbtipm734AsukHPujNKSqDvSPHrdNtMoU8uEzYZ9v56TAJ9G17Ng7LmovML6fweCK32vNk6cSRd"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDxndW7yXxGfT2Cx4Lpef9E5ANXJArjVkmUNxvLWyuG6hiwuG5BEayFxFcQc23XWGx9sx3nNKCs4tsGmhqzKMA5pjtfKSiGhQmkpNb32hjmPhn8vQyCXPVxFNLmwXgaqFLxhdpnqu7ca"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJzvdwSXi57wXDeHfh6yiFhCRYwC8GeN1Nz6TfDzhnfP3Q2irbB35SZR9py9HgPYgQo36ujZP48bu58jdWUF7KPRa6SFudDYLFsdJdwcYxyRBFPkrei8U1JjbmSMhfsNsZDiNMXhjda"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEDCVnTuT9u7smRFvKiiVYXGu3cMtwLXpKRDuyaa337YodspbaaaTGavGuE2ATdZXPoge4Yx2QFtduJgCZhuCrNJmkfmgFKuAWDFtiuNddhbtNX4bXoGkupZFh7vhR4BTRmCFWX49UMv"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDs4BCD1hx3etekjaB8MiVpq2mfh16iRyM3gX56fzq5mZypFdL9cjTgs3PCHQknwtThUPatg9JH4kq3rYMtN8cqLZDQ99Gn93QbVsbvT8BCRETNtokLMm7xwqANBY5qevVJKxSWgZBAf"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNELzNRWAoicpwypNXDt1GCjEn8CgowRNByCgMuG16wgcgZoXP7Kp8t2rPMNvHDWLc84vuGVKv2w6ts993MXHsxJXLYuRUCszgwoS7MqrYKyxqQoTjaydRqqXiLQEANCVmccUaAYkDS3Y"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDe4vHKn7wMawmvndgoMrM27dqeyx6pE4w6jd6Mn1tb7KXt8zT25SnpV5t6rqxtgWu6pFfLfbMcNERSqoofoWxhHrvPNB5QiAZe9mWnyYzsVXNF2Kfqd447dLjNAzk6ykC2H18DynXD9"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEJq3rSQy5XU5DFVprevY1LCTN24EiauqRQ2VvHeVAsGNWjpuacvzKJEkVMtS7T3iLg98iTzhLNPUEnuLnRwj6mcAssB5hukeScoyUeimiinDgPW5pipFXZiuNHgDaCNo3WoYh7g11EU"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNEN2FhLa2FdnptaBozaYBUiWcter7p4inQuCbVar9MfdhRPT9RnSa1tQ21FdUwd9fxKWzimi5kYjdFRxSGkWGEjRpEA77SP7v2LV2GGRASDG6WKkJTVbfmeyBwNLBTHia5ZiqTQHQQ6K"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE3fuviun7uKdXvRd77HGo39FkL8PXLgBXnGwtGviEEqHZ6uti5aZg2L2yoHKTPs4EiFQb7FwmL7osz6LwLvhFA7D9cZ61N9iP3XwqQGJeasubu87nfcj6TyDmXi8PfhBTzCgcrBaEEt"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDs39Vk2rLLy9o43yNVBFrouEY9p49SHQjSyV4vvX7wpi52x1k3Eykg8soVmwLFDqJBfF3vvKWZuz2xjaQT9opUA5P2miTpJwP1RGu9vm2mM1gFcZxNd1fHBY8Jggezr7We9qCShZwCY")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDkYC7a3vFoSeVqxcZFpd5F1vswktvgFCXtDrF37bWLUE835MTdoRjMhBthfADbopXTqADQeiJz9e4mwrx9fGixEsmfp4knBfdAG3W4YEpw9sKuYiXuydyip4pK6JUeZ8nZbCXnR48PR"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNE2pXYz8vGxvqVjcA59pw2qfnkotFdKeVnnmKy1Loh9HXGnoHnLn24Mvsci8GQM1EdMHSs5TCWxVjGAU1ysfKSWZ9kcuJV6Ez2bExyXdqy2kRg5rJCHFX6Ek6oRNve2WdmDnvtswjtRZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDfMPRGkKNx89t3f99bm2rx8vQ2pNVesJGWn2XnoRjv8LuiR7idXhHwkvwniLCD8qUu5J2Z1zE2gziXdaCQBYVc3UBkEEpne8J3wSa3Euii9ht8nZnfVV3GmHmPSwaAq7YcZ4oUiyTBf"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDypcUkVoNSsbdhT9ytXwVxxU2ECEhaLsgq2ceiBzRxQonBtxsofVs9BAjb43BrWf5rUs5ewRyogkiaWddSkGNhXQHCk8FtJ4HDUfPARHMYstvEP2h9CWuE5t1MdUD1Q9tXDPJRMy2qq")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNDq1qqFyWAsxif2JqRzsepGULCSfe72mHx7aGxGSy2jZp4QfdKKGxxsGEd8cwn9WJ8oeVZ4B6TtmXrB5Dg2oWsatRzpUXSLug4cg3xcXAv4At4QfNJ9oD9RQjiMXRcdFtnErEVumUGp9"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDsh6jrSfinUQdrUXxD4KSNbTy9HYL5eX83RXaYSEB6CQMEuyTrdb8vkUuKdpqLeNmpw7qppNKcNoZzKAJDREaXAFT3iz5gvJbxVoXQQ8A8En9k24QBD9pjbM3WEVY4Az5arf93qnyGW")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tdNE5hh3P5aq8A9nZehrrKxsvoovxEHx9t2hDec2Novay4N6Pdq89W2YNkBbruYrhdLppwVZPqYLf1ChQiZg98MbJmcAKVfmbpeuQmn9WBmgTwD8a7SwTd1MfqPGHLon9GYVA2aw35C9mr"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tdNDjjAwyjgvNgU1x8uWs1n44H8vK7UGrRLvXzkcv8iC3Jw9A1B1UDUZndgBZh6zTb23pNatt7ujfTbCVjiihTZRMJcErZSkz93qE5Ue5VpAJsvaQvpHQGj3XexP2fK6i6xMfQArSvcXWV")
      } ]

  let compare acct1 acct2 = Public_key.Compressed.compare acct1.pk acct2.pk

  let fake_accounts =
    (* hack to workaround duplicate generated keys *)
    let enough = fake_accounts_target - List.length real_accounts in
    let too_many = enough * 2 in
    let open Quickcheck in
    let too_many_accounts =
      random_value ~seed:(`Deterministic "fake accounts for testnet postake")
        (Generator.list_with_length too_many Fake_accounts.gen)
    in
    eprintf "TOO MANY ACCOUNTS HAS DUP: %B\n%!"
      (List.contains_dup too_many_accounts ~compare) ;
    let accounts_dups_removed =
      List.dedup_and_sort too_many_accounts ~compare
    in
    eprintf "ACCOUNTS DUPS REMOVED HAS DUP: %B\n%!"
      (List.contains_dup accounts_dups_removed ~compare) ;
    List.take accounts_dups_removed enough

  let accounts =
    let all_accounts = real_accounts @ fake_accounts in
    eprintf "REAL ACCOUNTS HAS DUP: %B\n%!"
      (List.contains_dup real_accounts ~compare) ;
    eprintf "FAKE ACCOUNTS HAS DUP: %B\n%!"
      (List.contains_dup fake_accounts ~compare) ;
    eprintf "ALL ACCOUNTS HAS DUP: %B\n%!"
      (List.contains_dup all_accounts ~compare) ;
    List.dedup_and_sort all_accounts ~compare
end)
