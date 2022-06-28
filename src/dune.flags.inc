(include dune.linker.inc)

(env
  (_
    (flags (:standard -short-paths
            -ccopt=%{read:dune-linker}
            -cclib -ljemalloc
            -w @a-4-16-29-40-41-42-44-45-48-58-59-60-66-69-70))))
