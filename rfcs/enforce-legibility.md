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

; An 'open <X>' statement is...
(rules

  ; - left untouched if...
  (keep
    ; ...either it is allow-listed, ...
    (or (in-list ("Base" "Core" "Core_kernel" "Async" "Async_kernel" "Mina_base"
                  "Import" "Currency" "Signature_lib" "Unsigned"))
        ; ...it is used for infix operators, ...
        exports-syntax
        ; ...it is only for its exposed submodules, ...
        exports-modules-only
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
         (>= uses 15)
         ; ... it only exports direct symbols, not from submodules, and...
         (not exports-subvalues)
         ; ... it does not exports types (avoid using ppx_import).
         (not exports-types)))

  ; - removed and replaced by local 'let open <X> in's if...
  ;   ... it is used only by only a few functions.
  (local (<= functions 4))

  ; - moved closer to its first actual use if...
  ;   ... it is too far from that optimal placement.
  (move (>= dist-to-optimal 40)))
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
ocamlclose lint -p fixes file1.ml file2.ml # Prints a set of recommendations, saved in a 'fixes' file
ocamlclose patch -ic fixes                 # Modifies the original file in place, checking they can still build
```

Here are some use cases for each rule.

### Remove

Some open statements are just not used enough to justify their existence. For example, the file `src/lib/work_selector/work_lib.ml` contains an `open Currency` which is just used once. `ocaml-close` yields the following patch:

```diff
 open Core_kernel
-open Currency
 open Async
 
 module Make (Inputs : Intf.Inputs_intf) = struct
@@ -123,7 +122,7 @@
       (Inputs.Snark_pool.get_completed_work snark_pool statements)
       ~f:(fun priced_proof ->
         let competing_fee = Inputs.Transaction_snark_work.fee priced_proof in
-        Fee.compare fee competing_fee < 0)
+        Currency.Fee.compare fee competing_fee < 0)
 
   module For_tests = struct
     let does_not_have_better_fee = does_not_have_better_fee
```

### Structure

When a global statement is used a lot but only for a referring to a few different symbols from the opened module, we can make this set of symbols explicit by using a structured open. For example, in file `src/lib/pickles_types/hlist.ml`, we obtain:

```diff
 open Core_kernel
-open Poly_types
+open struct
+  open Poly_types
+  module type T4 = T4
+  module type T3 = T3
+  module type T2 = T2
+  module type T0 = T0
+  module type T1 = T1
+end
+
 
 module E13 (T : T1) = struct
   type ('a, _, _) t = 'a T.t
```

Note that currently, the `structure` rule does not match if one of the symbols is a type, even though it would be very useful (often a module is opened only for its single type `t`). This is because opening a type alias does not export the constructures or fields of the original type. Hence in the structured open, we would have to explicitly copy the whole definition of the original type, which would arguably defeat the legibility purpose. Another possibility is the usage of `ppx_import` or `ppx_open`. However this would add new ppxs in the Mina codebase (staged ppxs even, which slow down the compilation since they need access to type information), which would again go against legibility.

### Local

Some open statements are heavily used, but their usage is concentrated in only a few functions. In this case, we can remove the global open and add a few local opens in these functions instead. For example in `src/lib/transition_frontier/persistent_frontier/persistent_frontier.ml`, we can transform two different opens:

```diff
 open Async_kernel
 open Core
 open Mina_base
-open Mina_state
 open Mina_transition
-open Frontier_base
 module Database = Database
 
 exception Invalid_genesis_state_hash of External_transition.Validated.t
@@ -11,6 +9,8 @@
 let construct_staged_ledger_at_root
     ~(precomputed_values : Precomputed_values.t) ~root_ledger ~root_transition
     ~root ~protocol_states ~logger =
+  let open Frontier_base in
+  let open Mina_state in
   let open Deferred.Or_error.Let_syntax in
   let open Root_data.Minimal in
   let snarked_ledger_hash =
@@ -162,6 +162,7 @@
 
   let fast_forward t target_root :
       (unit, [> `Failure of string | `Bootstrap_required]) Result.t =
+    let open Frontier_base in
     let open Root_identifier.Stable.Latest in
     let open Result.Let_syntax in
     let%bind () = assert_no_sync t in
@@ -185,6 +186,8 @@
   let load_full_frontier t ~root_ledger ~consensus_local_state ~max_length
       ~ignore_consensus_local_state ~precomputed_values
       ~persistent_root_instance =
+    let open Frontier_base in
+    let open Mina_state in
     let open Deferred.Result.Let_syntax in
     let downgrade_transition transition genesis_state_hash :
         ( External_transition.Almost_validated.t
@@ -344,6 +347,7 @@
   x
 
 let reset_database_exn t ~root_data ~genesis_state_hash =
+  let open Frontier_base in
   let open Root_data.Limited in
   let open Deferred.Let_syntax in
   let root_transition = transition root_data in
```

### Moving

The open statements are often all grouped at the beginning of the file. Sometimes, this is very far from the point of their first actual use, or the even in a scope that is too global compared to its real use. In some of these case, it makes sense to move it. For example in file `src/lib/network_pool/transaction_pool.ml` (a very large file), we can move two open statements hundres of line away so that their scope is narrower.

```diff
@@ -7,8 +7,6 @@
 open Async
 open Mina_base
 open Pipe_lib
-open Signature_lib
-open Network_peer
 
 let max_per_15_seconds = 10
 
@@ -197,6 +195,7 @@
 
 (* Functor over user command, base ledger and transaction validator for
    mocking. *)
+open Network_peer
 module Make0
     (Base_ledger : Intf.Base_ledger_intf) (Staged_ledger : sig
       type t
@@ -1468,6 +1467,7 @@
             ~conf_dir:None
             ~pids:(Child_processes.Termination.create_pid_table ()))
 
+    open Signature_lib
     module Mock_transition_frontier = struct
       module Breadcrumb = struct
         type t = Mock_staged_ledger.t
```

Moving opens away from the beginning of the file can be risky since it makes the rest of the code more dependent on the order of declaration. This can be mitigated by moving open statements to the beginning of their smallest necessary scope (for example a submodule) rather than to their first usage point.

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
