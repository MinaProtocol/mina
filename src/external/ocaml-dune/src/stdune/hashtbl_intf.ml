module type S = sig
  include MoreLabels.Hashtbl.S

  val add : 'a t -> key -> 'a -> unit

  val find : 'a t -> key -> 'a option
  val find_or_add : 'a t -> key -> f:(key -> 'a) -> 'a

  val fold : 'a t -> init:'b -> f:('a -> 'b -> 'b) -> 'b
  val foldi : 'a t -> init:'b -> f:(key -> 'a -> 'b -> 'b) -> 'b

  val of_list_exn : (key * 'a) list -> 'a t
end
