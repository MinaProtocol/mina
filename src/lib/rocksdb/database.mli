type uuid := Uuid.Stable.V1.t

type key := Bigstring.t

type data := Bigstring.t

type t = { uuid : uuid; db : (Rocks.t[@sexp.opaque]) } [@@deriving sexp]

type db := t

(** [create filename] creates a database contained in [filename]. 

    @param filename will be created if it does not exist
 *)
val create : string -> t

val get : t -> key:key -> data option

val get_batch : t -> keys:key list -> data option list

val set : t -> key:key -> data:data -> unit

(** Any key present both in [remove_keys] and [key_data_pairs] will be absent
    from the database. 

    @param remove_keys defaults to [[]]
*)
val set_batch :
  t -> ?remove_keys:key list -> key_data_pairs:(key * data) list -> unit

val remove : t -> key:key -> unit

val close : t -> unit

val to_alist : t -> (key * data) list

val make_checkpoint : t -> string -> unit

val create_checkpoint : t -> string -> t

val get_uuid : t -> uuid

module Batch : sig
  type t = Rocks.WriteBatch.t

  val remove : t -> key:key -> unit

  val set : t -> key:key -> data:data -> unit

  val with_batch : db -> f:(t -> 'a) -> 'a
end
