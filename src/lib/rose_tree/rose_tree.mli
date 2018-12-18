type 'a t = T of 'a * 'a t list

val of_list_exn : 'a list -> 'a t

val iter : 'a t -> f:('a -> unit) -> unit

val fold_map : 'a t -> init:'b -> f:('b -> 'a -> 'b) -> 'b t
