# This script is to produce genesis ledger for the daemon config file
# The script expects
# 1. csv file that contains the spec for each account (balance, delegate, nonce) were delegate is the index of an account in the same list
# 2. path to keys folder which contains a sub-drifolder for community block producer keys "community/" generated using https://github.com/MinaProtocol/mina/blob/lk86/keygen-script-with-random-passwords/scripts/generate-community-keys.sh and another sub-folder for any other keys "others/"
# 3. path where genesis ledger file is to be written

import csv
import os
import subprocess
import sys
import json
import random
import functools

block_producer_count = 330
block_producer_accounts = []
other_accounts = []
ledger = []


def key_directory(is_block_producer, directory):
    if is_block_producer:
        key_folder = "community/"
    else:
        key_folder = "others/"
    return (directory+"/"+key_folder)


def generate_keypair_command(filename, directory, password):
    # python doesn't like something about this command string; Maybe try using local build instead of docker
    # keys were pre-generated for instead
    command = ["sudo", "docker", "run", "-v", "%s:/keys" % directory, "--entrypoint", "/bin/bash", MINA_DAEMON_IMAGE,
               "-c", '''"MINA_PRIVKEY_PASS='%s' mina advanced generate-keypair --privkey-path /keys/%s "''' % (password, filename)]
    print(command)
    return command


def mina_account(pk, balance, nonce, delegate, count):
    if delegate == "" or delegate == None:
        delegate = pk
    return ({"pk": pk, "balance": "{:10.9f}".format(balance), "delegate": delegate, "nonce": str(nonce), "count": count})


def execute_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE)
    output, error = process.communicate()

    if process.returncode > 0:
        print(output.decode('utf-8'))
        print(error)
        print('Executing command \"%s\" returned a non-zero status code %d' %
              (command, process.returncode))
        sys.exit(process.returncode)

    if error:
        print(error.decode('utf-8'))

    return output.decode('utf-8')


block_producer_filename = "community-"
other_key = "mina_key_"


def get_pk(path):
    f = open(path, 'r')
    pk = f.readline()
    return pk.strip()


def get_mina_key(i, is_block_producer, directory, password):
    if is_block_producer:
        keyfile = "community-"+str(i+1)+"/" + \
            block_producer_filename + str(i+1)+"-key"
        sub_dir = key_directory(True, directory)
    else:
        keyfile = other_key + str(i)
        sub_dir = key_directory(False, directory)
    pk_file = keyfile+".pub"
    if os.path.exists(sub_dir+pk_file):
        return (get_pk(sub_dir+pk_file))
    else:
        print("key for %dth row not found %s" % (i, sub_dir+pk_file))
        # command=generate_keypair_command(keyfile,sub_dir,password)
        # execute_command(command)
        # return (get_pk(sub_dir+"/"+pk_file))


def read_csv(filename):
    print("Reading ", filename)
    print("Expecting format: balance,delegate,nonce")
    with open(filename) as stake_file:
        csv_reader = csv.reader(stake_file, delimiter=',')
        count = 0
        for row in csv_reader:
            if row[2] == "":
                nonce = 0
            else:
                nonce = int(row[2])
            value = (float(row[0]), row[1], nonce)
            if count >= block_producer_count:
                other_accounts.append(value)
            else:
                block_producer_accounts.append(value)
            count += 1


def get_delegate_key(delegate_index: str):
    try:
        return (ledger[int(delegate_index)]['pk'])
    except:
        ""


def create_accounts(keys_dir, extra_accounts_count):
    # block producers
    for index, (balance, delegate, nonce) in enumerate(block_producer_accounts):
        is_block_producer = True
        public_key = get_mina_key(
            index, is_block_producer, keys_dir, "itn-track3-d91afe4")
        ledger.append(mina_account(public_key, balance, nonce,
                      get_delegate_key(delegate), index))
    # all other accounts from the csv
    for index, (balance, delegate, nonce) in enumerate(other_accounts):
        is_block_producer = False
        try:
            public_key = get_mina_key(
                index, is_block_producer, keys_dir, "itn-track3-d91afe4")
            if public_key != None:
                ledger.append(mina_account(public_key, balance,
                              nonce, get_delegate_key(delegate), index))
        except:
            print("Ignoring %dth key" % index)
    key_count_so_far = len(block_producer_accounts) + len(other_accounts)
    # extra 0-balance account with no delegate
    for index in range(key_count_so_far, key_count_so_far + int(extra_accounts_count/2)):
        public_key = get_mina_key(index, False, keys_dir, "itn-track3-d91afe4")
        if public_key != None:
            ledger.append(mina_account(public_key, 0, 0, None, index))
    # extra 0-balance account with random nonce and random delegate
    for index in range(key_count_so_far + int(extra_accounts_count/2), key_count_so_far + extra_accounts_count):
        public_key = get_mina_key(index, False, keys_dir, "itn-track3-d91afe4")
        if public_key != None:
            ledger.append(mina_account(public_key, 0, random.randint(
                0, 30), get_delegate_key(random.randint(0, 999)), index))


def generate_ledger(output_dir):
    filename = "genesis_ledger_track3.json"
    with open(output_dir+"/"+filename, 'w') as fl:
        json.dump(ledger, fl, indent=2)


def foldl(func, xs, init):
    return (functools.reduce(func, xs, init))


pk_stake = dict()


def update_pk_stake(pk, balance):
    if pk_stake.get(pk) == None:
        pk_stake[pk] = float(balance)
    else:
        old_balance = pk_stake[pk]
        pk_stake[pk] = old_balance + float(balance)


def get_pk_stake():
    for account in ledger:
        pk = account['pk']
        delegate = account['delegate']
        if delegate == "" or delegate == None or delegate == pk:
            # if not delegating/sef delegating
            update_pk_stake(pk, account['balance'])
        else:
            update_pk_stake(delegate, account['balance'])


def add_balance(acc, account):
    return (acc + float(account['balance']))


def show_stake(total_currency):
    get_pk_stake()
    values = sorted(pk_stake.items(), key=lambda x: x[1], reverse=True)
    for pk, balance in values:
        stake = (balance/total_currency)*100
        if stake > 0.001:
            print("pk: %s stake %s%%" % (pk, "{:10.3f}".format(stake)))


def main():
    args = sys.argv
    csv_file = args[1]
    keys_directory = args[2]
    output_dir = args[3]
    read_csv(csv_file)
    create_accounts(keys_directory, 90000)
    total_currency = foldl(add_balance, ledger, 0)
    print("Total currency %f" % total_currency)
    show_stake(total_currency)
    generate_ledger(output_dir)


main()
