# organize src/lib

===

# Goal

1. Organize libraries from the `src/lib` folder into subfolders.

## What problems does it solve?

### 1 - Separation of concerns (copied from the `Mina and Ocaml` google doc)

> The Mina codebase uses a “flat” hierarchy, resulting in an extremely large number of subdirectories. The src/lib directory alone contains 183 subdirectories. This is excessive, and could be eased with a stratified architecture that segments the codebase into components, separated by concern. This would also make it possible to organize commits by component, making the review process far more effective, as modifications to each component could be reviewed separately by contributors familiar with individual components. This would also facilitate more effective code ownership, and make it easier to make improvements in stages, by operating on only a few components at a time. Separation of concerns would also make testing each component much more effective, as they could be tested in isolation from other components.
> 
>  This would also make it possible to organize commits by component, making the review process far more effective, as modifications to each component could be reviewed separately by contributors familiar with individual components. This would also facilitate more effective code ownership, and make it easier to make improvements in stages, by operating on only a few components at a time. Separation of concerns would also make testing each component much more effective, as they could be tested in isolation from other components.

### 2 - Documentation
It would be easier, especially as a newcomer to understand the structure of the project.
  - We could have a `README.md` file describing the various folders
  - We could generate readable dependency graphs.
    - Using different colors for different folders.
    - Focusing on some subsets of folders. For instance, in the graphs below I ignored the `"utils"` libraries (which are usually small and non application specific).
	They are numerous so this simplifies the graphs quite a bit if we are not interested in them.

	- We could also generate a graph of dependencies between folders which gives an overview of the underlying dependencies.
	
# Design

I made a first attempt at defining some groups, but my knowledge of the project is still limited so I would like some feedback on this.

In order to minimize merge conflict, moving the libraries to various subfolders can be done iteratively. And we could start by the things we are most confident about.

At the moment, I would start with:

- The `utils` folder: these libraries are quite easy to identify and moving them to a `utils` folder would unclutter the `src/lib` directory quite a bit.

- The `crypto` folder (at least the libraries which were part of [this PR](https://github.com/MinaProtocol/mina/pull/9540)), and I see that this was already started in the
`feature/group-lookups-mina` branch.

## First attempt at grouping


I tried to create meaningful groups and to not have to many edges in the following graph of [dependencies between groups](./res/reorganize_src_lib/class_graph.png) (which is still a bit complex).

- The section below contains some information about the groups.
- In the following dependency graphs, the libraries are colored according to their respective groups. The first one is the most readable (but contains less information) because it does not contain the `Utils` and `Logging` groups, and was run through the `tred` tool, which removes a lot of edges while preserving reachability.

    - [without utils and logging - treded](./res/reorganize_src_lib/no_utils_tred.png)
    - [without utils and logging](./res/reorganize_src_lib/no_utils.png)
    - [all libraries - treded](./res/reorganize_src_lib/all_libs_tred.png)
    - [all libraries](./res/reorganize_src_lib/all_libs.png)

- The exact groups can also be found in the [library_group.md](./res/reorganize_src_lib/library_groups.md) file.



### Current Groups

- `Others`: Libraries that could stay at the toplevel, as their own group, or that I am not sure about.
For instance the `mina_base` library that contains a lot a files and will maybe be split in the future.

- `Utils`: Non application specific and usually small libraries. Most of the time leaves of the dependency graph.

- `Logging`: Libraries related to logging that everyone can depend on (even the `Utils` one).

- `Testing`: This folder would would contain two types of testing libraries:
    - High level calls to tests such as `command_line_tests`.
    - Test related utils such as `quickcheck_lib` (The difference with the `Utils` folder is that these would be allowed to depend on other application specific libraries).

  The other folders could also contain a `testing` subfolder for specific test related libraries (for instance the `mina_net2_tests` would be in the `Network` group).
    

- `Processes`: Libraries related to parallelism and inter process communication,
   such as `child_processes` and `pipe_lib`.

- `Network`: Libraries related to network communication between the various component.

- `Config`: Libraries such as `mina_numbers` defining primitive types used by most other groups.

- `Crypto`:
  Creating the `crypto` folder was already attempted in [this PR](https://github.com/MinaProtocol/mina/pull/9540) that I used as a reference.
  Would it make sense to split it between the libraries that depend on the `Config` group,
  and those that do not ?

- `Snarky`: The libraries from the snarky git submodule.

- `Transition`: Modules related to the handling of transitions
(many of which have the `transition_` prefix).

- The other name should be self descriptive. I am not very confident about those but I tried to respect clusters in the dependency graph :
  `Consensus`, `Staged_ledger`, `Genesis_ledger`, `Rosetta` and `Caching`.


## Inter folder dependencies

If some dependencies seem strange in the above graph of [dependencies between groups](./res/reorganize_src_lib/class_graph.png):

- maybe a library should be moved to another group.
- or there may be some refactoring to do in order to remove these dependencies.

### Potential unnecessary dependencies 
Using this graph I may have found some unnecessary dependencies (which are already "fixed" in the above graphs).

- The `rc_pool` library depends on `snark_params`: can it just be removed from the dune file ?
- The `snark_worker` library depends on `cli_lib` which seem necessary to access the  `Transaction_snark_work` module. Could it depend directly on the `transaction_snark_work` library instead?

### Automatic checks

Once some folders are created, It would be possible to add automatic checks to forbid some unwanted dependencies.

For instance at the moment, modules from the `Utils` library would only be able to depend on other modules from `Utils` and on modules from `Logging`.

## Libraries that nobody depends on.

There seem to be some libraries that nobody depends on, for instance `sha256_lib`, `time_simulator` and `distributed_dsl`.

Are these really unused? Maybe there could be an automatic check as well to warn when this happens?
