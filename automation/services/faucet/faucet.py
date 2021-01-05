from subprocess import Popen, PIPE
import CodaClient
import os
import asyncio
import logging

DAEMON_HOST = os.environ.get("DAEMON_HOST", "localhost")
DAEMON_PORT = os.environ.get("DAEMON_PORT", "8304")
FAUCET_PUBLIC_KEY = os.environ.get("FAUCET_PUBLIC_KEY", "tNciQAUCyj35pvqiLXgpCsdiQVU2DN2sqgYiFrCG6E6muLcpBsJtSd57f9hctDAokidxyh3FxNTGzYcnLf2XG6jxj4WjqjMEekszvLSTCXtmfTK1U1HgbiyioqAn5CBXDcdGZLaTqfadts")
FAUCET_FEE = os.environ.get("FAUCET_FEE", "8")


class Faucet():
    def __init__(self):
        self.coda = CodaClient.Client(graphql_host = DAEMON_HOST, graphql_port = DAEMON_PORT)
        self.logger = logging.getLogger(__name__)
    
    async def new_block_subscribe(self, callback):
        self.logger.debug("New Block Subscription.")
        await self.coda.listen_new_blocks(FAUCET_PUBLIC_KEY, callback)
        
    def faucet_status(self):
        response = self.coda.get_daemon_status()
        self.logger.debug("Getting Daemon Status: {}".format(response))
        return response

    def faucet_wallet(self):
        response = self.coda.get_wallet(pk=FAUCET_PUBLIC_KEY)
        self.logger.debug("Getting Faucet Wallet: {}".format(response))
        return response

    def faucet_transaction(self, recipient, amount): 
        """Sends a faucet transaction to a daemon located at DAEMON_HOST:DAEMON_PORT
        """
        memo = ""       
        self.logger.debug("{} {} {} {} {}".format(recipient, FAUCET_PUBLIC_KEY, amount, FAUCET_FEE, memo))
        response = self.coda.send_payment(recipient, FAUCET_PUBLIC_KEY, amount, FAUCET_FEE, memo)
        self.logger.info("Sent a Payment, got a response: {}".format(response))
        return response



if __name__ == "__main__":
    f = Faucet()
    f.faucet_transaction("tNciGaGWUJZ5CtTdi25eTxdCfx4AfD25iSFZYL9MzM9sW7GRBtN9jETfZmir69unuegc638eg8TXtt2i4vuVDZ1WKNh7CtFrvURhg4Wb2zcs9gM55tpthUomq3no46s2JKWhj9em6T724f", "100")
