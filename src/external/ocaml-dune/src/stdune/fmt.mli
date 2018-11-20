type 'a t = Format.formatter -> 'a -> unit

val list : ?pp_sep:unit t -> 'a t -> 'a list t

val failwith : ('a, Format.formatter, unit, 'b) format4 -> 'a

val string : string -> Format.formatter -> unit

val text : string t

val prefix
  : (Format.formatter -> unit)
  -> (Format.formatter -> 'b -> 'c)
  -> (Format.formatter -> 'b -> 'c)

val ocaml_list : 'a t -> 'a list t

val quoted : string t

val const : 'a t -> 'a -> unit t

val record : (string * unit t) list t

val tuple : 'a t -> 'b t -> ('a * 'b) t

val nl : unit t

val optional : 'a t -> 'a option t
