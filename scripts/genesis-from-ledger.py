#!/usr/bin/env python

# generate OCaml code for the genesis ledger, using accounts in current ledger
# output is to stdout, so it can be redirected to a convenient filename
# to use this script, a daemon must be running and synched to a network

import subprocess
import sys
from datetime import datetime

output = subprocess.check_output(['coda', 'advanced', 'dump-ledger', '-json'])
accounts=output.split('\n')

prelude = ['(* GENERATED GENESIS LEDGER AT: ' + str(datetime.now ()) + ' *)'
,''
,'open Core'
,'open Coda_base'
,'open Functor'
,''
,'let accounts = ['
]

for line in prelude :
    print(line)

count=0
for account in accounts :
    if not account == "" :
        if count > 0 :
            sys.stdout.write ('; ')
        else :
            sys.stdout.write ('  ')
        print ('\"' + account.replace('\"','\\"') + '\"')
        count = count + 1

postlude= [']'
,''
,'module Accounts = struct'
,' let accounts = List.map accounts ~f:(fun s ->'
,'   let account = Yojson.Safe.from_string s |> Account.Stable.Latest.of_yojson |> Result.ok_or_failwith in'
,'   (None,account))'
,'end'
,''
,'include Make_from_base (Accounts)'
]

for line in postlude :
    print(line)
