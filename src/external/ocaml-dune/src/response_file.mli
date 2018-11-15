(** Response file support *)

open Stdune

type t =
  | Not_supported
  | Zero_terminated_strings of string
  (** The argument is the command line flag, such as "-args0" *)

(** Return whether [prog] supports a response file or not *)
val get : prog:Path.t -> t

(** Registers the fact that [prog] supports a response file *)
val set : prog:Path.t -> t -> unit
