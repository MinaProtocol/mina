open Core_kernel

module type Inputs_intf = sig
  module Impl : Snarky.Snark_intf.S

  module Fqe : sig
    type _ t_

    val real_part : 'a t_ -> 'a

    val parts : 'a t_ -> 'a list
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax

  let summary ~g1s ~g2s ~gts =
    let%map elts =
      List.map g1s ~f:(fun (x, _) -> x)
      @ List.concat_map g2s ~f:(fun (x, _) -> Fqe.parts x)
      @ List.concat_map gts ~f:(fun (a, _) -> Fqe.parts a)
      |> Checked.List.map ~f:(fun x ->
             Field.Checked.choose_preimage_var x ~length:Field.size_in_bits
             >>| List.hd_exn )
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
end
