ppx_version
===========

The `ppx_version` preprocessor comprises a type deriver, an annotation
for modules, and a syntax linter.

Type deriver
------------

This deriver is meant to be added automatically when using the
%%versioned annotation for `Stable` modules (see below). That code is in
versioned_module.ml

*** You should not need to add this deriver to the `deriving` list explicitly ***

The deriver accomplishes these goals:

 1) check that a versioned type is always in valid module hierarchy
 2) versioned types depend only on other versioned types or OCaml built-in types

The usage in type declarations is:

  [@@deriving version]

  or

  [@@deriving version { option }]

where the option is one of "rpc" or "binable" (mutally
exclusively). For types within signatures, no options are used.

Within structures, the deriver generates two definitions:

   let version = n
   let __versioned__ = ()

where `n` is taken from the surrounding module Vn.

Within signatures, the deriver generates the definition:

   val __versioned__ : unit

The purpose of `__versioned__` is to make sure that types referred to
in versioned type definitions are themselves versioned.

Without options (the common case), the type must be named "t", and its
definition occurs in the module hierarchy "Stable.Vn" or
"Stable.Vn.T", where n is a positive integer.

The "binable" option asserts that the type is versioned, to allow
compilation to proceed. The types referred to in the type are not
checked for versioning with this option. It assumes that the type will
be serialized using a "Binable.Of_..." or "Make_binable" functors,
which relies on the serialization of some other type.

If "rpc" is true, again, the type must be named "query", "response",
or "msg", and the type definition occurs in the hierarchy "Vn.T".

Versioned modules
-----------------

Modules in structures with versioned types are annotated:

  [%%versioned
    module Stable = struct
      module Vn = struct
        type t = ...
      end
     ...
  end]

Within a `Stable` module, there can be arbitrarily many versioned type
modules, which must be listed in descending numeric order (most recent
version first).

Modules in signatures are annotated similarly (note the colon):

  [%%versioned:
    module Stable : sig
      module Vn : sig
        type t = ...
      end
     ...
  end]

The annotation generates a deriver list for the type that includes
`bin_io` and `version`, which are added to any other deriver items
already listed

Just past the most recent Vn, a definition is generated:

  module Latest = Vn

A type definition is generated just past the `Stable` module:

  type t = Stable.Latest.t

Sometimes that causes compilation issues, which can be avoided by
adding the annotation `[@@@no_toplevel_latest_type]` at the start of
the `Stable` module, in either structures or signatures.

For compatibility with older code, there is the annotation:

  [@@@with_all_version_tags]

Given at the start of a `Vn` module, generates a module
Vn.With_all_version_tags`, where the `Bin_prot` functions add the
version number as an integer at the start of the serialization of this
type, and similarly for all versioned types referred to by this type
(which means those referred-to types must also have that
annotation). That mimics the way all types were serialized in the
original Mina mainnet. The representation of some values, like public
keys, rely on the `Bin_prot` serialization, so this annotation is
required in order to maintain that representation.

A related annotation is:

  [@@@with_top_version_tag]

Given at the start of a `Stable` module, generates for each contained
module `Vn`, another module `Vn.With_top_version_tag`, where the
`Bin_prot` serialization adds the version number at the start of the
type serialization, but does not change the serialization of
referred-to types. That's useful to know which version the remainder
of the serialization is for. For example, a transaction id is the
Base64 encoding of the `Bin_prot` serialization of a command.
Therefore, the transaction id contains the information about the
transaction type version used to create it.

or JSON serialization:

  [@@@with_versioned_json]

When given at the start of a `Stable` module, for each module `Vn`, if
the `yojson` deriver is used in `Vn.t`, then `Vn.to_yojson` generates:

 `Assoc [("version",`Int n); ("data",<the yojson serialization of `t`>)]

For example, use this version-tagged JSON for precomputed and
extensional blocks to know which version of the code produced them.

Syntax linter
-------------

The linter finds invalid syntax related to type versioning.

The lint rules:

- "deriving bin_io" and "deriving version" never appear in types
   defined inside functor bodies, except for the `Make_str` functors
   used for wire types.

- otherwise, "bin_io" may appear in a "deriving" attribute only if
  "version" also appears in that extension

- versioned types only appear in versioned type definitions

- versioned type definitions appear only in %%versioned... extensions

- packaged modules, like "(module Foo)", may not be stable-versioned
  (but allowed inside %%versioned for legitimate uses)

- the constructs "include Stable.Latest" and "include Stable.Vn" are prohibited

 - uses of Binable.Of... and Bin_prot.Utils.Make_binable functors are
   always in stable-versioned modules, and always as an argument to
   "include"

- these restrictions are not enforced in inline tests and inline test modules
