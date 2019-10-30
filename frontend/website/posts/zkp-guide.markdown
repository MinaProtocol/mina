---
title: What are zk-SNARKs?
subtitle: The Complete Guide to Crypto's Most Powerful Proofs 
date: 2019-10-25
author: O(1) Labs
---

<style>
    .hero { 
        position: absolute;
        height: 34rem;
        width: 100vw;
        top: 0;
        left: 0;
        background: url("https://cdn.codaprotocol.com/website/static/blog/zkp-guide/square-texture-02514419102fe2c115d32784e87d7db659bcd8e8f1be53286ec3a5fad0c8e0f7.png") no-repeat center center;
        background-size: cover;
        z-index: -2;
        
    }
    
    .hero:after {
        display: block;
        position: absolute;
        content: "";
        height:10rem;
        bottom: 0;
        left: 0;
        right: 0;
        background: linear-gradient(rgba(255, 255, 255, 0),rgba(255, 255, 255, 1));
        z-index: -1; 
        
    }
    
    .title { 
       padding-top:14rem;
       text-align:center;
       color: #00315A;
    }
    
    .subtitle {
        text-align:center;
    }
    
    .author, .date {
        display: none;
    }
    
    .link-wrapper {
        display:flex;
        justify-content: space-around;
        margin: 7rem 0;
    }
    
    .link { 
        color: #00315A !important;
    }
    
    .blog-content {
        position: static;
        margin-top: 11rem;
    }
    
    main { position: relative; }
</style>

<div class="hero">
</div>  

<span id="get-started"> <h1>  Get Started </h1> </span>
Zero Knowledge Proofs. zk-SNARKs. These terms are frequently used in cryptocurrency circles, often in the context of making transactions private. In the context of Coda Protocol, they are an essential part of our principal innovation: a small, constant-sized blockchain. Their origins extend back to 1985, when zero knowledge proofs were first explained in the paper “The Knowledge Complexity of Interactive Proof-Systems.” But the question remains: what actually are they?

The central vision of cryptocurrencies is to enable indivduals to decrease their reliance on centralized powers and third parties intermediaries. zk-SNARKs are an innovation that can make that vision a reality. Yet, because zk-SNARKs are so complex, it’s challenging to find clear, accessible resources. Our team of cryptographers and engineers compiled, summarized and reviewed the available resources to help you get started, whether you’re a beginner or an expert. Know of a resource we should include? Let us know in the comments section below. 
    
First, Izaak and Vanishree, two members of our cryptography team who have devoted their lives to the study of zk-SNARKS, will get you started with an introduction.

[Zero-knowledge Proofs: An Intuitive Explanation](https://codaprotocol.com/blog/zkp.html)  
Vanishee Rao, a cryptographer working on Coda Protocol, offers up this explanation, using the classic 3 coloring problem to introduce key concepts including soundness, zero-knowledgness, and verifiers. Highly visual, this short (<5 minute) read is a great place to start. 

[Using zk-SNARKs For A Constant Sized Blockchain ](https://www.youtube.com/watch?v=fjdDbE_fgww&feature=youtu.be)  
In this presentation, Izaak Meckler, co-founder and CTO of O(1) Labs, and principal cryptographer working on Coda Protocol, provides an overview and introduction not only of the concepts behind zk-SNARKs but complete with practical examples of why they matter. 


<h1 id="learn-more"> Learn More </h1>
  
These are the best 101-style resources that make Zero Knowledge Proofs and zk-SNARKs more accessible. Visual metaphors and simplified explanations are used to refine and expand upon the concepts introduced above. 

[Introduction to Zero-Knowledge Proofs](https://medium.com/coinmonks/introduction-to-zero-knowledge-proofs-8e8261b4a48a)  
This is a good starting place. First, it has a bit of historical background, explaining the original context of the 1985 paper "“The Knowledge Complexity of Interactive Proof-Systems” that got the whole thing going. Second, it has a slightly simplified and more visual retelling of the Ali Baba cave story. Third, it provides a nice succinct summary of the three properties that a zero knowledge proof must satisfy: completeness, soundness, zero-knowledge.

[Explain Like I’m 5: Zero Knowledge Proof  - Halloween Edition](https://hackernoon.com/eli5-zero-knowledge-proof-78a276db9eff)  
This example takes the somewhat well known “Yao’s Millionaire Problem” - where two millionaires want to discover if they have the same amount of money without either of them having to actually disclose their holdings - and puts it in the context of two kids (obviously named Alice and Bob) who want to find out if they hauled in the same amount of candy while trick-or-treating. 

[[Video] Zero Knowledge Proof - ZPK](https://www.youtube.com/watch?v=OcmvMs4AMbM)  
If we really want to ratchet up the visuals, let’s go straight to YouTube. This short (10 minute) explainer users animation to demonstrate another simple version of being able to prove that something is the case without revealing the specific circumstances that make it so. In this case, the example used is a person who is trying to convince their color blind friend that there is a difference between a green and red ball. This video also gets into the difference between interactive and non-interactive ZKPs, setting the stage for discussion of SNARKS. 

[[Video] Zero Knowledge Proof](https://www.youtube.com/watch?v=HUs1bH85X9I)  
If the video above is the 101-level starter for ZKPs, think of this as the 102-level video. Featuring more narration and a few different visual examples - including a card deck where one proves that a card is a certain color without revealing anything else, this video also reiterates the fundamental properties required for a zero knowledge proof. 

[Zero Knowledge Proofs: An illustrated primer - 1 & 2](https://blog.cryptographyengineering.com/2014/11/27/zero-knowledge-proofs-illustrated-primer/)  
Alright, now we’re getting into the good stuff! This two part series comes from Matthew Green, who has been involved with Zcash since the beginning of the project and who spends most of his time as a cryptographer and professor at Johns Hopkins University. Part one does a few things. First, it goes deeper into the origins and background of ZKPs - including a discussion of why we got interested in them in the first place. Second, it uses a set of real world examples including a telecommunications-themed version of the graph three-coloring problem to explain what makes these types of interaction “zero-knowledge.” Third, it introduces additional important concepts like commitment schemes. While part 1 is distinctly non-technical, part 2 veers into some technical territory that’s still relatively easy to follow. 

[WTF is Zero-Knowledge Proof](https://hackernoon.com/wtf-is-zero-knowledge-proof-be5b49735f27) & [Introduction to Zero Knowledge Proof: The protocol of next generation Blockchain](https://medium.com/coinmonks/introduction-to-zero-knowledge-proof-the-protocol-of-next-generation-blockchain-305b2fc7f8e5)  
Now that you’ve had a chance to really wrap your head around the basic idea of zero knowledge proofs, and have been seen a number of different visual metaphors, let’s introduce a few additional concepts. Both of these pieces are very similar, and work as a pair. While they’re still very 101, they will expand your perspective to include: 1) the difference between interactive and non-interactive zero knowledge proofs and 2) zk-SNARKS. The second piece in particular does a nice job of breaking down each part of the acronym as a way to begin understanding the concepts involved. 

[Zero Knowledge Proofs Part One: The Cryptographic Protocols and Their Variations](https://www.bitrates.com/news/p/zero-knowledge-proofs-part-one-the-cryptographic-protocols-and-their-variations)  
This piece more or less reiterates a lot of the concepts discussed in the previous pieces. One valuable addition is an additional simplified definition of zk-SNARKs and a comparison to zk-STARKs. 

[[Video] What are ZK-Snarks?](https://www.youtube.com/watch?v=Rku9pABMLKI)  
Now that we’ve bridged from zero knowledge proofs to SNARKs, let’s drop another quick intro video for the visually minded. This 4 minute overview is going to give you the basics so that we can dive back into some more substantive content. 

[zk-SNARKS and zk-STARKS Explained](https://www.binance.vision/blockchain/zk-snarks-and-zk-starks-explained)  
This piece comes from Binance Academy and goes even farther in explaining the difference between zk-SNARKS and zk-STARKS. This is one of the most succinct and clearest non-technical short explanations out there. 

[What is zkSNARKs? The Comprehensive Spooky Moon Math Guide](https://blockgeeks.com/guides/what-is-zksnarks/)  
While mostly non-technical, this does use a bit of math to get deeper into the explanation of zkSNARKs. That said, it does so only after many helpful visuals and simplified initial explanations, and does so in a way that we promise, after all the other things you’ve read, you’re going to understand. 

[Why zk-SNARKs Are Crucial For Blockchain Data Privacy](https://www.forbes.com/sites/samantharadocchia/2018/04/24/why-zk-snarks-are-crucial-for-blockchain-data-privacy/#f12f86d50f04)  
So far we’ve seen a lot of visual explanations for what zero knowledge proofs are, as well as simplified definitions for wrapping our heads around the concept of zk-SNARKs. What we haven’t seen yet is a simple, clear articulation of why this all matters. In this piece for Forbes though, Samantha Radocchia does exactly that. She draws the lines between the copious amount of data the services around us to collect, the rampant abuse and insecurity of that data, and the need for privacy technology like SNARKs. 

[[Video] Rhapsody in Zero Knowledge: Proving Without Revealing ](https://youtu.be/jKSz7W5dTgY)  
This wonderful talk takes many of the concepts found in the above articles and puts them in a succinct, clear sequence. If you need just one video to sum up absolutely everything in this 101 section and get ready for the next, more technical section, this is the one for you. 

<h1 id="get-technical"> Get Technical </h1>  

If you’ve read this far, you’re ready to get technical. The below covers both the how and the why, explaining in more detail the application for zk-SNARKs and why they hold so much promise for delivering on cryptocurrency’s core mission. 

[Introduction to zk-SNARKs with Examples](https://media.consensys.net/introduction-to-zksnarks-with-examples-3283b554fc3b)  
Posted on the ConsenSys blog, this piece puts all of the key concepts you’ve learned above - such as verifiers, provers, and witnesses - into a mathematically framework that can provide the basis for a more technical understanding. Even for a non-technical audience, this is still interesting reading that you’ll likely be able to follow along. 

[[Video] Introduction to SNARKs](https://youtu.be/jr95o_k_SwI)  
Filmed at DevCon 3, this 20 minute talk is an introduction to SNARKs from Dr. Christian Reitweissner. One of the valuable aspects of this talk is the framesetting. Even before diving into the topic, he explains why SNARKs are so important for blockchains, discussing both scaling and privacy. 

[[Video] Eli Ben-Sasson, ZCash founding scientist, co-inventor of zk-SNARKs, co-founder of Starkware](https://www.youtube.com/watch?v=LEiwd31bQr0)  
Sometimes you need to go straight to the source. Eli Ben-Sasson was a co-founder of Zcash, co-inventor of SNARKs and has (as you might expect) a wealth of knowledge to share. This is not just your standard video interview, but is effectively an introductory seminar on the topic. It will be even better once you’ve gotten the primer with some of the above resources, but in either case, this is absolutely a must watch. 

[Zero-knowledge proofs, a board game, and leaky abstractions: how I learned zk-SNARKs from scratch](https://medium.com/@weijiek/how-i-learned-zk-snarks-from-scratch-177a01c5514e)  
Speaking of the above blog post, this piece is from a coder who used that, among other resources, to teach themselves how to work with zk-SNARKs. This is a great combination of a personal learning journal plus some insights that might help you as well. 

[Learning about zk SNARKs](https://zaki.manian.org/blog/learning-about-zk-snarks/)  
Zaki Manian, from the Tendermint team, put together this resource guide to make it easy for people to dive in and learn more about ZKPs and SNARKs. He organizes the content he suggests into a few different categories: Surveys, Quadratic Arithmetic Programs, Pairing Cryptography, Core SNARK papers, and Recent Research. If our curation is your 101 guide, this provides a great jumping off point to go deeper. 

[Vitalik Buterin’s SNARK series](https://medium.com/@VitalikButerin/zk-snarks-under-the-hood-b33151a013f6)  
When it comes to SNARK content, this is the GOAT. From late 2016 to early 2017, Ethereum creator Vitalik Buterin wrote a three part series. The first piece was ‘Quadratic Arithmetic Programs: from Zero to Hero’ digging (as Vitalik put it) into “the machinery behind the technology.” Part 2 was ‘Exploring Elliptic Curve Pairings, and part 3 was ‘zk-SNARKS: Under the Hood’. This is a much more technical exploration that is built on the framework of the other two. Not for the faint of heart, but amazing content nonetheless. 
