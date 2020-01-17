---
title: Coda Protocol Testnet [Beta] Retrospective — Week 4
date: 2019-08-20
author: Christine Yip & Pranay Mohan
---

Today, we've arrived at the fifth week since Coda's first public testnet [BETA] was released. It has been incredibly fun to dive in with the core group of our community evangelists. While stress-testing the network, testing main parts of the core protocol, staking, and producing blocks, unexpected situations arised and the community graciously embraced these surprises. The testing provided us with invaluable feedback, and instead of having a new testnet release, we will focus on improving the infrastructure and stabilizing the testnet this week. The community is also invited to join us in this retrospective week, and earn Testnet Points\* along the way! Read on for more details.

![](https://miro.medium.com/max/3520/1*JKk8rrJ2-tCrPe8s9kheEg.jpeg)

## Week 5 Challenges

The total number of Testnet Points\* that 105 users racked up on the [leaderboard](http://bit.ly/TestnetBetaLeaderboard) went over 140,000 last week! If you missed out on previous challenges, it is not too late to catch up, since we're having our biggest points\* challenge yet this week! You can also earn bonus points\* if you were active in the previous week(s), see Challenge #11 'Don't Break the Chain!'. Check out all challenges [here](https://codaprotocol.com/testnet.html).

New challenges are here for you to rack up more Testnet Points\*! 

**Challenge #12 "CLI FYI"**

Submit a product improvement or feature you’d like to see in the Coda command line interface (CLI). Post a new thread on the Discourse [forums](http://forums.codaprotocol.com) in the “Product” category and add this to the title: "[CLI Feature]". The community can vote on it by “hearting” the post, and comment / discuss details in the thread. Add your Discord username to be counted for pts\*.

Every feasible feature suggested will get 500 pts\*. Top 5 features will win a bonus - and the community gets to vote for top 5. Bonus: 2500, 2000, 1500, 1000, 500 pts\* respectively. Feasible feature means well scoped ideas that Coda could technically implement- eg. The block producing CLI command should tell you % likelihood of winning a block and the time until the next slot you can produce blocks for. No guarantees that suggested features will be implemented. But if you submit a PR implementing one, you could win a massive **bonus** of 5000 pts\*, which means that you could **win up to 8000 pts\*** with this challenge!

**Challenge #13 "My two codas"**

We are overwhelmed by the active involvement and enthusiasm from the community for the Testnet [BETA]. Your contributions and feedback are invaluable to us. Earn 400 Testnet Points\* for giving your two codas by filling out this [survey](http://bit.ly/CommunityRetro).

**Challenge #14 "Leonardo da Coda"**

We're holding a community arts contest! Bring out your most creative self to create Coda-related GIFs and emoji's! Post your GIF and emoji on the forum in respectively [this thread](https://forums.codaprotocol.com/t/community-art-contest-leonardo-da-coda/) for GIFs and [this thread](https://forums.codaprotocol.com/t/community-art-contest-emojis/) for emojis. You can have unlimited number of entries so cut yourself loose! The community can vote on the best entries by “hearting” the entry posts, so do not forget to also "heart" your favorite entries! Top 3 entries will receive bonus points: 300 pts\* for the best GIF and emoji, 200 pts\* for the second place and 100 pts\* for the third place. 

## Week 4 Retrospective

Another week, another testnet release put to trial. This past week, about thirty block producers were in action, each staking about ~3% of the total coda supply to participate in consensus. This was an important testnet, as the Coda network can only be decentralized if it supports many parties participating in consensus. This week was the first test of this in the wild, and was successful as we saw over 20 nodes successfully produce blocks and receive coda for their efforts. However, we also found some bugs that we were able to squash and further harden the protocol.

There were three main technical issues that emerged this past week:

1) Initially, there was no snark work being done, and only when 128 transactions were queued up to be snarked did the snark work begin. The reason for this delay in starting snark work was a bug that caused an "off by one" error. This was relatively easy to fix, and should be resolved moving forward.

2) Some block producers were not able to produce blocks, despite being live and connected to their nodes for multiple days. Initially, the thought process was that it was just pure bad luck for these block producers, and they just had to wait for their time to roll around. Shout out to garethdavies, who alerted us to this not being the case, as they had an impressive uptime of 2 days, 4 hours, and 54 minutes, but no blocks produced. With garethdavies' help we debugged this issue and found that when the `set-staking` command was used to start the block producer, it didn't produce blocks for some users. When garethdavies switched to passing a `-block-producer-key` flag to the daemon when starting it, they were able to begin producing blocks. We will dig into this further to find out why the commands behaved differently.

3) The fork strikes again — in the previous testnet, there was a long fork issue that caused the network to partition. We thought we had debugged this and attributed it to two reasons: 

- Colocating block producers with snark workers on the O(1) labs nodes, which may have delayed block production, thereby forking the chain when a new block was produced on a lagging tip
- Parameters, Δ (delta — acceptable network delay in number of slots, in which past blocks can be accepted) and k (the number of blocks until the network assumes finality), were configured in a way that caused "forkiness". Specifically, when k is smaller than Δ, what can happen is that blocks are finalized and thrown away while nodes are still waiting for them. This can cause nodes to get stuck on a tip unable to receive any more blocks, and then will have to build on top of that, causing a fork. This was resolved by establishing an invariant that k should always be greater than Δ.

However, given that another fork happened on day 6 of this testnet, and didn't resolve itself, we dug further into this issue. This time, the fork was due to a partition in the network where the peer graph had a bridge with one node (the seed node). When that node dropped out, the graph split into two networks and was unable to heal. You can find the full investigation here: [https://forums.codaprotocol.com/t/8-17-medium-rare-fork-investigation/113](https://forums.codaprotocol.com/t/8-17-medium-rare-fork-investigation/113).

All said and done, a successful week in terms of uncovering issues and fixing issues. We will take a break this week and not have the testnet live, so that the Coda development team can focus on stability again and ensure that these same issues don't pop up in future testnets. Thanks again for the community's support and patience in this process — our spirits are boosted when we see comments like these:

![](https://miro.medium.com/max/2760/1*EkWF1VqVlqC4qDdRgcVe5Q.png)

## Community in Action

When last week's testnet 'Medium Rare' was released, the early adopters in the community were eager to dive in and start staking.

![](https://miro.medium.com/max/1110/1*I7-W3OvMK4GomvClavebng.png)

More than 40 members signed up to participate on 'Medium Rare' as block producers and committed themselves to run their nodes throughout the week. 30 of them were selected and they received 20,000 testnet coda's to participate in staking and produce blocks. One of the community members, *awacate*, enthusiastically started to promote her block producer shortly after she got her node up.

![](https://miro.medium.com/max/1178/1*NoDGjOKli_PuI8zx1F-HtQ.png)

The coolest thing to see, was the core group of the community evangelists banding together to get the block production started, and celebrating when everyone started to successfully sync with the blockchain..

![](https://miro.medium.com/max/1112/1*DMoy--u1csfUYJMHdEZs6Q.png)

...however, not everyone was lucky enough to get selected for proposing the next block. One member, *jspadave*, could have used some more luck at the beginning!

![](https://miro.medium.com/max/1108/1*5VAV9wyZs3QfMlDpSasTRw.png)

...but no worries! In the end, he produced about 30 blocks last week. In total, the passionate block producers in the community generated more than 400 blocks last week! Read on to see who produced the most blocks last week and won 4000 Testnet Points\*!

## Community MVP Winners

Each week, we reward the community leaders who are making testnet a great, collaborative experience. Please join us in congratulating the Community MVP Winners!

**Winners Challenge #9 'Block Party'**

Last week, we had one of our biggest points\* challenge yet, with up to 4000 points\* on the line for the person who produces the most blocks. Congratulations to the winners!

1st place 4000 pts\* - @dk808 (47 blocks!)
2nd place 3000 pts\* - @y3v63n
3rd place 2000 pts\* - @Gs

1000 pts\* for everyone who produced at least one block:
@Prague
@jspadave
@Dmitry_D
@novy@Alexander
@Danil_Ushakov
@LatentHero
@whataday2day
@garethtdavies
@Ilya123
@TipaZloy
@Bison_Paul
@Hunterr84
@MattHarrop/_Figment_Network
@OranG3
@boscro
@PetrG
@ttt

**Bug Bounties**

Major Bug Bounty 2000 pts\*: @garethdavies for helping debug the CLI command that enabled block production but didn't generate any blocks. (see [Github](https://github.com/CodaProtocol/coda/issues/3234))

Minor Bug Bounty 200 pts\*: @doronz2 for finding an issue related to logging when bootstrapping. (see [Github](https://github.com/CodaProtocol/coda/issues/3172))

Community MVP Gold (+1000 Testnet Points\*)

@whataday2day for always being around, being actively involved in the testnet from the start, and being helpful to other community members when they get stuck.

Community MVP Silver (+500 Testnet Points\*)

@dk808 , @Bison Paul , @Ilya | Genesis Lab , @Alexander , @Turbotrainedbamboo for active participation in the Testnet [Beta] and helping with uncovering odd behaviour leading to forks.

## Conclusion

The entire team at O(1) Labs would like to express our sincere gratitude to all testnet participants for joining early on this unpredictable and fun ride, their unwavering support and belief in Coda.

---

*\*Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.*
