;; Check whether jemalloc is available to the compiler. Use it as an allocator if that's the case, and use libc otherwise.
(rule
  (target dune-alloc)
  (action (with-stdout-to dune-alloc
    (bash "
        printf 'Checking if jemalloc is available... ' 1>&2
        if pkg-config --exists jemalloc; then
          echo 'Yes, using jemalloc as an allocator' 1>&2
          pkg-config --libs jemalloc
        else
          echo 'No, using the default allocator from libc' 1>&2
        fi
    "))))
