open Core_kernel
open Fold_lib

module Make (Inputs : Inputs_intf.S) = struct
  open Inputs

  let g1_to_bits t =
    let x, y = G1.to_affine_exn t in
    Bigint.(test_bit (of_field y) 0) :: Field.to_bits x

  let g2_to_bits t =
    let x, y = G2.to_affine_exn t in
    let y0 = List.hd_exn (Fqe.to_list y) in
    assert (not Field.(equal y0 zero)) ;
    Bigint.(test_bit (of_field y0) 0)
    :: List.concat_map (Fqe.to_list x) ~f:Field.to_bits

  let random_oracle =
    let field_to_bits = Fn.compose Array.of_list Field.to_bits in
    fun x ->
      field_to_bits x |> Blake2.bits_to_string |> Blake2.digest_string
      |> Blake2.to_raw_string |> Blake2.string_to_bits |> Array.to_list

  let hash ?message ~a ~b ~c ~delta_prime =
    pedersen
      Fold.(
        group3 ~default:false
          ( of_list (g1_to_bits a)
          +> of_list (g2_to_bits b)
          +> of_list (g1_to_bits c)
          +> of_list (g2_to_bits delta_prime)
          +> of_array (Option.value ~default:[||] message) ))
    |> random_oracle |> Field.of_bits
    |> Group_map.to_group (module Field) ~params
    |> G1.of_affine
end
