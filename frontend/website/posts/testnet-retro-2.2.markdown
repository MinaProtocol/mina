---
title: Coda Protocol Testnet [Beta] Retrospective - Phase 2.2
date: 2019-10-24
author: Christine Yip & Pranay Mohan
---

Testnet Beta Phase 2.2 was a busy period, marked by a lot of tinkering and breaking. The community rose up to the challenge to increase the transaction throughput during 'Magic Window' hours, and a new bug soon came to the surface, which the team can now investigate. In the meantime, there are also notable technical developments in the protocol that will be rolled out with the new release of this week, called "Van-Helsing". We're excited to see how the testing with the community will go using these new components. If the community reaches a transaction objective together, we will reward everyone with 2X bonus points! Read on for more details and sign up [here](http://bit.ly/TestnetForm) to receive testnet updates.

![](/static/blog/testnet-retro-2.2/twitter-card.jpg)

## **Table of Contents**

Release 2.3 Challenges

Retrospective Release 2.2 and Updates in 2.3

Community in Action

Release 2.2 Testnet Challenge Winners

## Release 2.3 Challenges

The community racked up more testnet points* during release 2.2, reaching a total of more than 140.000 points* on the [leaderboard](https://codaprotocol.com/testnet.html). 

Due to the new bugs, the community could not reach the high target number for transactions. This week, the community will have a chance again to reach the objective in a "Magic Window" hour and earn **2X bonus points***! Besides the previous ongoing challenges (staking challenge, community MVP, bug bounties, etc.), we also have a new challenge to reward the leaders in the community, who share their tactics and strategies to reach the "Magic Window" objective. Good luck, Codans!

**Challenge: Magic Windows**

**[BONUS]** A co-op challenge for the community: if the objective of sending and including at least 1080 transactions in a block during a "Magic Window" hour is achieved, then *everyone* will get **double points***!

There will be 4 one-hour windows in the week where node operators can do one of two things:

1. Send as many transactions as you can (measured as the # of transactions that made it into a block during the hour).
2. Win as many tokens from snark work as possible (measured as the total amount of coda earned through snark fees during the hour).
- 500 pts* — 1 transaction included in a block (during a window)
- 500 pts* — 5 coda in fees generated from SNARKs (during a window)
- 1000 pts* — for top 20 in most transactions included in a block, or most fees gained from selling SNARKs on the snarketplace (during a window)

The 4 one-hour windows are:

Thursday October 24th, 9–10pm UTC-7

Saturday October 26th 9–10am UTC-7

Tuesday October 29th, 9–10pm UTC-7

Wednesday October 30th, 9–10am UTC-7

**Challenge: Coda Stratego**

Become a leader in the community and share your strategy for the "Magic Windows" challenge to get 500 points*. By sharing your tactics to send more transactions and sell more snarks, you'll help the community stress test the network more effectively. Feel free to share your strategy on a platform where the community can easily find it and get organized, for example - share a link to a new forum post at [forums.codaprotocol.com](http://forums.codaprotocol.com) in the #testnet-connected / #testnet-general channel.

**Challenge: Staking on "Van-Helsing"**

- 1000 pts* — For block producers that generate at least one block that is accepted into the ledger and finalized.

BONUS:

- 1000 pts* — For block producers that generate at least 16 blocks.
- 2000 pts* — For the block producer with most blocks in the chain.
- 1000 pts* — For the runner up.
- 500 pts* — For third place.

**Other on-going challenges to earn testnet points*:**

-Community MVP for up to `1000 pts`*

-You Complete me for up to `1000 pts`*

-Bug Bounties for up to `1000 pts`*

-Introduction on Discord for `100 pts`*

See [here](https://codaprotocol.com/testnet.html) for all details on on-going challenges.

## **Retrospective Release 2.2 and Updates in 2.3**

**Retrospective release 2.2:**                                                                                                                                                                                                                                                                                                                 

Release 2.2 continued the staking challenge from the previous release, and also added a challenge to stress the network with transaction throughput and increased SNARK generation. We updated the testnet parameters to allow for increased throughput, and discovered a bug where nodes went into long blocking compute cycles where they did not respond to messages from peers. When this happened frequently enough, peers ended up banning each other, leading to dropping peer count. We also believe this may have exercised some unusual race conditions in communicating with our gossip network process.

The root cause of this is thought to be two potential issues:

- changing parameters to enable higher transaction throughput

    In Coda, there is a data structure called a "scan state" — which is a set of tree-like structures that represent transaction SNARK work to be performed. If there are n transactions, this data structure grows n*logn in size. As a result, increased throughput helps tests the assumptions around the scan state. From this testnet, we found out that serialization and deserialization of scan state is really inefficient, and with higher transaction throughput, this caused issues. As a result, the above problem may have emerged

- changing to Poseidon hashing function

    We replaced Pedersen hashes with Poseidon hashes, which are more efficient in SNARKs, but also take longer to compute. This may also have led to the issues where nodes banned each other. 

We're still investigating this issue, and will share more as we debug. Follow along in the #testnet-operations Discord channel for live updates.

**Notable technical developments in Release 2.3 Van-Helsing:**

- libp2p is the peer discovery layer now!

    As mentioned in previous weeks we've been working to switch the discovery layer from the Haskell implementation of Kademlia to libp2p. This change was made because the previous discovery layer was quite buggy, and we expect libp2p to be more stable. This release will be useful to debug any issues from changing a key part of the networking stack.

- Memory issues improved with jemalloc

    We've had some issues in past weeks with daemon memory consumption being too high, and have done some work on improving this. Most recently, we changed our memory allocator the OCaml garbage collector uses from glibc malloc to [jemalloc](https://github.com/jemalloc/jemalloc). The reasoning for this change was that when we profiled memory usage, we discovered that fragmentation was a significant issue. Hence jemalloc, which emphasizes fragmentation avoidance helped us optimize memory usage. This had some pretty great initial results, showing a baseline of ~36% reduction in memory usage.

## **Community in Action**

Since the launch of Testnet Beta Phase 1, we've seen many people join Coda's community and felt their positive energy. We're very happy to be able to work closely with highly energetic and passionate members, like *garethtdavies, pk, whataday2day, kunkomu, gnossienli,* and many more. Together with the community, we're strengthening the protocol during every testnet release and working towards the first succinct blockchain to achieve true decentralization at scale.

![](/static/blog/testnet-retro-2.2/community-1.png)

*Gnossienli* noticing the steady progress of every testnet release

![](/static/blog/testnet-retro-2.2/community-2.png)

Testnet MVPs *pk* and *Ilya | Genesis Lab* were ready at the starting line of testnet release 2.2

![](/static/blog/testnet-retro-2.2/community-3.png)

*pk* is always brimming with positive energy and excited to test things out on the testnet

![](/static/blog/testnet-retro-2.2/community-4.png)

*Kunkomu* and *pk* discussing strategies to earn coda testnet tokens on the snarketplace (zk-SNARKs marketplace)

We also want to give a special shoutout to the newest asset in our community, *CrisF.* He joined the testnet recently, gave us helpful and detailed feedback, and even already found a bug!

![](/static/blog/testnet-retro-2.2/community-5.png)

We're truly grateful for all the interest and support from the community. It is very encouraging and a great motivation for us, and we will keep marching towards a robust mainnet candidate together. If you or if you have friends who want to join the community, then get started [here](https://codaprotocol.com/docs/getting-started/) and [join](https://discordapp.com/invite/Vexf4ED) us. We look forward to growing the community together.

## Release 2.2 Testnet Challenge Winners

Every release, we will reward community members who are making testnet a great, collaborative experience. Please join us in congratulating the winners of release 2.2! 

Challenge 'Community MVPs'

- **GOLD** `1000 pts`* : @kunkomu and @pk for always being around, positive, and helpful to the community members. @garethtdavies for always going the extra mile and updating the block explorer that he built for Coda - this time, he updated the explorer to paginate transactions!
- **SILVER** `500 pts`* : @CrisF for his passionate involvement, diving enthusiastically in Coda, providing detailed feedback about the testnet and submitting (bug) reports about his findings.

Challenge Staking on 'Seared Kobe'

1. `4000pts`* - @Matt Harrop / Figment Network (created 172 blocks!)
2. `3000 pts`* - @gnossienli (created 156 blocks)
3. `2500 pts`* - @pk (created 150 blocks)

Challenge 'GUI Feedback'

`1000pts`* - @pk 

`500pts`* - @novy 

Challenge 'Bug Bounty'

`1000 pts`* Major - Cris.F

Check out the [leaderboard](https://codaprotocol.com/testnet.html) for all winners and earned testnet points*.

Our entire team is grateful for the community's active participation in making the testnet a positive experience for everyone. We are working hard to iterate and work towards a robust succinct blockchain. [Stay tuned](http://bit.ly/TestnetForm) for more exciting things in the public Testnet Beta and see you over on [Discord](http://bit.ly/CodaDiscord)!

---

**Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
