(** Represents list of filenames that can possibly be renamed by setting the
    [dst] field *)
open Stdune

type 'a file =
  { src : 'a
  ; dst : 'a option
  }

type 'a t = 'a file list

val dst_path : string file -> dir:Path.t -> Path.t
val src_path : string file -> dir:Path.t -> Path.t

val map : 'a t -> f:('a -> 'b) -> 'b t

val empty : 'a t

module Unexpanded : sig
  type nonrec t = String_with_vars.t t
  val decode : t Stanza.Decoder.t
end

val is_empty : _ t -> bool
