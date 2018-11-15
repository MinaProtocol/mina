(** Command line flags *)

(** Print dependency path in case of error *)
val debug_dep_path : bool ref

(** Debug the findlib implementation *)
val debug_findlib : bool ref

(** The command line for "Hint: try: dune external-lib-deps ..." *)
val external_lib_deps_hint : string list ref

(** Capture the output of sub-commands *)
val capture_outputs : bool ref

(** Always print backtraces, to help debugging dune itself *)
val debug_backtraces : bool ref

(** Command to use to diff things *)
val diff_command : string option ref

(** Automatically promote files *)
val auto_promote : bool ref

(** Force re-running actions associated to aliases *)
val force : bool ref

(** Instead of terminating build after completion, watch for changes *)
val watch : bool ref
