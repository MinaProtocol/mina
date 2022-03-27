module type Hash_intf = sig
  type t

  val merge : height:int -> t -> t -> t
end

val merge_hash : (module Hash_intf with type t = 'hash) -> int -> 'hash -> 'hash

val cache :
     (module Hash_intf with type t = 'a)
  -> init_hash:'a
  -> int
  -> 'a Immutable_array.t

val extensible_cache :
  (module Hash_intf with type t = 'a) -> init_hash:'a -> int -> 'a
