module type S = Hashtbl_intf.S

module Make(Key : Hashable.S) : S with type key = Key.t

type ('a, 'b) t = ('a, 'b) MoreLabels.Hashtbl.t

val hash : 'a -> int

val create : ?random:bool -> int -> ('a, 'b) t

val reset : ('a, 'b) t -> unit

val remove : ('a, _) t -> 'a -> unit

val length : (_, _) t -> int

val iter : ('a, 'b) t -> f:(key:'a -> data:'b -> unit) -> unit

val replace : ('a, 'b) t -> key:'a -> data:'b -> unit

val add : ('a, 'b) t -> 'a -> 'b -> unit

val find : ('a, 'b) t -> 'a -> 'b option
val find_or_add : ('a, 'b) t -> 'a -> f:('a -> 'b) -> 'b

val fold  : ('a, 'b) t -> init:'c -> f:(      'b -> 'c -> 'c) -> 'c
val foldi : ('a, 'b) t -> init:'c -> f:('a -> 'b -> 'c -> 'c) -> 'c

val mem : ('a, _) t -> 'a -> bool

val keys : ('a, _) t -> 'a list

val to_sexp : ('a -> Sexp.t) -> ('b -> Sexp.t) -> ('a, 'b) t -> Sexp.t
