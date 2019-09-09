---
title: Coda Protocol Testnet [Beta] Retrospective — Week 6
date: 2019-09-04
author: Christine Yip & Pranay Mohan
---

A new testnet release ‘Grab Bag’ is here with an entire set of new, fun challenges! We also have an exclusive BONUS this week for new members! Join this week to get **double** Testnet Points\* on ‘New Member’ challenges and place yourself on the [leaderboard](https://codaprotocol.com/testnet.html) with 100+ other members! (Read on for details on challenges.)

![](https://miro.medium.com/max/3520/1*occ9-ZLMNgO-5waaNnofgw.jpeg)

## Table of Contents

[Public Testnet Beta Milestone](https://medium.com/codaprotocol/coda-protocol-testnet-beta-retrospective-week-6-64035ba7fc1e#0294)

[Week 7 Challenges](https://medium.com/codaprotocol/coda-protocol-testnet-beta-retrospective-week-6-64035ba7fc1e#41fc)

[Retrospective Week 6](https://medium.com/codaprotocol/coda-protocol-testnet-beta-retrospective-week-6-64035ba7fc1e#4cb4)

[Community in Action](https://medium.com/codaprotocol/coda-protocol-testnet-beta-retrospective-week-6-64035ba7fc1e#188a)

[Challenge Winners Week 6](https://medium.com/codaprotocol/coda-protocol-testnet-beta-retrospective-week-6-64035ba7fc1e#b1a1)

## Public Testnet Beta Milestone

We’ve hit an important public Testnet Beta milestone this week — 100 active members who racked up over 200,000 testnet points\*! Check out the [leaderboard](https://codaprotocol.com/testnet.html).

If you haven’t started yet, this week will be great timing. We have a New Member Welcome Bonus for double testnet points\* and our team is ready to help new members to get started. Previously, we had a [live demo](https://youtu.be/HF9fLDj5oSc) to show members how to set up a node on the testnet. Send us (o1christine#8079 or any other O(1)Labs team member) a dm on [Discord](http://bit.ly/CodaDiscord), and we can hop on a call to help you get started! We are also happy to help experienced users when they get stuck, have questions about this week’s challenges, or about anything else!

## Week 7 Challenges

Challenge #16 “New Member Welcome Bonus”

This week, we have a package deal with a big bonus for new members. This would be a great chance to invite your friends to join! New members who complete all of the following three challenges this week will receive *two times the total points\* value as a bonus*: #1 ‘Connect to Testnet’, #3 ‘Join Discord’, and #6 ‘Nice to Meet You’ (check out all challenge descriptions [here](https://codaprotocol.com/docs/coda-testnet/)). So instead of 700 pts\* (respectively 500 + 100 + 100), new users will receive 1400 pts\* ! — [Get started](https://codaprotocol.com/docs/getting-started/)!

Challenge #17 “Hello Memo”

Did you know that Coda supports 32bytes of memos in its transactions? You can fit a SHA256 hash. Think of the possibilities! For this challenge, we’d like you to send a single transaction with a memo inside of it. `coda client send-payment` now supports a `-memo` flag. In that memo please stick the string "Hello Memo". You can send this transaction to anyone, for example a friend. You'll earn 500 pts\* for doing so. As always, please hit the faucet with your discord account so that we can associate a public key with your discord username in order to add your score to the leaderboard.

Challenge #18 “Oops”

Coda also supports cancelling transactions — you just need to make sure to cancel it before it gets included inside a block! For this challenge, we’d like you to cancel a transaction. This means, (a) you must send a transaction and (b) take the transaction-id that comes out and then cancel it again with `coda client cancel-transaction`. You'll earn 500 pts\* for doing so. In order to incentivize nodes to accept your cancellations, a fee is debited from your account greater than the fee that's present in the transaction pool. You'll know if the cancellation when through if after a while you notice your balance is lowered (by the fees from the cancellation). As always, please hit the faucet with your discord account so that we can associate a public key with your discord username in order to add your score to the leaderboard.

Challenge #19 “GraphCoolL”

Coda has a GraphQL API! It’s super experimental, and we are already in the process of changing several parts of it, but we’ve noticed that some in the community have already successfully built interesting tools on top of our API. We’re interested in getting your feedback! We want you to build something cool on GraphQL and tell us how we can make it better. You’ll earn 500 pts\* for building something and including some sort of constructive feedback (note anything you have issues with, you wish were different, things that were easy, etc). Please share it as a post on discourse with a `[GraphQL]` tag. `[GraphQL] Your title here`. In order to receive points\*, you must (a) include your source code (via a link to a public repo on github or embedded on the forums) and license it under the Apache2 license and (b) include some sort of constructive feedback (note anything you have issues with, you wish were different, things that were easy, etc).

You’ll earn 500 pts\* for sending us anything that we feel has achieved (a) and (b), as described above, and we’ll award a BONUS of an additional 2000 pts\* for the coolest use and 1000 pts\* for second place! Good luck.

## Retrospective Week 6

> “In general, if any branch of trade, or any division of labour, be advantageous to the public, the freer and more general the competition, it will always be the more so.”
> — Adam Smith, The Wealth of Nations

We’re entering week 7 of the Coda Public Testnet Beta. Last week was the first time snark work took center stage, as the challenge revolved around nodes competing to generate and sell zk-SNARK proofs in what we affectionately call the “snarketplace”. This was an important week, as it allowed us to test the economic assumptions that underpin the snarketplace, as it is intended to be a permission-less and dynamic system. We anticipate that by allowing as many nodes to generate snarks, over time the prices will go down and become advantageous to end-users of the Coda network. That said, this week was only the first dry run at this experiment, and we had some cool outcomes. Notes from the week:

Snark work challenge

* Initially, when we launched the challenge, we were surprised to see so many nodes charging nothing for their SNARK work. When we dug into why this was happening, we realized that we had made an error in the challenge copy! The copy initially said that the metric for success was the number of SNARK proofs generated — when in fact we wanted to reward users that generated the most in **fees** over the week. While this mixup was frustrating for node operators, it helped validated our assumptions because nodes optimized for selling the SNARKs by reducing their fees to 0. This was great to see, as the market prices behaved rationally when the goal was a fire-sale (albeit unintended).
* When we updated the copy to prioritize selling fees, many snark workers weren’t able to sell their proofs because nodes in other time zones who hadn’t seen the update were consuming all the SNARK jobs. This helped confirm the logic that block producers, when given a choice, will buy lower-cost SNARK proofs.
* Interestingly, the O(1) Labs nodes were still selling proofs even though the fee was set to 2 coda. The reason why was that we ran our nodes with the flag `-work-selection` seq meaning we were producing proofs sequentially, while other nodes had defaulted to `-work-selection rand`, or random. What this means is that other nodes were producing work that wasn't as prioritized, as block producers will always buy proofs in order. This allowed the O(1) nodes to charge a higher fee, as nobody was competing for the same jobs. In fact, rand is quite inefficient in practice, as it has a 16x overhead against an optimal job selection for our network parameters. Once we mentioned this to other node operators, the playing field became more level. This is an area where we would love community input and discussion on improving the work selection algorithm. If anyone has thoughts and wants to contribute, please comment in Discord or the forums. We will also follow up with a more thorough explanation of how SNARK work is queued and processed.

Implicit nonce finding issue

* As part of this challenge, we added a repeater-bot that would send transactions automatically every couple of minutes (with a large fee, to enable more expensive snark work). We noticed that after a while, the repeater transactions stopped getting accepted by the network because of invalid nonces. Note that all transactions include a nonce to protect against double spends. We worked around it by just killing and restarting this node — but we do have a hypothesis as to why it’s happening:
* We compute the nonce not only by looking inside the ledger but also looking at our local transaction pool to see what other transactions are already enqueued. We believe, but haven’t verified, that what happens is some transactions are on this node’s transaction pool but failed to propagate through the network for some reason. As this situation is likely unavoidable, we need a different solution. We plan on looking at other cryptocurrency protocols to see what they do in this situation — if you have thoughts please share on discord or the forums!

Memory leaks

* We’re still not sure what’s causing the memory leaks, but we’re adding more instrumentation to improve observability. We’ve been using the process of elimination to figure out the root cause, and we are pretty sure that this is happening somewhere in the networking layer. See this Github issue for more details: [https://github.com/CodaProtocol/coda/issues/2979](https://github.com/CodaProtocol/coda/issues/2978)
* Some folks may be wondering why we didn’t use a language with resource safety for the protocol (ex. Rust) which would, when used properly, protect us against this sort of issue. The short answer is that OCaml allows for greater development velocity while retaining performance — OCaml enables an easiness to the creating embedded DSLs which we took advantage of with Snarky our SNARK programming language. OCaml’s runtime performance, while adequate, will somewhat soon become a bottleneck for us in certain sections of our codebase. We intend to offload that work using helper processes written in Rust.

libp2p

* We’ve added libp2p for peer discovery under a CLI flag! Please note that it is still under development and therefore buggy. We’re asking community members to try it and report bugs, but be aware that it is not stable enough to join the network seamlessly. Stay tuned for further updates as we migrate from Kademlia to libp2p.

Thanks again to the community for your participation in the testnet. This was a fun week, and we hope to refine and continue to test the snarketplace. This week’s challenges are a grab bag — see here for more details.

## Community in Action

Once we updated the SNARK challenge #15 from producing the most zk-SNARKs to earning the most testnet tokens by selling SNARK work, the users started to change their strategies right away. The Community MVP of the week, *garethtdavies*, created a script which outputs how users are ranked based on the SNARK fees. This information was greatly welcomed by all, competition wouldn’t be as exciting without a ranking board!

![garethdavies' post with the output from his script](https://miro.medium.com/max/1440/1*-DIQ7TbqVGgyMQi1UbHeOw.png)

The testnet beta users used creative ways to get ahead in the competition. Everyone kept an eye on their competitors on the snarketplace (marketplace for zk-SNARKs), and it did not go unnoticed that user ansonlau3 succeeded in selling his SNARK work for a very favorable fee.

![Conversation between garethdavies and whatad2day discussing high snark fees](https://miro.medium.com/max/1416/1*EElG7iTWZYJhCC7NMXJDfg.png)

It has been incredibly fun to test and explore the dynamics of the snarketplace with the community. Users experimented with the SNARK worker fees, the selection of different SNARK works, increasing the number of transactions, and more. We are grateful to all members who joined us on the journey to develop novel technologies.

## Challenge Winners Week 6

Each week, we reward the community leaders who are making testnet a great, collaborative experience. You can see each week’s winners on the new [leaderboard](https://codaprotocol.com/testnet.html):

Challenge #15 — Something Snarky:

This week’s challenge was to explore the Snarketplace by producing snark work and earning tokens from the snark work fees. 37 node operators produced at least one SNARK, and the users that earned the most testnet coda from these fees are:

1. LatentHero who earned 2241 testnet coda — LatentHero even managed to sell two SNARKs with a fee of 999 testnet coda!

2. Dmitry D who earned 1274 testnet coda

3. y3v63n who earned 849 testnet coda

Challenge #4 — ‘Community MVP’:

Gold 1000 pts\* : garethdavies for being a leader in making the testnet a great, collaborative experience. He created a ranking board for the SNARK workers, continuously improved it, and shared it with the community, bounced off ideas related to GraphQL API during the office hours calls with the team, shared findings related to the challenge with other testers, and he is always around to help out in the community. Congratulations, garethtdavies, it’s great to have you here!

Silver 500 pts\* : whataday2day for being one of the most active community members last week and since the testnet launch, helping out community members when they have questions, and making it easy for them to navigate through resources by adding information to the Community Wiki on Coda Protocol’s [forum](https://forums.codaprotocol.com/). (Check out the instructions [here](https://forums.codaprotocol.com/t/how-to-community-wiki/153) if you would like to make contributions to the community Wiki too!)

Challenge #7 — ‘You Complete Me’:

Major Contribution 1000 pts\* : garethdavies for creating scripts/PRs for ranking SNARK workers, and identifying the owners of the public keys.

The entire team at O(1) Labs would like to express our sincere gratitude and appreciation to our growing community.

We look forward to meeting you over on [Discord](http://bit.ly/CodaDiscord)!

\**Testnet Points (abbreviated pts) are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
