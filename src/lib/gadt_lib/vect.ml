type ('el, 'n) t =
  | [] : ('el, Peano.zero) t
  | ( :: ) : 'el * ('el, 'n) t -> ('el, 'n Peano.succ) t

let is_empty : type n. ('a, n) t -> bool = function
  | [] ->
      true
  | _ :: _ ->
      false

let rec to_list : type n. ('a, n) t -> 'a list = function
  | [] ->
      []
  | h :: t ->
      h :: to_list t

let rec map : type n. f:('a -> 'b) -> ('a, n) t -> ('b, n) t =
 fun ~f ls -> match ls with [] -> [] | h :: t -> f h :: map ~f t

let rec map2 : type n. f:('a -> 'b -> 'c) -> ('a, n) t -> ('b, n) t -> ('c, n) t
    =
 fun ~f ls_a ls_b ->
  match (ls_a, ls_b) with
  | [], [] ->
      []
  | h_a :: t_a, h_b :: t_b ->
      f h_a h_b :: map2 ~f t_a t_b

let rec fold : type n. init:'b -> f:('b -> 'a -> 'b) -> ('a, n) t -> 'b =
 fun ~init ~f ls ->
  match ls with [] -> init | h :: t -> fold ~init:(f init h) ~f t

let rec fold_map :
    type n. init:'b -> f:('b -> 'a -> 'b * 'c) -> ('a, n) t -> 'b * ('c, n) t =
 fun ~init ~f ls ->
  match ls with
  | [] ->
      (init, [])
  | h :: t ->
      let init', h' = f init h in
      let init'', t' = fold_map ~init:init' ~f t in
      (init'', h' :: t')

module Quickcheck_generator = struct
  open Core_kernel.Quickcheck
  open Generator.Let_syntax

  let rec map :
      type n. f:('a -> 'b Generator.t) -> ('a, n) t -> ('b, n) t Generator.t =
   fun ~f ls ->
    match ls with
    | [] ->
        return []
    | h :: t ->
        let%bind h' = f h in
        let%map t' = map ~f t in
        h' :: t'
end
