type (_, _) t =
  | PC : ('g1, < g1: 'g1 ; .. >) t
  | Scalar : ('s, < scalar: 's ; .. >) t
  | ( :: ) : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t

let degree_bounded_pc = PC :: PC
