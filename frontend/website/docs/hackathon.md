
# DeFi Hackathon

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/defi-ccd2aaa30d2123423d835e6315c137e8f61720ae2bb6f713592eca6b0f123c22.png" alt="DeFi hackathon masthead" />

## GraphQL Workshop

We will be hosting the GraphQL workshop at 10pm PST on Friday, 11/1.

## Hackathon Challenges

### Painting with Coda
Build the coolest visualization on top of the [Coda GraphQL API](https://codaprotocol.com/docs/developers/graphql-api/). 

We've spun up a [public GraphQL read-only endpoint](graphql.o1test.net/graphql) to make it easier for you to get started!

Visualizations will be judged on the following criteria:

- Project must use data from the Coda GraphQL API
- Uniqueness of visualization
- Design & UI
- Efficiency of implementation

Here are some example project ideas we'd *love* to see: 

- Node Dashboard (Monitor Your Node)
  - Peer Map
- Block Visualization w/ slots (like [this](https://connerswann.me/2019/09/weekend-project-coda-blockchain.html) but better)
- TPS Meter
  - Count new blocks as they come in, compare with slot + epoch + timestamp 
- Calculate Fee Transfer Waste
- Block Explorer
- Tools for Node Operators

There is a total of $2500 in prizes to be won.

### Connect to the Testnet
Connect to the [Coda testnet](https://codaprotocol.com/testnet.html) and stop by our booth for a small prize. Read the [Getting Started](https://codaprotocol.com/docs/getting-started/) docs here.

Requirements for synchronizing to the network:

- Connect a node to the live network
- Successfully receive funds from the faucet
- Send a transaction to a friend! (any address is fine!)
- Show us at our booth

Learn about the Coda Protocol at [codaprotocol.com](https://codaprotocol.com/).

### Connect with the Coda AMI

We've prepared a Coda SFBW AMI for ya'll to connect to the testnet with that makes it easy with AWS. You'll need an amazon aws account, sign in and then visit the EC2 portal.

[](https://cdn.codaprotocol.com/website/static/img/ami/1-6c501486332637252a40c5aeb62d63df3108d509b527cccedf343f5d9884970d.png)

Select US West (Oregon) on the top-right:

[](https://cdn.codaprotocol.com/website/static/img/ami/2-dac56b33955b7d249eba4c5db643a71ec0db604877ed2d9ecc6d6c9d2f88e2df.png)

Then "Launch Instance":

[](https://cdn.codaprotocol.com/website/static/img/ami/3-461121606785a8f0bab6c6e3a02db7276975f7507ec9802be3b6e14bd64cd666.png)

Search for "coda-sfbw" and then select the "Community AMI section" and you'll see our AMI, `coda-sfbq-onclick-2019-11-01-0849`. Afterwards, click "Select":

[](https://cdn.codaprotocol.com/website/static/img/ami/4-c2e5baf8a00569b3f10c0f02f1df17a1188363c979df9358e60364651852ad55.png)

Select an Instance Type. You should select either a `t2.large` or a `t2.xlarge` type, preferably `t2.xlarge`. Afterwards, click "Review and Launch":

[](https://cdn.codaprotocol.com/website/static/img/ami/5-af38a30f0aeb1a2636e271f43616095bd445e8a5eab4fbd82335ab1609fd05db.png)

Now, select your security groups by clicking "Edit security groups". This is important to do so that you join the network and communicate with other peers:

[](https://cdn.codaprotocol.com/website/static/img/ami/6-cc1a1ece6ae25d0331acb4ab36ce1265aca9dc7b5a91e6c5a9d6d83b95757f2f.png)

You will now want to open the default external port (8302) and rpc-port (8303) to the public. You will do this by adding two "Custom TCP" role. The source of each of the roles should be "0.0.0.0/0". The port range should be filled in as 8302 and 8303. Then, click on "Review and Launch"
[](https://cdn.codaprotocol.com/website/static/img/ami/7-d2db24ecd85e161decaa03fb49cf5305edb8e38f45bd4e43b18b2045ae6791ee.png)

Make sure to review your settings one more time. They should correspond to the picture below. Once you're happy, click on "Launch"
[](https://cdn.codaprotocol.com/website/static/img/ami/8-1b60b9718e8b71824311d9848448e4bc3de4598f21a3c8874ac1a50aff1b295b.png)

You will then have to select an existing key pair or create a new one. More than likely, you will create a new key pair and you will have to select a name for the key. Afterwards, click on "Download Key Pair"
[](https://cdn.codaprotocol.com/website/static/img/ami/9-7407f873877e6a3f9b9c7adc0123301c1d562900e1c2a50fbded1ba2b73db894.png)

Your instance should now be created. Click on the instance id to see the status of the instance:
[](https://cdn.codaprotocol.com/website/static/img/ami/10-ba61e2f9d67f33767de7d43074ca80a4913aebc2f841f7d9825df5d2d4bb2071.png)

Wait for the instance state to have the "Instance State" to be `running`. Once it is `running`, You can ssh into the your instance by sshing into the ip address. For this example, ip address is `54.187.93.172`:
[](https://cdn.codaprotocol.com/website/static/img/ami/11-f3ffc3372c402e79625d451e8ecbe648ffda27b494862c853ac6e48e1fbfa798.png)

On the terminal, ssh into your instance using the following command:
`ssh -i <key> ubuntu@<ip-address>`. You may have to `sudo` the command to `ssh` into your instance. You can see an example below:
[](https://cdn.codaprotocol.com/website/static/img/ami/12-3b1d3085ad9c55b754d2e0e4e70e1afc955fa5c33dcb587963979f6fa96f609e.png)

Now, you can connect to the testnet with the following command:
```
coda daemon \
    -discovery-port 8303 \
    -peer /dns4/peer1-van-helsing.o1test.net/tcp/8303/ipfs/12D3KooWHMmfuS9DmmK9eH4GC31arDhbtHEBQzX6PwPtQftxzwJs \
    -peer /dns4/peer2-van-helsing.o1test.net/tcp/8303/ipfs/12D3KooWAux9MAW1yAdD8gsDbYHmgVjRvdfYkpkfX7AnyGvQaRPF \
    -peer /dns4/peer3-van-helsing.o1test.net/tcp/8303/ipfs/12D3KooWCZA4pPWmDAkQf6riDQ3XMRN5k99tCsiRhBAPZCkA8re7
```

You can now try to send a transaction by following the document, [My First Transaction](https://codaprotocol.com/docs/my-first-transaction/):
[](https://cdn.codaprotocol.com/website/static/img/ami/13-cfa34e094991c735ba2e165169d5cff9900ce9f96d5c38d7b9639bd69afe29f3.png)
