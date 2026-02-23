## Plonkish prelude

This library contains modules supporting "plonkish" systems that aren't necessarily tied
to kimchi (e.g. future work for o1vm, arrabiata folding, etc)

This library provides data structures encoded at the type level. The idea is to
encode runtime invariants and rely on the OCaml compiler to verify properties at
compile time instead of adding a runtime overhead.