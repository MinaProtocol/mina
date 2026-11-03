type t = Dirty.t Promise.t Lazy.t

let generate_or_load (t : t) = Lazy.force t

let ( + ) (t1 : t) (t2 : t) : t =
  lazy
    (let%map.Promise t1 = Lazy.force t1 and t2 = Lazy.force t2 in
     Dirty.(t1 + t2) )
