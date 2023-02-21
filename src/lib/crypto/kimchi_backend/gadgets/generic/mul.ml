open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let multiply (type f) =
  let left = v0 in 


with_label "generic_mul" (fun () -> 
  assert_ {
    annotation = Some __LOC__
    ; basic = 
    Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T (Basic {left; right, output}) }; p3)
  })