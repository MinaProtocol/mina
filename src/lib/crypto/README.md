# Crypto

This folder groups cryptography-relevant packages.

```
crypto/ 
├── kimchi_backend/   # the glue between kimchi and snarky/pickles (TODO: move to a kimchi/ folder)
├── kimchi_bindings/  # the glue between ocaml and kimchi (the proof system in rust) # TODO: rename to kimchi
└── proof-systems     # a submodule pointing to the Rust implementation of kimchi
```

<!--
TODO: this should go in a README-dev.md, or somwewhere else where the mina
documentation for developers is.
At least, it should be a scripts in src/scripts where we mention the commit hash
of the proof-systems repository.
-->
## Update proof-systems

[proof-systems](https://github.com/o1-labs/proof-systems/) is a git submodule.
To update, make your changes upstream. After that, run in this repository:
```
COMMIT_HASH=yourcommithash
cd proof-systems
git fetch
git checkout ${COMMIT_HASH}
cd ../
git add proof-systems
git commit -m "Deps: bump up proof-systems to ${COMMIT_HASH}"
```


