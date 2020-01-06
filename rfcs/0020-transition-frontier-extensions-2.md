## Summary
[summary]: #summary

The RFC proposes a new design for Transition Frontier Extensions (previously known as the Transition Frontier Listener). The design in code has changed drastically as newer development needs arose. This RFC intends to improve upon the current design by consolidating concerns and providing a stricter guideline to what should and should not be an extension.

## Motivation
[motivation]: #motivation

Transition Frontier Extensions, as they are right now in the code, are fairly messy. There are multiple representations of what a Transition Frontier Diff is, some extensions exist only to resurface diff information, and extensions are not provided some necessary information at initialization. New rules/guidelines are necessary for determining what should and should not be an extension, as well as what the scope of extensions should be.

## Prior art
[prior-art]: #prior-art

See [#1585](https://github.com/CodaProtocol/coda/pull/1585) for early discussions about Transition Frontier Extensions (then referred to as the Transition Frontier Listener).

## Detailed design
[detailed-design]: #detailed-design

### Direct List of Modification

- pass Transition Frontier root into Extension's `initial_view` function
- remove Root\_diff extension
- remove New\_root diff
- replace diffs to micro-diffs w/ mutant types
- remove persistence diffs (and just use micro-diffs)
- rewrite Transition Frontier to use micro-diff pattern internally for representing mutations
- add a diff pipe for tests

### Extensions Redefined

A Transition Frontier Extension is an stateful, incremental view on the state of a Transiton Frontier. When a Transition Frontier is initialized, all of its extensions are also initialized using the Transition Frontier's root. Every mutation performed is represented as a list of diffs, and when the Transition Frontier updates, each Extension is notified of this list of diffs synchronously. Transition Frontier Extensions will notify the Transition Frontier if there was a update to the Extension's view when handling the diffs. If an Extension's view is updated, then a synchronous event is broadcast internally with the new view of that Extension. A Transition Frontier Extension has access to the Transition Frontier so that it can query and calculate information it requires when it handles diffs.

### Extension Guidelines

An extension's only input should be Transition Frontier Diffs. An extension should only be used if there is some incrementally computable view of information on top of the Transition Frontier that cannot be queried in with reasonable computational complexity on the fly. As an example, an extension which just provides the best tip is useless since the best tip can just be queried in O(1) time from the underlying Transition Frontier. An example of what makes a good extension, however, is tracking information such as the set of removed/added breadcrumbs from the best tip. With the exception of the Persistence Buffer Extension, Transiton Frontier Extensions should not resurface diffs they receives as that would be considered an abstraction leak. Diffs should (ideally) only be surfaced as part of tests. As part of this RFC, the Root\_diff extension will be removed as this extension violates this last rule, causing a leak of diff information.

### New Transition Frontier Micro-diffs

Transition Frontier Diffs will now be represented as smaller, composable micro-diffs rather than monolithic diffs like before. The primary advantage of this is composability, however it also helps to unify diffs with persistent diffs, allowing us to more easily implement the incremental hash computation in transition frontier and removes a layer of translation between diff formats. It also more easily allows us to defer extra computation into the Transition Frontier Extensions themselves by keeping the individual diffs light. Below is an psuedo-code implementation of the new micro-diffs.

```ocaml
type 'mutant diff =
  | Breadcrumb_added : Breadcrumb.t -> {added: Breadcrumb.t; parent: Breadcrumb.t} diff
  | Root_transitioned : {new: State_hash.t; garbage: Breadcrumb.t list} -> {previous: Root.t; new: Root.t; garbage: Breadcrumb.t list} diff
  | Best_tip_changed : State_hash.t -> {previous: Breadcrumb.t; new: Breadcrumb.t} diff
```

Using these micro diffs, the Transition Frontier will return a list of diffs for every mutation. For instance, it is possible for the Transition Frontier to just have one diff `[Breadcrumb_added ...]`, or it could have upwards of three diffs `[Breadcrumb_added ...; Root_transitioned ...; Best_tip_changed ...]`.

NOTE: The New\_root diff is no longer necessary as Transition Frontier roots are now provided to Extensions at initialization.

### In-Code Documentation and Notices

As part of this RFC, we will add some documentation comments to the code related to Extensions describing the guidelines for adding new extensions and what the concerns of an extension should be. This will mostly just be regurgating information from the section in here laying out those guidelines.

### Implementation Details

In order to break a dependency cycle between the Transition Frontier and its Extensions, the Transition Frontier will be split up into a base implementation and a final wrapper that glues the base implementation together with the Extensions. The base Transition Frontier will include nearly all of the Transition Frontier data structure internals (Breadcrumbs, Nodes, queries), but it will not include the final full function for adding breadcrumbs to the tree. Instead, it will provide two key functions that are part of adding breadcrumbs with the following signature:

```ocaml
(* [Diff.E.t] is the existential wrapper for a ['a Diff.t] *)
val calculate_diffs : t -> Breadcrumb.t -> Diff.E.t list
val process_diff : type mutant. t -> mutant Diff.t -> mutant
```

Extensions can then be defined using this base module. Then the final module can glue everything together, as shown in this psuedo-code:

```ocaml
module Extension = struct
  module type S = sig
    ...
  end

  let update (module Ext : S) t diffs =
    let opt_deferred =
      let open Deferred.Option.Let_syntax in
      let%bind view = Ext.handle_diffs t diffs in
      Ext.broadcast t view
    in
    Deferred.map opt_deferred ignore
end

module Extensions = struct
  type t =
    { snark_pool_refcount: Extension.Snark_pool_refcount
    ; ... }
  [@@deriving fields]

  let update_all t diffs =
    fold t
      ~snark_pool_refcount:(Extension.update (module Extension.Snark_pool_refcount))
      ...
end

let add_breadcrumb t breadcrumb =
  let diffs = calculate_diffs breadcrumb in
  t.incremental_hash <-
    List.fold_left diffs ~init:t.incremental_hash ~f:(fun hash (Diff.E.T diff) ->
      Incremental_hash.hash hash (process_diff t diff));
  Extensions.update_all t.extensions diffs
```
