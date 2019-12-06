---
title: Coda Protocol Testnet [Beta] Retrospective - Phase 2.1
date: 2019-10-17
author: Christine Yip & Pranay Mohan
---

Phase 2 of Coda's Public Testnet Beta kicked off with a *lot* of interest in the staking challenge. 70 people signed up to stake on the new release and about 50 people ran a testnet node. Together, the community was going strong and racked up almost 100k testnet points* on the new Phase 2 [leaderboard](https://codaprotocol.com/testnet.html). Want to stay updated about Coda's testnet? Sign up for testnet updates [here](http://bit.ly/TestnetForm).

![](/static/blog/testnet-retro-2.1/twitter-card.jpg)

## Table of Contents

Release 2.2 Challenges

Retrospective Release 2.1 and Updates in 2.2

Community in Action

Release 2.1 Testnet Challenge Winners

## Release 2.2 Challenges

Release 2.2 of the Coda public testnet beta launched on October 8th, at 2pm UTC-7. This week's release is called Seared Kobe, and features a re-run of the staking challenge, new challenges for sending transactions and creating zk-SNARKs, and a **BIG** bonus for the *entire* testnet community if we reach an objective! Read on for details:

Challenge: The staking challenge continues on release 'Seared-Kobe'!

- 1000 pts* — For block producers that generate at least one block that is accepted into the ledger and finalized.

BONUS:

- 1000 pts*— For block producers that generate at least 16 blocks.
- 2000 pts* — For the block producer with most blocks in the chain.
- 1000 pts* — For the runner up.
- 500 pts* — For third place.

Challenge: Magic Windows

This week, we will have a co-op challenge for the community!

- There will be 4 one-hour windows in the week where node operators can do one of two things:

    1) Send as many transactions as you can (measured as the # of transactions that made it into a block during the hour).

    2) Win as many tokens from snark work as possible (measured as the total amount of coda earned through snark fees during the hour).

- 500 pts* — 1 transaction included in a block (during a window)
- 500 pts* — 5 coda in fees generated from SNARKs (during a window)
- 1000 pts* — for top 20 in most transactions included in a block, or most fees gained from selling SNARKs on the snarketplace (during a window)
- Bonus: DOUBLE POINTS for everyone if any window achieves at least 2700 transactions (included in a block for the hour)! Hopefully you can achieve this together!
- The 4 one-hour windows are:
Thursday October 10th, 9-10pm UTC-7
Saturday October 12th 9-10am UTC-7
Tuesday October 15th, 9-10pm UTC-7
Wednesday October 16th, 9-10am UTC-7

Challenge: GUI Feedback

We're shipping a GUI wallet that will allow you to begin sending and receiving coda! Without having to touch a terminal (well almost), see [GitHub](https://github.com/CodaProtocol/coda/releases/download/0.0.9-beta2/Coda.Wallet-0.1.0.dmg).

Please let us know about your experience by providing us with feedback on the GUI wallet.

- 500 points* for trying out the GUI Wallet and sharing feedback in the [Product channel in the forum](https://forums.codaprotocol.com/c/product) — please include "[GUI Feedback]" in the title of your post
- 1000 point* bonus for getting it to work on Linux.

Other on-going challenges:

-Community MVP for up to `1000 pts`*

-You Complete me for up to `1000 pts`*

-Bug Bounties for up to `1000 pts`*

-Introduction on Discord for `100 pts`*

See [here](https://codaprotocol.com/testnet.html) for all details on on-going challenges.

## **Retrospective Release 2.1 and Updates in 2.2**

Phase 2 kicked off with a new release Filet Mignon, which featured a staking challenge where Coda nodes had a chance to compete for the title of top Block Producer. Here are the quick numbers:

- 70 people signed up to stake
- 48 ran a node
- 44 produced at least 1 block
- 31 produced at least 8 blocks (the cut off for the bonus)

![](/static/blog/testnet-retro-2.1/pie-graph.png)

As you can tell, over 50% of sign ups were able to successfully produce blocks and participate in consensus, resulting in the largest staking testnet thus far. In addition, the network was remarkably stable over the 2 weeks, despite almost 50% of stake belonging to community node operators. We are grateful to these highly technical community members for their hard work on the testnet.

Notes from the week:

- The largest problem was memory issues

    Many node operators struggled initially due to their daemon occupying upwards of 8GB of RAM. Once they bumped to 12 or 16GB, this problem was largely resolved. But if we're to sanity check and do some napkin math, the Coda daemon shouldn't be hogging 8 gigs of memory. We investigated this issue and addressed it in a couple ways:

    - We first looked at the OCaml wrappers around the C++ code used for implementing cryptographic primitives. Because OCaml only sees the pointer to the C++ code, it doesn't detect the memory pressure from the C++ objects. As a result, the OCaml garbage collector wasn't running frequently enough, causing memory bloat. We fixed this by triggering the GC every 10 minutes, to free up memory more frequently. Unfortunately however, this only made a small improvement, so it didn't resolve the problem.
    - Additionally, we implemented a new hash function called [Poseidon](https://eprint.iacr.org/2019/458.pdf) inside SNARK circuits. Poseidon uses less constraints than Pedersen hashes, making more a more efficient hashing. This helped reduce the public parameter (proving key, verification key) size footprint from 1.2GB to 544MB. It also helps bring slot time down from 6 minutes to 3 minutes!
    - We're still investigating memory issues and will update as we learn more.
- "Split brain" network partition experiment
    - We ran an intentional experiment to partition the network (or soft fork it), and see how it recovered. You can read more details on how we conduct these tests [here](https://forums.codaprotocol.com/t/intentional-split-brain-network-isolation-and-repair/189).

This week's release 2.2 features two improvements to the user interfaces that node operators can use to spin up a Coda node:

- We heard your [CLI FYI suggestions](https://forums.codaprotocol.com/c/product), and began implementing them in the CLI! Read the [forum](https://forums.codaprotocol.com/t/some-cli-changes-in-testnet-2-2/220) post for more details.
- We're shipping a GUI wallet that will allow you to begin sending and receiving coda! Without having to touch a terminal (well almost), see [GitHub](https://github.com/CodaProtocol/coda/releases/download/0.0.9-beta2/Coda.Wallet-0.1.0.dmg).

As always, we continue to stabilize the protocol and add features in each testnet release cycle. Thanks again to the node operators and community for supporting and working to develop and grow Coda.

## **Community in Action**

In the first release of testnet Phase 2, we see a number of new names around in the community on [Discord](http://bit.ly/CodaDiscord), where our team and the community hangs out. The below quotes show what drove people to join the Coda community.

![](/static/blog/testnet-retro-2.1/community-1.png)

It's cool to see members dive in enthusiastically. After all, as *gnossienli* points out, what is a better way to learn about the first succinct blockchain than to try it out yourself?

Another new member, *Eosgermany*, was attracted to Coda, because of its uniqueness and the use of zk-SNARKs in the blockchain.

![](/static/blog/testnet-retro-2.1/community-2.png)

![](/static/blog/testnet-retro-2.1/community-3.png)

We welcome everyone with different kinds of backgrounds to join our community and to learn from each other, like our new member *Kunkomu.*

![](/static/blog/testnet-retro-2.1/community-4.png)

Besides the new members, our testnet veterans are still going strong. Our community MVP *_pk_* takes the staking challenge very seriously and did his best to learn from other community members and to find a way to win more opportunities to produce blocks on Coda Protocol.

![](/static/blog/testnet-retro-2.1/community-5.png)

![](/static/blog/testnet-retro-2.1/community-6.png)

It was fun to see how Phase 2 of Coda's public testnet Beta kicked off with the testnet users brimming with excitement. We are looking forward to continuing improving Coda Protocol together with the community.

## Release 2.1 Testnet Challenge Winners

Every release, we will reward community members who are making testnet a great, collaborative experience. Please join us in congratulating the winners of release 2.1!

Challenge 'Community MVPs'

- **GOLD** `1000 pts`* : @garethtdavies for providing and maintaining an accurate Coda Block Explorer to both the team and the testnet users throughout release 2.1, it has been a lifesaver in many cases!
- **GOLD** `1000 pts`* : @_pk_ for being one of our important testnet evangelists and a leader in the community - he referred about 6 new community members to join Coda's testnet, and he is always around and helpful!

Challenge 'Filet Mignon'

1. `4000pts`* - @Ilya | Genesis Lab (created 41 blocks!)
2. `3000 pts`* - @Matt Harrop / Figment Network (created 39 blocks)
3. `2500 pts`* - @Prague (created 35 blocks)

Challenge 'Bug Bounty'

`1000 pts`* Major - Star.LI, davidg, Matt Harrop / Figment Network

`200 pts`* Minor - ayenlis, Marius | Ubik Capital

Our entire team is grateful for the community's active participation in making the testnet a positive experience for everyone. We are working hard to iterate and work towards a robust succinct blockchain. [Stay tuned](http://bit.ly/TestnetForm) for more exciting things in the public Testnet Beta and see you over on [Discord](http://bit.ly/CodaDiscord)!

---

**Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
