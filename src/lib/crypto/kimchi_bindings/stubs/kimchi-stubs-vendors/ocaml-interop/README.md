# ocaml-interop

![build](https://github.com/tezedge/ocaml-interop/workflows/build/badge.svg)
[![crate](https://img.shields.io/crates/v/ocaml-interop.svg)](https://crates.io/crates/ocaml-interop)
[![documentation](https://docs.rs/ocaml-interop/badge.svg)](https://docs.rs/ocaml-interop)
[![license](https://img.shields.io/crates/l/ocaml-interop.svg)](https://github.com/tezedge/ocaml-interop/blob/master/LICENSE)

_Zinc-iron alloy coating is used in parts that need very good corrosion protection._

**API IS CONSIDERED UNSTABLE AT THE MOMENT AND IS LIKELY TO CHANGE IN THE FUTURE**

[ocaml-interop](https://github.com/tezedge/ocaml-interop) is an OCaml<->Rust FFI with an emphasis on safety inspired by [caml-oxide](https://github.com/stedolan/caml-oxide), [ocaml-rs](https://github.com/zshipko/ocaml-rs) and [CAMLroot](https://arxiv.org/abs/1812.04905).

Read the full documentation [here](https://docs.rs/ocaml-interop/).

Report issues on [Github](https://github.com/tezedge/ocaml-interop/issues).

## A quick taste

### Convert between plain OCaml and Rust values

```rust
let rust_string = ocaml_string.to_rust();
// `cr` = OCaml runtime handle
let new_ocaml_string = rust_string.to_ocaml(cr);
```

### Convert between Rust and OCaml structs/records

```ocaml
(* OCaml *)
type my_record = {
  string_field: string;
  tuple_field: (string * int);
}
```

```rust
// Rust
struct MyStruct {
    string_field: String,
    tuple_field: (String, i64),
}

impl_conv_ocaml_record! {
    MyStruct {
        string_field: String,
        tuple_field: (String, i64),
    }
}

// ...

let rust_struct = ocaml_record.to_rust();
let new_ocaml_record = rust_struct.to_ocaml(cr);
```

### Convert between OCaml and Rust variants/enums

```ocaml
(* OCaml *)
type my_variant =
  | EmptyTag
  | TagWithInt of int
```

```rust
// Rust
enum MyEnum {
    EmptyTag,
    TagWithInt(i64),
}

impl_conv_ocaml_variant! {
    MyEnum {
        EmptyTag,
        TagWithInt(OCamlInt),
    }
}

// ...

let rust_enum = ocaml_variant.to_rust();
let new_ocaml_variant = rust_enum.to_ocaml(cr);
```

### Call OCaml functions from Rust

```ocaml
(* OCaml *)
Callback.register "ocaml_print_endline" print_endline
```

```rust
// Rust
ocaml! {
    fn ocaml_print_endline(s: String);
}

// ...

let ocaml_string = "hello OCaml!".to_boxroot(cr);
ocaml_print_endline(cr, &ocaml_string);
```

### Call Rust functions from OCaml

```rust
// Rust
ocaml_export! {
    pub fn twice_boxed_int(cr, num: OCamlRef<OCamlInt64>) -> OCaml<OCamlInt64> {
        let num = num.to_rust(cr);
        let result = num * 2;
        result.to_ocaml(cr)
    }
}
```

```ocaml
(* OCaml *)
external rust_twice_boxed_int: int64 -> int64 = "twice_boxed_int"

(* ... *)

let result = rust_twice_boxed_int 123L in
(* ... *)
```

## References and links

- OCaml Manual: [Chapter 20  Interfacing C with OCaml](https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html).
- [Safely Mixing OCaml and Rust](https://docs.google.com/viewer?a=v&pid=sites&srcid=ZGVmYXVsdGRvbWFpbnxtbHdvcmtzaG9wcGV8Z3g6NDNmNDlmNTcxMDk1YTRmNg) paper by Stephen Dolan.
- [Safely Mixing OCaml and Rust](https://www.youtube.com/watch?v=UXfcENNM_ts) talk by Stephen Dolan.
- [CAMLroot: revisiting the OCaml FFI](https://arxiv.org/abs/1812.04905).
- [caml-oxide](https://github.com/stedolan/caml-oxide), the code from that paper.
- [ocaml-rs](https://github.com/zshipko/ocaml-rs), another OCaml<->Rust FFI library.
- [ocaml-boxroot](https://gitlab.com/ocaml-rust/ocaml-boxroot)
