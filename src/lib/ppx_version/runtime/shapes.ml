(* shapes.ml -- registry of Bin_prot shapes *)

open Core_kernel
module Shape_tbl = Hashtbl.Make (Base.String)

let shape_tbl : Bin_prot.Shape.t Shape_tbl.t = Shape_tbl.create ()

let find path_to_type = Shape_tbl.find shape_tbl path_to_type

let iteri ~f = Shape_tbl.iteri shape_tbl ~f

let equal_shapes shape1 shape2 =
  let canonical1 = Bin_prot.Shape.eval shape1 in
  let canonical2 = Bin_prot.Shape.eval shape2 in
  Bin_prot.Shape.Canonical.compare canonical1 canonical2 = 0

let register path_to_type (shape : Bin_prot.Shape.t) =
  match Shape_tbl.add shape_tbl ~key:path_to_type ~data:shape with
  | `Ok ->
      ()
  | `Duplicate -> (
      (* versioned types inside functors that are called more than
         once will yield duplicates; OK if the shapes are the same
      *)
      match find path_to_type with
      | Some shape' ->
          if not (equal_shapes shape shape') then
            failwithf "Different type shapes at path %s" path_to_type ()
          else ()
      | None ->
          failwithf "Expected to find registered shape at path %s" path_to_type
            () )
