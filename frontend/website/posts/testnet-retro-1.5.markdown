---
title: Coda Protocol Testnet [Beta] Retrospective — Week 5
date: 2019-08-27
author: Christine Yip & Pranay Mohan
---

Welcome to week 6 of the Coda Public Testnet Beta. This week’s challenge, Something Snarky, is all about generating zk-SNARKs. Node operators will be competing to produce as many SNARKs as possible to sell to block producers on the snarketplace — read on for more details. In addition, we have a brand new [leaderboard](https://codaprotocol.com/testnet.html) design to keep track of your place on the list.

![](https://miro.medium.com/max/3520/1*oe8TP8e3kBp2jFkYowCiKw.jpeg)

## Week 6 Challenges

Challenge #15 — Something Snarky:

This week’s challenge makes snark work the primary objective. Node operators that produce at least one SNARK will get 1000 pts\*.

BONUS: Top 3 node operators who are able to sell the most SNARKs in the snarketplace (meaning your SNARK was not just produced, but also selected by a block producer) will win an additional 3000, 2000, and 1000 pts\* respectively. Hint — your SNARKs are more likely to be bought if the fees are lower, so feel free to experiment with the economics! ;)

Challenge #15 ‘Something Snarky’

*(Updated) This week’s challenge is to earn testnet tokens by performing SNARK work. Node operators that produce at least one SNARK will get 1000 pts\*. *

BONUS: Top 3 node operators who are able to earn the most tokens with their SNARKs on the snarketplace will win an additional +3000 pts\* , +2000 pts\* , and +1000 pts\* respectively. Hint — your SNARKs are more likely to be bought if the fees are lower, so feel free to experiment with the economics!

**Week 5 Retrospective**

Week 5 was an opportunity to retrospect on the state of the network over the past month and reflect on what could be improved to ensure a better experience for node operators. Maintaining the Coda testnet is a significant operational load, and as a small team of core contributors, each live issue we were debugging took precious time away from coding, hardening infrastructure, and developing processes. As such, we took a much needed week off from ops and support and we're heads down on fixing issues. Here’s what we focused on during week 5:

*Nightly builds*

We began the process of automatically deploying a nightly build of the testnet that builds the code in the `develop` branch and spins up a local testnet on AWS to run for 12 hours. This is critical, as it gives us an opportunity to catch low hanging bugs that manifest in straightforward conditions. By having this base level of testing, we can ensure that the bugs that do manifest in a released testnet end up being more complex, and due to unpredictable user interactions that will help us have a much more specific surface area of testing.

*The transition from Kademlia to libp2p*

One of the issues we’ve been noticing over the past 4 weeks is the tendency of the network to fork. We’ve changed our protocol parameters and taken measures to prevent this on our side, but we’ve still encountered forks each week. As [this investigation details](https://forums.codaprotocol.com/t/8-17-medium-rare-fork-investigation/113), much of our issues were due to Kademlia as our peer discovery layer. We finally bit the bullet and decided to transition to libp2p sooner than later. We made a lot of progress and estimate that this will get merged in by next week’s release.

*Memory profiling*

Several users reported daemon crashes due to memory leaks, so we spent some time profiling memory usage by the daemon. We added a flag `-memory-profiling` that runs the daemon with profiling enabled, using [a variant of OCaml](https://github.com/jhjourdan/ocaml/tree/memprof) that supports statistically profiling the heap. See this PR for more details on profiling support and implementation: [https://github.com/CodaProtocol/coda/pull/3247](https://github.com/CodaProtocol/coda/pull/3247).

Thanks again to the community for accommodating one week of downtime for the testnet — we hope to continuously strengthen the testnet so that the experience improves week over week.

**Community MVP Winners**

Each week, we reward the community leaders who are making testnet a great, collaborative experience. You can see each week’s winners on the new [leaderboard](https://codaprotocol.com/testnet.html):

Challenge #12 — ‘CLI FYI’:

We had 24 submissions for CLI feature requests, and many of them are great ideas that we’re adding to the roadmap to implement in the near future. The top five ideas were:

1st — 3000 pts\*: Ilya | Genesis Lab ([see feature](https://forums.codaprotocol.com/t/cli-feature-ability-to-set-detailed-information-about-node-operator-team/123))

2nd — 2500 pts\*: alexander ([see feature](https://forums.codaprotocol.com/t/cli-feature-e-mail-notifications/119))

3rd - 2000 pts\*: whataday2day([see feature](https://forums.codaprotocol.com/t/cli-feature-the-number-of-blocks-produced-in-client-status/124))

4th — 1500 pts\*: novy ([see feature](https://forums.codaprotocol.com/t/cli-feature-auto-upgrade/121))

5th — 1000 pts\*: pk ([see feature](https://forums.codaprotocol.com/t/coda-node-startup-script/145))

Challenge #5 — Bug Bounties

Minor Bug Bounty 200 pts\*: garethtdavies ([https://github.com/CodaProtocol/coda/issues/3288](https://github.com/CodaProtocol/coda/issues/3288))

Challenge #7 — ‘You Complete Me’

1000 pts\*: garethdavies for his contributions to the documentations and his extensive blog on Coda GraphQL API, which allows the development of future tools such as block explorers, wallets, and more. Check out his blog [here](https://garethtdavies.com/crypto/first-steps-with-coda-graphql-api.html).

Challenge #14 — ‘Leonardo da Coda’ (GIF contest)

300 pts\* 1st place: alexander

200 pts\* 2nd place: Pk and alexander (shared)

100 pts\* 3rd place: onemoretime

Thanks again to the Coda community members who have been participating in the testnet. There are a lot more cool features and challenges in store, so stay tuned and stay connected!

\* *Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
