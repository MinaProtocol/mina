open Core_kernel

include module type of Result

module List : sig
  val map : 'a list -> f:('a -> ('b, 'e) result) -> ('b list, 'e) result
end
