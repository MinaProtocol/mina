# snarky

`snarky` is an OCaml front-end for writing R1CS SNARKs.
It is modular over the backend SNARK library, and comes with backends
from [libsnark](https://github.com/scipr-lab/libsnark).

Disclaimer: This code has not been thoroughly audited and should not
be used in production systems.

## Getting started
- First install libsnark's dependencies as specified [here](https://github.com/scipr-lab/libsnark#dependencies)
- Then, make sure you have [opam](https://opam.ocaml.org/doc/Install.html) installed.
- Then, install `snarky` by running
```bash
opam pin add snarky git@github.com:o1-labs/snarky.git
```
and answering yes to the prompts.

The best place to get started learning how to use the library are the annotated examples.
- [Election](examples/election/election_main.ml): shows how to use Snarky to verify an election was run honestly.
- [Merkle update](examples/merkle_update/merkle_update.ml): a simple example updating a Merkle tree.

## Design

The intention of this library is to allow writing snarks by writing what look
like normal programs (whose executions the snarks verify). If you're an experienced
functional programmer, the basic idea (simplifying somewhat) is that there is a monad
`Checked.t` so that a value of type `'a Checked.t` is an `'a` whose computation is
certified by the snark. For example, we have a function
```ocaml
mul : var -> var -> (var, _) Checked.t.
```
Given `v1, v2 : var`, `mul v1 v2` is a variable containg the product of v1 and v2,
and the snark will ensure that this is so.


### Example: Merkle trees
One computation useful in snarks is verifying membership in a list. This is
typically accomplished using authentication paths in Merkle trees. Given a
hash `entry_hash`, an address (i.e., a list of booleans) `addr0` and an
authentication path (i.e., a list of hashes) `path0`, we can write a checked
computation for computing the implied Merkle root:

```ocaml
  let implied_root entry_hash addr0 path0 =
    let rec go acc addr path =
      let open Let_syntax in
      match addr, path with
      | [], [] -> return acc
      | b :: bs, h :: hs ->
        let%bind l = Hash.if_ b ~then_:h ~else_:acc
        and r = Hash.if_ b ~then_:acc ~else_:h
        in
        let%bind acc' = Hash.hash l r in
        go acc' bs hs
      | _, _ -> failwith "Merkle_tree.Checked.implied_root: address, path length mismatch"
    in
    go entry_hash addr0 path0
```

The type of this function is
```ocaml
val implied_root : Hash.var -> Boolean.var list -> Hash.var list -> (Hash.var, 'prover_state) Checked.t
```
The return type `(Hash.var, 'prover_state) Checked.t` indicates that the function
returns a "checked computation" producing a variable containing a hash, and can be
run by a prover with an arbitrary state type `'prover_state`. 

Compare this definition to the following "unchecked" OCaml function (assuming a function `hash`):
```ocaml
let implied_root_unchecked entry_hash addr0 path0 =
  let rec go acc addr path =
    match addr, path with
    | [], [] -> acc
    | b :: bs, h :: hs ->
      let l = if b then h else acc
      and r = if b then acc else h
      in
      let acc' = hash l r in
      go acc' bs hs
    | _, _ ->
      failwith "Merkle_tree.implied_root_unchecked: address, path length mismatch"
  in
  go entry_hash addr0 path0
;;
```
The two obviously look very similar, but the first one can be run to generate an R1CS
(and also an "auxiliary input") to verify that computation. 

## Implementation

Currently, the library uses a free-monad style AST to represent the snark computation.
This may change in future versions if the overhead of creating the AST is significant.
Most likely it will stick around since the overhead doesn't seem to be too bad and it
enables optimizations like eliminating equality constraints.
