(** Reinstate the automatic major-heap compaction that OCaml 4 performed and
    OCaml 5 dropped.

    OCaml 4.14 compacted the major heap whenever wasted space exceeded
    [Gc.control.max_overhead] percent of live data (default 500). OCaml 5 removed
    that trigger: [max_overhead] "is currently not available in OCaml 5 ...
    setting [it] therefore has no effect", and the runtime compacts only on an
    explicit {!Gc.compact}. Empty major-heap pools go to a freelist that stays
    mapped, so a long-lived process holds its high-water mark indefinitely — the
    collector knows the data is dead, but the pages never go back to the OS.

    {!Gc.create_alarm} runs a callback at the end of each major GC cycle, which is
    exactly where OCaml 4 evaluated the policy, so it can be restored in user
    code. Measured on a load-then-idle workload, this takes a 5.3 process from
    237 MiB down to the 7 MiB an OCaml 4 build settles at unaided. *)

val install :
     ?overhead:int
  -> ?min_peak_heap_mib:float
  -> ?should_compact:(unit -> bool)
  -> logger:Logger.t
  -> unit
  -> unit

(** [install ~logger ()] arranges for the major heap to be compacted whenever
    wasted space exceeds [overhead] percent of live data.

    @param overhead
      percentage of live data above which wasted heap triggers compaction.
      Defaults to 500, matching OCaml 4.14's [max_overhead] default.

      Deliberately a {e ratio} rather than an absolute cap: a cap degenerates
      once live data legitimately exceeds it, firing a compaction on every major
      cycle that cannot free anything and pinning the process on stop-the-world
      pauses precisely when memory is already tight.

    @param min_peak_heap_mib
      processes whose heap has never reached this size are left alone, so
      short-lived and small ones never pay for a pause that could not reclaim
      much. Defaults to 256 MiB.

      Keyed on the {e peak} heap deliberately. Sweeping returns emptied pools to
      a freelist that stays mapped, so the reported heap size falls while RSS
      does not — which is exactly the state worth compacting. A floor on the
      current heap refuses to act precisely then, and was observed doing so.

    @param should_compact
      consulted immediately before compacting; returning [false] skips this
      opportunity and waits for the next major cycle. Use it to keep
      stop-the-world pauses away from latency-critical work — the daemon gates on
      not currently producing a block.

    The alarm lives for the lifetime of the process and is deliberately not
    returned: nothing needs to delete it, and exposing {!Stdlib.Gc.alarm} would
    clash at call sites that [open Core], whose [Gc] offers a nested
    [Expert.Alarm] module and no [alarm] type.

    Setting [MINA_GC_COMPACTION=off] disables the alarm; setting it to a positive
    integer overrides [overhead]. This exists as a rebuild-free kill switch: the
    alarm introduces stop-the-world pauses into long-running processes, and an
    operator who needs them gone should not have to wait for a release. *)
