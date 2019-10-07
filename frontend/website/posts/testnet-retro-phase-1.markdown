---
title:  Coda Protocol Testnet [Beta] Retrospective - Phase 1
date: 2019-09-20
author: Christine Yip & Pranay Mohan
---

Coda Protocol's Phase 1 of the public Testnet Beta has concluded! We had 8 successful weeks of testnet on a 1-week release schedule. The technical advancement that was made would not have been possible without the participation of enthusiastic members in the community. 

Some important milestones that we hit include:

- 126 community members participated
- 96 users connected to the testnet
- 270,000+ Testnet points\* were awarded
- 10 *really* cool and useful testnet related resources were created by the community (check them out under community highlights)

After Phase 1, we will progress to more stable, and scalable testnet releases and will move from a rapid iteration cycle of a 1-week cadence to a 2-week cadence to support this, read on to check out what new and exciting things to expect, and sign up [here](http://bit.ly/TestnetForm) to be notified via email when public Testnet Beta Phase 2 is open!

![](/static/blog/testnet-retro-phase-1/twitter-card.jpg)

**Table of Contents**

Public Testnet Beta Phase 2

Retrospective Phase 1

Community Highlights

Cool Community-Created Testnet Tools and Guides

**Public Testnet Beta Phase 2**

Phase 2 of the testnet will begin on September 24th with the first challenge, Filet Mignon. **Registrations for this Staking Challenge are open [here](https://forums.codaprotocol.com/t/staking-challenge-signups-filet-mignon/187) until September 24th 2pm UTC-7! Sign up to stake on the genesis block of Testnet Beta Phase 2!**

In Phase 1 of the testnet, we had one-week release cycles which gave us a chance to test out the feature-set in Coda and ensure that everything worked. In Phase 2, we're switching to two-week releases to build upon Phase 1's successes. Two-week release cycles will enable Coda developers to focus concurrently on maintaining the durability of each network, while also prioritizing feature development and protocol improvements.

**Goals for Phase 2 include:**

- Testing the durability and stability of each network and targeting high uptime
- Building momentum through each release, so that features introduced each cycle strengthen in quality in the following releases
- Automating [the points leaderboard](https://codaprotocol.com/testnet.html) to update user participation in real time
- Lowering block times, improving throughput, and ramping up protocol parameters to ensure faster finality
- Improving developer / user tools, and incorporating [CLI feedback received in Phase 1](https://forums.codaprotocol.com/c/product)

**Phase 2 release dates:**

- Release 2.1 (Filet Mignon): 9/24 — 10/7
    - **Make sure to [sign up](https://forums.codaprotocol.com/t/staking-challenge-signups-filet-mignon/187) for the staking challenge before the deadline on September 24th 2pm UTC-7**
- Release 2.2: 10/8 — 10/21
- Release 2.3: 10/22 — 11/4
- Future releases TBD

**Retrospective Phase 1**

Let's take some time and reflect on the remarkable testnet metrics from the past two months:

- 8 networks spun up, each testing different features in Coda
- 104 ledger accounts generated on the network
- 36 unique peers connected at one point
- Thousands of blocks produced

![](/static/blog/testnet-retro-phase-1/block-count.png)

In addition, Phase 1 of the public testnet featured two significant firsts for cryptocurrencies:

1. Usage of recursive zk-SNARKs to enable a succinct blockchain

    In week 6 of Phase 1, we ran a SNARK work challenge where node operators on the Coda network ran SNARK worker nodes and helped compress transactions. This resulted in:

    - 4192 SNARK proofs produced
    - 8853 codas in SNARK fees accrued

    Furthermore, it was a chance to test assumptions on the SNARKetplace economics and ensure that incentives were aligned.

2. Implementation of Ouroboros proof-of-stake consensus in a production network

    Week 4 featured a block producer challenge where stake was distributed amongst 30 keys belonging to the community, allowing users to produce blocks and earn coinbase rewards from staking their coda. By the end of the week, nodes across the world (including nodes in Russia, Canada, USA, UK, and Asia) had produced blocks and participating in permission-less and probabilistic proof of stake consensus.

Both of these technical achievements tested in practice helps harden and march towards a strong mainnet release candidate for Coda. We look forward to seeing even more technical developments and accomplishments from Phase 2.

**Community Highlights**

It was incredibly fun to see how users became leaders in he community and how passionate they were with being involved early in the development of Coda Protocol. Members steadfastly showed up in full force every week for the testnet releases, completed challenges, and built exciting things for the Testnet Beta. We want to give a special shout out to these highly technical leaders in the community and reward them with a head start on the Phase 2 Leaderboard.  Please join us in congratulating them!

Final Top 10 positions on the [Phase 1 Leaderboard](http://bit.ly/TestnetBetaLeaderboard):

**1st	garethtdavies** *(starting at 1000 pts\* in Phase 2!)*
**2nd	Alexander** *(starting at 900 pts\* in Phase 2)*
**3rd	y3v63n** *(starting at 800 pts\* in Phase 2)*
4th	whataday2day *(starting at 700 pts\* in Phase 2)*
5th	Dmitry D *(starting at 600 pts\* in Phase 2)*
6th	Ilya | Genesis Lab *(starting at 500 pts\* in Phase 2)*
7th	LatentHero *(starting at 400 pts\* in Phase 2)*
8th	novy *(starting at 300 pts\* in Phase 2)*
9th	ansonlau3 *(starting at 200 pts\* in Phase 2)*
10th	ssh *(starting at 100 pts\* in Phase 2)*

Community MVPs: *(+200 pts\* head start in Phase 2)*

- *Garethtdavies* for actively participating *every* week in the Testnet Beta Phase 1, finding the most bugs, building a CODA block explorer on top of Coda GraphQL API, and sharing his testnet experience and guides with the community in his blog.  An overachiever!
- *Whataday2day* for actively participating *every* week in the Testnet Beta Phase 1, and always being around to help out community members.
- *Pk* for sharing additional notes for setting up a node on the testnet. It's very much in line with the team's spirit, since it's also open source! Everyone can join and collaborate [here](https://hackmd.io/@pkrasam/coda)!

**Cool Community-Created Testnet Tools and Guides**

We also want to put the community spotlight on the following *very* cool things that community members built and created. Make a note of these tools and guides, as they might come in handy when you're going to set up a node on public Testnet Beta Phase 2!

- [Blockchain Explorer](https://codaexplorer.garethtdavies.com) built by *[garethtdavies](https://twitter.com/_garethtdavies)*
- [Instructions](https://forums.codaprotocol.com/t/unofficial-wsl-instructions/26?u=codacommunity) for windows users to set up a node on Testnet Beta using WSL, thanks to *whataday2day* .
- [Blog: First Steps with Coda GraphQL API](https://garethtdavies.com/crypto/first-steps-with-coda-graphql-api.html). Thanks *[garethtdavies*](https://twitter.com/_garethtdavies) for showing how to get started with Coda GraphQL API, which allows the development of future tools such as block explorers, wallets, etc.
- [Blog: Prototyping a Coda Blockchain Explorer](https://medium.com/@_garethtdavies/prototyping-a-coda-blockchain-explorer-dbe5c12b4ae2). Thanks to *[garethtdavies](https://twitter.com/_garethtdavies)*
- [Additional Notes + Screenshots for Setting Up a Testnet Node](https://hackmd.io/@pkrasam/coda). Thanks to *[pk](https://twitter.com/pkrasam)* . It's OSS, so everyone is invited to join and contribute!
- [Snark Tool for Ranking SNARK Workers](https://gist.github.com/garethtdavies/1819f2600507920c378ef65fb377c959) (fees and number of zk-SNARKs). Thanks to *[garethtdavies*](https://twitter.com/_garethtdavies) for creating and sharing the script with the community!
- [Live demo to set up a testnet node (Russian)](https://www.youtube.com/watch?v=QQ_0GI7kiPA). Thanks to *Alexander*
- [Testnet Set Up Guide (Russian)](https://telegra.ph/Zapusk-nody-Coda-v-Testnet-08-07). Thanks to *Alexander*
- [Testnet Documentation (Simplified Chinese)](https://shimo.im/docs/KRpKktRCx3pcqJc6/read). Instructions for connecting to testnet translated to simplified Chinese, thanks to *[ansonlau3](https://twitter.com/Anson_LauHK)*
- [Testnet Documentation (Traditional Chinese)](http://bit.ly/CodaCN) Instructions for connecting to testnet translated to Chinese. Thanks to *[ansonlau3](https://twitter.com/Anson_LauHK)*

Our entire team is grateful for the community's active participation in making the testnet a positive experience for everyone. We have been working hard to get Coda Protocol to the state it is today, and it has been exciting and fun to see you testing it! [Stay tuned](http://bit.ly/TestnetForm) for more exciting things in Phase 2 and see you over on [Discord](http://bit.ly/CodaDiscord)!

**Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*