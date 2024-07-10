# ocaml-rs - OCaml extensions in Rust

<a href="https://crates.io/crates/ocaml">
    <img src="https://img.shields.io/crates/v/ocaml.svg">
</a>

`ocaml-rs` allows for OCaml extensions to be written directly in Rust with no C stubs. It was originally forked from [raml](https://crates.io/crates/raml), but has been almost entirely re-written thanks to support from the [OCaml Software Foundation](http://ocaml-sf.org/).

Works with OCaml versions `4.06.0` and up

Please report any issues on [github](https://github.com/zshipko/ocaml-rs/issues)

NOTE: While `ocaml-rs` *can* be used safely, it does not prevent a wide range of potential errors or mistakes. It should be thought of as a Rust implementation of the existing C API. [ocaml-interop](https://github.com/simplestaking/ocaml-interop) can be used to perform safe OCaml/Rust interop. The latest version of `ocaml-rs` actually uses `ocaml-interop` behind the scenes to interact with the garbage collector. `ocaml-rs` also exports an `interop` module, which is an alias for `ocaml_interop` and the two interfaces can be combined if desired.

### Getting started

Take a look at the [ocaml-rust-starter](http://github.com/zshipko/ocaml-rust-starter) project for a basic example to help get started with `ocaml-rs`.

On the Rust side, you will need to add the following to your `Cargo.toml`:

```toml
ocaml = "*"
```

or

```toml
ocaml = {git = "https://github.com/zshipko/ocaml-rs"}
```

For macOS you will need also to add the following to your project's `.cargo/config` file:

```toml
[build]
rustflags = ["-C", "link-args=-Wl,-undefined,dynamic_lookup"]
```

This is because macOS doesn't allow undefined symbols in dynamic libraries by default.

Additionally, if you plan on releasing to [opam](https://github.com/ocaml/opam), you will need to vendor your Rust dependencies to avoid making network requests during the build phase, since reaching out to crates.io/github will be blocked by the opam sandbox. To do this you should run:

```shell
cargo vendor
```

then follow the instructions for editing `.cargo/config`

### Build options

By default, building `ocaml-sys` will invoke the `ocamlopt` command to figure out the version and location of the OCaml compiler. There are a few environment variables to control this.

- `OCAMLOPT` (default: `ocamlopt`) is the command that will invoke `ocamlopt`
- `OCAML_VERSION` (default: result of `$OCAMLOPT -version`) is the target runtime OCaml version.
- `OCAML_WHERE_PATH` (default: result of `$OCAMLOPT -where`) is the path of the OCaml standard library.
- `OCAML_INTEROP_NO_CAML_STARTUP` (default: unset) can be set when loading an `ocaml-rs` library into an OCaml
  bytecode runtime (such as `utop`) to avoid linking issues with `caml_startup`

If both `OCAML_VERSION` and `OCAML_WHERE_PATH` are present, their values are used without invoking `ocamlopt`. If any of those two env variables is undefined, then `ocamlopt` will be invoked to obtain both values.

Defining the `OCAML_VERSION` and `OCAML_WHERE_PATH` variables is useful for saving time in CI environments where an OCaml install is not really required (to run `clippy` for example).

### Features

- `derive`
  * enabled by default, adds `#[ocaml::func]` and friends and `derive` implementations for `FromValue` and `IntoValue`
- `link`
  * link the native OCaml runtime, this should only be used when no OCaml code will be linked statically
- `no-std`
  * Allows `ocaml` to be used in `#![no_std]` environments like MirageOS

### Documentation

[https://docs.rs/ocaml](https://docs.rs/ocaml)

### Examples

```rust
// Automatically derive `IntoValue` and `FromValue`
#[derive(ocaml::IntoValue, ocaml::FromValue)]
struct Example<'a> {
    name: &'a str,
    i: ocaml::Int,
}


#[ocaml::func]
pub fn incr_example(mut e: Example) -> Example {
    e.i += 1;
    e
}

#[ocaml::func]
pub fn build_tuple(i: ocaml::Int) -> (ocaml::Int, ocaml::Int, ocaml::Int) {
    (i + 1, i + 2, i + 3)
}

#[ocaml::func]
pub fn average(arr: ocaml::Array<f64>) -> Result<f64, ocaml::Error> {
    let mut sum = 0f64;

    for i in 0..arr.len() {
        sum += arr.get_double(i)?;
    }

    Ok(sum / arr.len() as f64)
}

// A `native_func` must take `ocaml::Value` for every argument and return an `ocaml::Value`
// these functions have minimal overhead compared to wrapping with `func`
#[ocaml::native_func]
pub fn incr(value: ocaml::Value) -> ocaml::Value {
    let i = value.int_val();
    ocaml::Value::int(i + 1)
}

// This is equivalent to:
#[no_mangle]
pub extern "C" fn incr2(value: ocaml::Value) -> ocaml::Value {
    ocaml::body!(gc: (value) {
        let i = value.int_val();
        ocaml::Value::int( i + 1)
    })
}

// `ocaml::native_func` is responsible for:
// - Ensures that #[no_mangle] and extern "C" are added, in addition to wrapping
// - Wraps the function body using `ocaml::body!`

// Finally, if your function is marked [@@unboxed] and [@@noalloc] in OCaml then you can avoid
// boxing altogether for f64 arguments using a plain C function and a bytecode function
// definition:
#[no_mangle]
pub extern "C" fn incrf(input: f64) -> f64 {
    input + 1.0
}

#[cfg(feature = "derive")]
#[ocaml::bytecode_func]
pub fn incrf_bytecode(input: f64) -> f64 {
    incrf(input)
}
```

Note: By default the `func` macro will create a bytecode wrapper (using `bytecode_func`) for functions with more than 5 arguments.

The OCaml stubs would look like this:

```ocaml
type example = {
    name: string;
    i: int;
}

external incr_example: example -> example = "incr_example"
external build_tuple: int -> int * int * int = "build_tuple"
external average: float array -> float = "average"
external incr: int -> int = "incr"
external incr2: int -> int = "incr2"
external incrf: float -> float = "incrf_bytecode" "incrf" [@@unboxed] [@@noalloc]
```

For more examples see [test/src](https://github.com/zshipko/ocaml-rs/blob/master/test/src) or [ocaml-vec](https://github.com/zshipko/ocaml-vec).

### Type conversion

This chart contains the mapping between Rust and OCaml types used by `ocaml::func`

| Rust type        | OCaml type           |
| ---------------- | -------------------- |
| `()`             | `unit`               |
| `isize`          | `int`                |
| `usize`          | `int`                |
| `i8`             | `int`                |
| `u8`             | `int`                |
| `i16`            | `int`                |
| `u16`            | `int`                |
| `i32`            | `int32`              |
| `u32`            | `int32`              |
| `i64`            | `int64`              |
| `u64`            | `int64`              |
| `f32`            | `float`              |
| `f64`            | `float`              |
| `str`            | `string`             |
| `[u8]`           | `bytes`              |
| `String`         | `string`             |
| `Option<A>`      | `'a option`          |
| `Result<A, B>`   | `exception`          |
| `(A, B, C)`      | `'a * 'b * 'c`       |
| `&[Value]`       | `'a array` (no copy) |
| `Vec<A>`, `&[A]` | `'a array`           |
| `BTreeMap<A, B>` | `('a, 'b) list`      |
| `LinkedList<A>`  | `'a list`            |

NOTE: Even though `&[Value]` is specifically marked as no copy, any type like `Option<Value>` would also qualify since the inner value is not converted to a Rust type. However, `Option<String>` will do full unmarshaling into Rust types. Another thing to note: `FromValue` for `str` and `&[u8]` is zero-copy, however `IntoValue` for `str` and `&[u8]` creates a new value - this is necessary to ensure the string is registered with the OCaml runtime.

If you're concerned with minimizing allocations/conversions you should use `Value` type directly.

#### Pointers to Rust values on the OCaml heap

`Pointer<T>` can be used to create and access Rust types on the OCaml heap.

For example, for a type that implements `Custom`:

```rust
use ocaml::FromValue;

struct MyType;

unsafe extern "C" fn mytype_finalizer(v: ocaml::Raw) {
    let ptr = v.as_pointer::<MyType>();
    ptr.drop_in_place()
}

ocaml::custom_finalize!(MyType, mytype_finalizer);

#[ocaml::func]
pub fn new_my_type() -> ocaml::Pointer<MyType> {
    ocaml::Pointer::alloc_custom(gc, MyType)
    // ocaml::Pointer::alloc_final(gc, MyType, finalizer, None) can also be used
    // if you don't intend to implement `Custom`
}

#[ocaml::func]
pub fn my_type_example(t: ocaml::Pointer<MyType>) {
    let my_type = t.as_mut();
    // MyType has no fields, but normally you
    // would do something with MyType here
}
```

#### Custom exception type

When a Rust `panic` or `Err` is encountered it will be raised as a `Failure` on the OCaml side, to configure a custom exception type you can register it with the OCaml runtime using the name `Rust_exception`:

```ocaml
exception Rust

let () = Callback.register_exception "Rust_error" (Rust "")
```

It must take a single `string` argument.

## Upgrading

Since 0.10 and later have a much different API compared to earlier version, here is are some major differences that should be considered when upgrading:

- `FromValue` and `IntoValue` have been marked `unsafe` because converting OCaml values to Rust and back also depends on the OCaml type signature.
  * A possible solution to this would be a `cbindgen` like tool that generates the correct OCaml types from the Rust code
- `IntoValue` now takes ownership of the value being converted
- The `caml!` macro has been rewritten as a procedural macro called `ocaml::func`, which performs automatic type conversion
  * `ocaml::native_func` and `ocaml::bytecode_func` were also added to create functions at a slightly lower level
  * `derive` feature required
- Added `derive` implementations for `IntoValue` and `FromValue` for stucts and enums
  * `derive` feature required
- `i32` and `u32` now map to OCaml's `int32` type rather than the `int` type
  * Use `ocaml::Int`/`ocaml::Uint` to refer to the OCaml's `int` types now
- `Array` and `List` now take generic types
- Strings are converted to `str` or `String`, rather than using the `Str` type
- Tuples are converted to Rust tuples (up to 20 items), rather than using the `Tuple` type
- The `core` module has been renamed to `sys` and is now just an alias for the `ocaml-sys` crate and all sub-module have been removed
