# OCaml-gen

This crate provides automatic generation of OCaml bindings.
Refer to the rustdoc for more information.

## Example

Here's an example of generating some bindings. Create a `main.rs` as:

```rust
use ocaml_gen::prelude::*;

// Some Rust code you have:

#[derive(ocaml::FromValue, ocaml::IntoValue, ocaml_gen::CustomType)]
pub struct SomeType {
  pub a: u8,
}

#[ocaml_gen::func]
#[ocaml::func]
fn create_some_type() -> SomeType {
  SomeType { a: 42 }
}

fn main() {
  // initialize your environment
  let env = &mut Env::default();

  // choose where you want to write the bindings
  let w = &mut std::io::stdout();

  // you can declare modules
  decl_module!(w, env, "Types", {
      // and types
      decl_type!(w, env, SomeType => "t");
  });

  decl_module!(w, env, "Functions", {
      // and functions
      decl_func!(w, env, create_some_type => "create");
  });
}
```

Note that the underlying function imported by `decl_func!` is actually `caml_of_numeral_to_ocaml`, which is created by the annotated macro `ocaml_gen::func`.
So either your function is in scope, or you import everything (e.g. `use path::*`), or you import the derived function directly (e.g. `use path::caml_of_numeral_to_ocaml`).

The OCaml bindings generated should look like this:

```ocaml,ignore
module Types = struct
  type nonrec t
end

module Functions = struct
  val create : unit -> Types.t
end
```

## Usage

In general, you can use this library by following these steps:

1. annotate your types and functions with [`ocaml-rs`](https://github.com/zshipko/ocaml-rs) and `ocaml_gen` macros.
2. create a `main.rs` file to generate your binding file `bindings.ml` as shown above.
3. use the [`ocaml-rs`](https://github.com/zshipko/ocaml-rs) crate to export the static library that OCaml will use.
4. add a `dune` file to your crate to build the Rust static library as well as the OCaml bindings. (protip: use `(mode promote)` in the dune file to have the resulting binding file live within the folder.)
5. optionally enforce in CI that the promoted binding file is correct.

You can see an example of these steps in the [test/](test/) folder. (Although we don't "promote" the file with dune for testing purposes.)

### Annotations

To allow ocaml-gen to understand how to generate OCaml bindings from your types and functions, you must annotate them using ocaml-gen's macros.

To allow generation of bindings on structs, use [`ocaml_gen::Struct`](https://o1-labs.github.io/ocaml-gen/ocaml_gen/derive.Struct.html):

```rust,ignore
#[ocaml_gen::Struct]
struct MyType {
  // ...
}
```

To allow generation of bindings on enums, use [`ocaml_gen::Enum`](https://o1-labs.github.io/ocaml-gen/ocaml_gen/derive.Enum.html):

```rust,ignore
#[ocaml_gen::Enum]
enum MyType {
  // ...
}
```

To allow generation of bindings on functions, use [`ocaml_gen::func`](https://o1-labs.github.io/ocaml-gen/ocaml_gen/attr.func.html):

```rust,ignore
#[ocaml_gen::func]
#[ocaml::func] // if you use the crate ocaml-rs' macro, it must appear after
pub fn your_function(arg1: String) {
  //...
}
```

To allow generation of bindings on custom types, use [`ocaml_gen::CustomType`](https://o1-labs.github.io/ocaml-gen/ocaml_gen/derive.CustomType.html):

```rust,ignore
#[ocaml_gen::CustomType]
struct MyCustomType {
  // ...
}
```

### Binding generations

To generate bindings, you must create a `main.rs` file that uses the `ocaml_gen` crate functions to layout what the bindings `.ml` file will look like.
The first thing to do is to import the types and functions you want to generate bindings for, as well as the `ocaml_gen` macros:

```rust,ignore
use ocaml_gen::prelude::*;
use your_crate::*;
```

You can then use `decl_module!` to declare modules:

```rust,ignore
  let env = &mut Env::default();
  let w = &mut std::io::stdout();

  decl_module!(w, env, "T1", {
      decl_module!(w, env, "T2", {
        decl_type!(w, env, SomeType);
      });
  });

  decl_module!(w, env, "T3", {
    decl_type!(w, env, SomeOtherType);
  });
```

You can rename types and functions by simply adding an arrow:

```rust,ignore
decl_type!(w, env, SomeType => "t");
```

You can also declare generic types by first declaring the generic type parameters (that you must reuse for all generic types):

```rust,ignore
decl_fake_generic!(T1, 0); // danger:
decl_fake_generic!(T2, 1); // make sure you
decl_fake_generic!(T3, 2); // increment these correctly

decl_type!(w, env, TypeWithOneGenericType<T1>);
decl_type!(w, env, ThisOneHasTwo<T1, T2>);
decl_type!(w, env, ThisOneHasThreeOfThem<T1, T2, T3>);
```

You can also create type aliases with the [`decl_type_alias!`](https://o1-labs.github.io/ocaml-gen/ocaml_gen/macro.decl_type_alias.html) macro but it is **highly experimental**.
It has a number of issues:

* the alias doesn't work outside of the module it is declared current scope (which is usually what you want)
* the alias is ignoring the instantiation of type parameters. This means that it might rename `Thing<usize>` to `t1`, eventhough `t1` was an alias to `Thing<String>` (this is the main danger, see [this tracking issue](https://github.com/o1-labs/ocaml-gen/issues/4))
* it won't work (binding generation will throw an error) if you try to alias two instantiations of the same generic type (for example, `t1` is the alias of `Thing<usize>` and `t2` is the alias of `Thing<String>`)
