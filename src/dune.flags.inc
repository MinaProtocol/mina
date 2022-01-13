(env
  (_
    (flags (:standard
      -short-paths
      -cclib=-ljemalloc ; We use jemalloc as an allocator everywhere
      -cclib=-Wl,--allow-multiple-definition ; Otherwise jemalloc's malloc implementation may collide with the one provided by libc
      -w @a-4-29-40-41-42-44-45-48-58-59-60-66
))))
