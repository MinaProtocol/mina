# RMP - Rust MessagePack

RMP is a pure Rust [MessagePack](http://msgpack.org) implementation.

[![Build Status](https://travis-ci.org/3Hren/msgpack-rust.svg?branch=master)](https://travis-ci.org/3Hren/msgpack-rust)
[![Coverage Status][coveralls-img]][coveralls-url]

This repository consists of three separate crates: the RMP core and two implementations to ease serializing and
deserializing Rust structs.

 crates.rs                                 | API Documentation               |
-------------------------------------------|---------------------------------|
 [![rmp][crates-rmp-img]][crates-rmp-url]     | [RMP][rmp-docs-url]             |
 [![rmps][crates-rmps-img]][crates-rmps-url]   | [RMP Serde][rmps-docs-url]      |
 [![rmpv][crates-rmpv-img]][crates-rmpv-url]   | [RMP Value][rmpv-docs-url]      |

## Features

- **Convenient API**

  RMP is designed to be lightweight and straightforward. There are low-level API, which gives you
  full control on data encoding/decoding process and makes no heap allocations. On the other hand
  there are high-level API, which provides you convenient interface using Rust standard library and
  compiler reflection, allowing to encode/decode structures using `derive` attribute.

- **Zero-copy value decoding**

  RMP allows to decode bytes from a buffer in a zero-copy manner easily and blazingly fast, while Rust
  static checks guarantees that the data will be valid as long as the buffer lives.

- **Clear error handling**

  RMP's error system guarantees that you never receive an error enum with unreachable variant.

- **Robust and tested**

  This project is developed using TDD and CI, so any found bugs will be fixed without breaking
  existing functionality.

## Requirements

- Rust 1.53.0 or later

[rustc-serialize]: https://github.com/rust-lang-nursery/rustc-serialize
[serde]: https://github.com/serde-rs/serde

[coveralls-img]: https://coveralls.io/repos/3Hren/msgpack-rust/badge.svg?branch=master&service=github
[coveralls-url]: https://coveralls.io/github/3Hren/msgpack-rust?branch=master

[rmp-docs-url]: https://docs.rs/rmp
[rmps-docs-url]: https://docs.rs/rmp-serde
[rmpv-docs-url]: https://docs.rs/rmpv

[crates-rmp-img]: https://img.shields.io/crates/v/rmp.svg
[crates-rmp-url]: https://lib.rs/crates/rmp

[crates-rmps-img]: https://img.shields.io/crates/v/rmp-serde.svg
[crates-rmps-url]: https://lib.rs/crates/rmp-serde

[crates-rmpv-img]: https://img.shields.io/crates/v/rmpv.svg
[crates-rmpv-url]: https://lib.rs/crates/rmpv
