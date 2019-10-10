### Versioned types with `asserted`

Types that have `deriving version {asserted}` are types that refer to types, perhaps indirectly, 
that the Coda codebase does not control. Such types can come from external libraries, such as Snarky. 
The types with that annotation are contained in the usual `Stable.Vn` module hierarchy, so we
can refer to them in other versioned types.

Because we don't control such types, their serializations may change over time. Therefore, for those
types, we must have tests that detect such changes. The convention is to create a module
`Stable.For_tests` with tests of the form:
```ocaml
let%test "the-type serialization vn" =
let v = ... in
let known_good_hash = ...
Serialization.check_serialization (module Vn) v known_good_hash
```
where `v` is a value of the version-asserted type, the known-good hash is the SHA256 hash of
the `Bin_prot` serialization of the value. The `Serialization` module in this library
has a `print_hash` function that can be used to print such a hash when writing a test.

If one of these test fails, it means the serialization has changed. In that case, create a new version 
for the version-asserted type, and a new serialization test for that new version; delete the old version 
and its test

