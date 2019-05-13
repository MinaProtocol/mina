---
title: Zero-knowledge Proofs&#58; An Intuitive Explanation
date: 2019-05-13
author: Vanishree Rao
---

If you are hearing about zero-knowledge proofs -- a fascinating cryptography tool, for the first time, you are likely to say "Hah! That sounds impossible." Read on to get an intuitive understanding of what they are. But first, some background. Zero-knowledge proofs (or ZKPs)  were [invented](http://people.csail.mit.edu/silvio/Selected%20Scientific%20Papers/Proof%20Systems/The_Knowledge_Complexity_Of_Interactive_Proof_Systems.pdf) by Shafi Goldwasser, Silvio Micali, and Charles Rackoff in 1985. Ever since, ZKPs have been one of the most active areas of research in Cryptography. Moreover, recently, they are enjoying significant impact on real-world applications, specifically on blockchain technologies. [Zcash](https://z.cash/technology/), a pioneering blockchain project, employed ZKPs to achieve anonymity in financial transactions. At O(1)Labs, we are building CODA, the first succinct blockchain, using ZKPs. No matter how many transactions are recorded on the blockchain, the blockchain remains at most the size of a few tweets. 



## What are Zero-knowledge Proofs?

ZKPs are a powerful tool that enable you do the following. Let’s say you have a secret. Using ZKPs, you can prove that you have the secret without even revealing the it!  

Now let’s look at a puzzle and see how you could convince anybody that you know a solution without revealing it. 


### A Puzzle called 3-Coloring. 

The 3-coloring puzzle can be described as follows. You are given a graph of nodes and edges (like in the figure below). The task is to find a "3-coloring" to the graph, which is a coloring of the nodes with three different colors in such a way that no two connected nodes have the same color. 

![An uncolored graph.](/static/blog/zkp/uncolored-graph.png)

![A colored graph.](/static/blog/zkp/colored-graph.png)

### A Zero-knowledge Proof for the 3-coloring Puzzle. 

We will construct a ZKP protocol for the 3-coloring puzzle. Before that, let’s quickly recall the two properties we are looking for in the protocol. 

A ZKP protocol between you and someone -- call her  Verifier, must satisfy the following properties: 
\begin{itemize}
\item if you are cheating (i.e., if you do not know a 3-coloring), then Verifier should be able to catch you -- this property is called  \emph{soundness}
\item Verifier should not learn anything about the 3-coloring -- this property is called  \emph{zero knowledgeness}

Now, let's try to construct a ZKP protocol. Imagine the graph drawn on the floor in a closed space. Per the 3-coloring you know, you would place the corresponding colored balls on the nodes. Then you would completely cover the balls with inverted opaque bowls. 
Then, Verifier comes and points at an edge of her choice. You would lift up the two bowls on either side of the edge. Verifier verifies that the balls revealed are of different colors. If they are not, you are caught cheating. 

Notice that if you didnt really know a 3-coloring (meaning there is at least one edge with same colored balls on either side), you would get caught with some probability (namely, at least, $1/E$ where $E$ is the number of edges in the graph). Also, no further information about the 3-coloring is revealed to Verifier, since whatever Verifier viewed could be simulated by just picking two random, but differently-colored balls. Thus, this protocol provides some degree of soundness and perfect zero knowledgeness. 

## Soundness

Note that there is still some significant probability that you could cheat and still get away with it (namely, $(1 - 1/E)$). This probability is called the \emph{soundness error}.  We would like to reduce this error to negligible. Here is an idea.  Repeat the above protocol multiple times. Now, you can get away only if you get away in each one of those executions. This significantly reduces the soundness error, as quantified in the following.   






### More Rigorously,…

The more rounds you execute, higher is the Verifier’s confidence on the soundness of your claim. Let’s say that you do not know a 3-coloring for the graph.  The probability that you will not get caught can be bounded as follows. 

Let $N$ be the total number of rounds. 

$$\Pr[\text{You will not be caught in Round }i \leq N] \leq 1 - \frac{1}{E}$$

$$\Pr[\text{You will not be caught in any of the N rounds}] \leq \left(1 - \frac{1}{E} \right)^N$$





 

## Zero Knowledgeness

\todo

Unfortunately, there is an issue in the above protocol. Since Verifier gets to see the coloring two nodes at a time, she can learn the entire 3-coloring by running enough rounds. Here is an idea on how we can get around this issue. After every round, you would ask Verifier to step out of sight, you would randomly permute the colors and again cover all the nodes. That way, anything that Verifier might have learned in one round is not relevant in the subsequent rounds, since whatever Verifier viewed can be simulated by just picking two two random, but differently-colored balls in each round. 


 


