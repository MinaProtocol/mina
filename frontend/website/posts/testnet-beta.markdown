---
title: O(1) Labs Releases Testnet [Beta] for Coda Protocol, the First Succinct Blockchain
date: 2019-07-24
author: Claire Kart
---

We’re thrilled to announce that Coda Protocol launched its first public testnet in Beta today, July 24th 2019 at 2pm PST. We’ve seen interest from more than 700 members of our community in joining, so we expect that this will be an exciting and engaging process thanks to the efforts of a core group of our community evangelists.

In this blog post, we will introduce Coda at a high level, including our motivations, philosophy, and technology innovations, as well as share a bit more about the testnet process and how the community can get involved.

## About Coda

At the core of blockchains and cryptocurrencies is that they allow us to trade centralized institutions for decentralized networks. At a base, technological level, this comes from a distributed network of validators being able to come to consensus about the state of the blockchain. Put a different way, networks are decentralized in large part because of the breadth of the network of validators who can independently validate them.

A decade into the blockchain and cryptocurrency industry, however, we’re discovering an interesting quirk creating a hidden force for centralization. Blockchains are, increasingly, victims of their own success.

As a blockchain is utilized more and more (a good thing), the chain becomes longer and longer. As this happens, it decreases the pool of people who have the computational and bandwidth capacity to participate in validating and securing the network (a bad thing). Over time, this pushes blockchains towards a new form of centralization with only those with the highest network and computational capacity at the top of the food chain.

At its base, Coda is designed to address this problem. Our goal is to enable user-owned, universally-accessible digitized finance through the cryptographic innovation of a tiny, accessible, constant-sized blockchain.

## Here's how it works.

Whereas other blockchains grow with every new transaction, we replace the blockchain with a constant-sized zero knowledge proof only the size of a few kilobytes, or a page of text. This proof is a replacement of having to check the entire blockchain’s history, standing in exactly for the process of verifying the underlying transactions. What’s more, it can be updated efficiently by using recursive zk-SNARKS.

Let’s use the name succinct blockchain to refer to the combination of a state (consisting of the set of account balances and information required for consensus) and a zk-SNARK which says “there is a blockchain which you could have downloaded that would have convinced you that this is actually the current state”. Just as we can update a plain old blockchain by appending a new block to the end, we can update a succinct blockchain by applying the block to get an updated state and combining the previous proof with the new block to get an updated proof.

We accomplish this is by creating a proof that says “there is a proof that said state S had a blockchain backing it AND there is a single block which when applied to state S gives us that new state”. Because zk-SNARKs are succinct, this new proof is still as tiny and easy to verify as the last. For those who want to learn more, this technique is called recursive composition of zk-SNARKs.

There’s obviously a lot to unpack in terms of how this works, so if you want to dive in deeper, we recommend you check out this technical introduction to Coda.

## Why this matters.

What does this approach do for Coda though? In short, it means that we can have a cryptocurrency that is constant-sized and resource-efficient. In turn, this addresses accessibility problems and the inevitable success-enabled form of centralization discussed above.

Practically, this means we can have a better form of programmable money:

* No compromisable 3rd parties that have unknown incentives, create dependencies on their uptime, or lack accountability to have to rely on to trust the state of the blockchain and use the cryptocurrency. Users can run nodes from any device at any time.
* The Coda javascript API has equivalent security to a full node. This creates minimal complexity to integrate and build with Coda.
* The fact of Coda’s constant size and resource efficiency isn’t limited to right now, but will persist regardless of throughput or years of transaction history.

## About Testnet [Beta]

Cryptocurrency projects run the gamut from extremely gated and permissioned to entirely open source. We’ve always been focused on the latter. Since we open sourced our code in October 2018, everything we’ve built has been public.

This same philosophy informed our decision to open our testnet to public beta now. We’re opening ourselves as early as possible because we want to give our community a chance to get involved. Because it is so early, however, those who do wish to dive in should expect it to be a bit chaotic, messy, unpredictable, and almost certainly a ton of fun.

To get specific, we’re looking for:

1. **Early adopters** — We’re hoping to find those folks who love getting involved and learning about emerging technologies before they’re polished for the mainstream.
2. **People who love a good challenge** — SNARKs have incredible potential, but they still need a lot of work to realize that promise.
3. **Long term thinkers** — Building the foundations for a new economic system isn’t done overnight. We’re looking for people who are aligned with our mission and in it for the long term.<Paste>

Speaking of fun, we’ll be adding some fun community incentives to get this network really humming. These include:

1. **Weekly challenges** — based on our goals, we’ll issue weekly challenges to organize behavior.
2. **Testnet Points**\* — get recognized with points for achieving qualitative and quantitative objectives.
3. **[Leaderboard Spreadsheet](http://bit.ly/TestnetBetaLeaderboard)** — publicly track your points and ranking compared to other participants.

The team has published all the necessary [documentation](https://codaprotocol.com/docs/) to help you get started. If you’re as excited about SNARKs as we are, or simply want to be involved in helping realize a truly decentralized financial system, we can’t wait to work with you.

Head on over to the [Coda Discord server](http://bit.ly/CodaDiscord) to get started, and let’s dive in!

-----

*\*Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
