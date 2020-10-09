## Summary
[summary]: #summary

This RFC proposes some strategies to make our snark key management more
flexible, and to allow us to be more explicit about which keys to use and when
to generate them.

## Motivation
[motivation]: #motivation

The current key management strategy is brittle and hard to understand or
interact with.
* Every change that affects the snark keys requires a recompile of the majority
  of our libraries, and it is not possible to specify changes to the constraint
  system and the corresponding proving/verification keypairs at
  runtime.
* Snark keys are generated as part of the build process for some of the
  compile-time configurations, which slows down compiles and obfuscates the
  particular keys that any build is using, as well as preventing us from using
  a single, unified binary for our different configurations.
* Every set of keys that have been generated for a CI job are stored in the S3
  keys bucket, with no easy way to identify them.
* Keys in the S3 bucket are always preferred to locally-generated keys during
  the build process.
  - During local builds from developers' machines, internet connection problems
    may result in either partially-downloaded keyfiles or long download waits
    while the keys are fetched from S3.
* It is difficult for the infrastructure team to find and package the correct
  keys for a particular binaries when deploying.
* The caching behavior for keys is implicit and entangled with the pickles
  proof system interface, which makes it hard for the team to inspect or adjust
  the behavior.

The goal of this RFC is to resolve these issues. At a high-level, the proposed
steps to do this are:
* Make keys identifiable from the file contents.
* Add a tool for generating keys outside of the build process.
* Allow new keys to be specified explicitly.
* Make key generation explicit, removing it from the build process.

## Detailed design
[detailed-design]: #detailed-design

### Make keys identifiable from the file contents

In order to confirm that loaded keys are compatible with a given configuration,
we need to have some representation of the configuration embedded with the keys
files. We propose that every key (and URS) file contains a header in minified
JSON format before the actual contents, specifying
* the constraint constants, as defined in the runtime configuration
* the SHA commit identifiers for the current commit in the coda, marlin and
  zexe repos used when generating the keys
* the length of the binary data following the header, so that we can validate
  that the file was successfully downloaded in full, where applicable
* the date when the file's contents were created
* the type of the file's contents
* the constraint system hash (for keys) or domain size (for URS)
* any other input information
  - e.g. constraint system hash for the transaction snark wrapped by a
    particular blockchain snark
* a version number, so that we can add or modify fields
* the identifying hash, which should match the hash part of the filename for
  generated files

For example, a header for the transaction snark key file might look like:
```json
{ "header_version": 1
, "kind":
    { "type": "step_proving_key"
    , "identifier": "transaction_snark_base" }
, "constraint_constants":
    { "c": 8
    , "ledger_depth": 14
    , "work_delay": 2
    , "block_window_duration_ms": 180000
    , "transaction_capacity": {"txns_per_second_x10": "2"}
    , "coinbase_amount": "200"
    , "supercharged_coinbase_factor": 2
    , "account_creation_fee": "0.001" }
, "commits":
    { "coda": "COMMIT_SHA_HERE"
    , "marlin": "COMMIT_SHA_HERE"
    , "zexe": "COMMIT_SHA_HERE" }
, "length": 1000000000
, "date": "1970-01-01 00:00:00"
, "constraint_system_hash": "MD5_HERE"
, "identifying_hash": "HASH_HERE" }
```

This will allow us to identify files from S3 or in a cache directory by
examining only the header, making it easier to remove outdated keys and to
find or enumerate keys.

The majority of the work here is adjusting the rust code so that the header can
be generated from OCaml and written to the same file as its contents.

### Add a tool for generating keys outside of the build process

This tool could be an `internal`/`advanced` subcommand of the main executable
to begin with. The interface may be extremely basic, reusing the current
runtime configuration files:

```
coda.exe advanced generate-snark-keys -config-file path/to/config.json
```

Suggested optional arguments are:
* `-key-directory` - specify the directory to place the keys in
* `-output-config-file` - write a config file with the keys path information
  included
* `-list-missing-headers` - do not generate files, instead dump the JSON
  headers of key files that do not already exist in the given key directory.
  + This is for use by the infrastructure team, so that CI and deployment
    processes can identify which keys to look for in S3 or another cache
    without explicitly building S3 code into the process.
  + This should probably have an exit status of 1 (rather than the normal 0)
    if e.g. transaction snark keys are missing, to signal to the CI tool that
    some files are missing but their headers could not be inferred because they
    depend on other files.

Most of this is calling existing functions; the only particular difficulty is
modifying `Pickles` and `Cache_dir` to allow finer-grained control of cache
locations for keys.

### Allow new keys to be specified explicitly.

In order to allow different keys to be used with the same binary, we need a way
to specify the files to load or the directories to search in. We should add
fields to the runtime configuration `config.json` file for
* `snark_key_directories` - the list of directories to search in for keys
* `snark_keys` - a list where the filenames of individual keys can be
  specified, identified by a `kind` field matching the one in the key's header.

For example,
```json
{ ...
, "snark_key_directories": ["~/.coda_cache_dir/snark_keys"]
, "snark_keys":
    [ { "kind":
        { "type": "step_proving_key"
        , "identifier": "blockchain_snark" }
      , "path": "~/Downloads/blockchain_snark_pk" }
    , { "kind":
        { "type": "step_verification_key"
        , "identifier": "blockchain_snark" }
      , "path": "~/Downloads/blockchain_snark_vk" }
    , { "kind":
        { "type": "wrap_proving_key"
        , "identifier": "blockchain_snark" }
      , "path": "~/Downloads/blockchain_snark_wrap_pk" }
    , { "kind":
        { "type": "wrap_verification_key"
        , "identifier": "blockchain_snark" }
      , "path": "~/Downloads/blockchain_snark_wrap_vk" } ] }
```

Integrating this with the `Pickles` library will involve restructuring its
`compile` function, probably converting it to a functor that exposes a module
with the hidden load and store operations for keys, as well as the other
functions that will need to be called explicitly once there is no implicit
caching. Once this is done, the paths can be passed to the relevant subsystems,
can load the files on-demand from the Pickles interfaces.

### Make key generation explicit, removing it from the build process.

Once the other stages have been completed, the CI, deployment, and release
processes will need to be updated to ensure that the keys are correctly placed/
packaged, and that the configuration file specifies the correct locations. The
specific details of these are not clear yet and may vary, so these details are
considered out of the scope of this RFC.

In most cases, it should be possible to use the
`coda.exe advanced generate-snark-keys -config-file path/to/input_config.json -output-config-file path/to/output_config.json`
form of the `generate-snark-keys` function above to do most or all of the
necessary setup work.

When the switchover is complete, removing the `Snark_keys` library from the
repo will stop keys from being generated at build time with no other changes
needed.

## Drawbacks
[drawbacks]: #drawbacks

* This adds an extra step to building a working, proof-enabled binary.
* This adds more features to the `config.json` configuration files that most
  users will/should not use.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Rationale:
* This design adds useful information that has been missing to the place where
  it would be used.
* This design separates the distinct concerns of code compilation and
  cryptographic artifact generation.
* This design is simpler and more flexible than the current system.
* This design makes it possible to change caching solutions in response to cost
  and complexity changes.
* This design moves a poorly-understood part of our infrastructure to the
  configuration level of the other infrastructure components.

## Prior art
[prior-art]: #prior-art

The current system.

## Unresolved questions
[unresolved-questions]: #unresolved-questions
