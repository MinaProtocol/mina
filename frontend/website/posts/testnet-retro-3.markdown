---
title: Coda Protocol Testnet [Beta] Retrospective — Week 3
date: 2019-08-13
author: Christine Yip & Pranay Mohan
---

This is the fourth week that the Coda public testnet has been live! Last week, with the help of the early adopters in the community, we successfully stress-tested the network with increased transaction throughput, allowing us to identify potential issues and resolve them before the mainnet launch. A big thanks to all the testnet participants who have stayed active through the entire process, we wouldn't be able to test out the protocol in the wild without all your contributions!

This week's testnet release is called 'Medium Rare' - a pun on steak, since users will be staking their coda this week to earn new Testnet Points*.

![](Untitled-79219210-0508-4035-ae4d-c6db1804dae2.png)

## Week 4 Challenges

More challenges are ready for you to win points*! Last week, we saw some fierce competition as participants battled to see who could send the most transactions. Read on for winners of last week and see where you rank now on the [leaderboard](http://bit.ly/TestnetBetaLeaderboard). 

This week's challenges:

**Challenge #9 ‘Block Party’**

This is one of our biggest points challenge yet, with up to 4000 points* on the line for the winner. In order to complete this challenge, you'll need to stake coda to be an active block producer. Block producers who generate more than 14 blocks this week will successfully complete this challenge - 1000 pts*. BONUS for those who produce the most blocks: 1st place - +3000 pts*, 2nd place - +2000 pts*, 3rd place - +1000 pts*.

**Challenge #10 ‘Bookworm’**

Reach Trust Level 1 'Basic' on Coda Protocol's forum. We believe reading is the most fundamental and healthy action in any community. If you are willing to spend a little time reading, you will quickly be promoted to the first trust level. Sign up on our [forum](https://forums.codaprotocol.com/) , enter at least 5 topics, read at least 30 posts, and spend a total of 10 minutes reading posts to obtain Trust Level 1 'Basic' and 100 Testnet Points*.

**Challenge #11 ‘Don't Break the Chain!’**

Earn extra bonus points for every uninterrupted weeks that you participated in the testnet and earned points*.

If you earned points this week and last week - 100 pts*

If you earned points this week and the previous 2 weeks - 200 pts*

If you earned points this week and the previous 3 weeks  - 300 pts*

Etc.

You can still earn Testnet Points* with past challenges! [Find them here](https://codaprotocol.com/docs/coda-testnet/#testnet-points).

## Community in Action

In the third week after the release of Testnet [Beta], the team felt courageous enough to invite the early Coda adopters to stress-test the network and to see how the testnet would behave under high transaction volumes (see challenge #8 ‘Bonanza’). This was a success — more so than we imagined! As noticed by one of the community members, *novy*, the transaction throughput from everyone participating allowed us to surface issues in parts of the codebase that we can now dig into and fix. 

![](Untitled-41f35033-e3ac-403f-8576-bcae4b22da3e.png)

This week has been a rollercoaster ride. At one point we were experiencing *a long fork*. One fork consisted of 287 blocks and the other fork 225.

![](Untitled-5d64e759-c0eb-463a-824f-563c3ed70e50.png)

After some time, it seemed that this bug was resolved on its own, and the community was celebrating the recovery..

![](Untitled-55e9e1d7-82db-44cc-8b95-8641463129c4.png)

..but we had to brace ourselves for another dive on the roller coaster - about 9 hours of heavy testing from our dedicated community later, the network was down again.

![](Untitled-a85d105a-9cb4-48e3-9c01-2d01023a75db.png)

After a few more ups and downs on the ride, we decided that is has been enough fun and excitement for the week. We took down the network to dig into the newly discovered bugs and to fix them. This finally gave the users like *jspadave* and *whataday2day* room to take a breather.

![](Untitled-31148570-2fff-441e-bbd4-e58e3e931024.png)

## Week 3 Retrospective

"Everybody has a plan until they get punched in the mouth." — Mike Tyson

In this case, Mike may as well have been talking about cryptocurrency networks, because all bets are off the table when transaction volumes spike. Last week's challenge as mentioned above was 'Bonanza', where users were encouraged to send as many transactions as possible. We knew we were in for some fun surprises, but could not have predicted the outcome. The increased transaction throughput from everyone participating allowed us to surface issues in the codebase as well as operationally. See below for more details:

Issue 1 — Snark work bottleneck

Initially there was a network choke point due to a bottleneck in snark work. In Coda, there is a tree-like data structure that tracks the "transaction snark scan state", which consists of transactions queued up to be snarked. This data structure became saturated quickly and queued up work was not being picked up by enough workers. The O(1) Labs nodes run snark workers that usually pick up the slack, but in this situation, the transaction throughput was higher than usual. 

The main issue was that all the O(1) Labs nodes were running both block producers and snark workers, causing both roles to compete for compute on the same machines. We `nice nice`'ed those workers ([nice](https://en.wikipedia.org/wiki/Nice_(Unix)) is a program that allows you to reduce the priority of processes), but even those `nice nice`'s were too much for our VMs and we couldn't produce a block fast enough to fill a slot. This triggered an edge case that we had never exercised, causing all our nodes to die!

The fix was relatively simple - we spun up a new machine (with 96 cores!) purely dedicated for snark work.

Issue 2 — The looooooong fork

Midway through the week, the network experienced a long fork where two chains diverged quite significantly. Adding to the woes, all of the O(1) Labs nodes were stuck on one fork, while many of the community members' nodes were on the other. Since the O(1) Labs had the majority of the coda staked, the other nodes were not able to produce blocks, and were not observing any "correct" blocks being gossiped in the network. This basically froze the network due for most participants.

The cause for the long fork was primarily due to a low `k` value. `k` is a constant that measures the number of blocks until the network assumes finality for blocks. This helps control the consensus mechanism. We artificially set the constant low in order to make the network move faster and hit more edge cases. Unfortunately, we were a bit overzealous, and this caused more forking in the network, as blocks were assumed to be finalized very quickly.

In this case, after enough epochs (a measurement of time in Coda), the forks resolved on their own - but the downside was that all the transactions that users get on the "dissolved" fork were lost!

Issue 3 — Strange Digits

The transaction mempool uses very interesting data structures under the hood (if you're into diving deeper check out [this document](https://github.com/CodaProtocol/coda/blob/develop/rfcs/0010-txpool-dos-mitigation.md)). While we had very good unit test coverage on this data structure, it turned out that under certain workloads which hadn't appeared in our internal testing, we triggered a crash here. And this is a viral crasher, for all the nodes that you gossip the transaction to, everyone crashes! This is still under investigation and you can track the issue here: [https://github.com/CodaProtocol/coda/issues/3143](https://github.com/CodaProtocol/coda/issues/3143)

Thanks to all the community members for bearing with the technical difficulties this week. While the network may have struggled, the challenge was a success, allowing Coda developers to test theoretical code in production and harden the protocol.

This week's testnet release is called 'Medium Rare' - a pun on steak, since users will be staking their coda this week. The url to connect will be: [medium-rare.o1test.net:8303](http://medium-rare.o1test.net:8303/)

## Community MVP Winners

Each week, we reward the community leaders who are making testnet a great, collaborative experience. Please join us in congratulating the Community MVP Winners!

**Winners Challenge #8 'Bonanza'**

Last week, we had our biggest points challenge yet, with up to 4000 points* on the line for the person who sends the most transactions. Congratulations to the winners!

1st place 4000 pts* - @Dmitry D (over a thousand transactions!) 

2nd place 3000 pts* - @y3v63n

3rd place 2000 pts* - @whataday2day

**Bug Bounties**

Major Bug Bounty 2000 pts*: @AlexanderYudin - (see [github](https://github.com/CodaProtocol/coda/issues/3159)) 

Minor Bug Bounty 200 pts*: @ssh - (see [github](https://github.com/CodaProtocol/coda/issues/3128)) 

**Community MVP Gold / Challenge #7 'You Complete Me' (+1000 Testnet Points*)**

@alexander for translating testnet instructions into Russian and adding useful screenshots. This makes it very helpful for other technical Russian community members to get connected to Testnet [Beta]! You can find them [here](https://telegra.ph/Zapusk-nody-Coda-v-Testnet-08-07).

@whatday2day for setting up step by step instructions to run a testnet node on WSL. Currently, the official documentation includes instructions for macOS and Linux. @whataday2day provided step by step instructions to get Coda running on Windows Subsystem for Linux. The instructions are added to our Community Wiki on Coda Protocol's [forum](https://forums.codaprotocol.com/t/unofficial-wsl-instructions/26?u=codacommunity).

**Community MVP Silver (+500 Testnet Points*)**

@jspadave for always being around, positive and for his unwavering perseverance to keep going to the testnet faucet, even if he did not even get a drip to drink. Thank you for working with the engineering team to improve the faucet transactions, @jspadave!

@ssh for always being around, continuously supporting the team by providing useful feedback, and giving pointers for improvement (e.g. incorrect weblinks, align blockchain terminology, etc.).

@joe_land1 for always being around, support other community members when they get stuck, and also for offering help to them to run a testnet node on Windows.

For participants who were not able to send 20 transactions last week due to network issues, don't worry! We will have another challenge to send transactions where you will have the chance to win full points from this week again.

## Conclusion

We are overwhelmed by the community's contributions and enthusiasm to participate in the Testnet [Beta] and to tackle the challenges. The transaction throughput that the community created in the last week proved to be of incredible value to help us strengthen the foundations for a new succinct blockchain and a decentralized economic system.

We would like to express our sincere gratitude to all testnet participants for joining early on this unpredictable and fun ride, and their unwavering support.

![](Untitled-4f166d79-321e-4854-b98d-927bac6d08f2.png)


--- 
*\*Testnet Points (abbreviated ‘pts.’) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*