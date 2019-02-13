## Summary

We describe ways to version modules containing types with serialized
representations.

## Motivation

Within the Coda codebase, modules contain (ideally) one main type. As
the software evolves, that type can change.  When compiling, the OCaml
type discipline enforces consistent use of such types. Sometimes we'd
like to export representations of those types, perhaps by persisting
them, or by sending them to other software. Such other software
may be written in languages other than OCaml.

## Detailed design

There are three main serialized representations of data used in the
Coda codebase: `bin_io`, `sexp`, and `yojson`. The readers and writers
of those representations are typically created using the `derive`
annotation on types.

### Explicit versioning

The `bin_io` representation and associated `bin_prot` library are
claimed to be type-safe when used in OCaml (see 
[Jane Street bin\_prot](https://github.com/janestreet/bin_prot/).
Moreover, other programming languages don't appear to be able to
produce or consume this representation. Therefore, type and versioning
information need not be stated explicitly in this
representation. Nonetheless, it is still important to use versioning,
so that a type of a particular name always has the same
representation.

Many programming languages can produce and consume the `sexp` and
`yojson` representations. Given an OCaml type, the derived
writers for those representation do not mention the type or
a version. So non-OCaml consumers of these representations
cannot easily detect the type distinctions in OCaml that gave
rise to the representations.

When a new version of a type is created, it can be worthwhile
to retain the older version and associated code. That allows
producing and consuming representations for older versions of the software.

Suppose we create a module with a name and a version:

```ocaml
module Some_data = struct

  let name = "some_data"

  module Stable = struct

    module V1 = struct

      let version = 1

      module T = struct
        type t = ... [@@deriving bin_io,sexp,yojson]
      end

      module Versioned = struct

        type t =
          { name : string
          ; version : int
          ; t : T.t
          } [@@deriving bin_io,sexp,yojson]

        let create t =
          { name
          ; version
          ; t
          }

        let to_yojson (t : T.t) =
          yojson_of_t @@ create t

        (* similarly for binio, sexp *)

      end
    end
  end
end
```

Putting the name and version in the type `Versioned.t` means they'll be
in the `sexp` and `yojson` representations, allowing any software to
detect type version changes.

Note that the definition of `Versioned` is boilerplate, and could be
generated with an OCaml ppx.

A new version of the module `V2` consists of a new version number,
a new submodule `T`, and the same boilerplate. A ppx could
take the version number and submodule to produce the complete
module definition. Perhaps it would also take the list of
serializations needed (often just one or two are needed), as
well as other `deriving` items.

It could be useful to transform data from an older version to a newer
version. Such a transformer could be included as a ppx argument.

### Serialization restricted to Stable, versioned modules

Serialization should be allowed only for modules following
this discipline, including the use of the `Stable` submodule
containing versions.

An exception can be carved out for using `sexp` serialization of data
from modules without `Stable` and versioning. That kind of
serialization is useful for logging and other printing from within
Coda, and is less likely to be used with other software.

### Coordination with RPC versioning

RFC 0012 indicates how to version types used with the Jane Street
RPC mechanism. The types specified in versioned modules here can
also be used in the query, response, and message types used for
RPC. In that case, if a new version of a module is created, the
RPC version should be updated at the same time.

### Embracing this discipline

As of this writing, there are over 600 type definitions with `deriving
bin_io` in the Coda codebase, even more with `sexp`. Only about 60
type definitions are versioned using the `Stable.Vn` naming discipline
(and without the explicit version information suggested here). To
embrace this discipline fully will take some effort.

We can make awareness of the existing recommendation, or the extended
discipline suggested here a checklist item for Github pull requests.

A ppx to implement the extended discipline will make it easier to comply
with the standard.

### Syntax for ppx

A use of the ppx might look like:

```ocaml
[@@versioned_module
  (`Version 1
  ,`Type (int * string),
  ,`Deriving [bin_io;sexp;yojson;eq]
  )
]
```
The ppx would generate the `Version` module, as above. That module would not
contain any special code for `eq` or other non-serialization `deriving` items,
other than to mention them in a `deriving` annotation.

## Drawbacks

We may not need the versioning for `sexp` and `yojson`, if these representations
are not, in fact, used by other software.

## Rationale and alternatives

The main choice is between versioning and not versioning. If we don't
use versioning, given a representation, it becomes unclear what type
it's associated with.

We could extend the discipline here to string representations, though
those are not automatically derivable.

## Prior art

The file `docs/style-guide.md` mentions versioning of stable module types.
