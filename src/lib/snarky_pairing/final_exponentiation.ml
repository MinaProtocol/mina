open Core_kernel

module type Inputs_intf = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Fqk : sig
    include Snarky_field_extensions.Intf.S with module Impl = Impl

    val cyclotomic_square : t -> (t, _) Impl.Checked.t

    val frobenius : t -> int -> t
  end

  module N : Snarkette.Nat_intf.S

  module Params : sig
    val loop_count : N.t

    val loop_count_is_neg : bool

    val final_exponent_last_chunk_w1 : N.t

    val final_exponent_last_chunk_is_w0_neg : bool

    val final_exponent_last_chunk_abs_of_w0 : N.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax

  let exponentiate elt power =
    let naf = Snarkette.Fields.find_wnaf (module N) 1 power in
    let%bind elt_inv = Fqk.inv_exn elt in
    let rec go i found_nonzero acc =
      if i < 0 then return acc
      else
        let%bind acc =
          if found_nonzero then Fqk.cyclotomic_square acc else return acc
        in
        let%bind acc =
          if naf.(i) > 0 then Fqk.(acc * elt)
          else if naf.(i) < 0 then Fqk.(acc * elt_inv)
          else return acc
        in
        go (i - 1) (found_nonzero || naf.(i) <> 0) acc
    in
    go (Array.length naf - 1) false Fqk.one

  let final_exponentiation6 el =
    let%bind el_q_3_minus_1 =
      let%bind el_inv = Fqk.inv_exn el in
      Fqk.(frobenius el 3 * el_inv)
    in
    let alpha = Fqk.frobenius el_q_3_minus_1 1 in
    let%bind beta = Fqk.(alpha * el_q_3_minus_1) in
    let%bind w0 =
      let%bind base =
        if Params.final_exponent_last_chunk_is_w0_neg then Fqk.inv_exn beta
        else return beta
      in
      exponentiate base Params.final_exponent_last_chunk_abs_of_w0
    and w1 =
      let beta_q = Fqk.frobenius beta 1 in
      exponentiate beta_q Params.final_exponent_last_chunk_w1
    in
    Fqk.(w0 * w1)

  let final_exponentiation4 el =
    let%bind el_inv = Fqk.inv_exn el in
    let%bind el_q_2_minus_1 = Fqk.(el_inv * Fqk.frobenius el 2) in
    let%bind w1 =
      let el_q_3_minus_q = Fqk.frobenius el_q_2_minus_1 1 in
      exponentiate el_q_3_minus_q Params.final_exponent_last_chunk_w1
    in
    let%bind w0 =
      let%bind base =
        if Params.final_exponent_last_chunk_is_w0_neg then
          Fqk.(el * Fqk.frobenius el_inv 2) (* el_inv_q_2_minus_1 *)
        else return el_q_2_minus_1
      in
      exponentiate base Params.final_exponent_last_chunk_abs_of_w0
    in
    Fqk.(w0 * w1)
end
