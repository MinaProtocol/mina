type 'a t

val create : max_size:int -> 'a t

val push : 'a t -> length:Coda_numbers.Length.t -> data:'a -> unit

val find : 'a t -> Coda_numbers.Length.t -> 'a option

val find_exn : 'a t -> Coda_numbers.Length.t -> 'a
