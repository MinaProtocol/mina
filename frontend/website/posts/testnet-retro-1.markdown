---
title: Coda Protocol Testnet [Beta] Retrospective — Week 1
date: 2019-07-29
author: Claire Kart
---

Coda Protocol launched its first public testnet in beta on July 24th 2019 at 2pm PST. As the first succinct blockchain, it generated significant interest from the community.

![Hello Coda balloons](https://miro.medium.com/max/1400/0*Cd7runvzrrtH3RjK)

## The Community in Action

Our community of early-adopters showed up in full-force, with over 250 people joining [Discord](http://bit.ly/CodaDiscord). Of those, 32 people successfully ran a Coda node, connected to the network, and sent their first transaction. An additional 32 people started playing around in the documentation, and are working on getting their Coda nodes set up for Week 2.

The community is now active in all parts of the globe, with particularly strong participation coming from Australia, China, Europe, Russia, and North America. One community member, turbotrainedbamboo, created a cool visualization of the peers he was chatting to on 07.29.2019 at 7:16 PM PST and shared it with the community.

![Map of testnet participants spread across North America, Europe and Asia.](https://miro.medium.com/max/1400/0*sMqPaGIsyR_BS8rx)

It’s clear from the conversations on the [Coda Discord server](http://bit.ly/CodaDiscord) that our community is highly-technical, loves a challenge, and is passionate about the long-term potential of establishing the foundations of a new, decentralized economic system.

With the release of the testnet beta, we also launched Testnet Points\* to recognize community members’ contributions to the testnet and the weekly challenges. We didn’t really anticipate how popular the point system would be… but the whole team was receiving messages from every channel like this all week:

![Screenshot of a chat message saying "I WANT MY POINTS"](https://miro.medium.com/max/1400/0*S5mjcMzMhtFY49ho)

I guess everyone loves a little good old-fashioned competition? And don’t worry… she got her points!

You can check out the [public leaderboard](http://bit.ly/TestnetBetaLeaderboard) to see how all 59 community members are ranking.

The coolest part of seeing the community in action came at a moment when the testnet tooling hit a potential roadblock. On July 26th, at 7am PST, our faucet bot, ‘Tiny’, went down for a period of time, meaning that no one could get funds to participate in the network. Our team was slowly getting up and making their way online, but a community member, *ssh*, stepped up and sent another community member, *Wallace*, 45 coda, allowing them to continue sending transactions on the network. This gave time for our team to troubleshoot and restore service to Tiny. While this could have potentially been a negative experience, the Coda community showed its cooperative spirit and banded together.

![Screenshot of the Discord chat where ssh hellped Wallace](https://miro.medium.com/max/1400/0*gkplovtUe0HNkbMr)

## Testnet Philosophy

When building Coda, we strive to be as transparent and permissionless as possible. We open sourced our code in October 2018, and since then have focused on sharing developments with the community as early as possible, including going live with Coda’s first public testnet. That fundamental decision meant that our first week was a bit chaotic, unpredictable, a little bit of a wild ride at times, and a ton of fun.

## Week 1 Retrospective

We launched the [first testnet](http://bit.ly/CodaBlog), ‘Hello, Coda’, at 2pm on Wednesday, July 24th. The first few days after launch went very smoothly and we felt quite confident about the testnet stability. But per Murphy’s law, it was only on Friday and the weekend that some bugs started throwing us wrenches. By Friday, our internal nodes had been running straight for 3 days, and a combination of the continuous uptime plus all of the activity on the network triggered a file descriptor resource leak (too many open files). This caused all of the nodes internal to O(1) Labs to crash at around the same time.

While rejoining the network wasn’t an issue, this presented a problem for restarting our nodes. Namely, we’ve yet to finish implementing ledger persistence, so none of our nodes had the ledger state, meaning that all the data might have been lost. Fortunately, one community node remained connected to the network, allowing one of our nodes to bootstrap to the most recent state, share it with our other nodes and stabilize the network. This event showed the beauty of Coda’s peer-to-peer network, where community nodes play a big role in helping secure the network and recover from issues.

A number of other bugs were also discovered by the community, which we are prioritizing fixing this week:

* The above mentioned file descriptor bug which briefly took down our network<Plug>CocRefresh
* Syncing to the network is only triggered when a block is received over gossip, leading to slow initial sync times (sometimes 10+ minutes)
* A bug on OS X caused random crashes for nodes on that platform every few days<Plug>CocRefresh
* A bug in Kademlia leading to nodes connecting to few (sometimes just 1) peers
* Missing parameters in our [GraphQL API](https://codaprotocol.com/docs/developers/graphql-api/), preventing our testnet bots from sending more than 1 transaction per block

Thanks to everyone who has helped find bugs and isolate these issues so far! We’re really excited to work towards a robust, decentralized piece of software together.

As a reminder, our hours are 10–6 PM PST, M-F. We’ll be doing our best to provide support during these hours, but may not be available right away outside of them. We’ll also be doing our best to keep the network running if something like the above happens again, but no guarantee the network won’t go down as we fix the issues.

## Release Schedule

We plan to release new versions of the testnet software every Tuesday at 2pm PST. As it is still early days, and our team is figuring out the cadence that works best for us and our community, this may change. We will keep the community updated.

Additionally, since last week was a short week, we will continue to run the original version released last week. The next software release will occur on 08.05.2019 at 2pm PST.

## Weekly Challenges

## *NEW* Challenges — Week 2

As we kick off Week 2, we are adding two on-going challenges that will run for multiple weeks. Have fun and see how many testnet points\* you can rack up! If you have questions, join [Office Hours](https://zoom.us/j/208206523) on 07.30 @ 4–5pm PST.

**Challenge #4** (on-going): Community MVP — Various pts.\* We saw so many people becoming leaders in the community and want to recognize them. Each week, we will recognize the winners of the previous week based on the point values below. We may give out all the awards in a week, or none, or several at each level. The more active the community is, the more points we can award in this category. Winners announced on Discord each week.

* Gold — 1000 pts.— made a major, or on-going contribution to the community throughout the week. A major stand-out.
* Silver — 500 pts.— always there, always helping, always positive.

**Challenge #5** (on-going): Major and Minor Bug Bounties — Various pts.

* Major — 2000 pts.— reported a new daemon crash that wasn’t already on the [known issues list](https://github.com/CodaProtocol/coda/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Testnet+Beta%22<Plug>CocRefresh).
* Minor — 200 pts.— reported a new issue related to minor bugs in the daemon, documentation, or testnet.

Since last week was a short week, we are continuing Week 1 challenges all this week. If you haven’t received your Week 1 points\*, it’s not too late…

## Week 1 Challenges

**Challenge #1**: Connect to Testnet — 1000 pts. for anyone who sends a transaction to the echo service (see the docs for more instructions).

**Challenge #2**: Community Helper — 300 pts. are awarded to anyone who helps another member of the community. This could include answering a question, helping them navigate the docs, and generally giving support and encouragement for those trying hard to get involved. We can only award points for what we see, so make sure you’re doing it in one of the official testnet channels so everyone can learn!

**Challenge #3**: Join Discord — 100 pts. awarded for introducing yourself in the #testnet-general channel. Name, location and what you’re excited about are all good things to share in order to get the points!

The entire team at O(1) Labs would like to express our sincere gratitude and appreciation to our growing community.

We look forward to meeting you over on [Discord](http://bit.ly/CodaDiscord)!

-----

*\*Testnet Points (abbreviated ‘pts.’) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points and are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
