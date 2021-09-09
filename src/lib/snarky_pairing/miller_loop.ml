open Core_kernel
open Sgn_type

module type Inputs_intf = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Fq :
    Snarky_field_extensions.Intf.S
    with module Impl = Impl
     and type 'a A.t = 'a
     and type 'a Base.t_ = 'a

  module Fqe :
    Snarky_field_extensions.Intf.S_with_primitive_element
    with module Impl = Impl
     and module Base = Fq

  module Fqk : sig
    include
      Snarky_field_extensions.Intf.S
      with module Impl = Impl
       and type 'a Base.t_ = 'a Fqe.t_
       and type 'a A.t = 'a * 'a

    val special_mul : t -> t -> (t, _) Impl.Checked.t

    val special_div : t -> t -> (t, _) Impl.Checked.t

    val unitary_inverse : t -> t
  end

  module G1_precomputation :
    G1_precomputation.S
    with module Impl = Impl
     and type 'a Fqe.Base.t_ = 'a Fqe.Base.t_
     and type 'a Fqe.A.t = 'a Fqe.A.t

  module G2_precomputation :
    G2_precomputation.S
    with module Impl = Impl
     and type 'a Fqe.Base.t_ = 'a Fqe.Base.t_
     and type 'a Fqe.A.t = 'a Fqe.A.t

  module N : Snarkette.Nat_intf.S

  module Params : sig
    val loop_count : N.t

    val loop_count_is_neg : bool
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax

  let double_line_eval (p : G1_precomputation.t)
      (c : G2_precomputation.Coeff.t) : (Fqk.t, _) Checked.t =
    with_label __LOC__
      (let px, _ = p.p in
       let%map c1 =
         let gamma_twist = Fqe.mul_by_primitive_element c.gamma in
         let%map t = Fqe.mul_field gamma_twist px in
         Fqe.(c.gamma_x - c.ry - t)
       in
       (p.py_twist_squared, c1))

  (* result = c.gamma_x + qy * (invert_q ? -1 : 1) - gamma_twist * px *)
  let add_line_eval ~invert_q (p : G1_precomputation.t)
      (c : G2_precomputation.Coeff.t) ((_, qy) : Fqe.t * Fqe.t) :
      (Fqk.t, _) Checked.t =
    with_label __LOC__
      (let px, _ = p.p in
       let%map c1 =
         let open Fqe in
         let gamma_twist = mul_by_primitive_element c.gamma in
         let%map t = mul_field gamma_twist px in
         c.gamma_x + (if invert_q then qy else Fqe.negate qy) - t
       in
       (p.py_twist_squared, c1))

  let uncons_exn = function [] -> failwith "uncons_exn" | x :: xs -> (x, xs)

  let finalize =
    if Params.loop_count_is_neg then Fqk.unitary_inverse else Fn.id

  let miller_loop (p : G1_precomputation.t) (q : G2_precomputation.t) =
    let naf = Snarkette.Fields.find_wnaf (module N) 1 Params.loop_count in
    let rec go i found_nonzero coeffs f =
      if i < 0 then return f
      else if not found_nonzero then
        go (i - 1) (found_nonzero || naf.(i) <> 0) coeffs f
      else
        let%bind f = Fqk.square f in
        let c, coeffs = uncons_exn coeffs in
        let%bind g_RR_at_P = double_line_eval p c in
        let%bind f = Fqk.special_mul f g_RR_at_P in
        if naf.(i) <> 0 then
          let c, coeffs = uncons_exn coeffs in
          let%bind g_RQ_at_P = add_line_eval ~invert_q:(naf.(i) < 0) p c q.q in
          let%bind f = Fqk.special_mul f g_RQ_at_P in
          go (i - 1) found_nonzero coeffs f
        else go (i - 1) found_nonzero coeffs f
    in
    with_label __LOC__ (go (Array.length naf - 1) false q.coeffs Fqk.one)
    >>| finalize

  let batch_miller_loop
      (pairs : (Sgn.t * G1_precomputation.t * G2_precomputation.t) list) =
    let naf = Snarkette.Fields.find_wnaf (module N) 1 Params.loop_count in
    let accum f acc pairs =
      Checked.List.fold_map pairs ~init:acc ~f:(fun acc (sgn, p, q) ->
          let c, coeffs = uncons_exn q.G2_precomputation.coeffs in
          let%bind a = f p c q.q in
          let%map acc =
            match (sgn : Sgn.t) with
            | Pos ->
                Fqk.special_mul acc a
            | Neg ->
                Fqk.special_div acc a
            (* TODO: Use an unsafe div here if appropriate. I think it should be fine
             since py_twisted is py (a curve y-coorindate, guaranteed to be non-zero)
             times a constant.
          *)
          in
          (acc, (sgn, p, {q with G2_precomputation.coeffs})) )
    in
    let rec go i found_nonzero pairs f =
      if i < 0 then return f
      else if not found_nonzero then
        go (i - 1) (found_nonzero || naf.(i) <> 0) pairs f
      else
        let%bind f = Fqk.square f in
        let%bind f, pairs =
          accum (fun p c _q -> double_line_eval p c) f pairs
        in
        if naf.(i) <> 0 then
          let%bind f, pairs =
            accum (add_line_eval ~invert_q:(naf.(i) < 0)) f pairs
          in
          go (i - 1) found_nonzero pairs f
        else go (i - 1) found_nonzero pairs f
    in
    go (Array.length naf - 1) false pairs Fqk.one >>| finalize
end
