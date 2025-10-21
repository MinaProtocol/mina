;; Check whether jemalloc is available to the compiler. Use it as an allocator if that's the case, and use libc otherwise.
(rule
  (target dune-alloc)
  (action (with-stdout-to dune-alloc
    (run %{dep:./check_jemalloc.sh}))))
