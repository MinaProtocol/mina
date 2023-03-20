# OCaml bindings for Kimchi

To call the [Kimchi](https://github.com/o1-labs/proof-systems) library from OCaml we need to generate bindings. 
These bindings are written in Rust with the help of two libraries: 

* [OCaml-rs](https://github.com/zshipko/ocaml-rs) to facilitate exporting a Rust library to a static library that can be used from within OCaml. Insead of exporting code directly to a C interface, it makes use of the OCaml runtime directly and can also store values and custom types on the OCaml heap.
* [ocaml-gen](https://github.com/o1-labs/proof-systems) to generate the necessary OCaml code. This library is used in [`src/main.rs`](./src/main.rs).

The bindings are generated automatically via the [`dune`](./dune) file's rule and [promoted](https://dune.readthedocs.io/en/stable/dune-files.html#promote) to this directory.

If you want to generate the OCaml binding manually, you can run the command dune's running yourself (which will print them in the terminal):

```shell
$ cargo run
```

## Some OCaml-rs guidelines

### Exposing types

There are two ways of dealing with types:

1. let OCaml handle your types: use the `ocaml::ToValue` and `ocaml::FromValue` traits to let OCaml convert your types into OCaml types.
2. Make your types opaque to OCaml: use [custom types](https://ocaml.org/manual/intfc.html#s:c-custom) to store opaque blocks within the OCaml heap. There's the [`ocaml::custom!`](https://docs.rs/ocaml/0.22.0/ocaml/macro.custom.html) macro to help you with that.

A good rule of thum: always use custom types unless you need to be able to access the fields of your type in OCaml. 
If you don't need access to all of the fields, consider implementing and exposing getters on a custom type instead of exposing your whole type.

There's one more extra consideration: opaque types store values on the Rust heap.
This won't let the OCaml garbage collector efficiently manage the space they take.
Storing values on the OCaml heap is often a good idea when performance issues are detected. 
That is, unless the values are long-lived (like an SRS or a prover index) or would be very inefficient on the OCaml heap (like a `Vec<_>` where we need to use `emplace_back`).

### How to think about custom types

Whenever you expose a custom type to the OCaml side, the OCaml side won't be able to create itself.
For this reason, a custom type is always associated to some other Rust functions that can create the type (and use it).

When creating a custom type, the value will be stored in the Rust heap, but a pointer of it will be stored in the OCaml heap (typical for OCaml).

The Rust value is copied or cloned only if the Rust functions exposed take a value as argument. If they take a reference, or the pointer direct (`ocaml::Pointer<T>`) then they can mutate the value in place.

For this reason, it can be useful to think of custom types as being passed as Rust-like mutable references everywhere, as the OCaml side has no way to know if the Rust side will mutate them or not.

It is only by looking at the implementations of the Rust functions exposed to the OCaml side that you can know in which case the Rust value will be mutated.

### Edge case: foreign types

Because of Rust's [*orphan rule*](https://github.com/Ixrec/rust-orphan-rules), you can't implement the `ToValue` and `FromValue` traits on foreign types. This means that you'll have to use the second option anytime you're dealing with foreign types, by wrapping them into a local type and using `custom!`.  (This is what we do with the arkworks types, for example)

### The ToValue and FromValue traits

Ocaml-rs exposes two traits to communicate to and from Ocaml: [ToValue and FromValue](https://github.com/zshipko/ocaml-rs/blob/f300f2f382a694a6cc51dc14a9b3f849191580f0/src/value.rs#L55:L73).

```rust
pub unsafe trait IntoValue {
    fn into_value(self, rt: &Runtime) -> Value;
}
pub unsafe trait FromValue<'a> {
    fn from_value(v: Value) -> Self;
}
```

These traits are implemented for all primitive Rust types ([here](https://github.com/zshipko/ocaml-rs/blob/f300f2f382a694a6cc51dc14a9b3f849191580f0/src/conv.rs)), and can be derived automatically via [derive macros](https://docs.rs/ocaml/0.22.0/ocaml/#derives). (Very much like serde.)

### Debugging

Don't forget that you can use [cargo expand](https://github.com/dtolnay/cargo-expand) to expand macros, which is really useful to understand what the ocaml-rs macros are doing.

```
$ cargo expand -- some_filename_without_rs > expanded.rs
```

In general, you will want to return a `Result<Value, ocaml::Error>` from your functions, and use the `?` operator to propagate errors.

Note that returning a `Result` will not return a `result` type in OCaml, but instead raise an exception.
Still, you will get better error messages on the OCaml side than if you were to use `unwrap` everywhere (I'm actually not sure why).
If this doesn't seem like a good-enough reason to return `Result` in your exposed functions already, note that the next version of OCaml-rs will make it possible to return `result` types in OCaml.

### Custom types

The macro [custom!](https://github.com/zshipko/ocaml-rs/blob/f300f2f382a694a6cc51dc14a9b3f849191580f0/src/custom.rs) allows you to quickly create custom types.

Values of custom types are opaque to OCaml. They are used to store the data of some Rust value on the OCaml heap. When this data may contain pointers to the Rust heap, or other data that requires a call to 'drop' in rust, you must provide a 'finalizer' for OCaml to call into to correctly drop these values. Best practice is to always provide such a finalizer, even if it's a no-op.

Here is how custom types are transformed into OCaml values:

```rust
unsafe impl<T: 'static + Custom> IntoValue for T {
    fn into_value(self, rt: &Runtime) -> Value {
        let val: crate::Pointer<T> = Pointer::alloc_custom(self);
        val.into_value(rt)
    }
}
```

which eventually is a call to `caml_alloc_custom`:

```rust
/// Allocate custom value
pub unsafe fn alloc_custom<T: crate::Custom>() -> Value {
    let size = core::mem::size_of::<T>();
    Value::new(sys::caml_alloc_custom(
        T::ops() as *const _ as *const sys::custom_operations,
        size,
        T::USED,
        T::MAX,
    ))
}
```

and the data of your type (probably a pointer to some Rust memory) is copied into the OCaml's heap ([source](https://github.com/zshipko/ocaml-rs/blob/f300f2f382a694a6cc51dc14a9b3f849191580f0/src/types.rs#L80)):

```rust
pub fn set(&mut self, x: T) {
    unsafe {
        core::ptr::write_unaligned(self.as_mut_ptr(), x);
    }
}
```

### A note on generic custom types

Note that the generated bindings do not allow you to differentiate the same custom type used in different context.

If you want to differentiate custom types, differentiate the Rust types first.

For example, if you have a generic custom type that must be converted to different OCaml types depending on the concrete parameter used, you will have to instead create non-generic custom types

### Helper macros

* the [impl_shared_ref!](src/caml/shared_reference.rs) macro for a thread-safe shared reference
* the [impl_shared_rwlock!](src/caml/shared_rwlock.rs) macro for a thread-safe shared mutable object.

### Conventions

* To ease eye'ing at FFI code, we use the `Caml` prefix whenever we're dealing with types that will be converted to OCaml. This allows to quickly read a function's signature and see that there are only types that support `ocaml::FromValue` and `ocaml::ToValue`. You can then implement the `From` trait to the non-ocaml types for facilitating back-and-forth conversions.
* You must not include any value from the OCaml heap within a custom type, otherwise you are likely to cause OCaml heap corruption and an eventual segfault.
* You should implement a `drop_in_place` finalizer for all custom types. Better be safe than sorry. (TODO: lint on this? or mandate this upstream)
* If a custom type is large, you can use a `Box` to only store a pointer (pointing to the Rust heap) in the OCaml heap. The OCaml heap is not well-suited to handling large opaque data.
* The priority is to keep small, potentially short-lived data on the heap so we don't fragment the rust heap and so that it gets free'd appropriately quickly.
* Since OCaml does not have fixed-sized arrays, we usually convert any arrays (`[T; N]`) into tuples (`(T, T, T, ...)`)
* Do not use `unwrap()` and other functions that can panic in the stubs. Instead return a `Result<_, ocaml::Error>` with a string literal (e.g. `Err(ocaml::Error::Message("my error"))`). This will get you much better errors on the OCaml side. If you want to add dynamic information you'll have to print it on the Rust side before returning the error (I haven't found a better way, `ocaml::Error` seems to only expect string literals).
