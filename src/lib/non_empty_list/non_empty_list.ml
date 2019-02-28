open Core_kernel

(* A non-empty list is a tuple of the head and the rest (as a list) *)
type 'a t = 'a * 'a list [@@deriving sexp, compare, eq, hash, bin_io]

let init x xs = (x, xs)

let singleton x = (x, [])

let uncons = Fn.id

let cons x' (x, xs) = (x', x :: xs)

let head (x, _) = x

let tail (_, xs) = xs

let rev (x, xs) =
  match List.rev (x :: xs) with
  | [] -> failwith "refute"
  | [x] -> (x, [])
  | h :: t -> (h, t)

let of_list_opt = function [] -> None | x :: xs -> Some (x, xs)

let tail_opt t = of_list_opt (tail t)

let map (x, xs) ~f = (f x, List.map ~f xs)

let rev (x, xs) = List.fold xs ~init:(singleton x) ~f:(Fn.flip cons)

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

let length = C.length

let to_list (x, xs) = x :: xs

let append (x, xs) ys = (x, xs @ to_list ys)

let take (x, xs) = function
  | 0 -> None
  | 1 -> Some (x, [])
  | n -> Some (x, List.take xs (n - 1))
