from CodaClient import Client, Currency, CurrencyFormat
import os
import schedule
import time
import urllib3
import random
from requests.exceptions import ConnectionError
from prometheus_client import Counter, start_http_server

def getenv_default_map(env_var: str, f, default):
    value = os.getenv(env_var)
    if value == None:
        return default
    else:
        return f(value)

def getenv_str(env_var: str, default: str) -> str:
    return os.getenv(env_var, default).strip()

def getenv_int(env_var: str, default: int) -> int:
    return getenv_default_map(env_var, int, default)

def getenv_currency(env_var: str, lower_bound: Currency, upper_bound: Currency) -> Currency:
    return getenv_default_map(env_var, Currency, Currency.random(lower_bound, upper_bound))

CODA_PUBLIC_KEY = getenv_str("CODA_PUBLIC_KEY", "4vsRCVyVkSRs89neWnKPrnz4FRPmXXrWtbsAQ31hUTSi41EkbptYaLkzmxezQEGCgZnjqY2pQ6mdeCytu7LrYMGx9NiUNNJh8XfJYbzprhhJmm1ZjVbW9ZLRvhWBXRqes6znuF7fWbECrCpQ")
MINA_PRIVKEY_PASS = getenv_str("MINA_PRIVKEY_PASS", "naughty blue worm")
AGENT_MIN_FEE = getenv_currency("AGENT_MIN_FEE", Currency("0.06"), Currency("0.1"))
AGENT_MAX_FEE = getenv_currency("AGENT_MAX_FEE", AGENT_MIN_FEE, AGENT_MIN_FEE + Currency("0.2"))
AGENT_MIN_TX = getenv_currency("AGENT_MIN_TX", Currency("0.0015"), Currency("0.005"))
AGENT_MAX_TX = getenv_currency("AGENT_MAX_TX", AGENT_MIN_TX, AGENT_MIN_TX + Currency("0.01"))
AGENT_TX_BATCH_SIZE = getenv_int("AGENT_TX_BATCH_SIZE", 1)
AGENT_SEND_EVERY_MINS = getenv_int("AGENT_SEND_EVERY_MINS", random.randint(1, 5))
AGENT_METRICS_PORT = getenv_int("AGENT_METRICS_PORT", 8000)


CODA_CLIENT_ARGS = {
    "graphql_host": getenv_str("CODA_HOST", "localhost"),
    "graphql_port": getenv_str("CODA_PORT", "3085")
} 


## Prometheus Metrics

TRANSACTIONS_SENT = Counter('transactions_sent', 'Number of transactions agent has sent since boot.')
TRANSACTION_ERRORS = Counter('transaction_errors', 'Number of errors that occurred while sending transactions.')

class Agent(object):
    """Represents a generic agent that operates on the coda blockchain"""

    def __init__(self, client_args, public_key, privkey_pass, min_tx_amount=AGENT_MIN_TX, max_tx_amount=AGENT_MAX_TX, min_fee_amount=AGENT_MIN_FEE, max_fee_amount=AGENT_MAX_FEE):
        self.coda = Client(**client_args)
        self.public_key = public_key
        self.privkey_pass = privkey_pass
        self.min_tx_amount = min_tx_amount
        self.max_tx_amount = max_tx_amount
        self.min_fee_amount = min_fee_amount
        self.max_fee_amount = max_fee_amount
        self.to_account = None

    def get_to_account(self):
        if not self.to_account:
            print("Getting new wallet to send to...")
            response = self.coda.create_wallet(self.privkey_pass)
            self.to_account = response["createAccount"]["publicKey"]
            print("Public Key: {}".format(self.to_account))
        return self.to_account

    def unlock_wallet(self):
        response = self.coda.unlock_wallet(self.public_key, self.privkey_pass)
        print("Unlocked Wallet!")
        return response

    def send_transaction(self):
        print("---Sending Transaction---")
        try: 
            to_account = self.get_to_account()
            print("Trying to unlock Wallet!")
            self.unlock_wallet()
        except ConnectionError:
            print("Transaction Failed due to connection error... is the Daemon running?")
            TRANSACTION_ERRORS.inc()
            return None
        except Exception as e: 
            print("Error unlocking wallet...")
            print(e)
            return None

        tx_amount = Currency.random(self.min_tx_amount, self.max_tx_amount)
        fee_amount = Currency.random(self.min_fee_amount, self.max_fee_amount)
        try: 
            response = self.coda.send_payment(to_account, self.public_key, tx_amount, fee_amount, memo="BeepBoop")
        except Exception as e: 
            print("Error sending transaction...", e)
            TRANSACTION_ERRORS.inc()
            return None
        if not response.get("errors", None):
            print("Sent a Transaction {}".format(response))
            TRANSACTIONS_SENT.inc()
        else: 
            print("Error sending transaction: Request: {} Response: {}".format(self.public_key, response))
            TRANSACTION_ERRORS.inc()
        return response

    def send_transaction_batch(self):
        responses = []
        for i in range(AGENT_TX_BATCH_SIZE):
            responses.append(self.send_transaction())
        return responses


def main():
    agent = Agent(CODA_CLIENT_ARGS, CODA_PUBLIC_KEY, MINA_PRIVKEY_PASS)
    schedule.every(AGENT_SEND_EVERY_MINS).minutes.do(agent.send_transaction_batch)
    print("Sending a transaction every {} minutes.".format(AGENT_SEND_EVERY_MINS))
    while True:
        schedule.run_pending()
        sleep_time = 10
        print("Sleeping for {} seconds...".format(sleep_time))
        time.sleep(sleep_time)

if __name__ == "__main__":
    print("Starting up...")
    start_http_server(AGENT_METRICS_PORT)
    print("Metrics on Port {}".format(AGENT_METRICS_PORT))
    print("Sleeping for 20 minutes...")
    time.sleep(60*20)
    main()
