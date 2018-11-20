Reproduction case for #1508: make sure that paths in `env` stanzas are
interpreted relative to the directory of the `env` stanza.

  $ dune printenv . | grep '[(]flags'
   (flags (-from-included-file))
  $ dune printenv src | grep '[(]flags'
   (flags (-from-included-file))
