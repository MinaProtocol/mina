open Core_kernel
include Result
open Let_syntax

module List = struct
  let map ls ~f =
    let%map r =
      List.fold_result ls ~init:[] ~f:(fun t el ->
          let%map h = f el in
          h :: t )
    in
    List.rev r
end
