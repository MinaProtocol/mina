(** Exceptions *)

(** An programming error, that should be reported upstream. The error message
    shouldn't try to be developer friendly rather than user friendly. *)
exception Code_error of Sexp.t


(* CR-soon diml:
   - Rename to [User_error]
   - change the [string] argument to [Loc.t option * string] and get rid of
   [Loc.Error]. The two are a bit confusing
   - change [string] to [Colors.Style.t Lib_name.t]
*)
(** A fatal error, that should be reported to the user in a nice way *)
exception Fatal_error of string

exception Loc_error of Loc.t * string

val fatalf
  :  ?loc:Loc.t
  -> ('a, unit, string, string, string, 'b) format6
  -> 'a

val code_error : string -> (string * Sexp.t) list -> _

type t = exn

external raise         : exn -> _ = "%raise"
external raise_notrace : exn -> _ = "%raise_notrace"
external reraise       : exn -> _ = "%reraise"

val protect : f:(unit -> 'a) -> finally:(unit -> unit) -> 'a
val protectx : 'a -> f:('a -> 'b) -> finally:('a -> unit) -> 'b

val raise_with_backtrace: exn -> Printexc.raw_backtrace -> _
