type ('a, _) t =
  | [] : ('a, 'n) t
  | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n Nat.s) t

let rec to_list : type a n. (a, n) t -> a list = function
  | [] ->
      []
  | x :: xs ->
      x :: to_list xs

let rec length : type a n. (a, n) t -> int = function
  | [] ->
      0
  | _ :: xs ->
      1 + length xs

let rec to_vector : type a n. (a, n) t -> a Vector.e = function
  | [] ->
      T []
  | x :: xs ->
      let (T xs) = to_vector xs in
      T (x :: xs)

let rec map : type a b n. (a, n) t -> f:(a -> b) -> (b, n) t =
 fun xs ~f -> match xs with [] -> [] | x :: xs -> f x :: map xs ~f

let rec extend_to_vector : type a n.
    (a, n) t -> a -> n Nat.t -> (a, n) Vector.t =
 fun v a n ->
  match (v, n) with
  | [], Z ->
      []
  | [], S n ->
      a :: extend_to_vector [] a n
  | x :: xs, S n ->
      x :: extend_to_vector xs a n

let rec of_vector : type a n m. (a, n) Vector.t -> (n, m) Nat.Lte.t -> (a, m) t
    =
 fun v p ->
  match (v, p) with [], _ -> [] | x :: xs, S p -> x :: of_vector xs p

let rec of_list_and_length_exn : type a n. a list -> n Nat.t -> (a, n) t =
 fun xs n ->
  match (xs, n) with
  | [], _ ->
      []
  | x :: xs, S n ->
      x :: of_list_and_length_exn xs n
  | _ ->
      failwith "At_most: Length mismatch"

open Core_kernel

module Yojson (N : Nat.Intf) :
  Vector.Yojson_intf1 with type 'a t := ('a, N.n) t = struct
  let to_yojson f t = Vector.L.to_yojson f (to_list t)

  let of_yojson f s =
    Result.map (Vector.L.of_yojson f s) ~f:(Fn.flip of_list_and_length_exn N.n)
end

(* TODO: Change to check length before reading the whole list. *)
module Binable (N : Nat.Intf) : Binable.S1 with type 'a t := ('a, N.n) t =
  Binable.Of_binable1
    (List)
    (struct
      type nonrec 'a t = ('a, N.n) t

      let to_binable = to_list

      let of_binable xs = of_list_and_length_exn xs N.n
    end)

module Sexpable (N : Nat.Intf) : Sexpable.S1 with type 'a t := ('a, N.n) t =
  Sexpable.Of_sexpable1
    (List)
    (struct
      type nonrec 'a t = ('a, N.n) t

      let to_sexpable = to_list

      let of_sexpable xs = of_list_and_length_exn xs N.n
    end)

module With_length (N : Nat.Intf) = struct
  type nonrec 'a t = ('a, N.n) t

  let compare c t1 t2 = Base.List.compare c (to_list t1) (to_list t2)

  include Yojson (N)
  include Binable (N)
  include Sexpable (N)
end
