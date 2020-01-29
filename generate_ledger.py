#!/usr/bin/env python3

import json

content = """
let vrf_winner_keypair =
    let conv (pk, sk) =
        ((Core_kernel.Binable.of_string (module
            Signature_lib.Public_key.Compressed.Stable.Latest) pk),
            (Core_kernel.Binable.of_string (module
                Signature_lib.Private_key.Stable.Latest) sk))
    in conv ("\\001\\001`\\232/\\r\\250p\\253\\234f7^I\\156\\235'\\243\\001\\027;V\\249\\192Y\\158\\198#\\143:\\2138D\\211\\202\\022t\\212}\\205\\208\\193\\174\\253\\153\\192\\192\\215\\186\\217\\199\\218A\\185\\187\\178\\165~\\241\\198\\224\\149\\184\\152D\\130m\\b\\128\\166(\\209\\022yUK\\r\\243\\223'\\026o\\164\\170\\150\\255\\2234\\155B\\227E\\191vb\\236]\\000\\000\\001",  "`\\222n\\145/\\225]\\210\\202\\031\\136\\000\\016\\001\\174%]. 2X\\143GX,\\137\\209\\157\\177\\201\\190\\133\\006\\135>C\\015\\227\\187\\\\s\\237\\0169\\236\\215\\030\\151\\173\\236\\018\\134\\006\\194W\\229\\027\\232\\021Q\\141\\011\\173/\\209(\\015$\\226\\244\\254\\194\\154yT\\213J\\227\\166\\155'K\\209\\203\\231\\1662\\221\\239\\217c\\252\\151\\138\\131\\001\\000")

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
