(* Elliptic curve public constants *)

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

type 'typ ia_points = { acc : 'typ; neg_acc : 'typ }

(* Out of circuit representation of Elliptic curve *)
type t =
  { modulus : Bignum_bigint.t (* Elliptic curve base field modulus *)
  ; order : Bignum_bigint.t (* Elliptic curve group order *)
  ; a : Bignum_bigint.t (* Elliptic curve a parameter *)
  ; b : Bignum_bigint.t (* Elliptic curve b parameter *)
  ; gen : Affine.bignum_point (* Elliptic curve generator point *)
  ; mutable ia : Affine.bignum_point ia_points
        (* Initial accumulator point (and its negation) *)
  }

let ia_of_points (type typ) (acc : typ * typ) (neg_acc : typ * typ) :
    (typ * typ) ia_points =
  { acc; neg_acc }

let ia_of_strings ((acc_x, acc_y) : string * string)
    ((neg_acc_x, neg_acc_y) : string * string) =
  { acc = (Bignum_bigint.of_string acc_x, Bignum_bigint.of_string acc_y)
  ; neg_acc =
      (Bignum_bigint.of_string neg_acc_x, Bignum_bigint.of_string neg_acc_y)
  }

let ia_to_circuit_constants (type field)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = field)
    (ia : Affine.bignum_point ia_points) : field Affine.t ia_points =
  { acc = Affine.of_bignum_bigint_coordinates (module Circuit) ia.acc
  ; neg_acc = Affine.of_bignum_bigint_coordinates (module Circuit) ia.neg_acc
  }

(* Default, empty curve parameters *)
let default =
  { modulus = Bignum_bigint.zero
  ; order = Bignum_bigint.zero
  ; a = Bignum_bigint.zero
  ; b = Bignum_bigint.zero
  ; gen = (Bignum_bigint.zero, Bignum_bigint.one)
  ; ia =
      { acc = (Bignum_bigint.zero, Bignum_bigint.zero)
      ; neg_acc = (Bignum_bigint.zero, Bignum_bigint.zero)
      }
  }

(* In circuit representation of Elliptic curve (public constants) *)
module InCircuit = struct
  type parent_t = t

  type 'field t =
    { bignum : parent_t
    ; modulus : 'field Foreign_field.standard_limbs
    ; order : 'field Foreign_field.standard_limbs
    ; order_bit_length : int
    ; order_minus_one : 'field Foreign_field.Element.Standard.t
    ; order_minus_one_bits :
        'field Snarky_backendless.Cvar.t Snark_intf.Boolean0.t list
    ; a : 'field Foreign_field.Element.Standard.t
    ; b : 'field Foreign_field.Element.Standard.t
    ; gen : 'field Affine.t
    ; doubles : 'field Affine.t array
    ; ia : 'field Affine.t ia_points
    }
end

let double_bignum_point (curve : t) (point : Affine.bignum_point) :
    Bignum_bigint.t * Affine.bignum_point =
  let point_x, point_y = point in
  (* Compute slope using 1st derivative of sqrt(x^3 + a * x + b)
     * Note that when a = 0 (e.g. as in the case of secp256k1) we have
     * one fewer constraint (below).
  *)
  let slope =
    Bignum_bigint.(
      (* Computes s' = (3 * Px^2  + a )/ 2 * Py *)
      let numerator =
        let point_x_squared = pow point_x (of_int 2) % curve.modulus in
        let point_x3_squared = of_int 3 * point_x_squared % curve.modulus in

        (point_x3_squared + curve.a) % curve.modulus
      in
      let denominator = of_int 2 * point_y % curve.modulus in

      (* Compute inverse of denominator *)
      let denominator_inv =
        Common.bignum_bigint_inverse denominator curve.modulus
      in
      numerator * denominator_inv % curve.modulus)
  in

  let slope_squared = Bignum_bigint.((pow slope @@ of_int 2) % curve.modulus) in

  (* Compute result's x-coodinate: x = s^2 - 2 * Px *)
  let result_x =
    Bignum_bigint.(
      let point_x2 = of_int 2 * point_x % curve.modulus in
      (slope_squared - point_x2) % curve.modulus)
  in

  (* Compute result's y-coodinate: y = s * (Px - x) - Py *)
  let result_y =
    Bignum_bigint.(
      let x_diff = (point_x - result_x) % curve.modulus in
      let x_diff_s = slope * x_diff % curve.modulus in
      (x_diff_s - point_y) % curve.modulus)
  in

  (slope, (result_x, result_y))

let to_circuit_constants (type field)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = field)
    (curve : t) : field InCircuit.t =
  (* Need to know native field size before we can check if it fits *)
  Foreign_field.check_modulus_bignum_bigint (module Circuit) curve.modulus ;
  Foreign_field.check_modulus_bignum_bigint (module Circuit) curve.order ;
  let order_bit_length = Common.bignum_bigint_bit_length curve.order in
  let order_minus_one =
    Bignum_bigint.(if curve.order > zero then curve.order - one else zero)
  in
  InCircuit.
    { bignum = curve
    ; modulus =
        Foreign_field.bignum_bigint_to_field_standard_limbs
          (module Circuit)
          curve.modulus
    ; order =
        Foreign_field.bignum_bigint_to_field_standard_limbs
          (module Circuit)
          curve.order
    ; order_bit_length
    ; order_minus_one =
        Foreign_field.Element.Standard.of_bignum_bigint
          (module Circuit)
          order_minus_one
    ; order_minus_one_bits =
        Common.bignum_bigint_unpack_unconstrained_cvars
          (module Circuit)
          order_minus_one
    ; a =
        Foreign_field.Element.Standard.of_bignum_bigint (module Circuit) curve.a
    ; b =
        Foreign_field.Element.Standard.of_bignum_bigint (module Circuit) curve.b
    ; gen = Affine.of_bignum_bigint_coordinates (module Circuit) curve.gen
    ; doubles =
        ((* Precompute 2^i * curve.gen, 0 <= i < curve.order_bit_length *)
         let doubles =
           Array.init order_bit_length (fun _i ->
               Affine.as_prover_zero (module Circuit) )
         in
         let point = ref curve.gen in
         for i = 0 to order_bit_length - 1 do
           let _slope, double = double_bignum_point curve !point in
           point := double ;
           doubles.(i) <-
             Affine.of_bignum_bigint_coordinates (module Circuit) !point
         done ;
         doubles )
    ; ia =
        { acc =
            Affine.of_bignum_bigint_coordinates (module Circuit) curve.ia.acc
        ; neg_acc =
            Affine.of_bignum_bigint_coordinates
              (module Circuit)
              curve.ia.neg_acc
        }
    }
