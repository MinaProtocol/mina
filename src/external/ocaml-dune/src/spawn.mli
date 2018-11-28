(** Subset of https://github.com/janestreet/spawn/blob/master/src/spawn.mli *)

module Env : sig
  type t

  val of_array : string array -> t
end

val spawn
  :  ?env:Env.t
  -> prog:string
  -> argv:string list
  -> ?stdin:Unix.file_descr
  -> ?stdout:Unix.file_descr
  -> ?stderr:Unix.file_descr
  -> unit
  -> int
