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

When a new version of a type is created, it can be worthwhile to
retain the older version and associated code. That allows producing
and consuming representations for older versions of the software.  We
can also take older representations to produce a value of the type
associated with the latest version of a module.

Here is a proposed discipline for creating a module with a name and a version:

```ocaml
module Some_data = struct

  module Stable = struct

    module V1 = struct

      let version = 1

      type t = ... [@@deriving bin_io,...]

      type latest = t

      let to_latest = Fn.id
    end

    module Latest = V1

    module Module_decl = struct
      let name = "some_data"
      type latest = Latest.t
    end

    module Registrar = Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
    module Registered_Latest = Registered_V1

end
```

Registered modules produce representations that contain version numbers.
The `Registrar` module maintains a set of registered modules, indexed
by version numbers. A `Registrar` can take the representation produced
by a registered module, and produce a value of the type for the latest
module version, using the `to_latest` function in the registered module.

Example:
```ocaml
  let buf = Bin_prot.Common.create_buf some_size in
  ignore (Registered_Vn.bin_write_t ~pos:0 buf);
  match Registrar.deserialize_binary_opt buf with
   | None -> failwith "shouldn't happen"
   | Some _v -> printf "got latest version of some_Vn_value"
```

A new module version `V2` consists of a new version number,
a new type, which is also the type `latest`, and the function
`to_latest`.

So we'd have:

```ocaml
module Some_data = struct

  module Stable = struct

    module V2 = struct

      let version = 2

      type t = ... [@@deriving bin_io,...]

      type latest = t

      let to_latest = Fn.id
    end

    module Latest = V2 (* changed, was V1 *)

    module V1 = struct

      let version = 1

      type t = ... [@@deriving bin_io,...]

      type latest = Latest.t (* changed, was t *)

      let to_latest = ...    (* changed, was Fn.id *)
    end

    module Module_decl = struct
      let name = "some_data"
      type latest = Latest.t
    end

    module Registrar = Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
    module Registered_V2 = Registrar.Register (V2) (* new *)
    module Registered_Latest = Registered_V2       (* changed, was Registered_V1 *)
```

Clients of a versioned module should always use the `Registered_Latest`
version.

A ppx to produce a versioned module could take the version number and
a list of serializations needed (often just one or two are needed),
as well as other `deriving` items, and definitions for `latest` and
`to_latest`. There could be a separate ppx for the latest module
version, since `latest` and `to_latest` are already known in that case.
Yet another ppx could be used for the registrations.

### Serialization restricted to Stable, versioned modules

Serialization should be allowed only for modules following
this discipline, including the use of the `Stable` submodule
containing versioned modules.

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

The file `docs/style-guide.md` mentions versioning of stable module
types.

PR #1645, already merged, partially implements the registration
mechanism described here.  That implementation deals only with the
`bin_io` representation, not `yojson` or `sexp`.

PR #1633 added a checklist item for versioned modules to the PR
template.
