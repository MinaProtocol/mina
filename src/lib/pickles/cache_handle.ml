type t = Dirty.t Lazy.t

let generate_or_load (t : t) = Lazy.force t

let ( + ) (t1 : t) (t2 : t) : t = lazy Dirty.(Lazy.force t1 + Lazy.force t2)
