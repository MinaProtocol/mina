open Functor.Without_private
module Public_key = Signature_lib.Public_key

include Make (struct
  let accounts =
    [ { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciF7FJGCwcv6fqzfcaPZULVctz8faTjMc9mVzfRsiiu7oYQ1CoX5SKcn7pYfE9tSenLTfQDBqiJzrmJqnaJc1JhQZHbS4Eh9sErNE7ri4B8gsuuH1BfUfEb6KJqv7Ps4fHZJzYXV1fwr"
      ; balance= 160000000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciYD7fzw8tarSegqjwqW5S4rqnYhdW3PQUJLVB4MbVyatN4A3TuFgxSvwhiivsY7hRU1zmC4WjWUGhyqJu3wAJC5XGomiWoBTYdpw3GSyHVcUMS42cT9WRePbgdqmXxynFENhUb4ZfCF"
      ; balance= 160000000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciUYrLRbzRUqrDATeF5UCAKztPVtYCYLP2XXkzdEhx6QZmfG5fvpqVQuF5osTEqPHhegVs9EYtgr8bn4zk7u9Ckssmt6pbqad7gVMnCgG8eTakteadNgwK9cyVP3h5cVEs5ohrLmtUKU"
      ; balance= 160000000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci4wrwPNRG2crsHXBRsvm3fsowXi8KxQeft5pEmWwEaLoL8PHHQUaLokQuAtyjq7MMNwE3UEmpzap55gDqX7rWy3auUGsnVFKAybCBVMfnGgjPuimXre7FweRbVmpDxqMthuWoGT9kHz"
      ; balance= 160000000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3daA6WcHr15GCRtnf6VgdzEFFxWgGqKuFLiLnqsungR6T5p94RyywYX1ZXbeZTfEqWxLAWB6kPtFSjE2RHaqGhdhdqhTW36npQ8J9Y3TSawPq4TE8LxqeMyVpDX3xbpM9dftRNJcAr"
      ; balance= 160000000000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihT64BrtrravDKuWykrBMhGZqXN4ykPybA6DTNBvpZPQALqwmrM7YNuf6txkMvs9HhCfdxCgiAzQSf4v7JEpR159YgXM2P4J7XvxXsp6Zsc1NnZ4ELJQ1hCn33Jgv3yX2PWyjHd4ikD"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci5zkEwtwSxePqdGYaZbrwn9FvWHdoTmSjeMdAdkkEKptdDqnmE4UPZSwcBrTGXR3G7GkazxNdqRkd7mWW6Kx33Gc8yj8JaDMmBfqnJtE655MtLi9Q4Di78DYSQr9hwippGSsMA8W7Bj"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9tm8dUEDSnyRfWR4PX6KjcpJVo1P3NCQE57LzMzqaH2EdCk6oUt53FhdfeTHYRCE6pFysADQNrKynWNQPSAMexEcTy677mdDcJu9dZBnWgCCukwkhxf2XB8UWKAYXdTcALQ5p8xV6w"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci5AmXnuT2CwRRnUfxmbKhuULZkz6VedEhZ9pyrdQVWYimRuev4uKCQwyjtwGUFWFBvPVntXyoWx3bxmijBPPHaK9N1VPS3emFVc9RsawyiH6ve2G12qRWFusr4JPefr4oGpNorNzfoJ"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcifgGnBZEJCAsmWjuvY9cfkteoSJQnd2YsbZuaJ2TkrMj9YujwwRvwc9FGqwHjrqZYR56HNKsoNdaqXzKH2jhmxgQzkRK6WpdHmBgs8rNu7euzxxXBu96fYUfew1BQMTiT2aonL4Cuu7"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciawK1BJbPZY2bJD251PLAHKEcSMoRVEBfWKQzdPPBQnGHJRsM9cagWQwawbmgfnyCzMjA8EMWMBzkjiuFvfLxEDpKmeTF11p1dV4JLJVkvwuhaW9hxs9vkA4C2UncUUimzG8ocB3NVg"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcigDinkqkfqEPMszjMt2B3YyiXSECx1zc2U6HKCxNYyRKaUF9U3tFtQQ4LrnA27Yw3WTfC8E8cyDJT7hVdqbS823KoimBpEXBpNXMEpWDxjHdKVyr76wNb8WmdEKpJQSPP4bbsMqV2uU"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciG6fusWYWcYMtrhD9iUntcWFapP78KKkbttAajv2dzASa2xXKbCF6uDfXA8tfhrQrkSn3NHsHD99Aqu7y1kCtFk7RLWSwhnhsp7hdq4bpFFmKD14Lr8b6PFCrz79fVNxHYUzDdzkJ1S"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcigauU3vZ4TboPBffcztruFrp4DA9JMvrkrmG6KbgQbDw5MNJaRNezAbZ5rectDaDqSpVAPZEnd5gNg6Hc8eZZPY69doRJmULcKfdB9A2eSRdXfRb9NNEvkRWknJofU6TeMgDDiTMdCK"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWWRusSFu53MnG9LZZ66isz4A1apXbHFvmJGjeQuieyrKNGzjssr9JchEqHRVudgEcK8Rz24zcsAayacgJhEGGyYeFsvhwwX5Q4XY9PRJ2eo66KUn2dQq3hByYinQxcxC6RBzbjieuD"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciayqfgESjLXdcF4UqF5EEiWU8pVifsNoZz3gN7cCNdnw9p7mJP8wvU2iF48qNDCWmQfbbZ5jzDpLFAmjF9ZhgyXEERqv8vqBfAyPGtoAe7j5BhK7pDgA8i1N9pFPSXuamgJypxYjv4t"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciXPvGQbaVHTVdkiCrJK7MJsyk9rRXyttehsABWZV5jy2H1TEY9BpHaYYceCF6758c47DNsR8gBYRtoTvW1nNj82KvHmdjz2oHHqyQfCkjeN9R2cXTeBjHj1fqiViJGa1APz6odXiDT6"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciFiViKZtCyCTonhfAAaTBTCpch1qFsjiCgsoSDZxreBcxBZswpQG2CHwm5wS3BCzxv7LYVuiNeiv8uLJ4WCA3rpJWkwiziSpUJN6s9X81Pmk4dyLq6W4uz3GZ2CYr6Jqrm1boczs9eU"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAYGavGBLT2UDyXJtLUj3jdY8udnT665QRxct632YBc2A4NBwwughTNLs52DqV2C7jrvgnuyKcJf1CZyJzkQTvqseWomJrkWfGRSKJJM8XSMorZe24zaaV7XEjKgK4nRz8KZqFg2NDP"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJAiFEDF6c1FH7cGumgWEjVW2JbCbw7vCuh75dTaUz41XYTWjrSUvot1aMvjwNUM776tfM8ch5jWPgffgU1fGeLwHQdy7uyNXJWRgZrxPecNwJxMHRRYmW8Agmkkt5q3Xd2sywHyHwy"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNcihJz1wwWQ4UQ48S8cazQyZ1yYHZnTJpw97iTeKSYwApiqdq3pLE37gWZsZRDwDvsvSrAMLz5L4JysmEupXos3D36tHdSmPjTeB8xMvwc5GcbhFutMUPuWmy2Z4oVyEt8x8DDahwWAUr"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciGbjBCHBdkDAq6LkUtKJShSTLS7oXDrTaUm1QGxpZJ2vXkAVR53nvwjdruaAjEL683kDUuNktcEkHCpZntVDKwez16oYM5rM7MCJWckE8b4RkcnLJKZRbdPMoTzxfYQ9RyFesfTHRFB"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci5U1kgmJVXEVE9FVzBxytUNZRL77UP5sqGWfUa1jcepetTrv8b8WfC1bQw6xC5duVmfGa1ma8dSu5VfR9Nn8trqM3mra3PLjtQUcr7jbGVXjUYe7nsq6DavhuqddAh7e2ZAZ9dQHBa6"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci9H6YGGpQRNuExYyFzwHtSAWUPjhDR4Hcb32uJ1yttrAW5ECYzKckXiSjwL3q2Ehaimq3DjfL71s5oX6hTSmq1rGwjQhMxEqdbPjrk4DY9JhDcNHfhLqUwAukYMDZuXNmUbvkPS9W3b"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJsXuVrdt9cP26QZDbzTXBphFrCvNikBtJwEToSJhv3GTBJYPo8NN2wDFE6cPUEr8AReEjTom8uaQ737ThraN7cuTxxms4LqVMwxUvPMZFLT3TVgC4pojEvkHCRnJbcuWx94v9PWHtn"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci6vZfbTaSFrVLyZrPHE5p4fxHgDQwmqbYCvT2BQd3uz14m96vCyPjujJhuBVjdkF44vZPEun5Qi9fNMFqyKZdZx7DeJXRN3X1NCMJHrrTFD72dQFC1iQXFm5D9S6qBFPN72YBEURnUG"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciCeeQdWhvjbMvJjCaS81atPRUHi4dY3tmALJkWmBS5KUdL8i4yWeYPV2Ug3vWF8ro8QohVoGfCsccYNsa23qAuKccAENUw3dpCFsQp17jhfWCVVMDhcukPPetTMfhww5tbL4HtrPNgw"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciWGtagfAjTJY8uHgXamCsnwnZRDujwK1darMtT9GxGybtDk75mGNBbMkZCe7xSjBazxzBpt2smq35H73whJ2fCGahsrSFigzwUnHn6SGuMKiVd8PVhRYZh1QeLrkhRTg7rFFgB75bFk"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHRMgV1D3pQg4yMZhDwGXz25tq8kBmVWf5PEVi9AHCQLfEsaEpmNJBWyk9jpxH7ys37zyg8bDMC3L5Ui3x1RLh3seKhbUeTAj9zjasep8LyrEMYKbrJVUA5gsrfcvYJd5AwQSzqQrvJ"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAhnDV8iT7sjYDMQqhHNhaP8AWTTct9LjrwjfSyeDmvfMT9asxWDtwnWn5Weg12SaSALnBNyYqqdJQUAnKTcZax2rZ1QVp476wBpxc6TV3KrU9T7m25C4ewT6oybV5468DpRMpXFda5"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciAJVWvkp2GASTjM2d8nb5DoF4msuwtYNjZpJHBhAiswLoKSmGxFLEADgFZhwaa6LZuUXcfeLrtDCXymRY6noQ8W8gYuVbx1WFoNyDMryXtWCxzxAxCBphgigVYTK42W3PazgtH9EkKE"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNciLbEmF7T4khzmrsEjNCj2HEZkKYSdfJixSdSFXfxS4A8GoSw2g8nhrBr9HucZk6dfyBUZFwMGt8RZUHABJr2dFF9aYyfW3ut14UEwzysNYyKjUdo7ipy4c9dsuQKqpK61RgEmtmeJq1")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciHifgBQ1KS5a5f2d5in4SCUwvQ28uFj38YdLTNEEG5WrUcysQHCd812oxTz4P4cCzfg6M3nzvfXnTDT4YednFoipysdeA9b7b55ermYL7tFpnqhdmLQXD41H36H9Wgm4qraaGdMC27x"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci9yhyXdty9vH8fd5SxDGk2w4KDMuyi9Vx82KkbaN6kSZKhmKoBEPCu7y5wJ3p6RVezqccW6WBFcMXpEy6aJ3PAtBBquzyhzFVRrEmkFcRJGsRxj6dW2mtbH5zWkRCEtJhswsBWHA7T7")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciGJen1oCBQPPiFta4CWMRyUTgr7wWwzTp6NZ1ZRKUm7iiu6V3eM5iHquuDHPmWX4iRsPqgEMauyUtQVfcHmc98UE88fJwjR1f6s1nTM18ewVmGVAHrkjvzt5kDF4V4UCuMvgFtHNZcx"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcigrJUc1AHHGk6vRjNzGtVdwxm52DEGe2VmRNrK12nqmKYjorpyoQ1X6W4yeZX9aE51sGLPsus2iGJfGXNyVqmmE1DJqf4sX5Mxd6c2RSeoHRUZj7rFgEw8ycZ6ZCfHbF2UeB6fYjEG6")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNciJC7VPY6zVs2ucge5TeLrh7EgNAq5kMuwh4uCNm4T8BSYcc7GJTNFQcJftRCFmrFFU8qoEkuxGJGSHe2hVHLLFJDMLJamqqCNgiBp7GWus3ycitynS5fgaLXKWqj24Ceq6CR9Ktgwmh"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNci8fxtw4AhduBwKVsNpqJdZf2n1JuCPTa8LFnDpniTuRo4VPqYFMtvS3yhXmGjWBV72vpoHGAvvRCjEA35agWSF87wYy439hfxuCMpLd1fWdat5QkrqTWdxWvi42BFbAUaheGKu2k2kM")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "tNci3NfqeEkuKEgUZrEWVcGjJP2MCsxUfspouTrsULGTYnMQLDqwWcFxva9BZ3iEMDvjTCXzw3kdXR4CXeqbM7zLE4Rsfh4ep8yWs76BE95L7CvgutwW8wen1XnVij6Mk4a93xSAhqrC4q"
      ; balance= 6666666666
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "tNcijpGFdrgS5DRNEFJRgdurbnJdUGsmwNNZRaEVajBp7NMJrqjUaCHdk7YrUEYuzz9HEYdAKcL92n2nWHz9PyDS3FbQLnDcj953PYxaq33iPkzHoXpRBh61crzWnKYF5xHcDy23QyVW3t")
      } ]
end)
