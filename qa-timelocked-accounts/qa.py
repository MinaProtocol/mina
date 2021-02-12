
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
  not_writeable = [ i for i, v in enumerate(ledger['accounts']) if float(v['balance']) != 65500 and float(v['balance']) != 500 ]
  assert(len(writeable) == 3*len(counter))
  assert(len(not_writeable) > 0)

  grouped = list(zip(*(iter(writeable),) * 3))
  config_to_pks = {}
  for indexes, (balance, initial_min_balance, cliff_block_height, cliff_amount, vesting_period, vesting_increment, _, _, _) in zip(grouped, counter.keys()):

    if cliff_amount == "":
      cliff_amount = "0"

    if vesting_period == "0":
      vesting_period = "1"
      assert(vesting_increment == "0")

    cliff_block_height = str(math.ceil(int(cliff_block_height) / 2))
    vesting_period = str(math.ceil(int(vesting_period) / 2))
    config = (balance, initial_min_balance, cliff_block_height, cliff_amount, vesting_period, vesting_increment)
    config_to_pks[config] = []

    for index in indexes:

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

  for i, (pk, sk_path) in enumerate(pk_to_sk_path.items()):
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' +  coda_cmd + ' account import -config-directory ' + node_dir + ' -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" -privkey-path ' + sk_path
    print(run_local_cmd(cmd).stdout.read())

  for i, (pk, sk_path) in enumerate(pk_to_sk_path.items()):
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' account unlock -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" -public-key ' + pk
    print(run_local_cmd(cmd).stdout.read())

  while True:
    status = run_local_cmd('_build/default/src/app/cli/src/coda.exe client status -daemon-port 3000').stdout.read()
    if 'Synced' in status and 'Max observed block height:  1' not in status:
      break
    time.sleep(5)
    
  def send_txn(sender, receiver, fee, amount):
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' client send-payment -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" -fee ' + str(fee) + ' -amount ' + str(amount) + ' -receiver ' + receiver + ' -sender ' + sender
    print(run_local_cmd(cmd).stdout.read())

  def get_balance(pk):
    cmd = 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' client get-balance -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" --public-key ' + pk
    result = run_local_cmd(cmd).stdout.read()
    balance = float(result.split('\n')[-2].split(':')[1].split(' ')[1])
    return balance

  def get_balances(pks):
    cmds = [ 'CODA_PRIVKEY_PASS="naughty blue worm" ' + coda_cmd + ' client get-balance -rest-server "http://127.0.0.1:' + node_gql_port + '/graphql" --public-key ' + pk for pk in pks ]
    procs = [ run_local_cmd(cmd) for cmd in cmds ]
    results = [ p.stdout.read() for p in procs ]
    balances = [ float(result.split('\n')[-2].split(':')[1].split(' ')[1]) for result in results ]
    return balances

  expected_states = {}

  dest_pk = ledger['accounts'][not_writeable[0]]['pk']

  pk_to_configs = {}
  for config,pks in config_to_pks.items():
    for pk in pks:
      pk_to_configs[pk] = config

  while True:
    last_time = time.time()

    
    pks = list(pk_to_sk_path.keys())

    # ==============================================================

    # check the last transactions

    pk_to_balances = {}
    balances = get_balances(pks)

    for pk, b in zip(pks, balances):
      pk_to_balances[pk] = b
      if pk in expected_states:
        print('check', pk, b, '==', expected_states[pk])
        try:
          assert(expected_states[pk] == b)
        except:
          import IPython; IPython.embed()

    sleep_slots = 20

    # ==============================================================

    status = run_local_cmd('_build/default/src/app/cli/src/coda.exe client status -daemon-port 3000').stdout.read()
    global_slot_number = int([ s for s in status.split('\n') if s.startswith('Best tip global') ][0].split(':')[1].strip())
    global_slot_number_20 = global_slot_number + sleep_slots

    # send a transaction

    all_unlocked = True

    for config,pks in config_to_pks.items():

      _, initial_min_balance, cliff_block_height, cliff_amount, vesting_period, vesting_increment = [ int(x) for x in config ]

      still_locked_in_20_seconds = initial_min_balance if cliff_block_height > global_slot_number_20 else initial_min_balance - cliff_amount - max(math.floor((global_slot_number_20 - cliff_block_height) / vesting_period) * vesting_increment, 0)

      locked_now = initial_min_balance if cliff_block_height > global_slot_number else initial_min_balance - cliff_amount - max(math.floor((global_slot_number - cliff_block_height) / vesting_period) * vesting_increment, 0)

      #1. send such that account value + fee will be < locked amount (should not go through)
      #2. send such that account value >= locked amount, but with fee < locked amount (should not go through; do not include if all tokens are locked)
      #3. send such that account value + fee will be >= locked amount (should go through; do not include if all tokens are locked)

      pk_too_much = pks[0]
      too_much_unlocked_by_20 = pk_to_balances[pk_too_much] - still_locked_in_20_seconds
      fee_too_much = 2
      amount_too_much = too_much_unlocked_by_20 + 10
      send_txn(pk_too_much, dest_pk, fee_too_much, amount_too_much)
      expected_states[pk_too_much] = pk_to_balances[pk_too_much]

      pk_barely_too_much = pks[1]
      barely_too_much_unlocked_by_20 = pk_to_balances[pk_barely_too_much] - still_locked_in_20_seconds
      fee_barely_too_much = 10
      amount_barely_too_much = too_much_unlocked_by_20 - 5
      send_txn(pk_barely_too_much, dest_pk, fee_barely_too_much, amount_barely_too_much)
      expected_states[pk_barely_too_much] = pk_to_balances[pk_barely_too_much]

      pk_okay = pks[2]
      okay_unlocked_by_20 = pk_to_balances[pk_okay] - locked_now
      fee_okay = 2
      amount_okay = 5
      if okay_unlocked_by_20 >= amount_okay + fee_okay:
        send_txn(pk_okay, dest_pk, fee_okay, amount_okay)
        expected_states[pk_okay] = pk_to_balances[pk_okay] - fee_okay - amount_okay

      print('locked', locked_now, global_slot_number, cliff_block_height, vesting_period)

      all_unlocked = all_unlocked and locked_now == 0

    if all_unlocked:
      break

    # ==============================================================


    sleep_time = 2*sleep_slots - (time.time() - last_time)
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
