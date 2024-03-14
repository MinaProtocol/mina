#!/usr/bin/env python3
from dataclasses import dataclass
from typing import Optional, TypedDict
import psycopg2
import json
import os
import argparse

name = os.environ.get("DB_NAME", "archive")
user = os.environ.get("DB_USER", "mina")
password = os.environ.get("DB_PASSWORD")
host = os.environ.get("DB_HOST", "localhost")
port = os.environ.get("DB_PORT", "5432")
config_file = os.environ.get("CONFIG_FILE")


parser = argparse.ArgumentParser(
    description="Check that the genesis balances in the JSON file match the database."
)
parser.add_argument(
    "--config-file",
    required=config_file is None,
    default=config_file,
    help="Path to the node runtime configuration JSON file containing the ledger.",
)
parser.add_argument(
    "--name",
    default=name,
    help="Name of the database to connect to.",
)
parser.add_argument(
    "--user",
    default=user,
    help="Name of the user to connect to the database.",
)
parser.add_argument(
    "--password",
    required=password is None,
    default=password,
    help="Password to connect to the database.",
)
parser.add_argument(
    "--host",
    default=host,
    help="Host of the database.",
)
parser.add_argument("--port", default=port, help="Port of the database.")

args = parser.parse_args()


class TimingInfo(TypedDict):
    initial_minimum_balance: int
    cliff_time: int
    cliff_amount: int
    vesting_period: int
    vesting_increment: int


class LedgerAccount(TypedDict):
    pk: str
    balance: int
    timing: Optional[TimingInfo]
    delegate: Optional[str]
    nonce: Optional[int]
    receipt_chain_hash: Optional[str]


count_query = "SELECT COUNT(*) FROM accounts_accessed WHERE block_id = 1;"

query = """
SELECT pk.value, ac.balance, ti.initial_minimum_balance, ti.cliff_time, ti.cliff_amount,
       ti.vesting_period, ti.vesting_increment, pk_delegate.value, ac.nonce,
       ac.receipt_chain_hash
FROM accounts_accessed ac
INNER JOIN account_identifiers ai ON ac.account_identifier_id = ai.id
INNER JOIN public_keys pk ON ai.public_key_id = pk.id
LEFT JOIN timing_info ti ON ac.timing_id = ti.id AND ai.id = ti.account_identifier_id
LEFT JOIN public_keys pk_delegate ON ac.delegate_id = pk_delegate.id
WHERE ac.block_id = 1 AND pk.value = %s
LIMIT 1;
"""


def normalize_balance(balance) -> int:
    # split account["balance"] by decimal point
    balance_str = str(balance)
    split_balance = balance_str.split(".")
    if len(split_balance) == 1:
        balance_str = split_balance[0] + "000000000"
    elif len(split_balance) == 2:
        balance_str = split_balance[0] + split_balance[1].ljust(9, "0")
    return int(balance_str)


def row_to_ledger_account(row) -> LedgerAccount:
    initial_minimum_balance = int(row[2])
    cliff_time = int(row[3])
    cliff_amount = int(row[4])
    vesting_period = int(row[5])
    vesting_increment = int(row[6])
    return {
        "pk": row[0],
        "balance": int(row[1]),
        "timing": (
            TimingInfo(
                initial_minimum_balance=initial_minimum_balance,
                cliff_time=cliff_time,
                cliff_amount=cliff_amount,
                vesting_period=vesting_period,
                vesting_increment=vesting_increment,
            )
            if initial_minimum_balance != 0
            or cliff_time != 0
            or cliff_amount != 0
            or vesting_period != 0
            or vesting_increment != 0
            else None
        ),
        "delegate": row[7] if row[7] else None,
        "nonce": int(row[8]) if row[8] != "0" else None,
        "receipt_chain_hash": row[9] if row[9] else None,
    }


def json_account_to_ledger_account(account) -> LedgerAccount:
    return {
        "pk": account["pk"],
        "balance": normalize_balance(account["balance"]),
        "timing": (
            {
                "initial_minimum_balance": normalize_balance(
                    account["timing"]["initial_minimum_balance"]
                ),
                "cliff_time": int(account["timing"]["cliff_time"]),
                "cliff_amount": normalize_balance(account["timing"]["cliff_amount"]),
                "vesting_period": int(account["timing"]["vesting_period"]),
                "vesting_increment": normalize_balance(
                    account["timing"]["vesting_increment"]
                ),
            }
            if "timing" in account
            else None
        ),
        "delegate": account["delegate"] if "delegate" in account else None,
        "nonce": account["nonce"] if "nonce" in account else None,
        "receipt_chain_hash": (
            account["receipt_chain_hash"] if "receipt_chain_hash" in account else None
        ),
    }


def accounts_match(account_json, account_sql) -> bool:
    account_json = json_account_to_ledger_account(account_json)
    account_sql = row_to_ledger_account(account_sql)
    messages = []
    if account_json["pk"] != account_sql["pk"]:
        messages.append(f"pk: {account_json['pk']} != {account_sql['pk']}")

    if account_json["balance"] != account_sql["balance"]:
        messages.append(
            f"balance: {account_json['balance']} != {account_sql['balance']}"
        )

    if account_json["timing"] != account_sql["timing"]:
        messages.append(
            f"timing:\n{account_json['timing']} !=\n{account_sql['timing']}"
        )

    if account_json["delegate"] != account_sql["delegate"]:
        messages.append(
            f"delegate: {account_json['delegate']} != {account_sql['delegate']}"
        )
        if not (
            account_json["nonce"] == account_sql["nonce"]
            if account_json["nonce"]
            else account_sql["nonce"] == 0
        ):
            messages.append(f"nonce: {account_json['nonce']} != {account_sql['nonce']}")

    if len(messages) != 0:
        print(f"Account with pk '{account['pk']}' does not match the SQL query result.")
        for message in messages:
            print(f"\n{message}")
        return False
    else:
        return True


with open(args.config_file) as json_file:
    ledger = json.load(json_file)

ledger_accounts = ledger["ledger"]["accounts"]

with psycopg2.connect(
    dbname=args.name,
    user=args.user,
    password=args.password,
    host=args.host,
    port=args.port,
) as conn:
    with conn.cursor() as cur:
        cur.execute(count_query)
        result = cur.fetchone()
        count = result[0] if result else 0
        assert count == len(
            ledger_accounts
        ), f"Number of accounts in the JSON file ({len(ledger_accounts)}) does not match the number of accounts in the SQL query ({count})."
        print(f"Number of accounts in the JSON file and SQL query match ({count}).")

    print("Checking that the genesis balances in the JSON file match the database...")
    all_accounts_match = True
    for acc in ledger_accounts:
        with conn.cursor() as cur:
            cur.execute(query, (acc["pk"],))
            result = cur.fetchone()
            all_accounts_match = all_accounts_match and accounts_match(acc, result)

    assert all_accounts_match, "Some accounts do not match the SQL query result."
    print("All accounts match the SQL query result.")
