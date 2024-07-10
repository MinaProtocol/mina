# sprs, sparse matrices for Rust

[![Build status](https://github.com/sparsemat/sprs/actions/workflows/ci.yml/badge.svg)](https://github.com/sparsemat/sprs/actions)
[![crates.io](https://img.shields.io/crates/v/sprs.svg)](https://crates.io/crates/sprs)

sprs implements some sparse matrix data structures and linear algebra
algorithms in pure Rust.

The API is a work in progress, and feedback on its rough edges is highly
appreciated :)

## Features

### Structures

- CSR/CSC matrix
- triplet matrix
- Sparse vector

### Operations

- sparse matrix / sparse vector product
- sparse matrix / sparse matrix product
- sparse matrix / sparse matrix addition, subtraction
- sparse vector / sparse vector addition, subtraction, dot product
- sparse/dense matrix operations

### Algorithms

- Outer iterator on compressed sparse matrices
- sparse vector iteration
- sparse vectors joint non zero iterations
- simple sparse Cholesky decomposition (requires opting into an LGPL license)
- sparse triangular solves with dense right-hand side


## Examples

Matrix construction

```rust
  use sprs::{CsMat, CsMatOwned, CsVec};
  let eye : CsMatOwned<f64> = CsMat::eye(3);
  let a = CsMat::new_csc((3, 3),
                         vec![0, 2, 4, 5],
                         vec![0, 1, 0, 2, 2],
                         vec![1., 2., 3., 4., 5.]);
```

Matrix vector multiplication


```rust
  use sprs::{CsMat, CsVec};
  let eye = CsMat::eye(5);
  let x = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
  let y = &eye * &x;
  assert_eq!(x, y);
```

Matrix matrix multiplication, addition

```rust
  use sprs::{CsMat, CsVec};
  let eye = CsMat::eye(3);
  let a = CsMat::new_csc((3, 3),
                         vec![0, 2, 4, 5],
                         vec![0, 1, 0, 2, 2],
                         vec![1., 2., 3., 4., 5.]);
  let b = &eye * &a;
  assert_eq!(a, b.to_csr());
```

For a more complete example, be sure to check out the [heat diffusion](sprs/examples/heat.rs) example.


## Documentation

Documentation is available at [docs.rs](https://docs.rs/sprs).

## Changelog

See the [changelog](changelog.rst).

## Minimum Supported Rust Version

The minimum supported Rust version currently is 1.64. Prior to a 1.0 version,
bumping the MSRV will not be considered a breaking change, but breakage will
be avoided on a best effort basis.

## License

Licensed under either of

* Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or https://www.apache.org/licenses/LICENSE-2.0)
* MIT license ([LICENSE-MIT](LICENSE-MIT) or https://opensource.org/licenses/MIT)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the Apache-2.0
license, shall be dual licensed as above, without any additional terms or
conditions.

Please see the [contribution guidelines](Guidelines.rst) for additional information about
contributing.
