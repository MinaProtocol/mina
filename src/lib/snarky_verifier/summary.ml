open Core_kernel

module type Inputs_intf = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Fqe : sig
    type _ t_

    val real_part : 'a t_ -> 'a

    val to_list : 'a t_ -> 'a list
  end
end

module Input = struct
  type ('g1, 'g2, 'gt) t = {g1s: 'g1 list; g2s: 'g2 list; gts: 'gt list}
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax

  let summary_length_in_bits ~twist_extension_degree ~g1_count ~g2_count
      ~gt_count =
    let elts =
      g1_count
      + (twist_extension_degree * g2_count)
      + (twist_extension_degree * gt_count)
    in
    let signs = g1_count + g2_count + gt_count in
    (elts * Field.size_in_bits) + signs

  let summary {Input.g1s; g2s; gts} =
    let%map elts =
      List.map g1s ~f:(fun (x, _) -> x)
      @ List.concat_map g2s ~f:(fun (x, _) -> Fqe.to_list x)
      @ List.concat_map gts ~f:(fun (a, _) -> Fqe.to_list a)
      |> Checked.List.map ~f:(fun x ->
             Field.Checked.choose_preimage_var x ~length:Field.size_in_bits )
      >>| List.concat
    and signs =
      let parity x =
        let%map bs = Field.Checked.unpack_full x in
        List.hd_exn (bs :> Boolean.var list)
      in
      let real_part_parity a =
        let x = Fqe.real_part a in
        let%bind () = Field.Checked.Assert.non_zero x in
        parity x
      in
      let%map g1s = Checked.List.map g1s ~f:(fun (_, y) -> parity y)
      and g2s = Checked.List.map g2s ~f:(fun (_, y) -> real_part_parity y)
      and gts = Checked.List.map gts ~f:(fun (_, b) -> real_part_parity b) in
      g1s @ g2s @ gts
    in
    elts @ signs

  let summary_unchecked {Input.g1s; g2s; gts} =
    let parity x = Bigint.(test_bit (of_field x) 0) in
    let elts =
      List.map g1s ~f:(fun (x, _) -> x)
      @ List.concat_map g2s ~f:(fun (x, _) -> Fqe.to_list x)
      @ List.concat_map gts ~f:(fun (a, _) -> Fqe.to_list a)
      |> List.concat_map ~f:Field.unpack
    and signs =
      let real_part_parity a =
        let x = Fqe.real_part a in
        assert (not (Field.equal Field.zero x)) ;
        parity x
      in
      List.map g1s ~f:(fun (_, y) -> parity y)
      @ List.map g2s ~f:(fun (_, y) -> real_part_parity y)
      @ List.map gts ~f:(fun (_, b) -> real_part_parity b)
    in
    elts @ signs
end
