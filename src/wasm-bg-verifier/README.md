# wasm-bg-verifier

This is an implementation of the Bowe-Gabizon ported [from Snarkette](https://github.com/CodaProtocol/coda/blob/f28db1206900fc0a84bdcb1241920f5675fe2e3a/src/lib/snarkette/bowe_gabizon.ml). 

## Third-party code

The code in third_party is largely imported from the zcash project. It is managed with `git subtree`, see [this guide](https://www.atlassian.com/git/tutorials/git-subtree) for how to work with it.

## Performance

Here are some performance numbers versus the verifier from the [SNARK Challenge](https://github.com/CodaProtocol/snark-challenge/tree/f04d6313b11ce9fc2739b2d869e239e0d0a4565c/reference-05-verifier) when verifying a Coda blockchain SNARK:

Snarkette:

wasm-bg-verifier:

Measured on an otherwise mostly-idle Firefox 68.0 on an Intel i9-8950HK.
