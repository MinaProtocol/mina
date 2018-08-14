module Elem = struct
  type ('a, 's) t =
    | Here : ('a, 'a -> 'b) t
    | There: ('a, 's) t -> ('a, 'b -> 's) t

  let rec equal : type a s. (a, s) t -> (a, s) t -> bool =
   fun t t' ->
    match (t, t') with
    | Here, Here -> true
    | There xs, There xs' -> equal xs xs'
    | Here, There _ -> false
    | There _, Here -> false

  let _0 () = Here

  let _1 () = There (_0 ())

  let _2 () = There (_1 ())

  let _3 () = There (_2 ())

  let _4 () = There (_3 ())
end

module Elem2 = struct
  type ('x, 'y, 's) t =
    | Here : ('x, 'y, 'x -> 'y -> 'b) t
    | There: ('x, 'y, 's) t -> ('x, 'y, 'b -> 'c -> 's) t

  let rec equal : type x y s. (x, y, s) t -> (x, y, s) t -> bool =
   fun t t' ->
    match (t, t') with
    | Here, Here -> true
    | There xs, There xs' -> equal xs xs'
    | Here, There _ -> false
    | There _, Here -> false

  let _0 () = Here

  let _1 () = There (_0 ())

  let _2 () = There (_1 ())

  let _3 () = There (_2 ())

  let _4 () = There (_3 ())
end

module Make2 (T : sig
  type ('x, 'y) t
end) =
struct
  type _ t = [] : unit t | ( :: ): ('x, 'y) T.t * 'b t -> ('x -> 'y -> 'b) t

  module Mapper = struct
    type 'b t = {f: 'x 'y. ('x, 'y) T.t -> 'b}
  end

  let rec map : type a. a t -> 'b Mapper.t -> 'b list =
   fun ls mapper ->
    match ls with [] -> [] | h :: t -> List.cons (mapper.f h) (map t mapper)

  let rec get : type a x y. a t -> (x, y, a) Elem2.t -> (x, y) T.t =
   fun l elem ->
    match (l, elem) with
    | x :: _, Elem2.Here -> x
    | _ :: xs, Elem2.There e -> get xs e
    | _ -> .
end

module Make (T : sig
  type 'a t
end) =
struct
  type _ t = [] : unit t | ( :: ): 'a T.t * 'b t -> ('a -> 'b) t

  module Mapper = struct
    type 'b t = {f: 'a. 'a T.t -> 'b}
  end

  let rec map : type a. a t -> 'b Mapper.t -> 'b list =
   fun ls mapper ->
    match ls with [] -> [] | h :: t -> List.cons (mapper.f h) (map t mapper)

  let rec get : type a x. a t -> (x, a) Elem.t -> x T.t =
   fun l elem ->
    match (l, elem) with
    | x :: _, Elem.Here -> x
    | _ :: xs, Elem.There e -> get xs e
    | _ -> .
end

include Make (struct
  type 'a t = 'a
end)
