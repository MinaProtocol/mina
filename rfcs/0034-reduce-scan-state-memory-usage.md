## Summary
[summary]: #summary

This RFC analyzes current scan state memory usage and proposes a series of optimizations which can be peformed in order to allow us to meet our target TPS goals without consuming an astronomical amount of RAM.

## Motivation
[motivation]: #motivation

In order to motivate these optimizations, we first need to analyze the expected memory usage of the scan state at our target TPS and slot time parameters. Below are the relevant calculations for computing the total memory usage (in bytes) of a single scan state, given 3 parameters of the scan state. `M` is the depth of each tree in the scan state, `T` is the total number of trees per scan state, and `D` is the scan state delay (we will discuss these in more detail later).

![](https://latex.codecogs.com/gif.latex?%5Cdpi%7B150%7D%20%5Cbegin%7Balign*%7D%20Base%20%26%5Ctriangleq%20%5Bomitted%5D%20%5C%5C%20Merge%20%26%5Ctriangleq%20%5Bomitted%5D%20%5C%5C%20FullBranch%20%26%5Ctriangleq%202%20%5Ccdot%20Merge%20&plus;%207%20%5Ccdot%20Word%20%5C%5C%20EmptyBranch%20%26%5Ctriangleq%205%20%5Ccdot%20Word%20%5C%5C%20FullLeaf%20%26%5Ctriangleq%20Base%20&plus;%205%20%5Ccdot%20Word%20%5C%5C%20EmptyLeaf%20%26%5Ctriangleq%203%20%5Ccdot%20Word%20%5C%5C%20NumberOfBranches%20%26%5Ctriangleq%20T%20%282%5E%7BM%7D-1%29%20%5C%5C%20NumberOfFullBranches%20%26%5Ctriangleq%20%5Csum_%7Bi%3D1%7D%5E%7BM%7D%20%5Csum_%7Bj%3D1%7D%5E%7Bi%7D%202%5E%7BM-j%7D%20%28D&plus;1%29%20%5C%5C%20NumberOfEmptyBranches%20%26%5Ctriangleq%20NumberOfBranches%20-%20NumberOfFullBranches%20%5C%5C%20NumberOfFullLeaves%20%26%5Ctriangleq%20%28T-1%29%202%5E%7BM%7D%20%5C%5C%20NumberOfEmptyLeaves%20%26%5Ctriangleq%202%5E%7BM%7D%20%5C%5C%20TreeStructureOverhead%20%26%5Ctriangleq%20T%20%28%282M-1%29%20Word%29%20%5C%5C%20ScanState%20%26%5Ctriangleq%20TreeStructureOverhead%20%5C%5C%20%26%5Cphantom%7B%5Ctriangleq%7D&plus;%20NumberOfFullBranches%20%5Ccdot%20FullBranch%20%5C%5C%20%26%5Cphantom%7B%5Ctriangleq%7D&plus;%20NumberOfEmptyBranches%20%5Ccdot%20EmptyBranch%20%5C%5C%20%26%5Cphantom%7B%5Ctriangleq%7D&plus;%20NumberOfFullLeaves%20%5Ccdot%20FullLeaf%20%5C%5C%20%26%5Cphantom%7B%5Ctriangleq%7D&plus;%20NumberOfEmptyLeaves%20%5Ccdot%20EmptyLeaf%20%5Cend%7Balign*%7D)
<!--
```latex
\begin{align*}
Base &\triangleq [omitted] \\
Merge &\triangleq [omitted] \\
FullBranch &\triangleq 2 \cdot Merge + 7 \cdot Word \\
EmptyBranch &\triangleq 5 \cdot Word \\
FullLeaf &\triangleq Base + 5 \cdot Word \\
EmptyLeaf &\triangleq 3 \cdot Word \\
NumberOfBranches &\triangleq T (2^{M}-1) \\
NumberOfFullBranches &\triangleq \sum_{i=1}^{M} \sum_{j=1}^{i} 2^{M-j} (D+1) \\
NumberOfEmptyBranches &\triangleq NumberOfBranches - NumberOfFullBranches \\
NumberOfFullLeaves &\triangleq (T-1) 2^{M} \\
NumberOfEmptyLeaves &\triangleq 2^{M} \\
TreeStructureOverhead &\triangleq T ((2M-1) Word) \\
ScanState &\triangleq TreeStructureOverhead \\
  &\phantom{\triangleq}+ NumberOfFullBranches \cdot FullBranch \\
  &\phantom{\triangleq}+ NumberOfEmptyBranches \cdot EmptyBranch \\
  &\phantom{\triangleq}+ NumberOfFullLeaves \cdot FullLeaf \\
  &\phantom{\triangleq}+ NumberOfEmptyLeaves \cdot EmptyLeaf
\end{align*}
```
-->

##### TODO: fix indentation of NumberOfEmptyBranches computation; got rate limited by the API :(

For convenience, I have created a [python script](res/scan_state_memory_usage.py) which computes the scan state size in relation to the scan state depth and delay. As per [scan\_state\_constants.ml](https://github.com/MinaProtocol/mina/blob/8f4f05b50764a09fb748a590a7c50cd89bbed94d/src/lib/snark_params/scan_state_constants.ml), the scan state depth is computed by `1 + ceil(log2(MaxUserCommandsPerBlock + 2))`, and the maximum number of user commands per a block is set by `MaxTPS * W / 1000` (where `W` is the length of a slot in ms). Thus, at block windows of 30 seconds and a target `MaxTPS` of 1, the scan state depth would be `1 + ceil(log2((1 * 30000 / 1000) + 2)) == 1 + ceil(log2(32)) == 6`, and at 3 minute block windows, it would be `1 + ceil(log2((1 * 180000 / 1000) + 2)) == 1 + ceil(log2(182)) == 9`. The number of trees in a scan state is effected by both the depth of the scan state and the scan state delay. Scan state delay is a parameter which we will select closer to mainnet launch based on how many active snark workers we expect to be online (as well as the ratio of transaction snark proving time to slot length). Below is a graph of what the scan state size would be at various parameterizations of delay, for both 30 second slots and 3 minute slots.

![](res/scan_state_memory_usage.png)

For convenience, the 30 second (depth 6) graph is shown alone below so that the values are easier to inspect.

![](res/scan_state_memory_usage_depth_6.png)

[Raw CSV data](res/scan_state_memory_usage.csv)

What these graphs show is that the dominate factor in reducing scan state memory usage is actually length of a slot time. However, the length of a slot time is, in turn, dependent on blockchain proving time. Furthermore, if slot time is reduced, but transaction proving time increases (due to, i.e., transaction snark bundling), then delay will need to be increased. Still, lowering the slot time (to reduce the scan state depth) and increasing delay is preferrable to keeping the slot time higher to have a lower delay.

Still, even if we assume the best case of being able to achieve 30 second slots and only needing a scan state delay of 2, a single scan state in the current representation will take up a total of 21.58mb. This is unacceptable considering that we store a scan state at every single breadcrumb in the transition frontier. The transition frontier will always have at minimum `k` breadcrumbs (for a node that has been participating for at least `k` blocks on the network), and there exists some constant (let's call it `g` for now), which is greater than 1, that, when multiplied by `k`, gives us an average expected number of breadcrumbs in the transition frontier at any point in time. Calculating `g` is not possible until we have fully determined the consensus parameters for `f` and `Δ`, so as a dirty reason about the size of a transition frontier, we will somewhat conservatively assume `g = 2`. With this assumption, at `k = 1024` (the `k` value used by Cardano in the Ouroboros papers), all the scan states in the frontier will take up 22.09gb in the best case scenario, and 44.19gb in the average scenario. Therefore, the representation and storage rules for scan states needs to be modified in order to allow TPS to scale to a reasonable target for mainnet.

## Detailed design
[detailed-design]: #detailed-design

### Full vs. Partial Scan States
Scan states will be separated into 2 representations: full scan states, and partial scan states. A full scan state will is guaranteed to contain all the transaction witnesses for the base satements, where as a partial scan state has no such guarantee. As we will discuss below in the section "Global Transaction Witness Cache", the scan states will no longer store direct copies of the transaction witnesses. As such, the actual difference between a full and partial scan state is primarily that the transaction witnesses of a scan state will not have any guarantee of storage in the global transaction witness cache. Thus, full and partial scan states will individually have the exact same memory footprint, but indirectly, the memory footprint of a partial scan state is less since it only maintains weak references to transaction witnesses stored in the global transaction witness cache.

### Downgrading Full Scan States During Blockchain Extensions
Full scan states are only required at the tips of the transition frontier. These are the only blocks in the frontier where snark workers need the transaction witnesses to exist. In reality, snark workers only need the transaction witnesses at the best tip, but keeping the transaction witneses at all tips helps us cache transaction witnesses between blockchain extensions, which helps reduce the amount of transaction witnesses that need to be constructed when a reorg occurs. This means that the transition frontier will downgrade a full scan state into a partial scan state once a block extends the block that scan state belongs to. Said another way, when a block is added to a tip of the frontier, that tip becomes a branch. Tips will store full scan states (potential exceptions to this mentioned the section below), and branches will store partial scan states. Therefore, when a tip becomes a branch, the scan state for that block will be downgraded.

### Pruning Probalistically Dead Frontier Tips
Above we discuss that full scan states are only needed at the tips. This is true, but it's also true that as a tip is further back from the current best tip of the frontier, the probability that this tip (and thus the transaction witnesses contained in this tip) will be relevant at some point in the future goes down. Because of this, after some number of blocks are added to a better chain than a tip, its scan state can be downgraded. Downgrading this scan state is safe since, as long as we maintain the parent block's breadcrumb mask, we can always upgrade this scan state again if we need to in the future. Doing this incorrectly could potentially open up a denial of service attack (see [drawbacks](#drawbacks)), so it is important to take this into consideration when designing the function that will determine when to frontier tip is "dead", and thus, should have its scan state downgraded.

### Global Transaction Witness Cache
In the current implementation, identical transaction witnesses can exist duplicated across multiple scan states. Transaction witnesses which are inherited from the previous scan state will share the same pointer in the new scan state, but any transaction witnesses that are built up as part of applying a staged ledger diff are uniquely constructed in each scan state. It is rather common that multiple forks from the same parent block will share transaction witnesses, so long as the coinbase and fee transfers in a staged ledger diff exist at the end of the sequence of transactions. Duplication of these transaction witnesses can be identified faster than the actual construction of the transaction witness itself, so transaction witnesses can be stored in a global ref-counted cache instead of directly on the scan state itself. More formally, we compute a transaction witness `src -> dst` from the source merkle root `src` and the transaction `txn`. Building the transaction witness involves updating 2 accounts in a merkle tree, which, at the worst case, involves `57` merge hashes and `2` account hashes at ledger depth `30`. Given the `src` and `txn`, there is only one transaction witness `src -> dst` which can be constructed. Therefore, the value `H(src || H(txn))` uniquely identifies a transaction witness `src -> dst` without having to compute the `dst`. If a global transaction cache witness exists, then the staged ledger diff application algorithm can first check if `H(src || H(txn))` exists in the cache before building `src -> dst`. Under this scheme, the base statements of the scan state would no longer directly embed a reference to the transaction witness, but would instead store just the `H(src || H(txn))` for that witness, which will be used to find the actual transaction witness from the global transaction witness cache when it is required.

### Scan State Icebox
Similar to how the likelihood of a tip being extended decreases as the dominate chain in the transition frontier grows in length relative to that tip, the same is true for branches as well. The intermediate scan states in the transition frontier branches are needed to build new scan states which extend those branches. However, if we don't believe that a block will be extended (at least probalistically), we can persist the scan state of that block to disk, and load it back from disk if we ever need it again in the future. This "scan state icebox" where we persist the scan states to will need to be garbage collected as blocks are evicted from the transition frontier during root transitions.

## Work Breakdown/Prioritization

##### Must Do (definitely required to mitigate memory usage to acceptable levels)
1. Implement Global Transaction Witness Cache
2. Remove Transaction Witness Scan States Embedding
3. Implement Full/Partial Scan State Logic
4. Downgrade Branching Scan States in Frontier

##### Might Do (extra work which will further reduce memory usage)
1. Frontier Dead Tip Pruning
2. Scan State Icebox

## Drawbacks
[drawbacks]: #drawbacks

### Dead Frontier Tip Scan State Reconstruction Attack
Pruning probalistically dead frontier tips opens up nodes for potential denial of service attack. Pruning scan states is seen as "safe" because there is no actual loss in local data availability as long as the node maintains the ledger mask of the previous staged ledger in the transition frontier. This is because the scan state can be restored to its full format by recomputing the transaction witnesses from the previous staged ledger's target ledger. However, it is possible for an adversary to generate a fork off of an old tip in the frontier, then broadcast that, forcing any nodes which have pruned that scan state to reconstruct the transaction witnesses for it (under the current logic). This could be prevented by either adding a better heuristic for whether or not something is worth adding to our frontier (as in, if it's such a bad block, maybe we should skip it and only download it during catchup if later there is a good chain built off of it). Alternatively, this can be mitigated by only constructing transaction witnesses for tips which are "close enough" to our best tip in terms of strength. It would be a hard attack to execute in practice, but it is theoretically possible for an adversary to wait until a series of their accounts get VRF wins in nearby slots, and then make nodes perform a whole bunch of scan state witness reconstructions at the same time. All this said, it's not clear whether this attack could cause enough work to actually take nodes offline or lag behind the network enough to do anything bad.

### Incorrect Implementation of Scan State Icebox Leads to High Disk I/O
If the scan state icebox is not implemented correctly, it could potentially greatly increase the amount of disk I/O performed during participation. As such, it is very important that this is well instrumented and tested so that it does not accidentally vastly reduce performance in order to reduce the memory usage of the scan states some.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- can the exact gains from this be calculated before implementing these optimizations, so that we can use that as a framework for informing whether or not the optimizations were successful?
