## Summary
[summary]: #summary

This RFC proposes changes to the Berkeley release of the daemon which will bring daemon's maximum possible memory usage within the range of our current hardware memory requirements of the Mainnet release.

## Motivation
[motivation]: #motivation

With zkApps enabled, the maximum memory usage of the daemon now exceeds the current hardware requirements (`16GB`), in the event that the network is fully saturated with max-cost zkApps transactions in blocks for an extended period of time. With the planned parameters for Berkeley, we estimate that the maximum memory usage of a daemon is around `58.144633GB`.

## Detailed design
[detailed-design]: #detailed-design

In order to reduce the memory usage of the daemon, we will offload some of the memory allocated data to an on-disk cache. The [memory analysis section](#memory-analysis) will show that the majority of memory in the fully saturated max-cost transaction environment comes from ledger proofs, zkApps proofs, and zkApps verification keys. Each of these pieces of data are accessed infrequently by the daemon, and, as such, do not need to be stored in RAM for fast access.

Below is a list of all the interactions the daemon has with ledger proofs, zkApps proofs, and zkApps verification keys:

* ledger proofs are stored upon receipt of snark work from the gossip network
* zkApps proofs and newly deployed zkApps verification keys are stored upon receipt of zkApps transactions from the gossip network
* ledger proofs, zkApps proofs, and zkApps verification keys are read when a block is produced, in order for them to be included into the staged ledger diff
* ledger proofs, zkApps proofs, and zkApps verification keys are stored upon receipt of new blocks from the gossip network
* ledger proofs, zkApps proofs, and zkApps verification keys are read when a block is applied to the ledger
* ledger proofs, zkApps proofs, and zkApps verification keys are read when serving bootstrap requests to nodes joining the network

In order to write this data to disk, we will use the [Lightning Memory-Mapped Database](http://www.lmdb.tech/doc/) (LMDB for short). LMDB is a lightweight, portable, and performant memory map backed key-value storage database. We will demonstrate that the performance of this database is more than sufficient for our use case in the [impact analysis section](#impact-analysis).

For this optimization, it is not important that the on-disk cache is persisted across daemon runs. Such a feature can be added in the future, and this storage layer can double as a way to better persist data from the snark pool and data references from the persistent frontier. However, for now, we will set up the daemon so that it wipes the existing on-disk cache between every restart, in order to simplify the implementation and avoid having to deal with potentially a corrupted on-disk cache (in the event the daemon or operating system did not shut down properly). This is particularly important given our choice of LMDB does not provide complete guarantees against data corruption out of the box, due to the fact memory maps can lead to partial writes if the kernel panics or is otherwise interrupted before the system is gracefully shutdown.

To prevent disk leaks in the cache, we will use GC finalizers on cache references to count the active references the daemon has to information written to the cache. Since the daemon is always starting with a fresh on-disk cache, this will give an accurate reference count to any data cached on-disk. When a GC finalizer decrements the total reference count of an item stored on the cache to 0, it will delete that item from the cache. With this setup, the on-disk cache can only leak if there is a memory leak within the daemon itself, in which the daemon is leaking references to the cache.

## Memory Analysis
[memory-analysis]: #memory-analysis

<!-- TODO: better name for this script so that it's not so custom-tailored to this conversation -->
In order to accurately estimate the memory usage of the daemon in the fully saturated max-cost transaction environment, we have written a program `src/app/ram_fix_math/ram_fix_math.exe`. This program counts the size of GC allocations on various data structures used by the daemon, and does so by carefully ensuring every value is a unique allocation and that there are no shared references within data structures. We do this by transporting values back and forth via bin_prot, simulating the same behavior the daemon will have when it reads and deserializes data from the network. We then use these measurements to estimate the expected worst-case memory footprint of larger data structures in the system, such as the mempools and the frontier. Expectations around shared references across these larger data structures are directly subtracted from the estimates.

Below is the output of the script when all of the parameters are tuned to what we have planned for the Berkeley release.

```
baseline = 3.064569GB
scan_states = 15.116044GB
ledger_masks = 2.292873GB
staged_ledger_diffs = 32.345724GB
snark_pool = 4.453962GB
transaction_pool = 0.871383GB
TOTAL: 58.144555GB
```

In this output, the baseline is made up of static measurements taken from the daemon, which represents the overhead of running a daemon regardless of throughput or transaction cost. We have then estimated the expected worst-case memory usage of the scan states, ledger masks, and staged ledger diffs, which are the overwhelming majority of data allocated for the frontier. And finally, we estimate the memory footprint of the snark pool and transaction pool.

Now, if we adjust the estimates for proposed optimizations to store proofs and verification keys to disk (by subtracting their sizes from the memory footprint and replacing them with cache references), we get the following output.

```
baseline = 3.064569GB
scan_states = 3.658435GB
ledger_masks = 0.562126GB
staged_ledger_diffs = 9.202166GB
snark_pool = 0.014414GB
transaction_pool = 0.247903GB
TOTAL: 16.749612GB
```

As we can see, this brings the estimation down much closer to the current `16GB` hardware requirement. From here, we can look into additional optimizations to bring it down even further to fit within the current hardware requirements. Such optimizations could include:

* sharing the prover key allocation across the daemon's subprocesses, reducing the baseline to nearly 1/3rd of what it is now
* persisting the entire staged ledger diff of each block to disk, given we rarely need to read the commands contained within a staged ledger diff after the diff has been applied
* throwing out older proofs/commands from scan states once they are no longer required for the remaining work to be included

### Impact Analysis
[impact-analysis]: #impact-analysis

There is a space-time tradeoff here in the sense that, by excising data from RAM to disk, we are now needing to perform disk I/O and deserialize/serialize data in order to perform reads/writes. So part as part of this design, it is important to show that the performance hit we take for reading/writing data cached to disk is relatively insignificant in the operation of the daemon.

<!--
I tried to use the lmdb benchmarks to get accurate numbers for the exact sizes of our data structures, but was unable to get the program working with large sizes for some reason. I can spend some time later to make the benchmark program work, if necessary.
-->

LMDB provides benchmarks against other similar databases [on their website](http://www.lmdb.tech/bench/microbench/). The important piece of data here is that, with a 128MB cache and values of `100,000` bytes in size, LMDB is benched at being capable of performing `1,718,213` random reads per second (about `582` nanoseconds per read). Given the amount of reads, and frequencey of reads, a daemon will be performing from this on-disk cache, these benchmarks show that reading from LMDB will have a negligible effect on daemon performance. All proofs and verification keys we would read/write to disk are under this `100,000` benchmark size, so the actual performance should be better than this.
<!-- TODO: analyze the exact amount and frequency of reads to be really concrete here; also be concrete about the size of data we will be readin to show that the `100,000` byte size is overshooting what we actually need -->

Bin_prot serialization benchmarks for the proofs and verification keys have been added to the same program that does the memory impact analysis presented above. In this program, we run 10_000 trials of each operation, and take an average of the elapsed time for the entire execution. Below are the results from this program (as run on my local machine).

```
==========================================================================================
SERIALIZATION BENCHMARKS Pickles.Side_loaded.Proof.t
==========================================================================================
write: 32.424211502075195us (total: 324.24211502075195ms)
read: 46.872687339782715us (total: 468.72687339782715ms)

==========================================================================================
SERIALIZATION BENCHMARKS Mina_base.Verification_key_wire.t
==========================================================================================
write: 6.0153961181640625us (total: 60.153961181640625ms)
read: 1.0202760457992552ms (total: 10.202760457992554s)

==========================================================================================
SERIALIZATION BENCHMARKS Ledger_proof.t
==========================================================================================
write: 36.144065856933594us (total: 361.44065856933594ms)
read: 51.637029647827148us (total: 516.37029647827148ms)
```

Taking these numbers, we can estimate the relative impact deserialization/serialization will have on the important operations of the daemon. 

```
==========================================================================================
SERIALIZATION OVERHEAD ESTIMATES
==========================================================================================
zkapp command ingest = 218.46170425415039us
snark work ingest = 66.01405143737793us
block ingest = 18.206448364257813ms
block production = 397.33380432128905ms
```

The estimates for zkapp command and snark work ingest represent the overhead to add a single new max cost zkapp command or snark work bundle to the on-disk cache. The block ingest represents the cost to add resources from max cost block to disk, assuming we did not already have any of the items contained in the block already cached on-disk (in most circumstances, we would). The block production overhead is the amount of time the daemon would spend loading all relevant resources from disk in order to produce a max cost block.

## Drawbacks
[drawbacks]: #drawbacks

This approach requires us to perform additional disk I/O in order to offload the data from RAM to disk. Our above analysis shows this will have a negligible impact on the performance of a daemon, but this approach will mean we will use more disk space than before. Based on the estimates presented above, the worst case additional disk usage will be `~42GB`. With our initial approach, we mitigate the risk of a disk usage leak by wiping out the on-disk cache when the daemon restarts.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

The only real alternative to this approach would be to find some way to optimize the memory impact of the proofs and verification keys without writing them to disk, which would require some form of compression. Given proofs and verification keys are cryptographic data, and thus have a necessarily high degree of "randomness" in the values they contain, they are not easily compressed via normal techniques. Even still, the space/time tradeoff of compressing this data will be harder to argue for, given that we need to be able to read this data during critical operations of the daemon (block production, block ingest, snark work ingest, and zkapp command ingest).

## Prior art
[prior-art]: #prior-art

We do not have prior art in the direction of on-disk caching for relief of memory usage. We do have prior art for the LMDB implementation of OCaml, as we already have integrated LMDB into the Bitswap work we plan to release in a soft fork work after Berkeley. We can lean on this prior work here since we will also be using LMDB for this on-disk cache.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* Can we increase the hardware requirements to `32GB` at the point of the Berkeley release?
* Which of the additional recommended memory optimizations should we take first in order to bring the estimated memory usage well below the current `16GB` memory requirement?
* How much additional buffer should we leave between our memory estimate and the actual hardware requirements (accounting for RAM spikes and other processes on the system)?
