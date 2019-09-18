---
title: Coda Protocol Testnet [Beta] Retrospective — Week 8
date: 2019-09-18
author: Christine Yip & Pranay Mohan
---

It has been 8 weeks since Coda Protocol's Public Testnet Beta was launched. Last week's testing provided us with interesting findings in the protocol - read on to see how a bug (!) saved the day.

For the next testnet release "Filet Mignon", there will be an opportunity for testnet users to participate in the upcoming *Staking Challenge*. The deadline for registration is September 24th 2PM UTC-7, so be sure to check out the instructions [here](https://forums.codaprotocol.com/t/staking-challenge-signups-filet-mignon/187) and sign up on time if you want to participate!

Next week, we will have a break from the testnet. Stay tuned, we will announce soon what happens next!

## Table of Contents

Retrospective Week 8

Community Awards

## Retrospective Week 8

*"You've set my world on fire / And I know, I know everything's gonna be alright" — Kacey Musgraves, Golden Hour*

The past week's challenge was "Golden Hour", where Coda testnet users were encouraged to participate in two categories of competition between the hours of 9am-10am and 9pm-10pm:

1. Send the most transactions.
2. Receive the highest total fees from SNARKs sold.

Users were very active during the golden hours, as evident by the metrics:

- Users sent a total of 2108 transactions.
- Snark worker nodes accrued 1530 codas in fees from SNARKs.
- The protocol hit a throughput of 0.2 TPS (transactions per second), which doubled our expectations of 0.1 TPS for the first testnet phase.

While this figure is unimpressive in absolute standards, even when compared to Bitcoin's 7 TPS, this was a success given the conservative parameters we started the system with. As we progress out of beta phase of the testnet, we plan to slowly ramp up to double digit TPS, and then work our way to throughput that would truly allow for decentralization at scale.

## Bugs to the rescue

So what happened this week that was unanticipated? Well, everything started great — the "Golden Hour" testnet launched on Tuesday afternoon, and had the first test of transactions and SNARK volume that evening at 9pm PST. Everything seemed to go fine, and transactions were making it into blocks. However, after the 9am golden hour the next day, blocks stopped being produced, and as a result, transactions were stalling. This issue persisted through the next two golden hours, disrupting users' ability to send transactions. At this point, we were already in debug mode, but were not able to identify the issue yet. The saving grace came when a block producer crashed due to another unrelated error, and upon reboot started producing blocks again! When we restarted all the O(1) Labs block producers, we noticed the same thing.

For the first time, a bug had rescued us and resumed the network! What caused this? An invalid SNARK — perhaps one generated with old parameters —  wasn't being checked by clients before inclusion in a block. Some context — the public parameters are the verification key and proving key that are generated during a multiparty computation in order to be able to produce and verify SNARKs. When the SNARK circuit in question changes, these public values also change and become incompatible with other SNARK circuits.

As such, each of the Coda testnets has a new SNARK circuit with new proving and verification keys. What we think had happened in this case was that a node produced a SNARK using a proving key from a prior testnet. The peers that received this SNARK proof did not check whether it was valid or not and simply included it in a block if the node was a block producer. Then, when it came to broadcast the block to the world, the node did a sanity check by applying the new block to its own chain. When this failed, the node dumped the block and persistently tried again, to no avail (as the invalid SNARK was still in memory). Thus, by crashing and dumping all the old items in memory (since we don't persist the mempools), the lone block producer recovered itself and brought the network back.

We're working on fixing multiple things related to this week:

- We will now check SNARKs to make sure they're constructed using the right parameters. Concurrently we're exploring the usage of SNARKs that support universal and continuously updatable parameters even as the circuit changes, but they are quite recent in literature, and still need performance gains to be adopted in production.
- We're going to rebroadcast transaction pool and snark pool items that haven't been included in a block recently, so as to help circulate items to nodes that may have crashed and dumped their previous memory pools.
- Ironically, we don't know what caused the initial bug that helped restart the network, but we're debugging and will squish this helpful bug (sorry, we can't help it).

Lastly, another shoutout to user @garethtdavies for [building a block explorer](https://medium.com/@_garethtdavies/prototyping-a-coda-blockchain-explorer-dbe5c12b4ae2), which helped the team debug throughout this process. Stay tuned for more debugging journeys and interesting engineering reports as we continue to develop and harden Coda.

## Challenge Winners Week 8

Each week, we reward the community leaders who are making testnet a great, collaborative experience. Please join us in congratulating the winners!

**Challenge #20 — "Golden Hour"**

We have two groups of winners who got the most transactions included in a block during the Golden Hours of last week. One group with testnet users, and another group of highly engaged members who received testnet accounts with large funds to help out as "human faucets". Because the second group had access to large funds, they smartly used their wealth to get their transactions included in blocks by offering crazy high transaction fees!

Most transactions from testnet users:

1750 pts[\*](#disclaimer) 1st place - Tyler34214 (313 transactions)

1250 pts[\*](#disclaimer) 2nd place - Prague

Most transactions from wealthy "human faucets":

1750 pts[\*](#disclaimer) 1st place - y3v63n (1231 transactions)

1250 pts[\*](#disclaimer) 2nd place - garethtdavies

Most snark fees earned:

1750 pts[\*](#disclaimer) 1st place - Dmitry D (248 SNARK fees)

1250 pts[\*](#disclaimer) 2nd place - Ilya | Genesis Lab 

**Challenge #4 — 'Community MVP':**

1000 pts[\*](#disclaimer) : Ansonlau3 for providing testnet documentation in *[simplified Chinese](https://shimo.im/docs/KRpKktRCx3pcqJc6/read)*  to help Chinese community members get started on the testnet.

The entire team at O(1) Labs would like to express our sincere gratitude and appreciation to our growing and thriving community!

<div id="disclaimer" />
\**Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
