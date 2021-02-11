
import subprocess
import json
import math
import pty
import os
import signal
import csv
import time
import itertools

def main():
  rows = []
  with open('accounts.csv', 'r') as f:
    reader = csv.reader(f.readlines(), delimiter=",")
    for row in reader:
      rows.append(row)


  counter = {}
  for r in rows[1:]:
    r[-1] = r[-1].strip()
    tr = tuple(r[1:])
    counter.setdefault(tr, 0)
    counter[tr] += 1

  accounts_needed = len(counter)*3

  p = run_local_cmd("/bin/bash qa-timelocked-accounts/make_ledger.sh -f " + str(math.ceil(accounts_needed/2)))
  r = p.stdout.read()
  ledger_path = r.split('\n')[-2]

  with open(ledger_path) as f:
    ledger = json.load(f)

  writeable = [ i for i, v in enumerate(ledger['accounts']) if float(v['balance']) == 65500 or float(v['balance']) == 500 ]
  assert(len(writeable) == 3*len(counter))

  grouped = list(zip(*(iter(writeable),) * 3))
  config_to_pks = {}
  for indexes, (balance, initial_min_balance, cliff_block_height, cliff_amount, vesting_period, vesting_increment, _, _, _) in zip(grouped, counter.keys()):

    config = (balance, initial_min_balance, cliff_block_height, cliff_amount, vesting_period, vesting_increment)
    config_to_pks[config] = []
    for index in indexes:
      if cliff_amount == "":
        cliff_amount = "0"

      if vesting_period == "0":
        vesting_period = "1"
        assert(vesting_increment == "0")

      config_to_pks[config].append(ledger['accounts'][index]['pk'])

      ledger['accounts'][index]['balance'] = balance
      ledger['accounts'][index]['timing'] = {
        "initial_minimum_balance": initial_min_balance,
        "cliff_time": cliff_block_height,
        "cliff_amount": cliff_amount,
        "vesting_period": vesting_period,
        "vesting_increment": vesting_increment
      }
    #print(balance, initial_min_balance, cliff_block_height, vesting_period, vesting_increment)

  with open(ledger_path + '2', 'w') as outfile:
    json.dump(ledger, outfile, indent=4)

  pk_to_sk_path = {}
  net_path = '/'.join(ledger_path.split('/')[:-1])
  dirs = [ net_path + '/' + 'online_fish_keys', net_path + '/' + 'offline_fish_keys' ]
  for d in dirs:
    for pub_file in [ f for f in os.listdir(d) if f.endswith('pub') ]:
      with open(d + '/' + pub_file, 'r') as f:
        pk = f.read().strip()
        pk_to_sk_path[pk] = d + '/' + '.'.join(pub_file.split('.')[:-1])

  master, slave = pty.openpty()

  cmd = "/bin/bash qa-timelocked-accounts/run_local_network.sh -f " + str(math.ceil(accounts_needed/2))
  p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, stdout=slave, stderr=slave, close_fds=True)
  stdout = os.fdopen(master)
  while True:
    line = stdout.readline().rstrip()
    print(line)
    if line == 'DONE':
      break


  node_port = '6005'
  node_gql_port = '6006'
  coda_cmd = '_build/default/src/app/cli/src/coda.exe'
  node_dir = net_path + '/nodes/node_1/'

  while True:
    status = run_local_cmd('_build/default/src/app/cli/src/coda.exe client status -daemon-port ' + node_port).stdout.read()
    if 'not be running' not in status:
      break
    time.sleep(5)

  for pk, sk_path in pk_to_sk_path.items():
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' +  coda_cmd + ' account import -config-directory ' + node_dir + ' -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" -privkey-path ' + sk_path + ' &> /dev/null'
    print(run_local_cmd(cmd).stdout.read())

    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' account unlock -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" -public-key ' + pk + ' &> /dev/null'
    print(run_local_cmd(cmd).stdout.read())

  while True:
    status = run_local_cmd('_build/default/src/app/cli/src/coda.exe client status -daemon-port 3000').stdout.read()
    if 'Synced' in status and 'Max observed block height:  1' not in status:
      break
    time.sleep(5)
    
  def send_txn(sender, receiver, fee, amount):
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' client send-payment -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" -fee ' + str(fee) + ' -amount ' + str(amount) + ' -receiver ' + receiver + ' -sender ' + sender + ' &> /dev/null'
    print(run_local_cmd(cmd).stdout.read())

  def get_balance(pk):
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' client get-balance -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" --public-key ' + pk
    return run_local_cmd(cmd).stdout.read()

  while True:
    last_time = time.time()
    
    pks = list(pk_to_sk_path.keys())

    # check the last transactions
    print(get_balance(pks[0]))

    # send a transaction

    fee = 1
    amount = 1
    send_txn(pks[0], pks[1], fee, amount)


    sleep_time = 2*10 - (time.time() - last_time)
    print('sleeping', sleep_time)
    assert(sleep_time > 0)
    time.sleep(sleep_time)

def run_local_cmd(command):
  print(command)
  p = subprocess.Popen('/bin/bash -c \'' + command + '\'', shell=True, stdout=subprocess.PIPE, text=True)
  return p

  #1. put together a ledger reflecting the different account types Bijan sent over, ie
  #  https://docs.google.com/spreadsheets/d/1LE6wiKVnq9ZKGpCD24t6gA4YdleyWi-p_LvNl_dSvlY/edit#gid=0
  #2. run local network
  #   5 nodes
  #3. write a transaction sending and account checking script
  #  a. segments accounts by account types as sent over by Bijan above
  #  b. at the beginning of each 10th slot
  #    1. make sure balances reflect that
  #      a. transactions sent in the previous round that are expected to go through do
  #      b. transactions sent in the previous round that are not expected to go through don't
  #      c. check that no invariants are violated
  #    2. for random 3 accounts of each account type,
  #      1. send such that account value + fee will be < locked amount (should not go through)
  #      2. send such that account value >= locked amount, but with fee < locked amount (should not go through; do not include if all tokens are locked)
  #      3. send such that account value + fee will be >= locked amount (should go through; do not include if all tokens are locked)

os.setpgrp()
try:
  main()
except Exception as e:
  import traceback
  import sys
  exc_type, exc_obj, exc_tb = sys.exc_info()
  trace = traceback.format_exc()
  print(trace)
finally:
  os.killpg(0, signal.SIGKILL) # kill all processes in my group
