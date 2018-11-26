type ('a, 'b) t = T : ('a, 'a) t

let cast (type a) (type b) (T : (a, b) t) (x : a) : b = x
