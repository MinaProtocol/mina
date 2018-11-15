open! Stdune
(** Error reporting *)

(** Captures the backtrace and report an error.

    Because dune doesn't stop at the first error, it might end up
    reporting the same error twice about missing libraries for
    instance. To avoid this, we keep a cache of reported errors and
    ignore errors that have already been reported.

    We cache what is actually printed to the screen.  *)
val report : exn -> unit

type printer

val make_printer :
  ?backtrace:bool ->
  ?hint:string ->
  ?loc:Loc.t ->
  (Format.formatter -> unit) ->
  printer

val set_loc : printer -> loc:Loc.t -> printer

val set_hint : printer -> hint:string -> printer

(** Register an error printer. *)
val register : (exn -> printer option) -> unit

(** Find an error printer *)
val find_printer : exn -> printer option

(**/**)

(** Used internally at Jane Street.
  See https://github.com/ocaml/dune/pull/1368 *)
val map_fname : (string -> string) ref
