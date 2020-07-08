module Public_key = Signature_lib.Public_key

let name = "testnet_postake"

let accounts = lazy []

(*
open Intf.Public_accounts
    [ { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVw9P7XQFJWS4FsAsiXRSJyEKiVLCnVw2mRreE7iWout75RvZnm9q46sed2GvBF9Rh972AJrnuhrpPfCDGyhgsJm6kxZGhP5x9CTdty4cpFA8FmxNL8gB2UPTweGnQ1svjTVgUAbb8qB"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVW8do8EqsgJFy8B38k1qdoQ1MW6UuZ33qk8eXTHu8qqoTMZzHPF5r6haHZbvcRgXdYoYJsWAKZwCRqiXYrHhVUPQyqThsdmfkMxjKKhPZrkN23YcAyLMpj1iSAdRjHk8KnSz5vkLBmT"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVxE2UzLuGa1MfNtZqnJzDeR4vqX4qgn6BQ1qAAub7UWL3g6RpcTrzK5ZPZWqfsR8rZ7wzzVqnQ2mRXDLX24f4yLKSsN29dazXfcuCokipYbQCui1Ce5waTdV6sGBCarFcnw2mrMPMvG"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVveUThKmUYTfdpo41KZDyn3p8CrLYnM4sZ9q9wJtrkW4tfdGCq2CFcrw2GnQyBYCdqFSDuasj2NSmSbwryhF8McGj4JDYFyzN8SckcK5AreiiF4impwiimipEkA7ovhT47FxyPzkzUQ"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVKwNDotyLx7YE7tM4ApVHFSzb6a3r93c8cV9M9aBud3apY2fbbHUm12c9vviqiZdRmVDyV6onNQvRdMsieSHtPFA5EsnaRyjnTMsWsK3VKY8KkheCoN17SM6gaks57WZajMTP4AVh6V"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVYDaPGUK9VzzxfSm1xy3hqp9AVJvNaBKi33fdXvS4nat1Aw3s6V3dCz53x6REB6UJxiYZYbHYb47Frn7eKzazVsD5vnDJZkpsxRi3aenw6tJfdgzPFoSmmg7FFN5UNEigzYUrbRhCzF"
      ; balance= 1600000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ"
      ; balance= 0
      ; delegate= None }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVG8eGaiychTTqHuqSiPtuUBD91WaTCbLv8UgGRMVn8oiDcE3w1fvpzhryydSh1aX647ZCTD9SNP8913MH8YGxowbFz6F7b34vpkCYLmVTsrF4pUgve94hqfeoPrATbRVeQt5gMHPMWc"
      ; balance= 100000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVQHBmqHwgmu4PDym91FLemj7qXuuL5cNe6YM4QAs68QhH3hQo5GZrvg4k9F9hGij3djbATFDztAmyWcBs3sthhyNZ3q1W1db2g1wMHimMUzZhchnvPVVGiPXQ4j5y1kmyp86BRKLzkU"
      ; balance= 10000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVNxyqjmkwqhJSeCsPY113XHqjZ8vyUkye2JSaD5rC1DEvUnUxzej1cAP5xBz6xnxYBW6bvsaiKZmtQuuLkqrMN74Cqfo5fRYrxZP5ywy2qfC6AzwPA1AsDD2i9Jr7SZ1WjFkTquKvjG"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVyzW4UP9qLTtEf5Y7TDAsFfoA9kZDZJbu5NwhDGxdPHQriJq6fqLiE4DHxDjQCUNywhLqbHSsH8m9pUN1epaoC6Ld7GEP98fJTZR94o2YzLeGcFKjUqM9BPYsSjU9hxqs9iXTFN6Ydu"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVutRdXhTQeNbexNs6xoXFzBGjLnxPxLt6By9TbbhqJ93rJxcuMu1NHYYGWSbb75PqwiCUiL6ZqfrfwjQ6GuR9ZVWdmr1xi2KxpKoELCtC6SAa8TK74unSkuxEf49bjESqfZhqHyVsKa"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVbKw5LWM95jRPEjwccYwcjPCTdiG2A9VYdiz3r9Dqk47LmvPVnZzF6Nm1xu7H89Thu9ZR1Y9ZmmFZNn5R4vUjm6H5yguABryYDGodAoeDApsKu4RaAXuuAaHACaqnS3du7Y3XLQWxcM"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVM3h5M1M7xzwXQoBf4qvtLfZ3jQ9UNeJNFG5qjFHhMZHSBzPrzPDvotyvauH9G6Wh18UG9uxV4k7t3SXDFdxN7yca6crqqM6GBFfGi6KpHZVK7xTNCkWPMJmQWFTE1z4wbPTbx2LC1o"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVV9KykMe7WP5bDQnKCFFj2QgoVT6Y4oikqEpKHFwKd5mjZh4Wh9qXTcfEYzKfqm5p2SwhyXFVuRXpsfPo3F4gjwkFZdHjRDi9V44hwXDsQ4bXW93s2dJWaScyaeJYeft646WpaGYLW1"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVJ55uvEd9U66mXLyfzDeKRg2tnTD5agA6zrzW1JxTBfrHzdYLRf1WtGnX2PcMmMUfNbGnyWg82rQyRpxQF4YVA8grrFf9NsHKkgXtcAbnb1PAtQFtKiEmYCuSfyYAwpHEG21oxtD2yX"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVx3vaPinGPHMVBgCAPBUmaqU27tjiUcwPM4A5BBkZx7igjPVHcLfhaPwCP9u1f6gyDqBJdP8WdQQLBNoZzWP38nxn3Aj8s9VDCLySvTGkk88zePsZCjCipk2MNii7cSNyvnJG29GCst"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVyqS1rbjrWefJ9fMYG4BnfVAw9yyG87JJaau7WWXAiKA95QchBQukueJ4ik9nb95k458SZ8CRqanPXZ9Hfeo86ZWLpDDgqiGLdMMB9YDwsUjNzuxtdmFfqUD1LBFKj6oNbAt7DP3pt9"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVjUwuSa3hBsnU3F23jp6DSUzF8MLLfZKY9GCkB4LYGDj7rNmaCp3UN6kRvnPRFcwGseQpaEG3rNySsk9AQFTe59z7TQL67GVpFZkf5CD7hzPHLgXzoJYpenDN8U7FYAAZDCkKtSUTDb"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVuCRX5kUfGq7Cy8Ldpf1YM7eZTzqXtxt1u5vgPoneCsurWCfzJ9TVK9BQbSyKrbmhgviVUbYCxDYwaBvK2nHke7L3fMMwUw135NLW8vjvSbcYUTjP7pU5LXSsVz1smU7QVd4aWGQVeh"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVtmTqMuPkZb3JhzDoi733Q6rYrCUZNv7oSdgtoYcD9wz8WCRBkYzKJVibUMriyMeXbDt3Q9oeoNeAmjx5W1opdrMg1y53nGq5Bjpkf6Bmt3wjcBrifo6KaVAKA49JvNnqysEHkPND3q"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVwuHSaYaSxy6dTCD6PmnEk2tnUGGhostBYHSG3ybFe5ansY8pJjQbytKWBgCi1iMNCiTyP2V4udvcjWhhWTa2E39ntuwhSKhgUvGiH3dPwCvMzN6vSBKwesKXd812zWziSa9seJhNdc"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVcxFRWyj1V9UAhrZQvdUhxmGEdncoRbr212vrdzXpeZ4Fjcd87sQ5qupWXuxYXjcTcWgtjvku2xnVX2h4mUNtxeUgsimQDpJgP8SJfTxNTHpjkqdpdcAZnpJSFBQiFevHJ4MufGD1xJ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVLedVp1StPQzRqw7FGe6MsFckHN7BJMTmvgCtLYJpg3UQs8nK1hwA9V6XVyzKqyui531V1L5t7EZ5KFDEe8Rxam4DnTCpYZ9k2KPyNWQ1AzoJjjsRzT7noxakjW9FKnMKN2fJJa16xF"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVkQoWsTiQAUXFrLdxnoQWyUqJHozRG1C8DRhmz2s7BHApmDk3KveLu2nvGLDuK5FzyigA2PFAnSk9MmAVqXDs5HaBpqXbEkiisstSMoFoVeZdjPWN1Bs73nZ89UjKiciJr4qFVub6K5"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVXdPRHgjWxwPUSRDaFgK6xt9gjB5JFZLy9iYdV5wrr5gwzMepxQ2Vzap2vBg2FLtuTFUPuRJjD58gB1qbm1Qk7TC1ozrNpeE5HbyeXvvP2mtwwrK45kJ6cJ2DnHx8wvDSyWAtiANndZ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVnTXETtBZMCW5qren2nV8hKPA7XZfarDaWMV24DmFCnnAevHNmmqJDThcS4yAPihyARHj116kxHfoPvWxbSFFA35EFEt6qTnFHpYrNNj5NygM8Lf2HQ7k9nUSJxPCJjJ7KAxQe46Czo"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVX66RtkYoTtM4f3HU5GbxKn6KeHg4nGyB2KjtRyxKfFokKNQ4Et6crhNXsFNrMwjVyYxFRnELvKD9mWhK6UScXcURUum5fqfkKGBowSr4EowQWSfdjDpsVbXY6igf6TX8RpffiFjnuk"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVFsCeqLtM5p5nrEQikzb2bkfi13LJusQzvibzpoJLYtd3aMU2MBykzsBhsCwSKJYzuEWC8eFf9kxmo3QhhasaRKzqrzSLTYvuqz7j6RTdfSPDkfhC8M21JW7Xntaajf6pmBUGjPYYcx"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVnNbFM4CbwpEgEDbm2huDWE8uMNijByxstY3yCi7kZ6kBkV8562JckrHm42xoJsPVH8yYua4peJ5KsN1oK2CxhUAegtU5BAFc5zxADdA3SaVWHAbJaUgGFiuFcToC6V52k74fJu9Zog"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVNU9yU47PdtSFUBp3jEqYWRPejQSiPjgVN46ruz4mJq19sCiVPkSh6rqoww1zFnZAuw7gRAowzxjG7N5vrozBCCfKXaMpxBpsnhhKBiF1Z5cBHH1zECKbJ2HK51C96JVbuQfa6zTcFZ"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVjXg8PCG1gajD6eqHP58YBuHNzrcpBWqDT31YyJP17aEUFo2j3xf21vhHPPGV3EAnn1euauyJkEm7UTrWfn8ZevJaDJzaDnXAz8t1ammZZ7sSff83Ypkmv9ZcyY1iCLnhyRPH9Aqccq"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVaQMpthEeHCc1eEtTyxCdX8xchkv5spJLyFh7PJB8Ue3gMuE4L4sjbnugRGGbKutAJh2N9omrUtMcvUYzxKFqdSPWY5juaBxYQiur86wd1PWZqmd2gpRcR81qu5RjRiA6Leeaf5JA1L"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVh4LdeQz614EKeNKUjLanszf5mNmBFVh6M1VnZsfCMdjAqfFPk9yRw8L2peZEwk5oZ2qJtDcVasEQHDLJjgFS6vU6wYXC8VMPmuGAhVSd5p6QwJsqbv2oawrNvQBjkNCrwtAp8WuKX7"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVTbpAZpfoG2GmHAYatSsgkfywH2cC3WEYSVxLUYRezAqVkiGx6ghk4v1ss4EzFmAHoEHhQhdknLWTyqwBBP5pveSfHwvB3s1XMqmkavWH6Y7nowb1Z9JHnyc9UKrbjtgSKq6WQj4LKs"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVFRYDicwWE2yf9xiwgmsZD47EaZFNUikDQcwYevG9vNMyzZSgnN38yfBGU78PVP4ssHQmpZi744tPemMptXCqdNpQwWfsCC3228onQcxxW4q473fVPqoj19vRp61JUeTCLVHZqQ5xWZ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVNo6wbxac5fy3rgWYS1HKbyC8hb8W14WRr3cPViXRXjErivDp7VYTUhkgbQdKGXGptxZBey91jWEYCNVmmNAU9QrtCKabERrofZeBE8cfKA4c6VBE8as6MaWuSGaFuTipZiqUCsCP5f"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVsnxSQW4QYWwewWqdZ3VMcoC1kVtirphNK3zEEx3UcnwpABSj13c2iyL9w5bsL9KgFBXoF8ixtE1MPAyt9k26VPHRCYHyNtK38sPq5kB218S1w7TWk8mAc36GEdje5c3BpG7LLcAG66")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVzk82Kp5t2RU6tjr6GWE5tZ2x8mBEZNWYqQJixod1TTw7tTbs7FFce9XCsPTGuc3QLuR372pQwZTxw4wjcz1K7ppk8aX7ZWxHYcyJfrAr7yDvDbuiKosDTfGxeN1fcy3uM7cYNSVwtF"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVtkNvH1oSLm8h9XKrf8XFcepwEJCTX4M7tppHjNkkSB2FZ7mmrriaFkTVY2TB3aQduDLXhCwpRCCsmpf8s37bcm9kzfXcMEUBqD35mHBY8FgB6mPLuBJaj68V3SQPWKXQohdUzFJWZd"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVciL8orxBmoa6DeCwLFSuJTdWz9iMzHtCcuiezRwMtWbJDj32nP3JPHrrkwpidTgx8WiF7zuPoqkFmRXBYHXcBow9fB6gGrafiSQZCrjjnvA7E1635kko9RTML8cZAiG2XcFs9xbj6w")
      }
    ; { pk=
          Public_key.Compressed.of_base58_check_exn
            "4vsRCVZR9FPpVMZCksNNu22yd1raLKgvBEHQmx98evVbFMS1mJ4pnJ2jXaBWiFK7KNTkU6CV6VPXELPmmm5YxBuRDySCw9qWUvKkpBMSqYKGox6SUDR3E2tnuqpyWDLRPJiuxvC8jL8jWgSz"
      ; balance= 63000
      ; delegate=
          Some
            (Public_key.Compressed.of_base58_check_exn
               "4vsRCVWRSCQNrGSNoojhp258eeKCeXL8JVefQ8KpZ9DJhFE7AkcFm3czHcddUUbkmpavwuKW4o2QsexWzHnjwuD3ejGkGjqha3n2omrt1fCHN9NWN24jfrqrDTkoZDhm4RNKpRMX4jixX631")
      } ]
*)
