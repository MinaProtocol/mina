open Core_kernel
open Fold_lib
open Snarky

(* TODO: Have a compatibility layer so we only need the module M. *)
module Make
    (M : Snark_intf.Run)
    (Impl : Snark_intf.S with type field = M.field)
    (Inputs : Inputs_intf.S
              with type field := M.field
               and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t) =
struct
  open Inputs
  open M

  let bottom_bit y = List.hd_exn (Field.unpack_full y :> Boolean.var list)

  let choose_unpacking = Field.choose_preimage_var ~length:Field.size_in_bits

  let g1_to_bits (x, y) = bottom_bit y :: choose_unpacking x

  let g2_to_bits (x, y) =
    let y0 = List.hd_exn (Fqe.to_list y) in
    Field.Assert.non_zero y0 ;
    bottom_bit y0 :: List.concat_map (Fqe.to_list x) ~f:choose_unpacking

  module Blake2 = Snarky_blake2.Make (Impl)

  let random_oracle x =
    let open Impl in
    let open Let_syntax in
    Field.Checked.choose_preimage_var ~length:Field.size_in_bits x
    >>| Array.of_list >>= Blake2.blake2s >>| Array.to_list
    >>| Field.Var.project

  let group_map x =
    M.make_checked (fun () ->
        Snarky_group_map.Checked.to_group (module M) ~params x )

  let hash ?message ~a ~b ~c ~delta_prime =
    let open Impl in
    let open Let_syntax in
    M.make_checked (fun () ->
        g1_to_bits a @ g2_to_bits b @ g1_to_bits c @ g2_to_bits delta_prime
        @ Option.value_map message ~default:[] ~f:Array.to_list
        |> Fold.of_list
        |> Fold.group3 ~default:Boolean.false_ )
    >>= pedersen >>= random_oracle >>= group_map
end
