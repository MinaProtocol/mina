(** Helpers shared by the alcotest suites of the two Rosetta CLIs.

    Both suites do the same thing: spawn the binary, capture what it
    printed, and assert on it.  Sharing the spawning and the assertions
    keeps the guard in {!assert_no_ocaml_exn_leak} -- the regression both
    suites exist for -- from drifting between two copies. *)

(** [exe_beside_test name] is the binary [name] sitting next to the
    directory the test executable was built into.  Resolved relative to
    [Sys.get_argv ().(0)] so it survives dune's sandboxing, wherever
    dune chooses to [chdir] to. *)
val exe_beside_test : string -> string

(** [run_cli ~bin ?env args] runs [bin] and returns
    [(exit_code, stdout, stderr)].  A signalled child reports
    [128 + signal], as a shell would.

    Both pipes are drained concurrently and the child's stdin is closed:
    reading one to EOF and only then the other deadlocks as soon as a
    child writes more than a pipe buffer to the one not being read,
    which any test of a subcommand that reports progress on stderr would
    do. *)
val run_cli :
     bin:string
  -> ?env:(string * string) list
  -> string list
  -> int * string * string

(** [assert_no_ocaml_exn_leak label s] fails the test if [s] contains
    raw OCaml exception syntax.  Both CLIs promise never to print it,
    and the leak that prompted the promise -- [Unix_error] reaching
    stderr on ECONNREFUSED -- is what these needles look for. *)
val assert_no_ocaml_exn_leak : string -> string -> unit

(** [contains s ~sub] is substring containment, optionally ignoring
    case. *)
val contains : ?case_insensitive:bool -> string -> sub:string -> bool

(** [check_contains ~label s ~sub] fails the test, quoting [s], when
    [sub] is absent. *)
val check_contains : label:string -> string -> sub:string -> unit
