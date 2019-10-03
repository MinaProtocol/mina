# Transition Frontier Persistence

The transition frontier is broken into 3 parts:
- the full frontier, which is the in memory copy of the transition frontier with an expanded view of transitions called "breadcrumbs"
- the persistent root, which is a persistent record of some of the state at the root of the full frontier (this is kept directly in sync with the full frontier)
- the persistent frontier, which is a persistent record of the remaining, non-expanded information stored in the full frontier (the synchronization of this lags behind the transition frontier)

Persistence of the transition frontier is split up into two different layers in order to minimize the cost of persistence to the in memory operations on the full frontier. In particular, it is too expensive to serialize every transition when it is received, and  it's alos way too expensive to serialized the entire scan state on every root transition. However, we also don't want our persistent view to be too out of date and cause our view of the network to regress heavily during short periods of a node being offline. Therefore, one layer of persistence (the persistent root) is kept up-to-date with the in memory full frontier. In order to do this while minimizing the cost to the in memory operations on the full frontier, the amount of data written to disk on each update to the persistent root needs to be very small. Conversely, since the other layer of persistence (the persistent frontier) is synchronized in a periodic/lagging fashion, it's disk I/O operations can be more complex and write more data.

## Persistent Root

The persistent root contains two pieces of information: the snarked ledger database at the root of the transition frontier, and a root identifier. Every time a root transition occurs in the full frontier, the root identifier will be re-written to point to the new root of the full frontier. If a root transition moves to a new root for which there was a ledger proof emitted from the scan state, then the snarked ledger database is also updated to the new snarked ledger pointed to by the new root.

## Persistent Frontier

The persistent frontier is a persistent copy of the in memory full frontier, except that only transitions are stored and not the fully expanded breadcrumbs that exist in the full frontier. Additionally, at the root of the persistent frontier, a root identifier and a root staged ledger are kept. The full frontier can be recovered from the information in the persistent frontier by taking the root staged ledger and applying all of the staged ledger diffs from the transitions in the persistent frontier in order to rebuild the breadcrumbs. The persistent frontier is updated in another process[^1] which handles a chunk of full frontier diffs and applies them to the persistent representation.

[^1]: this is not true right now, but will be soon

## Loading the Full Frontier

Loading the full frontier is done by attempting to align the persistent root and the persistent frontier, then building a full frontier from the persistent frontier. If there is no persistent state, or the persistent root and the persistent frontier cannot be aligned, then a bootstrap is performed, after which the persistent data is reset. The full frontier is loaded from the persistent frontier by folding the root snarked ledger over all the paths in the frontier in order to reconstruct the breadcrumb at each position.
