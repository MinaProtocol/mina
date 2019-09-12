---
title: Coda Protocol Testnet [Beta] Retrospective — Week 7
date: 2019-09-11
author: Christine Yip & Pranay Mohan
---

We’ve arrived at the 8th week since Testnet [Beta] was launched. Last week, we saw about 40 testnet users participating in the ‘Grab Bag’ challenges and members becoming leaders in the growing community. Read on to check out the testnet findings of last week and the exciting things that the Codans have been building. Together, the community racked up more than 250,000 Testnet Points[\*](#disclaimer) (check out the [leaderboard](https://codaprotocol.com/testnet.html)) and this week, we have a new challenge again!

![](/static/blog/testnet-retro-7/twitter-card.jpg)

## Table of Contents

Week 8 Challenges

Retrospective Week 7

Community in Action

Community Awards

## Week 8 Challenges

**Challenge #20 — Golden Hour:**

This week's challenge is all about timing. We will have two "Golden Hours" every day:

9AM-10AM PST (UTC-7)

9PM-10PM PST (UTC-7)

During a Golden Hour, you'll have two actions you can perform to complete the challenge:

1) Send as many transactions as you can (measured as the # of transactions that made it into a block during Golden Hour).

2) Win as many tokens from snark work as possible (measured as the total amount of coda earned through snark fees during Golden Hour).

If this week, at least one of your transactions is included in a block during a Golden Hour, you will earn 250 pts[\*](#disclaimer).
If you sell at least one snark work during a Golden Hour, you will earn another 250 pts[\*](#disclaimer).

BONUS — At the end of the week:

- First place in either category will win +1500 pts[\*](#disclaimer).
- Second place in either category will win +1000 pts[\*](#disclaimer).
- 3rd - 20th place in either category will win +500 pts[\*](#disclaimer).

Note that only transactions that make it into a block and only snarks that are bought DURING the Golden Hours will count towards this challenge. You can participate in both categories, and win up to 3500 pts[\*](#disclaimer) for this challenge.

**Challenge #15 — "GraphCoolL"**

User *garethtdavies* built an awesome [CODA Blockchain Explorer](https://www.notion.so/codaprotocol/Testnet-Beta-Week-7-Recap-Blog-Post-9a936a0cb3c646189816f6ff872422b8#14bac81942f24cebab129c5b29752e14) on top of the [Coda GraphQL API](https://garethtdavies.com/crypto/first-steps-with-coda-graphql-api.html) and won Gold `2500 pts`[\*](#disclaimer) for this challenge last week. 
However, we noticed that some community members were confused about the deadline for challenge #15. In case you're building an interesting tool on top of the Coda API, we still want to reward you in the next week!
When your tool is completed, please share it with us as a new thread on the [forum](https://forums.codaprotocol.com/) with a [GraphQL] tag, so we'll know about your creation! The full description of challenge #15 can be found [here](https://codaprotocol.com/docs/coda-testnet/#challenges).

## Retrospective Week 7

Another week, another gossip net bug! One thing to keep in mind while working on cryptocurrencies is that computing has historically converged on the client-server model of networking. As a result, lots of money and time has been spent optimizing for that architecture, allowing for the modern internet that we all love and use daily. Relatively, peer-to-peer networks are still in their youth in terms of development and resiliency. We can count on one hand the p2p systems that have really broken through (BitTorrent anyone?).

Now, however, with the advent of cryptonetworks with billions of dollars at stake, p2p architectures are being treated as first-class citizens, allowing for more funding and development attention. We see the fruits of this in open source projects like libp2p that the community is converging on as an alternative to rolling their own solutions. This is an exciting time to be in this space, and we'll see compounding growth as our set of tools standardize and harden. At Coda, we're excited to be on this frontier and hope to share our experiences and learnings throughout the way with the community. 

Notes from this week:

**Leaky Faucet**

We noticed that some users were not getting tokens from the faucet, even though it looked like transactions were being issued. After some investigating, we realized it was due to nodes not able to infer the correct nonce for a pending transaction.

Some context -- all transactions have nonces attached to them in order to prevent transaction replays. Each time an account issues a new transaction, the nonce (you can think of it as a counter) must be incremented by one. If only one transaction can be pending at any given time, it is trivial to lookup the current nonce in the ledger and then send a transaction with the next nonce. However, since more than one transaction can be pending in Coda, we need to know what other transactions we have pending. Typically this is done by looking in the transaction pool for all pending transactions corresponding with an account to get an "inferred nonce" for any future transaction.

Unfortunately, we noticed that the inferred nonces for the faucet account were inconsistent amongst different nodes in the peer-to-peer network. As an example, let's say the current account nonce for the faucet was 5, and the faucet had issued transactions with nonces 6, 7, and 8. If none of the block producers received the transaction with nonce 6, then the network would never be able to apply transactions with nonces 7 and 8, causing that account to essentially be stuck. Even worse, if those transactions became evicted from the transaction pool, there would be no way to recover them, other than to reissue them.

As with many issues we've noticed, we attributed this bug to the gossip network not yielding eventually consistent transaction pools amongst nodes. In the short term, we mitigated this issue by asking several active testnet members to help us by being human faucets (shout out to *Alexander*, *y3v63n*, *whataday2day*, and others who stepped up). In the medium term, we're considering addressing this by periodically re-gossiping transactions that have been pending for a certain amount of time. Finally, in the long term, we hope the migration to libp2p will help resolve these networking related issues.

**SNARK fees greater than coinbase reward**

As mentioned in an [earlier blog post](https://codaprotocol.com/blog/testnet-retro-6.html), block producers on the Coda network need to buy snarks off the "snarketplace" before their block will be accepted. In addition, block producers need to buy the snarks in the order that they were added to the scan state (the Coda data structure that keeps track of the pending work to be done). Ordering is enforced in order to reduce the surface area for attack via gaming the ordering and to also reduce protocol complexity.

As a consequence, there was an interesting bug where if the first snark to be bought cost more than the coinbase reward, the block producer node would crash. The reason being - the protocol required the block producer to use the coinbase reward to usually purchase the first snark, and the transaction fees to purchase snarks further down the ordering continuum.

To mitigate this issue, we fixed the code to not crash upon this error, and simply log it while skipping block generation. However, we plan on changing the algorithm to allow more flexibility for the block producer to purchase another required snark that is lower on the ordering continuum with the coinbase reward and use the transaction fees to purchase any snarks more expensive than the block reward.

## Community in Action

In the last 1.5 months of testing, over 120 users connected to Coda's Public Testnet [Beta]. Last week, we welcomed more members to the community, who all have different reasons for joining Coda, like our newest members *NetOperator Wibby* and *nii236*.

![](/static/blog/testnet-retro-7/netoperator-34ea.png)

![](/static/blog/testnet-retro-7/nii-d2ba.png)

It is also *very* cool to see how the community has grown and how the core members are *thriving*. One of the testnet evangelists, *garethtdavies,* built a [CODA blockchain explorer](https://codaexplorer.garethtdavies.com/) which is being received with much enthusiasm in the community, as can be seen below. Check out his blog post about building the blockchain explorer on top of the [Coda GraphQL API](https://garethtdavies.com/crypto/first-steps-with-coda-graphql-api.html)  [here](https://medium.com/@_garethtdavies/prototyping-a-coda-blockchain-explorer-dbe5c12b4ae2).

![](/static/blog/testnet-retro-7/dmitri-8c11.png)

![](/static/blog/testnet-retro-7/explorer-c05.png)

*Ansonlau3* translated the testnet documentation to [Chinese](http://bit.ly/CodaCN) to help Chinese community members get started, and *Alexander* helped out the community by serving as a human testnet faucet during the last week. It is incredibly cool to see that a spirit of collaboration and helpfulness is ruling in the community!

![](/static/blog/testnet-retro-7/anson-302.png)

## Challenge Winners Week 7

Each week, we reward the community leaders who are making testnet a great, collaborative experience. Please join us in congratulating the winners!

**Challenge #19 — "GraphCoolL"**

Gold 2500 pts[\*](#disclaimer) : garethtdavies for building a [CODA blockchain explorer](https://codaexplorer.garethtdavies.com/) on top of the Coda GraphQL API! Check out his blog post [here](https://medium.com/@_garethtdavies/prototyping-a-coda-blockchain-explorer-dbe5c12b4ae2).

**Challenge #4 — "Community MVP":**

Gold 1000 pts[\*](#disclaimer) : Alexander for being the human faucet when our faucet bot was rebelling and refusing to send transactions.

**Challenge #7 — "You Complete Me":**

Major Contribution 1000 pts[\*](#disclaimer) : Ansonlau3 for translating the [testnet documentation to Chinese](//bit.ly/CodaCN). Now it's easier for our Chinese community members to get started with the testnet as well!

The entire team at O(1) Labs would like to express our sincere gratitude and appreciation to our growing and thriving community!

<p id="disclaimer">
\**Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
</p>

