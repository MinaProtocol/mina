open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type ('a, 'h) t = ('a, 'h) Mina_wire_types.With_hash.V1.t =
      { data : 'a; hash : 'h }
    [@@deriving annot, sexp, equal, compare, hash, yojson, fields]

    val to_latest : ('a -> 'b) -> ('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t
  end
end]

type ('a, 'h) t = ('a, 'h) Stable.Latest.t = { data : 'a; hash : 'h }
[@@deriving annot, compare, equal, fields, hash, sexp, yojson]

val map : ('a, 'b) t -> f:('a -> 'c) -> ('c, 'b) t

val map_hash : ('a, 'b) t -> f:('b -> 'c) -> ('a, 'c) t

val of_data : 'a -> hash_data:('a -> 'b) -> ('a, 'b) t

(** Set for [('a, 'h) t] that assumes the hash ['h] is cryptographically sound, and data is ignored
*)
module Set (Hash : Comparable.S) :
  Mina_stdlib.Generic_set.S1 with type 'a el := ('a, Hash.t) t
