# My First Transaction

In this section, we'll make our first transaction on the Coda network. After [setting up `coda`](../getting-started), we'll need to create a new account before we can send or receive coda. Let's first start up the node so that we can start issuing commands.

## Start up a node

Run the following command to start up a Coda node instance and connect to the network:

    $ coda daemon -peer genesis-test.o1test.net:8303

The host and port specified above refer to the seed peer address - this is the initial peer we will connect to on the network. Since Coda is a [peer-to-peer](../glossary/#peer-to-peer) protocol, there is no single centralized server we rely on. 

!!!note
    The daemon process needs to be running whenever you issue commands from `coda client`, so make sure you don't kill it by accident.

## Checking connectivity

Now that we've started up a node and are running the Coda daemon, open up another shell and run the following command:

    $ coda client status

Most likely we will see a response that include the fields below:

    ...
    Peers:                                         Total: 4 (...)
    ...
    Sync Status:                                   Synced

This step requires waiting for approximately ~5 minutes to sync with the network. When sync status reaches `Synced` and the node is connected to 2 or more peers, we will have successfully connected to the network.

### Troubleshooting hints:

- If the number of peers is 1 or fewer, there may be an issue with the IP address - make sure you typed in the IP address and port exactly as specified in [Start a Coda node](#start-a-coda-node).
- If sync status is `Offline` for more than 10 minutes, you may need to [configure port forwarding for your router ](/docs/getting-started/#port-forwarding). Otherwise you may need to resolve connectivity issues with your home network.
- If sync status is `Bootstrap`, you'll need to wait for a bit for your node to catch up to the rest of the network. In the Coda network, we do not have to download full transaction history from the genesis block, but nodes participating in block production and compression need to download recent history and the current account data in the network.

## Create a new account

Once our node is synced, we'll create a public/private key-pair so that we can sign transactions and generate an address to receive payments. For security reasons, we'll want to put the keys under a directory that is harder for attackers to access.

Run the following command which creates a public and private key `my-wallet` and `my-wallet.pub` under the `keys` directory:

    $ coda client generate-keypair -privkey-path keys/my-wallet

!!! warning
    The public key can be shared freely with anyone, but be very careful with your private key file. Never share this private key with anyone, as it is the equivalent of a password for your funds.

## Request coda

In order to send our first transaction, we'll first need to get some Coda to play with. Head over to the [Coda Discord server](https://discord.gg/ShKhA7J) and join the `faucet` channel. Once there, ask our faucet bot for some tokens (you'll receive 100). Here's an example:

    $request tNciWRVyhakSXV1gzHg8KdvWccJ4HXorwUPTUS2SgHVi3gKk4WUbcPqSvRBGSHSUVjZGhJooyLvSkQaxf8eFnAW5sQsAiDF1zRj1hDnnRVFRQsck3kQYna1ELv4UxBt6VP232wpCcrwh8g

Once a faucet-mod thumbs up your request, keep an eye on the discord channel to see when the transaction goes through on that side. 

We can check our balance to make sure that we received the funds by running the following command, passing in our public key:

    $ coda client get-balance -address <public_key>

You might see `No account found at that public\_key (zero balance)`. Be patient! Depending on the traffic in the network, it may take a few blocks before your transaction goes through.

While you're waiting take a look at your daemon logs for new blocks being generated. Run the following command to see the current block height:

    $ coda client status

## Make a payment

Finally we get to the good stuff, sending our first transaction! For testing purposes, there's already an echo service set up that will immediately refund your payment minus the transaction fees.

Let's send some of our newly received coda to this service to see what a payment looks like:

    $ coda client send-payment -amount 10 -receiver <public-key> -fee 2 -privkey-path keys/my-wallet

If you're wondering what we passed in to the commands above:

- For `amount`, we're sending a test value of `10` coda
- The `receiver` (public key) of the echo service is `TODO`
- For `fee`, let's use the current market rate of `2` coda
- The `privkey-path` is the private key file path of the private key we generated the `keys` folder

If this command is formatted properly, we should get a response that looks like the following:

Initiated payment
Receipt chain hash: A3gpN9j4j3UoJMoug6PVEwDvRKskfZtoSDCzwxS5ez7JbMjTJx9ZQHjWCPLsddp6u6pL1YsVfpWDLV3oWRRzpijo6LYApoEemeQirkQ1BFUmbkjWEi1ZCQhcFraNMS7Akyv2wA7gptqVt

## Check account balance

Now that we can send transactions, it might be helpful to know our balance, so that we don't spend our testnet tokens too carelessly! Let's check our current balance by running the following command, passing in the public key of the account we generated:

    $ coda client get-balance -address <public-key>

We'll get a response that looks like this:

    50

Once you feel comfortable with the basics of creating an address, and sending & receiving coda, we can move on to the truly unique parts of the Coda network - [participating in consensus and helping compress the blockchain](/docs/node-operator).
