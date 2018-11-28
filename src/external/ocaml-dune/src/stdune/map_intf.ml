module type S = sig
  type key
  and (+'a) t
  val empty     : 'a t
  val is_empty  : 'a t -> bool
  val mem       : 'a t -> key -> bool
  val add       : 'a t -> key -> 'a -> 'a t
  val update    : 'a t -> key -> f:('a option -> 'a option) -> 'a t
  val singleton : key -> 'a -> 'a t
  val remove    : 'a t -> key -> 'a t
  val add_multi : 'a list t -> key -> 'a -> 'a list t

  val merge
    :  'a t
    -> 'b t
    -> f:(key -> 'a option -> 'b option -> 'c option)
    -> 'c t
  val union
    :  'a t
    -> 'a t
    -> f:(key -> 'a -> 'a -> 'a option)
    -> 'a t

  (** [superpose a b] is [b] augmented with bindings of [a] that are
      not in [b]. *)
  val superpose : 'a t -> 'a t -> 'a t

  val compare : 'a t -> 'a t -> compare:('a -> 'a -> Ordering.t) -> Ordering.t
  val equal   : 'a t -> 'a t -> equal:('a -> 'a -> bool) -> bool

  val iter  : 'a t -> f:(       'a -> unit) -> unit
  val iteri : 'a t -> f:(key -> 'a -> unit) -> unit
  val fold
    :  'a t
    -> init:'b
    -> f:('a -> 'b -> 'b)
    -> 'b
  val foldi
    :  'a t
    -> init:'b
    -> f:(key -> 'a -> 'b -> 'b)
    -> 'b

  val for_all    : 'a t -> f:(       'a -> bool) -> bool
  val for_alli   : 'a t -> f:(key -> 'a -> bool) -> bool
  val exists     : 'a t -> f:(       'a -> bool) -> bool
  val existsi    : 'a t -> f:(key -> 'a -> bool) -> bool
  val filter     : 'a t -> f:(       'a -> bool) -> 'a t
  val filteri    : 'a t -> f:(key -> 'a -> bool) -> 'a t
  val partition  : 'a t -> f:(       'a -> bool) -> 'a t * 'a t
  val partitioni : 'a t -> f:(key -> 'a -> bool) -> 'a t * 'a t

  val cardinal  : 'a t -> int

  val to_list : 'a t -> (key * 'a) list
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t
  val of_list_map
    :  'a list
    -> f:('a -> key * 'b)
    -> ('b t, key * 'a * 'a) Result.t
  val of_list_exn : (key * 'a) list -> 'a t

  val of_list_multi  : (key * 'a) list -> 'a list t
  val of_list_reduce : (key * 'a) list -> f:('a -> 'a -> 'a) -> 'a t

  val keys   : 'a t -> key list
  val values : 'a t -> 'a list

  val min_binding : 'a t -> (key * 'a) option
  val max_binding : 'a t -> (key * 'a) option
  val choose      : 'a t -> (key * 'a) option

  val split: 'a t -> key -> 'a t * 'a option * 'a t
  val find : 'a t -> key -> 'a option

  val map  : 'a t -> f:(       'a -> 'b) -> 'b t
  val mapi : 'a t -> f:(key -> 'a -> 'b) -> 'b t

  val filter_map  : 'a t -> f:(       'a -> 'b option) -> 'b t
  val filter_mapi : 'a t -> f:(key -> 'a -> 'b option) -> 'b t
end
