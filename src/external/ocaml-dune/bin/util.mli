open Stdune
open Dune

val check_path : Context.t list -> Path.t -> unit

val find_root : unit -> string * string list
