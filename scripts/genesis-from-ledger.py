#!/usr/bin/env python

# generate OCaml code for the genesis ledger, using accounts in current ledger
# output is to stdout, so it can be redirected to a convenient filename
# to use this script, a daemon must be running and synched to a network

import subprocess
import sys
from datetime import datetime

output = subprocess.check_output(['coda', 'advanced', 'dump-ledger', '-json'])
accounts=output.split('\n')

count=0

print ('(* GENERATED GENESIS LEDGER AT: ' + str(datetime.now ())) + ' *)'
print ('')
print ('open Core')
print ('open Coda_base')
print ('open Functor')
print ('')
print ('let accounts = [')
for account in accounts :
    if not account == "" :
        if count > 0 :
            sys.stdout.write ('; ')
        else :
            sys.stdout.write ('  ')
        print ('\"' + account.replace('\"','\\"') + '\"')
        count = count + 1
print (']')
print ('')
print ('module Accounts = struct')
print (' let accounts = List.map accounts ~f:(fun s ->')
print ('   let account = Yojson.Safe.from_string s |> Account.Stable.Latest.of_yojson |> Result.ok_or_failwith in')
print ('   (None,account))')
print ('end')
print ('')
print ('include Make_from_base (Accounts)')
