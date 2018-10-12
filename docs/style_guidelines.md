# Style Guidelines

## Ocaml
[ocaml]: #ocaml

### General
[ocaml-general]: #ocaml-general

Our style guidelines are an extension of a couple of existing style guidelines. The first is ocamlformat, and it acts as the source of truth for most of our coding style. In fact, ocamlformat is a blocker on CI, so your code must be formated by it's guidelines in order to be merged into master. Ocamlformat does not handle all important cases of style, however, as it is only defining and enforcing how code should be spaced out and indented. For anything which ocamlformat does not cover, the [janestreet styleguide](https://opensource.janestreet.com/standards/) should be referenced. This styleguide we define here is intended to be an extension of the janestreet styleguide, with more attention to detail in concern to a few specific constructs we use regularly throughout our codebase.

### Mli Files
[ocaml-mli]: #ocaml-mli

A `*.mli` file should not be included for a `*.ml` file iff the `*.ml` file's automatically derived interface is different. Many `*.ml` files in our codebase consist of only signatures and a functor. In the case of those files, there is not purpose to redefining the `*.mli` file because there is no new or restricted information in that file. If a `*.ml` file contains implementations in the root structure, then a `*.mli` file should most likely be created.

### Modules
[ocaml-modules]: #ocaml-modules

#### Prefer Standardized Shortnames

The names `t`, `T`, and `S` are common shortnames used in modules to signify specific things.

The name `t` is used to represent the root type of a module. For instance, if there is a module `Account` which contains types and values related to accounts, then `Account.t` is the type of an account. The name `t` can also be used as a value iff there is only intended to be one value of the root type of the module. As an example, if you wanted to have a single global logger in a `Logger` module, the type `Logger.t` could be the type of a logger, and the value `Logger.t` could be the global logger value of type `Logger.t`.

The module name `T` is used to encapsulate the root type and basic definitions regarding a root type of a module. It is a common practice used when you want to instantiate some functors for a module's root type and have the instantiations appear in the module itself. As an example, it is common to call the `Comparable.Make` functor in order to derive various helper values/modules from a comparable type. In this case, if we had a module `Account` again, and we wanted to derive the `Comparable.S` signature, then we would define a module `T` in `Account` which defines a root type `t` and the required functions for the `Comparable.Make` functor argument (in this case, `compare`). With this `T` module, we can then `include T` and `include Comparable.Make (T)` in the `Account` module to bring in all related values/modules for the `Account.t` type. Here is a full example of that:

```
module Account = struct
  module T = struct
    type t = ... [@@deriving compare]
  end

  include T
  include Comparable.Make (T)
end
```

The module type name `S` is used for defining the root signature of a module. This is most commonly used when you have a module which contains a functor. In this case, we typically call the functor `Make` and declare the functor returns the type `S`, putting both of these values in the same module. Looking back at our previous example, `Core_kernel`'s `Comparable` module follows this pattern: `Comparable.Make` is a functor which returns a `Comparable.S`.

#### Prefer One Type Per Module
[ocaml-modules-singleton-types]: #ocaml-modules-singleton-types

As a general rule of thumb, each module should be scoped to a single type. This pattern helps isolate concerns and, in turn, allows value names to be shorter, as they are located by context. Take, for example, a `Merkle_tree` module. This module will need a type `Merkle_tree.t` which represents the entire merkle tree (or a node of it). A `Merkle_tree` will also want to have a `path` type. It is preferable to place this `path` type into it's own nested module (`Merkle_tree.Path.t` instead of `Merkle_tree.path`). To help understand why this is preferable, imagine we did put path in `Merkle_tree.path`. Now, `Merkle_tree` contains values (functions) that relate not only to the merkle tree type itself, but also the a path of a merkle tree. For clarity, it would be natural to prepend all of the value names related to a path with `path_` (`path_map`, `path_length`, etc...). By isolating `Path` to it's own module, we can shorten these names while keep the context of values clear. Additionally, if we choose to in the future, we may encapsulate the implementation details of `Path` by applying a restrictive signature to it, which would make the separation of concerns more clear via compiler enforcement.

#### No Monkeypatching
[ocaml-modules-monkeypatching]: #ocaml-modules-monkeypatching

Monkeypatching of modules is explicity disallowed in our codebase. Monkeypatching is defined as the act of taking an existing module and redefining it with extended or modified values. More simply, it's anything of the form.

```
module A = struct
  module M = struct
    let x = ...
  end
end

module M = struct
  include A.M
  let y = ...
  (* or `let x = ...` *)
end
```

Monkeypatching may be the easiest path to getting code to compile sometimes, but in general, it creates confusion and/or technical debt in the codebase. If you need to monkeypatch a module, you should have a good reason as to why.

#### Functor Signature Equalities
[ocaml-modules-functor-patterns]: #ocaml-modules-functor-patterns

Signature `with` statements for signatures of modules generated by functors should be limited to the form `S with module M1 = M2` whenever possible. Replacement equalities `:=` should be limited to `include` statements where portions of the signature need to be limited (for example, when a nested module in the signature is already defined at the current structure scope). The form `S with type t = ...` is also not preferred as it scales poorly as the number of common dependencies between signatures involved with a functor increases. Note that this places increased importance on the janestreet styleguide rule "Prefer standard signature includes to hand-written interfaces".

#### Functor Arity
[ocaml-modules-functor-arity]: #ocaml-modules-functor-arity

Functor can have a maximum arity of 3 (arity is the number of arguments; in this case, the number of nested functors - functors returning functors). If a functor requires more than 3 modules as arguments, then the required modules should all be nested into one module. The standard pattern for this is to define a signature `Inputs_intf` for your functor, which will, in turn, define the module arguments to the functor. See below for a simple example.

```
module type Inputs_intf = sig
  module A : A.S
  module B : B.S
  module C : C.S
  module D : D.S
end

module type S = sig
  include Inputs_intf

  (* ... *)
end

module Make (Inputs : Inputs_intf)
  : S
    with module A = Inputs.A
     and module B = Inputs.B
     and module C = Inputs.C
     and module D = Inputs.D =
struct
  open Inputs

  (* ... *)
end
```
