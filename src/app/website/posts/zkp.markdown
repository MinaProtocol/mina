---
title: Zero-knowledge Proofs&#58; An Intuitive Explanation
date: 2019-05-13
author: Vanishree Rao
---

Zero-knowledge proofs (ZKPs) are a powerful cryptographic primitive that enables you to prove that you have a secret, without revealing it to anyone.
 If you are hearing about ZKPs for the first time, you are likely to say "Hah! That sounds impossible." Read on to get an intuitive understanding of what they are. But first, some background. ZKPs were [invented](http://people.csail.mit.edu/silvio/Selected%20Scientific%20Papers/Proof%20Systems/The_Knowledge_Complexity_Of_Interactive_Proof_Systems.pdf) by Shafi Goldwasser, Silvio Micali, and Charles Rackoff in 1985. Ever since, ZKPs have been one of the most active areas of research in Cryptography. Moreover, recently, they are enjoying significant impact on real-world applications, specifically on blockchain technologies. [Zcash](https://z.cash/technology/), a pioneering blockchain project, employed ZKPs to achieve anonymity in financial transactions. At O(1)Labs, we are building CODA, the first succinct blockchain, using ZKPs. No matter how many transactions are recorded on the blockchain, the blockchain remains at most the size of a few tweets. 



## What are Zero-knowledge Proofs?

The purpose of zero-knowledge proofs is to convince someone you know something without revealing what that thing is. For example, you might want to convince someone that you know the solution to a puzzle without giving them the solution.

Let's look at a particular puzzle to see how you can accomplish exactly this.


### A Puzzle called 3-Coloring. 

The 3-coloring puzzle can be described as follows. You are given a graph of nodes and edges (like in the figure below). The task is to find a "3-coloring" to the graph, which is a coloring of the nodes with three different colors in such a way that no two adjacent nodes have the same color. 

![An uncolored graph.](/static/blog/zkp/uncolored-graph.png)

![A colored graph.](/static/blog/zkp/colored-graph.png)

### A Zero-knowledge Proof for the 3-coloring Puzzle. 

We will construct a ZKP protocol for the 3-coloring puzzle. Before that, let’s quickly recall the two properties we are looking for in the protocol. 

A ZKP protocol between you and someone else -- call her  Verifier, must satisfy the following properties: 

* If you are cheating (i.e., if you do not know a 3-coloring), then Verifier should be able to catch you -- this property is called  _soundness_

* Verifier should not learn anything about the 3-coloring -- this property is called  _zero knowledgeness_

Now, let's try to construct a ZKP protocol, where, your proving and Verifier's verifying procedures are as follows.

**Proving:** Imagine the graph drawn on the floor in a closed space. Per the 3-coloring you know, you would place the corresponding colored balls on the nodes. Then you would completely cover the balls with inverted opaque bowls.

**Verifying:** Then, Verifier comes and points at an edge of her choice. You would lift up the two bowls on either side of the edge. Verifier verifies that the balls revealed are of different colors. If they are not, you are caught cheating. 

Now that we've defined our protocol, we want to check that it satisfies *zero-knowledgeness* and *soundness* (the property that you can't cheat).

## Zero-knowledgeness

Note that no  information about the 3-coloring is revealed to Verifier, since whatever Verifier viewed could be simulated by just picking two random, but differently-colored balls. Thus, this protocol provides  perfect zero knowledgeness. 

## Soundness

If you didn't really know a 3-coloring, then for some two nodes connected by an edge, you put balls of the same color during the proving stage. That means that during the verifying stage, since Verifier picks an edge at random, the probability that they catch you is at least $1 / |E|$, where $|E|$ is the number of edges in the graph.


Note that there is still some significant probability that you could cheat and still get away with it (specifically, $(1 - 1/E)$). This probability is called the _soundness error_.  We would like to reduce this error to negligible. Here is an idea:  Repeat the above protocol multiple times. Now, you can get away only if you get away in each one of those executions. This significantly reduces the soundness error, as quantified in the following.   






### Soundness, More Rigorously

The more rounds you execute, higher is the Verifier’s confidence on the soundness of your claim. Let’s say that you do not know a 3-coloring for the graph.  The probability that you will not get caught can be bounded as follows. 

Let $N$ be the total number of rounds. 
<div class="katex-block">
```
\Pr[\text{You will not be caught in Round }i \leq N] \leq 1 - \frac{1}{E}
```
</div>

<div class="katex-block">
```
\Pr[\text{You will not be caught in any of the N rounds}] \leq \left(1 - \frac{1}{E} \right)^N
```
</div>







 

## Revisiting Zero-knowledgeness

Unfortunately, there is an issue in the above protocol. Since Verifier gets to see the coloring two nodes at a time, she can learn the entire 3-coloring by running enough rounds. Luckily, we can get around this issue: After every round, you would ask Verifier to step out of sight, you would randomly permute the colors and again cover all the nodes. That way, anything that Verifier might have learned in one round is not relevant in the subsequent rounds, since whatever Verifier viewed can be simulated by just picking two random, but differently-colored balls in each round. 


***Insert illustration for the final protocol***
 


