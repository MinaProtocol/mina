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

The rules are up to change, but we propose the following very basic rule as a first step, which only defines when an `open` should be completely removed.

**Remove** an `open` if:
- it is used 5 times or fewer in its scope

**Except** if either:
- the opened module is one of "Base", "Core" or "Core_kernel"
- it is used to import operators
- it is only used to import other modules (library layering)
- its scope does not exceed 40 lines (roughly a screen)

### Detection and enforcement

This RFC relies on a tool, [ocaml-close](https://github.com/tweag/ocaml-close) (being built for the sake of this RFC) that can analyze and enforce open rules. This tool would be added as a dependency and installed in the mina switch.

`ocaml-close` itself relies on a `.ocamlclose` file that must be at the root of the project and encodes the aforementionned rules. For example, the above rules are encoded as a lisp-like rule:

```scheme
((root)
 (rules
   ((keep
      (or ((in-list ("Base" "Core" "Core_kernel"))
           exports-syntax
           exports-modules-only
           (<= scope-lines 40))))
    (remove (<= uses 5)))
 (precedence (keep remove)))
```

This makes the rules easily modifiable in the future, along with the evolution of the tool and the consensus of the team, and we propose that future changes of rules can be made with simple pull requests rather than new RFCs. The current rules can always be gathered by consulting the `.ocamlclose` file.

### Integration into the development pipeline

We propose that the tool is run with the aforementioned rules **as a pre-commit hook**, only on files that are about to be committed. This allows for an incremental removal of problematic `open`s instead of blocking development (even with the very narrow rules exposed above, almost a hundred of problematic `open`s are detected in the whole code base).

The tool will block the commit if problems are found, and suggest modifications.
It is then up to the developer to automatically apply the suggested patches, manually fix the problem or override the tool's decision by white-listing the modules.

White-listing a module can be done by either modifying the global rule or dropping a new `.ocamlclose` encoding the white-listing. The module will thus only be white-listed in the directory and subdirectories of the new file, without affecting the global rules. Since it is encoded in the file-system, the white-listing can then be debated during a code review. 

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
