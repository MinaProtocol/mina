type z = Z

type _ s = S

type _ nat = Z : z nat | S : 'n nat -> 'n s nat

type ('a, _) t = [] : ('a, z) t | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n s) t

let rec map2 : type a b c n. (a, n) t -> (b, n) t -> f:(a -> b -> c) -> (c, n) t =
 fun t1 t2 ~f ->
  match (t1, t2) with [], [] -> [] | x :: xs, y :: ys -> f x y :: map2 xs ys ~f

let zip xs ys = map2 xs ys ~f:(fun x y -> (x, y))

let rec to_list : type a n. (a, n) t -> a list =
 fun t -> match t with [] -> [] | x :: xs -> x :: to_list xs

let rec length : type a n. (a, n) t -> n nat = function
  | [] ->
      Z
  | _ :: xs ->
      S (length xs)

let rec init : type a n. int -> n nat -> f:(int -> a) -> (a, n) t =
  fun i n ~f ->
  match n with
  | Z -> []
  | S n -> f i :: init (i + 1) n ~f

let init n ~f = init 0 n ~f

let rec fold_map : type acc a b n.
    (a, n) t -> f:(acc -> a -> acc * b) -> init:acc -> acc * (b, n) t =
 fun t ~f ~init ->
  match t with
  | [] ->
      (init, [])
  | x :: xs ->
      let acc, y = f init x in
      let res, ys = fold_map xs ~f ~init:acc in
      (res, y :: ys)

let rec map : type a b n. (a, n) t -> f:(a -> b) -> (b, n) t =
 fun t ~f -> match t with [] -> [] | x :: xs -> f x :: map xs ~f

type _ e =
  | T : ('a, 'n) t -> 'a e


let rec of_list : type a. a list -> a e = function
  | [] -> T []
  | x :: xs ->
    let T xs = of_list xs in
    T (x :: xs)

let rec fold : type acc a n. (a, n) t -> f:(acc -> a -> acc) -> init:acc -> acc
    =
 fun t ~f ~init ->
  match t with
  | [] ->
      init
  | x :: xs ->
      let acc = f init x in
      fold xs ~f ~init:acc

