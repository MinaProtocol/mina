(** Setup of dune *)

(** These parameters are set by [ocaml configure.ml] or copied from
    [setup.defaults.ml]. During bootstrap, values from [setup.boot.ml]
    are used *)

(** Where to find installed libraries for the default context. If
    [None], auto-detect it using standard tools such as [ocamlfind]. *)
val library_path : string list option

(** Where to install libraries for the default context. *)
val library_destdir : string option
