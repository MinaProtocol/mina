(* shapes.ml -- registry of Bin_prot shapes *)

open Core_kernel
module Shape_tbl = Hashtbl.Make (Base.String)

let shape_tbl : Bin_prot.Shape.t Shape_tbl.t = Shape_tbl.create ()

let register path_to_type (shape : Bin_prot.Shape.t) =
  Shape_tbl.add shape_tbl ~key:path_to_type ~data:shape

let iteri ~f = Shape_tbl.iteri shape_tbl ~f
