module type S = sig
  type elt
  and t

  val empty          : t
  val is_empty       : t -> bool
  val mem            : t -> elt -> bool
  val add            : t -> elt -> t
  val singleton      : elt -> t
  val remove         : t -> elt -> t
  val union          : t -> t -> t
  val inter          : t -> t -> t
  val diff           : t -> t -> t
  val compare        : t -> t -> Ordering.t
  val equal          : t -> t -> bool
  val is_subset      : t -> of_:t -> bool
  val iter           : t -> f:(elt -> unit) -> unit
  val map            : t -> f:(elt -> elt) -> t
  val fold           : t -> init:'a -> f:(elt -> 'a -> 'a) -> 'a
  val for_all        : t -> f:(elt -> bool) -> bool
  val exists         : t -> f:(elt -> bool) -> bool
  val filter         : t -> f:(elt -> bool) -> t
  val partition      : t -> f:(elt -> bool) -> t * t
  val cardinal       : t -> int
  val min_elt        : t -> elt option
  val max_elt        : t -> elt option
  val choose         : t -> elt option
  val split          : t -> elt -> t * bool * t
  val of_list        : elt list -> t
  val to_list        : t -> elt list
end
