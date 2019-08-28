---
title: Coda Protocol Testnet [Beta] Retrospective — Week 2
date: 2019-08-07
author: Christine Yip & Pranay Mohan
---

This week, we have a new release, ‘Share the Wealth’ and three new challenges to help you earn Testnet points*.

![](https://miro.medium.com/max/3520/1*p67RLkKOGQzEitPQDhSTtw.jpeg)

Since we launched Coda’s first public testnet in beta on July 24th, 2019, we’ve had 56 Codans connect and 74 rank on the [leaderboard](http://bit.ly/TestnetBetaLeaderboard). Competition has been pretty fierce, but fellow Codans are a helpful bunch. Head on over to [Discord](http://bit.ly/CodaDiscord) and [Docs](http://bit.ly/CodaDocs) to start tackling challenges!

## Week 3 Challenges

Fresh challenges are here! See where you rank on the [leaderboard](http://bit.ly/TestnetBetaLeaderboard) and post some points for the week.

**Challenge #6 ‘Nice to Meet You’**

Join the [new Coda forum](https://forums.codaprotocol.com/) and introduce yourself in the ‘Introductions’ thread! Again, name, location and what you’re excited about are all good things to share in order to get the points! — 100 Testnet points*

**Challenge #7 ‘You Complete Me’**

Contribute documentation/material to help others to get started on the Testnet. Many people are interested in running a node, but some need a little help getting started.

- 1000 Testnet points* for major contributions — e.g. new content which is not touched upon yet in the [official testnet docs](https://codaprotocol.com/docs/getting-started/): instructions in other languages, instructions for other operating systems besides macOS and Linux, etc.)
- 500 Testnet points* for minor contributions — e.g. complementary content to the official testnet docs: additional notes, etc.)

**Challenge #8 ‘Bonanza’**

Send as many transactions as you can! We’ll link the public key to a discord account by seeing what you use to ask the faucet for funds (and we’ll only use the first public key that you requested tokens as measurement).

- 1000 Testnet points* for sending 20 transactions
- Bonus: 1st place +3000, 2nd place +2000, 3rd place +1000 for 1st, 2nd, and 3rd place winners respectively for most transactions sent over the week!
If you’re just joining now, check out past challenges and point values in [our docs](https://codaprotocol.com/docs/coda-testnet/).

## Week 2 Retrospective & Week 3 Details

This release marks two weeks that the ‘Hello, Coda’ public testnet has been live and available for anyone to connect! In the first week, we were thrilled as the community embraced Coda, and began tinkering with the testnet, highlighting both what went well:

![](https://miro.medium.com/max/2932/0*qGH8E2YGl0rJ0HYu)

…and what could have gone better:

![](https://miro.medium.com/max/2924/0*9FCuXs4VKkX9yaW0)

Looking at all the feedback, we came to one conclusion — the second week’s theme would be **stability**. Because we believe in open development and access for all, we shipped Coda’s testnet as early as we thought was possible. This ensured some level of stability so that there was actually something to play with, but as users realized, the services and network would go down after heavy and continuous use.

Thus, we did not ship another release in week 2, as we needed to take some time and harden the next release. A little bit more detail around our release history to set some context:

The team initially developed on a master branch, and cut a release branch about ~3 weeks before the initial testnet launch. When we were thinking about a week 2 release, we realized that we would potentially be shipping three weeks’ work in master with only one week of testing. Knowing that this could cause a regression, we pulled back and focused on both ensuring the new code was stable, and addressing existing issues. Additionally, Week 2 challenges centered around helping community members and surfacing new bugs.

So far, this strategy has proven correct as the new testnet release, ‘Share the Wealth’, feels much more stable and has a few main improvements:

- Tiny (the faucet dog) and Echo bot correctness and uptime has been improved
- Much cleaner status messages and logging
- Plus some bug fixes (including some of the crashes and p2p layer issues)
- This release also marks the first one where we’ve switched over from Groth-Maller to Bowe-Gabizon SNARKs!

You can find more details and the changelog in the [release notes](https://github.com/CodaProtocol/coda/releases/tag/0.0.1-beta.2), and check out [the docs](https://codaprotocol.com/docs/) for information on how to get started with the new release.

Two things to note about the new release:

- If you already have Coda installed, you’ll need to upgrade the package to make sure you’re not using the old client — see [the installation section](https://codaprotocol.com/docs/getting-started/#installation) for details.
- Your testnet tokens *do not* carry over from ‘Hello, Coda’ to ‘Share the Wealth’. This way we all start on an even playing field for this week’s challenges.

Additionally, the Coda development team has switched to a [git-flow workflow](https://datasift.github.io/gitflow/IntroducingGitFlow.html). TL;DR: `develop` will be the branch with active development, `master` will be stable, and release branches will contain code to be shipped. Releases will also happen weekly at 2pm PT on Tuesdays, and code-freeze is enforced Wednesday at 2pm of the previous week — as we automate more of our QA, we’ll push our code-freezes out to further days. Coda is entirely open source, and everyone is encouraged to get involved and [begin contributing](https://codaprotocol.com/docs/contributing/)!

## The Community in Action

In the second week after we launched the first testnet, ‘Hello, Coda’, new early-adopters, like Bj below, are still joining the testnet, and completing challenges.

![](https://miro.medium.com/max/1128/0*nYPsu49QuufZHBQQ)

This week, the number of users who successfully ran a Coda node and sent their first transactions, doubled to 54. It’s fun to see how the community likes to play around with the testnet. Codans, like pk, are even doing a little match-making, finding peers to exchange coda with.

![](https://miro.medium.com/max/1510/0*7EwazOhgzMt8dQ2Q)

Some community members have become a little attached to their testnet coda, but we’re not complaining.

![](https://miro.medium.com/max/998/0*sirL_xt-y2ifS0eJ)

Whatever the fee was, sadly for Bj, and other Codans that accrued coda over the last two weeks, funds will not carry over to the new release and new challenges (read on for details).

Another highlight this week was seeing all the highly-technical Codans in action. Joe_land1 and whataday2day took it to the next level by setting up nodes in operating systems that aren’t officially supported yet. Currently, the documentation includes instructions for macOS and Linux. These two combined forces to get Coda running on Windows.

![](https://miro.medium.com/max/1378/0*Ngk1bppucJ4DLZdI)

After overcoming some struggles, they succeeded in running testnet nodes using Windows Subsystem for Linux.

Last week, we also hosted our [first Office Hours](https://youtu.be/HF9fLDj5oSc) for the testnet with about 15 community members joining. If you missed it, there will be more opportunities to meet our team and to get answers to testnet questions. Click [here](https://calendar.google.com/calendar/b/1?cid=bzFsYWJzLm9yZ19nZDJmdG52azYyNHFhazYxcHY3bTAybDRwMEBncm91cC5jYWxlbmRhci5nb29nbGUuY29t) if you want to add the Testnet [Beta] Office Hours to your calendar.

## Community MVP Winners

Each week, we reward the community leaders who are making testnet a great, collaborative experience. In the first two weeks, the community members below stood out. Please join me in congratulating the Community MVP Winners!

**Community MVP Gold (+1000 Testnet points\*)**

@ssh for the spirited participation in this wild ride of launching the testnet! Ssh used their technical knowledge to help other community members get connected to the testnet and did a lot of troubleshooting when they got stuck. Our technical team is super thankful. Thanks, ssh! (week 1 winner)

@Alexander for putting very detailed video & docs together for our technical Russian community. It proved to be very helpful for members to start their validator’s journey. (week 1 winner)

@pk for becoming a leader in the community with their positive and helpful attitude since the testnet [Beta] was released. @pk also documented all its steps to connect to the testnet. It is open-source, so other community members are invited to join and contribute as well! (week 2 winner)

**Community MVP Silver (+500 Testnet points\*)**

@Dmitry D for jumping in when our testnet bot Tiny went asleep during the weekend. His transactions made it possible for many new validators in the community to have a positive experience and fun with the testnet as well! (week 1 winner)

@turbotrainedbamboo for creating a cool visualization on which nodes he was chatting to around the world, and for sharing it with the community. If you want to take a look, the visualization was featured in our previous blog post Testnet [Beta] Retrospective Week 1 (week 1 winner)

@garethdavies for his active involvement in the community since the release of testnet [Beta]. Whether it’s providing the team with feedback on the testnet, helping out other community members to set up a node or sending transactions when our testnet bot fell asleep, @garethdavies was often around! (week 2 winner)

The entire team at O(1) Labs would like to express our sincere gratitude and appreciation to our growing community.

We look forward to meeting you over on [Discord](http://bit.ly/CodaDiscord) and our new [forum](https://forums.codaprotocol.com/)!