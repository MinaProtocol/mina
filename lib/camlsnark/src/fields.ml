open Core

module Make (Impl : Snark_intf.S) = struct
open Impl

module type Base_field = sig
  include Field_intf.S

  type value = t
  type var

  val spec : (var, value) Var_spec.t

  module Checked : sig
  end
end

module Exponentiation
    (M : sig
       type var

       module Checked : sig
         val one : var
         val sqr : var -> (var, _) Checked.t
         val mul : var -> var -> (var, _) Checked.t
         val div : var -> var -> (var, _) Checked.t
       end
     end)
= struct
  (* TODO: Make generic over bigint *)

  open M

  let exp elt (naf : Long_vector.t) =
(*     let naf : Long_vector.t = Libsnark.Util.find_wnaf_mnt6_q (Unsigned.Size_t.of_int 1) power in *)
    let open Let_syntax in
    let rec go i acc found_nonzero =
      if i < 0
      then return acc
      else
        let c = Signed.Long.compare (Long_vector.get naf i) Signed.Long.zero in
        let%bind acc =
          if found_nonzero
          then return acc
          else Checked.sqr acc
        in
        let (found_nonzero, macc) =
          if c <> 0
          then begin
            let macc =
              if c = 1
              then Checked.mul acc elt
              else Checked.div acc elt
            in
            (true, macc)
          end
          else (found_nonzero, return acc)
        in
        let%bind acc = macc in
        go (i - 1) acc found_nonzero
    in
    go (Long_vector.length naf - 1) Checked.one false
  ;;
end

(* TODO: There might be an issue with always using this one field type. *)
module Fp2 = struct

  module type S = sig
    type 'a t = 'a * 'a
    type var = Cvar.t t
    type value = Field.t t
    val non_residue : Field.t
    val spec : (var, value) Var_spec.t

    module Checked : sig
      val mul : var -> var -> (var, _) Checked.t
      val sqr : var -> (var, _) Checked.t
    end
  end

  module Make (M : sig val non_residue : Field.t end) : S = struct
    include M

    type 'a t = 'a * 'a
    type var = Cvar.t t
    type value = Field.t t

    let spec = Var_spec.(tuple2 field field)
    ;;

    (* See gadgetlib1/gadgets/fields/fp2_gadgets.tcc for explanation of these. *)

    module Checked = struct
      let mul (a_c0, a_c1) (b_c0, b_c1) =
        let open Let_syntax in
        let%bind v1 =
          exists Var_spec.field
            As_prover.(map2 ~f:Field.mul (read_var a_c1) (read_var b_c1))
        in
        let%bind ((r0, r1) as result) =
          exists spec begin
            let open As_prover in let open Let_syntax in
            let%map v1 = read_var v1
            and a0     = read_var a_c0
            and a1     = read_var a_c1
            and b0     = read_var b_c0
            and b1     = read_var b_c1
            in
            let open Field.Infix in
            let aA = a0 * b0 in
            ( aA + (non_residue * v1),
              ((a0 + a1) * (b0 + b1)) - (aA + v1))
          end
        in
        let%map () =
          let open Constraint in
          let open Cvar.Infix in
          assert_all
            [ r1cs a_c1 b_c1 v1
            ; r1cs a_c0 b_c0
                (Field.one * r0 - non_residue * v1)
            ; r1cs
                (a_c0 + a_c1)
                (b_c0 + b_c1)
                (r1 + r0 + Field.(sub one non_residue) * v1)
            ]
        in
        result
      ;;

      let sqr ((a_c0, a_c1) as t) =
        let open Let_syntax in
        let%bind ((r0, r1) as result) =
          exists spec
            As_prover.(map (read spec t) ~f:(fun (a, b) ->
              let open Field.Infix in
              ( (a + b) * (a + (non_residue * b)) - (a * b) - (non_residue * a * b) ,
                Field.of_int 2 * a * b)))
        in
        let%map () =
          let s = Field.(Infix.((one + non_residue) * inv (of_int 2))) in
          let open Constraint in
          let open Cvar.Infix in
          assert_all
            [ r1cs (Field.of_int 2 * a_c0) a_c1 r1
            ; r1cs (a_c0 + a_c1) (a_c0 + non_residue * a_c1) (r0 + s * r1)
            ]
        in
        result
      ;;
    end
  end
end

module Fp3 = struct
  module type S = sig
    type 'a t = 'a * 'a * 'a
    type var = Cvar.t t
    type value = Field.t t
    val non_residue : Field.t
    val spec : (var, value) Var_spec.t

    val negate : value -> value
    val sub : value -> value -> value
    val mul : value -> value -> value
    val inv : value -> value
    val square : value -> value

    module Checked : sig
      (* TODO: Remove once the equal-variable elimination pass is added. *)
      val assert_mul : var -> var -> result:var -> (unit, _) Checked.t

      val assert_equal : var -> var -> (unit, _) Checked.t

      val scale : var -> Field.t -> var
      val add : var -> var -> var
      val mul : var -> var -> (var, _) Checked.t
      val sqr : var -> (var, _) Checked.t

      val one : var
      val zero : var
    end
  end

  module Make (M : sig val non_residue : Field.t end) : S = struct
    (* TODO: Consider reusing the code in libff for this. *)
    include M

    type 'a t = 'a * 'a * 'a
    type var = Cvar.t t
    type value = Field.t t

    let spec = Var_spec.(tuple3 field field field)

    let sub (a0, a1, a2) (b0, b1, b2) = Field.Infix.(a0 - b0, a1 - b1, a2 - b2)

    let negate (a0, a1, a2) = Field.(negate a0, negate a1, negate a2)

    let square (a, b, c) =
      let open Field.Infix in
      let s0 = Field.square a in
      let ab = a * b in
      let s1 = ab + ab in
      let s2 = Field.square (a - b + c) in
      let bc = b*c in
      let s3 = bc + bc in
      let s4 = Field.square c in
      (s0 + non_residue * s3,
       s1 + non_residue * s4,
       s1 + s2 + s3 - s0 - s4)
    ;;

    let inv (a, b, c) =
      let open Field.Infix in
      let t0 = Field.square a in
      let t1 = Field.square b in
      let t2 = Field.square c in
      let t3 = a * b in
      let t4 = a * c in
      let t5 = b * c in
      let c0 = t0 - non_residue * t5 in
      let c1 = non_residue * t2 - t3 in
      let c2 = t1 - t4 in
      let t6 = Field.inv (a * c0 + non_residue * (c * c1 + b * c2)) in
      (t6 * c0, t6 * c1, t6 * c2)
    ;;

    (* See libff/libff/algebra/fields/fp3.tcc *)
    let mul (a0, a1, a2) (b0, b1, b2) =
      let open Field.Infix in
      let x0 = a0 * b0
      and x1 = a1 * b1
      and x2 = a2 * b2
      in
      ( x0 + non_residue * ((a1 + a2) * (b1 + b2) - x1 - x2),
        (a0 + a1) * (b0 + b1) - x0 - x1 + non_residue * x2,
        (a0 + a2) * (b0 + b2) - x0 + x1 - x2 )
    ;;

    (* See gadgetlib1/gadgets/fields/fp3_gadgets.tcc for explanation of these. *)

    module Checked = struct
      let one = let c = Cvar.constant in Field.(c one, c zero, c zero)
      let zero = let z = Cvar.constant Field.zero in (z, z, z)

      let assert_equal (a0, a1, a2) (b0, b1, b2) =
        assert_all
          [ Constraint.equal a0 b0
          ; Constraint.equal a1 b1
          ; Constraint.equal a2 b2
          ]
      ;;

      let add (a0, a1, a2) (b0, b1, b2) =
        Cvar.(add a0 b0, add a1 b1, add a2 b2)

      let scale (a0, a1, a2) c =
        Cvar.(scale a0 c, scale a1 c, scale a2 c)

      let assert_mul (a0, a1, a2) (b0, b1, b2) ~result =
        let (r0, r1, r2) = result in
        let open Let_syntax in
        let%bind v0 =
          exists Var_spec.field
            As_prover.(map2 (read_var a0) (read_var b0) ~f:Field.mul)
        and v4 =
          exists Var_spec.field
            As_prover.(map2 (read_var a2) (read_var b2) ~f:Field.mul)
        in
        let open Field.Infix in
        let two            = Field.of_int 2 in
        let four           = Field.of_int 4 in
        let beta           = non_residue in
        let beta_inv       = Field.inv beta in
        let eight_beta_inv = Field.of_int 8 * beta_inv in
        let open Constraint in
        let open Cvar.Infix in
        assert_all
          [ r1cs a0 b0 v0
          ; r1cs a2 b2 v4
          ; r1cs
              (Cvar.sum [a0; a1; a2])
              (Cvar.sum [b0; b1; b2])
              (r1 + r2 + beta_inv * r0 + Field.(sub one beta_inv) * v0 + Field.(sub one beta) * v4)
          ; r1cs (a0 - a1 + a2) (b0 - b1 + b2)
              (r2 - r1 + Field.(add one beta_inv) * v0 + beta_inv * r0 + Field.(add one beta) * v4)
          ; r1cs (a0 + two * a1 + four * a2) (b0 + two * b1 + four * b2)
              (two * r1
               + four * r2
               + eight_beta_inv * r0
               + Field.(sub one eight_beta_inv) * v0
               + Field.(sub (of_int 16) (mul two beta)) * v4)
          ]
      ;;

      let mul a b =
        let open Let_syntax in
        let%bind result =
          exists spec
            As_prover.(map2 (read spec a) (read spec b) ~f:mul)
        in
        let%map () = assert_mul a b ~result in
        result
      ;;

      let sqr t = mul t t
      ;;
    end
  end
end

module Fp4  = struct
  module Make
      (M : sig
         val non_residue : Field.t
      end)
  = struct
    type 'a t = 'a * 'a
  end
end

(* Fp6_2over3 ops *)
module Fp6_2_over_3 = struct
  module Make
      (M : sig
         val non_residue : Field.t
         val frobenius_coefficients_c1 : Field.t array

         module Fp2 : Fp2.S

         module Fp3 : sig
           include Fp3.S
           val frobenius_coefficients_c1 : Field.t array
           val frobenius_coefficients_c2 : Field.t array
         end
       end )
    : sig
    open M
    type 'a t = 'a Fp3.t * 'a Fp3.t
    type var = Cvar.t t
    type value = Field.t t

    val spec : (var, value) Var_spec.t

    module Checked : sig
      val one : var
      val zero : var

      val frobenius : var -> int -> var
      val inv : var -> (var, _) Checked.t
      val mul : var -> var -> (var, _) Checked.t
      val mul_by_2345 : var -> var -> (var, _) Checked.t
      val sqr : var -> (var, _) Checked.t
      val cyclotomic_sqr : var -> (var, _) Checked.t
    end
  end
  = struct
    open M

    type 'a t = 'a Fp3.t * 'a Fp3.t
    type var = Cvar.t t
    type value = Field.t t

    let spec = Var_spec.tuple2 Fp3.spec Fp3.spec

    let mul_by_non_residue (c0, c1, c2)= (Field.mul non_residue c2, c0, c1)

    let inv (a, b) =
      let t1 = Fp3.square b in
      let t0 = Fp3.sub (Fp3.square a) (mul_by_non_residue t1) in
      let new_t1 = Fp3.inv t0 in
      Fp3.(mul a new_t1, negate (mul b new_t1))
    ;;

    module Checked = struct
      let one = Fp3.Checked.(one, zero)
      let zero = Fp3.Checked.(zero, zero)

      let frobenius ((a0_0, a0_1, a0_2), (a1_0, a1_1, a1_2)) power =
        let power_mod_3 = power mod 3 in
        let coeff_3_1 = Fp3.frobenius_coefficients_c1.(power_mod_3) in
        let coeff_3_2 = Fp3.frobenius_coefficients_c2.(power_mod_3) in
        let coeff_6_1 = frobenius_coefficients_c1.(power mod 6) in
        let b0 = ( a0_0, Cvar.scale a0_1 coeff_3_1, Cvar.scale a0_2 coeff_3_2 ) in
        let b1 =
          ( Cvar.scale a1_0 coeff_6_1,
            Cvar.scale a1_1
              (Field.mul coeff_6_1 coeff_3_1),
            Cvar.scale a1_2
              (Field.mul coeff_6_1 coeff_3_2 ) )
        in
        (b0, b1)
      ;;

      let mul_by_non_residue (a0, a1, a2) = (Cvar.scale a2 non_residue, a0, a1)

      let mul_by_2345 (((a0_0, a0_1, a0_2) as a0), a1) (((_, _, b0_2) as b0), b1) =
        let open Let_syntax in
        let%bind v0 =
          exists Fp3.spec As_prover.(map2 ~f:Fp3.mul (read Fp3.spec a0) (read Fp3.spec b0))
        in
        let%bind ((v1_0, v1_1, v1_2) as v1) = Fp3.Checked.mul a1 b1 in
        let%bind r1_plus_v0_plus_v1 =
          Fp3.Checked.(mul (add a0 a1) (add b0 b1))
        in
        let one = Field.one in
        let neg_one = Field.negate one in
        let ((r0_0, r0_1, r0_2) as r0) = Fp3.Checked.add v0 (mul_by_non_residue v1) in
        let r1 = Fp3.Checked.(add r1_plus_v0_plus_v1 (scale (add v0 v1) neg_one)) in
        let%map () =
          let open Constraint in
          let open Cvar.Infix in
          assert_all
            [ r1cs a0_1 (Fp3.non_residue * b0_2) (r0_0 - non_residue * v1_2)
            ; r1cs a0_2  (Fp3.non_residue * b0_2) (r0_1 - v1_0)
            ; r1cs a0_0 b0_2 (r0_2 - v1_1)
            ]
        in
        (r0, r1)
      ;;

      let mul (a0, a1) (b0, b1) =
        let open Let_syntax in
        (* TODO: This is a bit less efficient than the libsnark gadget in
           "computing the witness" since they use the result of computing v1 in
           computing v0. *)
        let%map v0             = Fp3.Checked.mul a0 b0
        and v1                 = Fp3.Checked.mul a1 b1
        and r1_plus_v0_plus_v1 = Fp3.Checked.(mul (add a0 a1) (add b0 b1)) in
        let r0                 = Fp3.Checked.add v0 (mul_by_non_residue v1) in
        let r1                 = Fp3.Checked.(
          add r1_plus_v0_plus_v1 (scale (add v0 v1) (Field.negate Field.one)))
        in
        (r0, r1)
      ;;

      let cyclotomic_sqr ((c00, c01, c02), (c10, c11, c12)) =
        let (a0, a1) as a = (c00, c11) in
        let (b0, b1) as b = (c10, c02) in
        let (c0, c1) as c = (c01, c12) in
        let open Let_syntax in
        let%map (asq0, asq1) = Fp2.Checked.sqr a
        and (bsq0, bsq1) = Fp2.Checked.sqr b
        and (csq0, csq1) = Fp2.Checked.sqr c
        in
        let lc = Cvar.linear_combination in
        let ( * ) x y = (Field.of_int x, y) in
        ( ( lc [ 3 * asq0; (-2) * a0 ],
            lc [ 3 * bsq0; (-2) * c0 ],
            lc [ 3 * csq0; (-2) * b1 ] ),
          ( lc [ (Field.(mul (of_int 3) Fp2.non_residue), csq1); 2 * b0 ],
            lc [ 3 * asq1; 2 * a1 ],
            lc [ 3 * bsq1; 2 * c1 ] ) )
      ;;

      let assert_equal (a0, a1) (b0, b1) =
        let open Let_syntax in
        let%map () = Fp3.Checked.assert_equal a0 b0
        and () = Fp3.Checked.assert_equal a1 b1
        in
        ()
      ;;

      (* TODO: Right now this wastes 6(!) constraints on asserting the equality, it won't
         when the unification optimization is implemented. *)
      let inv t =
        let open Let_syntax in
        let%bind t_inv = exists spec As_prover.(map ~f:inv (read spec t)) in
        let%bind product = mul t t_inv in
        let%map () = assert_equal product one in
        t_inv
      ;;

      let sqr x = mul x x
    end
  end
end

end
