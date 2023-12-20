# Disk Caching Stats

This program computes the expected worst-case memory usage of the daemon before and after applying the disk caching changes proposed in [RFC 53: Reducing Daemon Memory Usage](rfcs/0053-reducing-daemon-memory-usage.md).

This program counts the size of GC allocations on various data structures used by the daemon, and does so by carefully ensuring every value is a unique allocation and that there are no shared references within data structures. We do this by transporting values back and forth via bin_prot, simulating the same behavior the daemon will have when it reads and deserializes data from the network. We then use these measurements to estimate the expected worst-case memory footprint of larger data structures in the system, such as the mempools and the frontier. Expectations around shared references across these larger data structures are directly subtracted from the estimates.

The program can be run with no arguments to run the calculation. The `Params` module contains parameters for the computation, which can be changed before recompiling the program to produce new results.
