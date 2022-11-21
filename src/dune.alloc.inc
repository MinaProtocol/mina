;; Check whether jemalloc is available to the compiler. Use it as an allocator if that's the case, and use libc otherwise.
(rule
  (target dune-alloc)
  (action (with-stdout-to dune-alloc
    (bash "
        printf 'Checking if jemalloc is available... ' 1>&2
        echo 'int main(){}' > .jemalloc_test.c
        if [ -z ${CC-} ]; then if command -v gcc > /dev/null; then CC=gcc; else CC=clang; fi; fi
        if $CC -ljemalloc .jemalloc_test.c -o /dev/null
            then printf 'Yes, using jemalloc as an allocator\n' 1>&2; printf jemalloc
            else printf 'No, using the default allocator from libc\n' 1>&2; printf c
        fi
    "))))
