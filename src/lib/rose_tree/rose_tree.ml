open Core_kernel

type 'a t = T of 'a * 'a t list

let rec of_list_exn = function
  | [] ->
      raise
        (Invalid_argument
           "Rose_tree.of_list_exn: cannot construct rose tree from empty list")
  | [h] -> T (h, [])
  | h :: t -> T (h, [of_list_exn t])

let rec iter (T (base, successors)) ~f =
  f base ;
  List.iter successors ~f:(iter ~f)

let rec fold_map (T (base, successors)) ~init ~f =
  let r = f init base in
  T (r, List.map successors ~f:(fold_map ~init:r ~f))
