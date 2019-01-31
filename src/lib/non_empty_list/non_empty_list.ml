open Core_kernel

(* A non-empty list is a tuple of the head and the rest (as a list) *)
type 'a t = 'a * 'a list [@@deriving sexp, compare, eq, hash]

let head (x, _) = x

let tail (_, xs) = xs

let map (x, xs) ~f = (f x, List.map ~f xs)

(* As the Base.Container docs state, we'll add each function from C explicitly
 * rather than including C *)
module C = Container.Make (struct
  type nonrec 'a t = 'a t

  let fold (x, xs) ~init ~f = List.fold xs ~init:(f init x) ~f

  let iter = `Custom (fun (x, xs) ~f -> f x ; List.iter xs ~f)
end)

let find = C.find

let find_map = C.find_map

let fold = C.fold

let iter = C.iter

let fold_until = C.fold_until

let length = C.length
