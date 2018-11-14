open Core_kernel

module Extended_projective = struct
  type 'a t = {x: 'a; y: 'a; z: 'a; t: 'a} [@@deriving sexp]
end

module type Simple_elliptic_curve_intf = sig
  type base

  type t

  val to_affine_coordinates : t -> base * base
end

module type S = sig
  module G1 : sig
    type t
  end

  module G2 : sig
    type t
  end

  module Fq_target : sig
    type t
  end

  module G1_precomputation : sig
    type t [@@deriving bin_io, sexp]

    val create : G1.t -> t
  end

  module G2_precomputation : sig
    type t [@@deriving bin_io, sexp]

    val create : G2.t -> t
  end

  val final_exponentiation : Fq_target.t -> Fq_target.t

  val miller_loop : G1_precomputation.t -> G2_precomputation.t -> Fq_target.t

  val unreduced_pairing : G1.t -> G2.t -> Fq_target.t

  val reduced_pairing : G1.t -> G2.t -> Fq_target.t
end

module Make
    (N : Nat_intf.S)
    (Fq : Fields.Fp_intf with type nat := N.t)
    (Fq_twist : Fields.Extension_intf with type base = Fq.t) (Fq_target : sig
        include Fields.Degree_2_extension_intf with type base = Fq_twist.t

        val frobenius : t -> int -> t

        val cyclotomic_exp : t -> N.t -> t
    end)
    (G1 : Simple_elliptic_curve_intf with type base := Fq.t) (G2 : sig
        include Simple_elliptic_curve_intf with type base := Fq_twist.t

        module Coefficients : sig
          val a : Fq_twist.t
        end
    end) (Info : sig
      val twist : Fq_twist.t

      val loop_count : N.t

      val is_loop_count_neg : bool

      val final_exponent_last_chunk_w1 : N.t

      val final_exponent_last_chunk_is_w0_neg : bool

      val final_exponent_last_chunk_abs_of_w0 : N.t
    end) :
  S with module G1 := G1 and module G2 := G2 and module Fq_target := Fq_target =
struct
  module G1_precomputation = struct
    type t = {px: Fq.t; py: Fq.t; px_twist: Fq_twist.t; py_twist: Fq_twist.t}
    [@@deriving bin_io, sexp]

    let create (p : G1.t) =
      let px, py = G1.to_affine_coordinates p in
      { px
      ; py
      ; px_twist= Fq_twist.scale Info.twist px
      ; py_twist= Fq_twist.scale Info.twist py }
  end

  module Dbl_coeffs = struct
    type t =
      {c_H: Fq_twist.t; c_4C: Fq_twist.t; c_J: Fq_twist.t; c_L: Fq_twist.t}
    [@@deriving bin_io, sexp]
  end

  module Add_coeffs = struct
    type t = {c_L1: Fq_twist.t; c_RZ: Fq_twist.t} [@@deriving bin_io, sexp]
  end

  let loop_count_size_in_bits = N.num_bits Info.loop_count

  module G2_precomputation = struct
    type t =
      { qx: Fq_twist.t
      ; qy: Fq_twist.t
      ; qy2: Fq_twist.t
      ; qx_over_twist: Fq_twist.t
      ; qy_over_twist: Fq_twist.t
      ; dbl_coeffs: Dbl_coeffs.t array
      ; add_coeffs: Add_coeffs.t array }
    [@@deriving bin_io, sexp]

    let twist_inv = Fq_twist.inv Info.twist

    let doubling_step_for_flipped_miller_loop
        ({Extended_projective.x; y; z= _; t} as current) =
      let a = Fq_twist.square t in
      let b = Fq_twist.square x in
      let c = Fq_twist.square y in
      let d = Fq_twist.square c in
      let e = Fq_twist.(square (x + c) - b - d) in
      let f = Fq_twist.(b + b + b + (G2.Coefficients.a * a)) in
      let g = Fq_twist.square f in
      let next =
        let x = Fq_twist.(negate (e + e + e + e) + g) in
        let y =
          Fq_twist.(scale d Fq.(negate (of_int 8)) + (f * (e + e - x)))
        in
        let z =
          Fq_twist.(square (current.y + current.z) - c - square current.z)
        in
        let t = Fq_twist.square z in
        {Extended_projective.x; y; z; t}
      in
      let coeffs =
        { Dbl_coeffs.c_H= Fq_twist.(square (next.z + current.t) - next.t - a)
        ; c_4C= Fq_twist.(c + c + c + c)
        ; c_J= Fq_twist.(square (f + t) - g - a)
        ; c_L= Fq_twist.(square (f + current.x) - g - b) }
      in
      (next, coeffs)

    let mixed_addition_step_for_flipped_miller_loop base_x base_y
        base_y_squared {Extended_projective.x= x1; y= y1; z= z1; t= t1} =
      let open Fq_twist in
      let b = base_x * t1 in
      let d = (square (base_y + z1) - base_y_squared - t1) * t1 in
      let h = b - x1 in
      let i = Fq_twist.square h in
      let e = i + i + i + i in
      let j = h * e in
      let v = x1 * e in
      let l1 = d - (y1 + y1) in
      let next =
        let x = square l1 - j - (v + v) in
        let y = (l1 * (v - x)) - ((y1 + y1) * j) in
        let z = square (z1 + h) - t1 - i in
        let t = square z in
        {Extended_projective.x; y; z; t}
      in
      (next, {Add_coeffs.c_L1= l1; c_RZ= next.z})

    let create (q : G2.t) =
      let qx, qy = G2.to_affine_coordinates q in
      let qy2 = Fq_twist.square qy in
      let qx_over_twist = Fq_twist.(qx * twist_inv) in
      let qy_over_twist = Fq_twist.(qy * twist_inv) in
      let rec go found_one r dbl_coeffs add_coeffs i =
        if i < 0 then (r, dbl_coeffs, add_coeffs)
        else
          let bit = N.test_bit Info.loop_count i in
          if not found_one then
            go (found_one || bit) r dbl_coeffs add_coeffs (i - 1)
          else
            let r, dc = doubling_step_for_flipped_miller_loop r in
            let dbl_coeffs = dc :: dbl_coeffs in
            if bit then
              let r, ac =
                mixed_addition_step_for_flipped_miller_loop qx qy qy2 r
              in
              let add_coeffs = ac :: add_coeffs in
              go found_one r dbl_coeffs add_coeffs (i - 1)
            else go found_one r dbl_coeffs add_coeffs (i - 1)
      in
      let r, dbl_coeffs, add_coeffs =
        go false
          {x= qx; y= qy; z= Fq_twist.one; t= Fq_twist.one}
          [] []
          (loop_count_size_in_bits - 1)
      in
      let add_coeffs =
        if not Info.is_loop_count_neg then add_coeffs
        else
          let open Fq_twist in
          let rZ_inv = inv r.z in
          let rZ2_inv = square rZ_inv in
          let rZ3_inv = rZ2_inv * rZ_inv in
          let minus_R_affine_X = r.x * rZ2_inv in
          let minus_R_affine_Y = negate r.y * rZ3_inv in
          let minus_R_affine_Y2 = square minus_R_affine_Y in
          let _r, ac =
            mixed_addition_step_for_flipped_miller_loop minus_R_affine_X
              minus_R_affine_Y minus_R_affine_Y2 r
          in
          ac :: add_coeffs
      in
      { qx
      ; qy
      ; qy2
      ; qx_over_twist
      ; qy_over_twist
      ; dbl_coeffs= Array.of_list (List.rev dbl_coeffs)
      ; add_coeffs= Array.of_list (List.rev add_coeffs) }
  end

  let miller_loop (p : G1_precomputation.t) (q : G2_precomputation.t) =
    let l1_coeff = Fq_twist.(of_base p.px - q.qx_over_twist) in
    let f = ref Fq_target.one in
    let found_one = ref false in
    let dbl_idx_r = ref 0 in
    let add_idx_r = ref 0 in
    for i = loop_count_size_in_bits - 1 downto 0 do
      let bit = N.test_bit Info.loop_count i in
      if not !found_one then found_one := !found_one || bit
      else
        let dbl_idx = !dbl_idx_r in
        incr dbl_idx_r ;
        let dc = q.dbl_coeffs.(dbl_idx) in
        let g_RR_at_P : Fq_target.t =
          let open Fq_twist in
          (negate dc.c_4C - (dc.c_J * p.px_twist) + dc.c_L, dc.c_H * p.py_twist)
        in
        (f := Fq_target.(square !f * g_RR_at_P)) ;
        if bit then (
          let add_idx = !add_idx_r in
          incr add_idx_r ;
          let ac = q.add_coeffs.(add_idx) in
          let g_RQ_at_P =
            let open Fq_twist in
            ( ac.c_RZ * p.py_twist
            , negate ((q.qy_over_twist * ac.c_RZ) + (l1_coeff * ac.c_L1)) )
          in
          f := Fq_target.(!f * g_RQ_at_P) )
    done ;
    if Info.is_loop_count_neg then (
      let add_idx = !add_idx_r in
      incr add_idx_r ;
      let ac = q.add_coeffs.(add_idx) in
      let g_RnegR_at_P =
        let open Fq_twist in
        ( ac.c_RZ * p.py_twist
        , negate ((q.qy_over_twist * ac.c_RZ) + (l1_coeff * ac.c_L1)) )
      in
      f := Fq_target.(inv (!f * g_RnegR_at_P)) ) ;
    !f

  let unreduced_pairing p q =
    miller_loop (G1_precomputation.create p) (G2_precomputation.create q)

  let final_exponentiation_first_chunk elt elt_inv =
    let open Fq_target in
    let elt_q3 = frobenius elt 3 in
    let elt_q3_over_elt = elt_q3 * elt_inv in
    let alpha = frobenius elt_q3_over_elt 1 in
    alpha * elt_q3_over_elt

  let final_exponentiation_last_chunk elt elt_inv =
    let open Fq_target in
    let elt_q = frobenius elt 1 in
    let w1_part = cyclotomic_exp elt_q Info.final_exponent_last_chunk_w1 in
    let w0_part =
      if Info.final_exponent_last_chunk_is_w0_neg then
        cyclotomic_exp elt_inv Info.final_exponent_last_chunk_abs_of_w0
      else cyclotomic_exp elt Info.final_exponent_last_chunk_abs_of_w0
    in
    w1_part * w0_part

  let final_exponentiation x =
    let x_inv = Fq_target.inv x in
    let x_to_first_chunk = final_exponentiation_first_chunk x x_inv in
    let x_inv_to_first_chunk = final_exponentiation_first_chunk x_inv x in
    final_exponentiation_last_chunk x_to_first_chunk x_inv_to_first_chunk

  let reduced_pairing p q = final_exponentiation (unreduced_pairing p q)
end
