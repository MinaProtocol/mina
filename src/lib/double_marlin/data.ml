open Core_kernel

type ('field, 'bool) t = 'field list * 'bool list

let bits bs = ([], bs)

let append (x1, b1) (x2, b2) = (x1 @ x2, b1 @ b2)

let concat : ('a, 'b) t list -> ('a, 'b) t = List.reduce_exn ~f:append

let pack_bits bs ~pack ~field_size =
  List.groupi bs ~break:(fun i _ _ -> i mod (field_size - 1) = 0)
  |> List.map ~f:pack

let assert_equal f t1 t2 ~pack ~field_size =
  let pack (x, b) = x @ pack_bits b ~pack ~field_size in
  List.iter2_exn (pack t1) (pack t2) ~f

let ( @ ) = append
