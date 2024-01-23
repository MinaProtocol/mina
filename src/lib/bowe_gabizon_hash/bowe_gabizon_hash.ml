open Core_kernel

module Make (Inputs : Inputs_intf.S) = struct
  open Inputs

  let g1 g =
    let x, y = G1.to_affine_exn g in
    [| x; y |]

  let g2 g =
    let x, y = G2.to_affine_exn g in
    Array.of_list (List.concat_map ~f:Fqe.to_list [ x; y ])

  let hash ?message ~a ~b ~c ~delta_prime =
    hash
      (Array.concat
         [ g1 a
         ; g2 b
         ; g1 c
         ; g2 delta_prime
         ; Option.value ~default:[||] message
         ] )
    |> group_map |> G1.of_affine
end
