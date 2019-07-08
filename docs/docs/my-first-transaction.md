# My First Transaction

In this section, we'll make our first transaction on the Coda network. After setting up `coda.exe`, we'll need to create a new account before we can send or receive coda. Let's first start up the node so that we can start issuing commands.

## Start a Coda node

Run the following command to start up a Coda node instance and connect to the network:

    $ coda.exe daemon -peer <seed-host>:<seed-port> 

The host and port specified above refer to the seed peer address.

!!!note
    This process needs to be running whenever you issue commands from `coda.exe client`, so make sure you don't kill it by accident.

## Check connection to the Coda network

Now that we've started up a node and are running the Coda daemon, let's open up another shell and run the following command:

    $ coda.exe client status

Most likely we will see a response that include the fields below:

    ...
    Peers:                                         Total: 4 (...)
    ...
    Sync Status:                                   Synced

This step requires waiting for approximately ~5 minutes to sync with the network. When sync status reaches `Synced` and the node is connected to 2 or more peers, you are connected to the network.

### Troubleshooting hints:

- If the number of peers is 1 or fewer, there may be an issue with the IP address - make sure you typed in the IP address and port exactly as specified in [Start a Coda node](#start-a-coda-node).
- If sync status is `Offline`, you may need to [configure port forwarding](/getting-started/#port-forwarding). Otherwise you may need to resolve connectivity issues with your home network.
- If sync status is `Bootstrap`, you'll need to wait for a bit for your node to catch up to the rest of the network. In the Coda network, we do not have to download full transaction history from the genesis block, but nodes participating in block production and compression need to download recent history and the current account data in the network.

## Create a new account

Once the node is connected to the Coda network, we'll create a public/private key-pair so that we can sign transactions and generate an address to receive payments. Use the following command and use `my-wallet` as the path:

    $ coda.exe client generate-keypair -privkey-path my-wallet

This creates a private key at `my-wallet` with a public key at `my-wallet.pub`

## Request coda

In order to send your first transaction, you'll need to get some Coda to play with. First head over to the [Coda Discord server](https://discord.gg/ShKhA7J) and join the `testnet` channel. Once there, simply post a message asking for some test coda and provide your public key. Here's an example:

    Hi, may I have some testnet Coda? My public key is: <public_key>

Once someone responds affirmatively, we can check our balance to make sure that we received the funds with the following command:

    $ coda.exe client get-balance -address <public_key>

## Make a payment

Finally we get to the good stuff, sending your first transaction. For testing purposes, we've setup an echo service that will immediately refund your payment minus the transaction fees. The address of this service is `codaBRrKLuuNMz8Hh6jmzobBWhV7uQ3dS`.

Let's send some of our newly received coda to this service to see what a payment looks like:

    $ coda.exe client send-payment \
        -amount <amount> \
        -receiver <public_key> \
        -fee <fee>
        -privkey-path <path>

If you're wondering what to pass in to the commands above:

- The `public_key` and `privkey-path` inputs correspond directly to the address above, and the private key file path you generated in a previous step.
- For `amount`, let's send a test value of `300` coda
- For `fee`, you can use the current market rate of `5` coda

## Get balance

Whenever you want to see what your balance is, use the following command, passing in the public key of the wallet you're using:

    $ coda.exe client get-balance -address <public-key>

Once you feel comfortable with the basics of creating an address and sending & receiving coda, we can move on to the truly unique parts of the Coda network - [participating in consensus and helping compress the blockchain](/node-operator).