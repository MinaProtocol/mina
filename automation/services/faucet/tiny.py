import discord
import re
import os
import json
import asyncio
import concurrent.futures
from faucet import Faucet
import CodaClient 
import backoff
import websockets 
import logging
import sys
import prometheus_client

#Turn Down Discord Logging
disc_log = logging.getLogger('discord')
disc_log.setLevel(logging.INFO)

# Configure Logging
logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
logger = logging.getLogger(__name__)

LISTENING_CHANNELS = ["faucet"]
FAUCET_APPROVE_ROLE = "faucet-approvers"
MOD_ROLE = "mod"
CODA_FAUCET_AMOUNT = os.environ.get("FAUCET_AMOUNT")
# A Dictionary to keep track of users
# who have requested faucet funds 
ACTIVE_REQUESTS = {}
DISCORD_API_KEY = os.environ.get("DISCORD_API_KEY")
METRICS_PORT = int(os.environ.get("FAUCET_METRICS_PORT"))

executor = concurrent.futures.ThreadPoolExecutor(max_workers=5)
client = discord.Client()
faucet = Faucet()

SENT_TRANSACTION_THIS_BLOCK = False

# PROMETHEUS METRICS
TRANSACTION_COUNT = prometheus_client.Counter("faucet_transactions_sent", "Number of Transactions sent since the process started")
TOTAL_CODA_SENT = prometheus_client.Counter("faucet_coda_sent", "Amount of Coda sent since the process started")
PROCESS_METRICS = prometheus_client.ProcessCollector(namespace='faucet')
PLEASE_WAIT_ERRORS = prometheus_client.Counter("faucet_please_wait_errors", "Number of 'Please Wait' Errors that have been issued")
BLOCK_NOTIFICATIONS_RECIEVED = prometheus_client.Counter("faucet_block_notifications_recieved", "Number of Block Notifications recieved")

# This is a fix for a bug in the Daemon where the Nonce is
# only incremented once per block, can be removed once it's fixed
# NOTE: This means we can only send one faucet transaction per block. 
async def new_block_callback(message):
    global SENT_TRANSACTION_THIS_BLOCK
    SENT_TRANSACTION_THIS_BLOCK = False
    logger.debug("Got a block! Resetting the Boolean to {}. {}".format(SENT_TRANSACTION_THIS_BLOCK, message))
    BLOCK_NOTIFICATIONS_RECIEVED.inc()


@client.event
async def on_ready():
    logger.info('We have logged in as {0.user}'.format(client))
    prometheus_client.start_http_server(METRICS_PORT)


@client.event
@backoff.on_exception(backoff.expo, OSError, max_tries=15)
@backoff.on_exception(backoff.expo,  websockets.exceptions.ConnectionClosed)
async def on_connect():
    # Call new block subscription
    logger.debug("Reconnecting to Coda Daemon...")
    await faucet.new_block_subscribe(new_block_callback)

@client.event
async def on_message(message):
    global SENT_TRANSACTION_THIS_BLOCK

    # Dont listen to messages from me
    if message.author == client.user:
        return

    # Check if the grumpus is listening
    if message.content.startswith('$tiny') and message.channel.name in LISTENING_CHANNELS:
        await message.channel.send('You summoned me?')

    # Mods-Only Status Command
    if message.content.startswith('$status') and message.channel.name in LISTENING_CHANNELS:
        if MOD_ROLE in [str(x) for x in message.author.roles]:
            status = faucet.faucet_status()["daemonStatus"]
            wallet = faucet.faucet_wallet()["wallet"]
            status_text = '''
**Daemon Status**
Blockchain Length: `{}`
Uptime: `{} seconds`
# Peers: `{}`
Best Consensus Time: `{}`
Consensus Time Now: `{}`
**Faucet** 
Balance (Total): `{}` Coda
Balance (Unknown): `{}` Coda
Nonce: `{}`
            '''.format(
                status["blockchainLength"], 
                status["uptimeSecs"], 
                len(status["peers"]), 
                status["consensusTimeBestTip"],
                status["consensusTimeNow"],
                wallet["balance"]["total"],
                wallet["balance"]["unknown"],
                wallet["nonce"]
            )
            await message.channel.send(status_text)

    # Help me grumpus! 
    if message.content.startswith('$help') and message.channel.name in LISTENING_CHANNELS:
        help_string = '''
Woof! I can help you get some coda on the testnet.
Just send me a message in the #faucet channel with the following contents: 

`$request <public-key>`

Once a mod approves, `100 CODA` will be sent to the requested address!
        '''

        await message.channel.send("```{}```".format(help_string))

    # Act as a faucet, responding to messages of the form: 
    #   $request <public-key>
    if message.content.startswith('$request') and message.channel.name in LISTENING_CHANNELS:
        channel = message.channel
        roles = message.guild.roles
        mod_role = next(role for role in roles if role.name == FAUCET_APPROVE_ROLE).mention
        requester = message.author

        # If we're not already tracking a request for this user
        if requester.id not in ACTIVE_REQUESTS:
            ACTIVE_REQUESTS[requester.id] = {
                "channel": channel,
                "requester": requester
            }
            logger.debug(ACTIVE_REQUESTS)
        # Otherwise, ignore this request
        else: 
            please_wait_text = "Hey {}, please wait or cancel your previous request for faucet funds!".format(requester.mention)
            await channel.send(please_wait_text)
            return

        try: 
            # Try to parse the message with regex
            regexp = "\$request (\w+)"
            m = re.search(regexp, message.content)
            if m and not SENT_TRANSACTION_THIS_BLOCK:
                recipient = m.groups()[0]
                amount = CODA_FAUCET_AMOUNT
                logger.debug(recipient)
                # Request transaction approval from the mods 
                approval_text = 'Hey {}, should I approve this transaction?: \nRequester: {}\nRecipient: {}\nAmount: {}\n *To cancel, react with ❌*'.format(mod_role, requester.mention, recipient, amount)
                approval_message = await channel.send(approval_text)

                # Check if a mod has approved the request
                def check_approval(reaction, user):
                    logger.debug("check approval {}".format(reaction))
                    logger.debug(user.roles)
                    return reaction.message.id == approval_message.id and FAUCET_APPROVE_ROLE in [str(x) for x in user.roles] and str(reaction.emoji) == '👍'
            
                # Check if a user has cancelled their request
                def check_cancel(reaction, user):
                    logger.debug("check cancel {}".format((reaction, reaction.message.id == approval_message.id and user == message.author and str(reaction.emoji) == '❌')))
                    return reaction.message.id == approval_message.id and user == message.author and str(reaction.emoji) == '❌'
                
                try:
                    # This is weird but in the docs there is a note explaining why you have to create tasks
                    # outside the call to `wait` instead of passing coroutines directly
                    #
                    # https://docs.python.org/3/library/asyncio-task.html#asyncio.wait
                    cancel = asyncio.create_task(client.wait_for('reaction_add', check=check_cancel))
                    approval = asyncio.create_task(client.wait_for('reaction_add', check=check_approval))

                    # Make sure approval reactions are for the right message
                    done, unfinished = await asyncio.wait({cancel, approval},
                                                        return_when=asyncio.FIRST_COMPLETED)
                    for task in unfinished:
                        task.cancel()
                    if len(unfinished) != 0:
                        await asyncio.wait(unfinished)
                    

                # Transaction was not approved
                except asyncio.TimeoutError:
                    await channel.send('Transaction Not Approved in Time: 👎')
                    
                # Transaction was approved
                else:
                    if approval in done:
                        # Alert in the channel that the transaction approved
                        await channel.send('Woof! -- Transaction Approved, fetching your funds...')
                        # Make call to ansible 
                        loop = asyncio.get_event_loop()
                        output = await loop.run_in_executor(executor, faucet.faucet_transaction, recipient, amount)
                        # Collect output and return it to the channel
                        await channel.send('{} Transaction Sent! Output from Daemon: ```{}```'.format(requester.mention, output))
                        logger.debug("Approved!")
                        
                        # Restrict any transactions being sent until next block
                        #SENT_TRANSACTION_THIS_BLOCK = True

                        #Increment metrics counters
                        TRANSACTION_COUNT.inc()
                        TOTAL_CODA_SENT.inc(int(amount))
                    elif cancel in done:
                        await channel.send('Transaction Cancelled!')
                        logger.debug("Cancelled...")
            elif SENT_TRANSACTION_THIS_BLOCK: 
                # If we get here then we have already sent a transaction this block and we should report an error
                logger.debug("SENT TOO MANY REQUESTS THIS BLOCK, NOT SENDING!")
                error_message = "I've sent too many transactions this block, please try again in a bit!"
                await message.channel.send(error_message)

                # Increment error metric
                PLEASE_WAIT_ERRORS.inc()
            else:
                logger.debug(message.content)
                error_message = '''Grrrrr... Invalid Parameters!!
                `$request <public-key>`
                '''
                await message.channel.send(error_message)
            
        finally:
            del ACTIVE_REQUESTS[requester.id]

client.run(DISCORD_API_KEY)
