open Core_kernel

let split_last_exn =
  let rec go acc x xs =
    match xs with
    | [] -> List.rev acc, x
    | x' :: xs -> go (x :: acc) x' xs
  in
  function
  | [] -> failwith "split_last: Empty list"
  | x :: xs -> go [] x xs
;;

let (+>) fold1 fold2 =
  fun ~init ~f ->
    fold2 ~init:(fold1 ~init ~f) ~f
