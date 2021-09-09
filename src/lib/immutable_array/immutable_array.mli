type 'a t

val of_array : 'a array -> 'a t

val get : 'a t -> int -> 'a

val to_list : 'a t -> 'a list
