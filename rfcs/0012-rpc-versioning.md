## Summary

We propose a mechanism to allow updating the versions of remote procedure
calls (RPCs) between Coda protocol nodes.

## Motivation

Coda uses a remote procedure call (RPC) mechanism for nodes to query
other nodes, and to broadcast messages to the gossip network. As the
codebase evolves, the structure of those RPC messages may evolve, and
new kinds of messages may be added. Nodes running different versions
of the software need to be able to communicate.

When querying, the caller and callee nodes may be using different
versions of RPC calls. The caller can be running the newer version,
and the callee the older version, or vice-versa. Both scenarios have
to be accommodated.

## Detailed design

The Jane Street Async library contains a module `Versioned_rpc` with
the machinery to allow evolution of RPC call versions.

In the `coda_network` library, the `Versioned_rpc` library is used in
two ways, for queries and for broadcasting.

### Queries

For queries, the pattern is (simplifying somewhat):

```
  module Query = struct

    module T = struct
      let name = ...
      module T = struct
        type query = ...
        type response = ... option
      end
      module Caller = T
      module Callee = T
    end

    include Versioned_rpc.Both_convert.Plain.Make (T)

    module V1 = struct
      module T = struct
        type query = ...
        type response = ... option
        let version = 1
        let query_of_caller_model = Fn.id
        let callee_model_of_query = Fn.id
        let response_of_callee_model = Fn.id
        let caller_model_of_response = Fn.id
     end
     include Register (T)
   end

  end
```
The name identifies the particular RPC query.  Calling the functor
`Plain.Make` creates the other functor `Register` called within
`V1`. The module `T.T` offers types for a query and response, and in
this code, both the caller and callee agree on those types (they could
differ, in theory).

The four functions implemented here with `Fn.id`, the identity
function, are coercions between the query and response types in
`T.T` and `V1.T`. In the existing RPC queries, those types are
are the same, so we can use the identity function.

For a given query, if we wish to update the protocol, we'd add:

```
  module V2 = struct
    module T = struct
      type query = ...
      type response = ... option
      let version = 2
      let query_of_caller_model : T.Caller.query -> query = ...
      let callee_model_of_query : query -> T.Callee.query = ...
      let response_of_callee_model : T.Callee.response -> response = ...
      let caller_model_of_response : reponse -> T.Caller.response = ...
   end
   include Register (T)
 end
```
The types of the coercions are shown. For each coercion, the input and
output types could differ.

There could be additional new modules for subsequent versions. Eventually,
versions could be pruned from the code, to encourage nodes to upgrade their
software. When a new query version is created, the `Vn` module for the previous
version could have a field added:
```
  let remove_this_version_after = "20200702"
```
A year or so past the introduction of the new version might be a
suitable date for removing the previous version.

The query modules are used in a list of "implementations". To define
an implementation, we need a function of type:
```
  Host_and_port.t -> version:int -> T.Caller.query -> T.Callee.response option Deferred.t
```
which does the work within the node to respond to the query. The host
and port represent the "connection state" of the TCP connection
between the nodes, which is the host and ephemeral port of the
caller. The version passed is the caller's. In theory, these functions
could dispatch on the version. Instead, the version should be
considered informative, and the real accomodation between versions
should happen in the coercions. Therefore, the implementation
functions do not need to change between versions.

### Broadcasting

The RPC versioning mechanism for broadcasting is similar, except that instead of
query and response types, there is a "msg" type. The versioning module defines
coercions

```
  val msg_of_caller_model : Caller.msg -> msg
  val callee_model_of_msg : msg -> Callee.msg
```

In the `V1` module, those are both `Fn.id`. For a new version, we'd
create a new `Vn` module with a new version number and appropriate
coercions.  As for queries, we'd want to indicate a removal date for
earlier-version modules.

## Drawbacks

Nodes using a version implemented by a versioning module cannot communicate
with nodes where that module has been removed. That's a feature, really,
although perhaps a temporary inconvenience for nodes that haven't upgraded their
software.

## Prior art

The Jane Street version RPC library is already in the Coda codebase.

## Unresolved questions

The versioning mechanism described here has not been tested locally.
