#!/usr/bin/env python3

import json

content = """
let vrf_winner_keypair =
    let conv (pk, sk) =
        ((Core_kernel.Binable.of_string (module
            Signature_lib.Public_key.Compressed.Stable.Latest) pk), sk)
    in conv ("\\001\\001`\\232/\\r\\250p\\253\\234f7^I\\156\\235'\\243\\001\\027;V\\249\\192Y\\158\\198#\\143:\\2138D\\211\\202\\022t\\212}\\205\\208\\193\\174\\253\\153\\192\\192\\215\\186\\217\\199\\218A\\185\\187\\178\\165~\\241\\198\\224\\149\\184\\152D\\130m\\b\\128\\166(\\209\\022yUK\\r\\243\\223'\\026o\\164\\170\\150\\255\\2234\\155B\\227E\\191vb\\236]\\000\\000\\001", 
     Signature_lib.Private_key.of_base58_check_exn "6BnSKU5GQjgvEPbM45Qzazsf6M8eCrQdpL7x4jAvA4sr8Ga3FAx8AxdgWcqN7uNGu1SthMgDeMSUvEbkY9a56UxwmJpTzhzVUjfgfFsjJSVp9H1yWHt6H5couPNpF7L7e5u7NBGYnDMhx")

open Functor.Without_private

let of_b58 = Signature_lib.Public_key.Compressed.of_base58_check_exn

include Make(struct
    let accounts = [
        { pk = fst vrf_winner_keypair ; balance= 1000; delegate= None }

 (* imported from annotated_ledger.json by ember's automation *)
"""

annotated_ledger = json.loads(open("annotated_ledger.json").read())

for account in annotated_ledger:
    content += """; { pk= of_b58 "%s"; balance= %d; delegate= %s (* %s *) }\n""" % ( account['pk'], account['balance'], "None" if account['delegate'] is None else 'Some (of_b58 "%s")' % account['delegate'], account['nickname'] if 'nickname' in account else account['delegate_discord_username'] if 'delegate_discord_username' in account else account['discord_username'])

content += """]
end)"""

print(content)
