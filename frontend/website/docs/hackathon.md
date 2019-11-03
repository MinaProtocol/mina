
# DeFi Hackathon

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/defi-ccd2aaa30d2123423d835e6315c137e8f61720ae2bb6f713592eca6b0f123c22.png" alt="DeFi hackathon masthead" />

## GraphQL Workshop

We will be hosting the GraphQL workshop at 10pm PST on Friday, 11/1.

## Hackathon Challenges

### Painting with Coda
Build the coolest visualization on top of the [Coda GraphQL API](https://codaprotocol.com/docs/developers/graphql-api/). 

We've spun up a [public GraphQL read-only endpoint](https://graphql.o1test.net/graphql) to make it easier for you to get started!

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

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/1-6c501486332637252a40c5aeb62d63df3108d509b527cccedf343f5d9884970d.png" alt="DeFi hackathon masthead" />

Select US West (Oregon) on the top-right:

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/2-dac56b33955b7d249eba4c5db643a71ec0db604877ed2d9ecc6d6c9d2f88e2df.png" />

Then "Launch Instance":

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/3-d3f7c7d3fee42b4e428700996e874d5a67691b85b5dc1208bb9a810d907e1a21.png" />

Search for "coda-sfbw" and then select the "Community AMI section" and you'll see our AMI, `coda-sfbq-onclick-2019-11-01-0849`. Afterwards, click "Select":

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/4-03169e19295db99953423f1dbbb1e7e35068932e98821fb269f1ee0fc8c0344d.png" />

Select an Instance Type. You should select either a `t2.large` or a `t2.xlarge` type, preferably `t2.xlarge`. Afterwards, click "Review and Launch":

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/5-3458cb87a86ce453d14d51c96fa58ad141a3cc06a25961f4a41a318f6e05f3f1.png" />

Now, select your security groups by clicking "Edit security groups". This is important to do so that you join the network and communicate with other peers:

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/6-f18b7cc85313ab812c4dd298844aa988337d57816804403498e99ac1c410b221.png" />

You will now want to open the default external port (8302) and rpc-port (8303) to the public. You will do this by adding two "Custom TCP" role. The source of each of the roles should be "0.0.0.0/0". The port range should be filled in as 8302 and 8303. Then, click on "Review and Launch"
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/7-b50b0b0fe180e0149f7e1b5401418c9c63661cb6ac540b8896070c9c6af6e92f.png" />

Make sure to review your settings one more time. They should correspond to the picture below. Once you're happy, click on "Launch"
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/8-506d79339ea1832f5b2c5582f32c361b2fd638c866b155368f05adc16cdadc89.png" />

You will then have to select an existing key pair or create a new one. More than likely, you will create a new key pair and you will have to select a name for the key. Afterwards, click on "Download Key Pair"
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/9-da39007510ecc6a5df18b898db673fc0db5c42fc0e85f72680dd87162de4e56d.png" />

Your instance should now be created. Click on the instance id to see the status of the instance:
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/10-ba2d226d55d26fd9d0750bdbe80869afe21d07d2993aec02f8d9577b838ad872.png" />

Wait for the instance state to have the "Instance State" to be `running`. Once it is `running`, You can ssh into the your instance by sshing into the ip address. For this example, ip address is `54.187.93.172`:
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/11-334a674d6fb73dbf371f6dfcf59f92f2424126fb538efa538734178751d1ced4.png" />

On the terminal, ssh into your instance using the following command:
`ssh -i <key> ubuntu@<ip-address>`. You may have to `sudo` the command to `ssh` into your instance. You can see an example below:
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/12-bfe70dcd5845ddc3e2a2fa35f7868beb6645d836297a14989acef40e238ac66c.png" />

Now, you can connect to the testnet with the following command:
```
coda daemon \
    -discovery-port 8303 \
    -peer /dns4/peer1-van-helsing.o1test.net/tcp/8303/ipfs/12D3KooWHMmfuS9DmmK9eH4GC31arDhbtHEBQzX6PwPtQftxzwJs \
    -peer /dns4/peer2-van-helsing.o1test.net/tcp/8303/ipfs/12D3KooWAux9MAW1yAdD8gsDbYHmgVjRvdfYkpkfX7AnyGvQaRPF \
    -peer /dns4/peer3-van-helsing.o1test.net/tcp/8303/ipfs/12D3KooWCZA4pPWmDAkQf6riDQ3XMRN5k99tCsiRhBAPZCkA8re7
```

You can now try to send a transaction by following the document, [My First Transaction](https://codaprotocol.com/docs/my-first-transaction/):
<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/ami/13-82c7d41da2c7652c4720718213f490a041799839cd6fca749971eaeb42550047.png" />
