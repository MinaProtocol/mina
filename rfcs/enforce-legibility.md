## Summary
[summary]: #summary

This RFC aims to introduce rules for limiting the usage of opens in OCaml code (`open Foo`) and automatically enforce these rules, using a dedicated tool.
The infrastructure for enforcing these styles rules would also give way to the introduction of other legibility rules in the future if there is a consensus.
For every such rule, the proposed infrastructure allows for an *incremental* process of compliance upgrade.

## Motivation
[motivation]: #motivation

Currently, for a newcomer to either the whole code base or one of its components,
it can be tedious to understand what is going on in the implementation of a feature. This can extend the development time of a new feature or facilitate the introduction of bugs if the code logic is not well understood.

One of the reason is the heavy use of `open`s which impedes the reader's ability to understand where a value is coming from when used. Developer tools such as `merlin` can help locating the origin of a value but it quickly becomes tedious to review the origin of every ambiguous value, wheras directly qualifying the value instead of opening its module would immediatly resolve the problem.

Of course, `open` is a useful tool and there are many cases where it makes sense to use it, such as for importing the infix operators of a module, or for library layering. This RFC aims to define simple, agreed on rules to determine when an `open` is problematic and either *remove* it (and re-qualify every imported value), *move* it closer to its usage, *transform* it into a local open or *restrain it* by explicitly expressing what symbols of the opened module are used in the source file.

## Detailed design
[detailed-design]: #detailed-design

### Rules

We propose a set of rules for flagging "bad" opens, encoded into a lisp-like configuration language, which can be understood and applied by the [ocaml-close](https://github.com/tweag/ocaml-close) tool (which is built for the sake of this RFC). This tool would be added as a dependency and installed in the mina switch.

The rules are up to change, but we propose the following set as a first step. They are to be put in a a `.ocamlclose` at the root of the project.
```scheme
(root) ; ocaml-close will not look for .ocamlclose files in parent directories

; Determines what is the considered the optimal placement of a global open.
; Either:
;   - 'pos':   the position before the first actual use of the open is optimal
;   - 'scope': the beginning of the smallest enclosing module of all the uses is
;              optimal
(placement scope)

; The order in which rules are matched
; (e.g., we keep opens matched by the 'keep' rule no matter the other rules)
(precedence (keep remove local structure move))

; List of opens that are never ever touched, considered "standard".
(standard ("Base" "Core" "Core_kernel" "Async" "Async_kernel" "Mina_base"
           "Import" "Currency" "Signature_lib" "Unsigned"))

; If there is only one non-standard open that should be modified, keep it,
; since there is no ambiguity
(single true)

; An 'open <X>' (where X is not in the allow-list) statement is...
(rules

  ; - left untouched if either...
  (keep
    (or ; ...it is used for infix operators, ...
        exports-syntax
        ; ...it is only for its exposed submodules, ...
        exports-subvalues-only
        ; ...or its scope is roughly a screen.
        (<= scope-lines 40)))

  ; - removed, and its uses re-qualified, if...
  ;   ... it is not used much and X is not too long and can be qualified easily.
  (remove (and (<= uses 5) (<= name-length 15) (not ghost-use)))

  ; - replaced by an explicit structured open, if...
  (structure
    ;   ... it exports few different identifiers, and...
    (and (<= symbols 5)
         ; ... it is used enough times, and...
         (>= uses 10)
         ; ... it only exports direct symbols, not from submodules, and...
         (not exports-subvalues)
         ; ... it does not exports types (avoid using ppx_import).
         (not exports-types)))

  ; - removed and replaced by local 'let open <X> in's if...
  ;   ... it is used only by only a few functions.
  (local (<= functions 4))

  ; - moved closer to its optimal position (see 'placement' parameter), if...
  ;   ... it is too far from that optimal placement, or after it.
  (move (and (>= dist-to-optimal 40) (not optimal-is-before))))
```

This makes the rules easily modifiable in the future, along with the evolution of the tool and the consensus of the team, and we propose that future changes of rules can be made with simple pull requests rather than new RFCs. The current rules can always be gathered by consulting the `.ocamlclose` file.

### Integration into the development pipeline

We propose that the tool is run with the aforementioned rules **as a pre-commit hook**, only on files that are about to be committed. This allows for an incremental removal of problematic `open`s instead of blocking development (with the rules exposed above, several hundreds of problematic `open`s are detected in the whole code base).

The tool will block the commit if problems are found, and suggest modifications.
It is then up to the developer to automatically apply the suggested patches, manually fix the problem or override the tool's decision by allow-listing the modules.

Allow-listing a module can be done by either modifying the global rule or dropping a new `.ocamlclose` encoding the allow-listing. The module will thus only be allow-listed in the directory and subdirectories of the new file, without affecting the global rules. Since it is encoded in the file-system, the allow-listing can then be debated during a code review. 

## Examples

The current above configuration contains rules for **removing** (`remove`), **narrowing** (`structure`), **localizing** (`local`) or **moving** (`move`) open statements. They are applied by running the following commands:

```bash
ocamlclose lint -p fixes      # Analyze the whole code base and print a set of recommendations, saved in a 'fixes' file
ocamlclose patch -ic fixes    # Modifies the original file in place, checking they can still build
```

The tool uses `.cmt` files and builds them if not already present. Since this can take some time, and a lot of files in the Mina code base do not build correctly, it can be worthwhile to do the following.

```bash
dune build @check                               # Build all buildable .cmt files
ocamlclose lint --skip-absent --silence-errors  # Analyze all files that could be built, ignore others
```

Here are some use cases for each rule.

### Remove

Some open statements are just not used enough to justify their existence. For example, the file `src/lib/gossip_net/any.ml` contains an `open Rpc_intf` which is just used once. `ocaml-close` yields the following patch:

```diff
@@ -21,7 +21,6 @@
 
 module Make (Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf) :
   S with module Rpc_intf := Rpc_intf = struct
-  open Rpc_intf
 
   module type Implementation_intf =
     Intf.Gossip_net_intf with module Rpc_intf := Rpc_intf
@@ -30,7 +29,7 @@
 
   type t = Any : 't implementation * 't -> t
 
-  type 't creator = rpc_handler list -> 't Deferred.t
+  type 't creator = Rpc_intf.rpc_handler list -> 't Deferred.t
 
   type creatable = Creatable : 't implementation * 't creator -> creatable
```

### Structure

When a global statement is used a lot but only for a referring to a few different symbols from the opened module, we can make this set of symbols explicit by using a structured open. For example, in file `src/lib/snarky/ppx/snarky_module.ml`, we open the `Location` to use a single of its values. Hence we can do:

```diff
@@ -1,5 +1,9 @@
 open Core_kernel
-open Location
+open struct
+  open Location
+  let raise_errorf = raise_errorf
+end
+
 open Ppxlib
 open Ast_helper
```

Note that currently, the `structure` rule does not match if one of the symbols is a type, even though it would be very useful (often a module is opened only for its single type `t`). This is because opening a type alias does not export the constructures or fields of the original type. Hence in the structured open, we would have to explicitly copy the whole definition of the original type, which would arguably defeat the legibility purpose. Another possibility is the usage of `ppx_import` or `ppx_open`. However this would add new ppxs in the Mina codebase (staged ppxs even, which slow down the compilation since they need access to type information), which would again go against legibility.

### Local

Some open statements are heavily used, but their usage is concentrated in only a few functions. In this case, we can remove the global open and add a few local opens in these functions instead. For example in `src/lib/mina_lib/mina_lib.ml`, we can transform two different opens:

```diff
@@ -4,9 +4,7 @@
 open Mina_base
 open Mina_transition
 open Pipe_lib
-open Strict_pipe
 open Signature_lib
-open O1trace
 open Otp_lib
 open Network_peer
 module Archive_client = Archive_client
@@ -413,6 +411,7 @@
 let create_sync_status_observer ~logger ~is_seed ~demo_mode ~net
     ~transition_frontier_and_catchup_signal_incr ~online_status_incr
     ~first_connection_incr ~first_message_incr =
+  let open O1trace in
   let open Mina_incremental.Status in
   let restart_delay = Time.Span.of_min 5. in
   let offline_shutdown_delay = Time.Span.of_min 25. in
@@ -763,6 +762,8 @@
  *     items from the identity extension with no route for termination
  *)
 let root_diff t =
+  let open O1trace in
+  let open Strict_pipe in
   let root_diff_reader, root_diff_writer =
     Strict_pipe.create ~name:"root diff"
       (Buffered (`Capacity 30, `Overflow Crash))
@@ -1273,6 +1274,8 @@
   able_to_send_or_wait ()
 
 let create ?wallets (config : Config.t) =
+  let open O1trace in
+  let open Strict_pipe in
   let catchup_mode = if config.super_catchup then `Super else `Normal in
   let constraint_constants = config.precomputed_values.constraint_constants in
   let consensus_constants = config.precomputed_values.consensus_constants in
```

### Moving

The open statements are often all grouped at the beginning of the file. Sometimes, this is very far from the point of their first actual use, or the even in a scope that is too global compared to its real use. In some of these case, it makes sense to move it. Moving opens away from the beginning of the file can be risky though since it makes the rest of the code more dependent on the order of declaration. This can be mitigated by moving open statements to the beginning of their smallest necessary scope (for example a submodule) rather than to their first usage point. Choosing between these two strategies is done with the `placement` parameter of the configuration.

For example in file `src/lib/snarky/src/base/typ.ml` (a large file), we can move an open statement in a submodule so that its scope is narrower.

```diff
@@ -1,5 +1,4 @@
 open Core_kernel
-open Types.Typ
 
 module Data_spec0 = struct
   (** A list of {!type:Type.Typ.t} values, describing the inputs to a checked
@@ -82,6 +81,7 @@
                   and type ('a, 's, 'f) t :=
                              ('a, 's, 'f) Checked.Types.As_prover.t) =
 struct
+  open Types.Typ
   type ('var, 'value, 'field) t =
     ('var, 'value, 'field, (unit, unit, 'field) Checked.t) Types.Typ.t
```

## Perspectives

This tool and general framework can be extended to perform various other analyses on the code, such as:

- ensuring that open statements do not shadow identifiers already in the scope, leading to potential dependency on the opening order
- detecting that there's a lot of unqualified names coming from multiple opens that are mixed within the same function, and suggesting to split the function
- computing various metrics about code quality, for example to encourage more documentation

## Drawbacks
[drawbacks]: #drawbacks

While the abundance of `open`s definitely does impact the legilibility of source code, this RFCs is not high-priority as it does not propose a new feature but a change to the development flow.
Concretely, it introduces a new step when committing, which can be frustrating for developers.
We argue that it should not be a problem as long as the analysis:
- is extremely fast
- provides a way to automatically and immediately apply suggested fixes
- provides a way to override the tool in case of false positives

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Other possibilities may be:
- *adding rules in the style guide, without automatic enforcement*: given the size of the Mina code base, fixing the legibility of the existing code by hand would be a huge undertaking, with a very low priority. I suspect it would never be done.
- *only suggesting fixes instead of blocking the commit*: this can be an option. However the risk is that the suggestions will become noise during the commit and are eventually always ignored.
- *moving the check in the CI*: it is my understanding that CI runs are already very long. Furthermore, problems detected by this analysis can be resolved by immediate developer input. Moving this step to the long CI process would imply multiple runs of the CI for a problem that would have been quick to detect and fix.
- *not doing anything*: the legibility of existing and future code would not improve. Furthermore, it would forgo an infrastructure that can be a first step towards implementing other legibility rules, or even safety rules that can prevent actual bugs.
