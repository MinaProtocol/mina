open Core

(* Deleted the finger tree based sequence type in favor of lists because of
   #3143. This is much slower. *)

[%%expires_after
"20190913"]

type 'e t = 'e list

let split_at = List.split_n

let snoc xs x = xs @ [x]

let cons x xs = x :: xs

let singleton x = [x]

let empty = []

let equal = List.equal

let sexp_of_t = List.sexp_of_t

let to_seq = Sequence.of_list

let iter = List.iter

let foldr f init xs = List.fold_right xs ~init ~f

let foldl f init xs = List.fold_left xs ~init ~f

let unsnoc = function
  | [] ->
      None
  | xs ->
      let len = List.length xs in
      Some (List.take xs (len - 1), List.last_exn xs)

let uncons = function [] -> None | x :: xs -> Some (x, xs)

let last_exn = List.last_exn

let head_exn = List.hd_exn

let length = List.length

let is_empty = List.is_empty
