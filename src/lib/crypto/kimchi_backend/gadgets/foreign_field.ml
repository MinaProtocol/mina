(* open Core_kernel *)

(* open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint *)

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(* Foreign field element limb size *)
let limb_bits = 88

(* Foreign field element limb size 2^L where L=88 *)
let two_to_limb = Bignum_bigint.(pow (of_int 2) (of_int limb_bits))

(* 2^2L *)
let two_to_2limb = Bignum_bigint.(pow (of_int 2) (of_int Int.(mul 2 limb_bits)))

(* 2^3L *)
let two_to_3limb = Bignum_bigint.(pow (of_int 2) (of_int Int.(mul 3 limb_bits)))

(* Binary modulus *)
let binary_modulus = two_to_3limb

(* Foreign_field_element type - foreign field elemenet over a generic field 'f
 *   It has 3 possible configurations:
 *     - Extended mode : 4 limbs of L-bits each, used by bound addition (i.e. Matthew's trick)
 *     - Normal mode : 3 limbs of L-bits each
 *     - Compact mode : 2 limbs where the lowest of 2L bits and the highest is L bits *)
module Foreign_field_element : sig
  type 'f t

  (* Create foreign field element from 4 limbs of 88 bits *)
  val of_extended_limbs : 'f * 'f * 'f * 'f -> 'f t

  (* Create foreign field element from 3 limbs of 88 bits *)
  val of_limbs :
    'f. (module Snark_intf.Run with type field = 'f) -> 'f * 'f * 'f -> 'f t

  (* Create foreign field element from 2 limbs: lowest of 2L bits and highest of L bits *)
  val of_compact_limbs :
    'f. (module Snark_intf.Run with type field = 'f) -> 'f * 'f -> 'f t

  (* Create foreign field element from biguint <= binary_modulus *)
  val of_bignum_bigint :
    'f. (module Snark_intf.Run with type field = 'f) -> Bignum_bigint.t -> 'f t

  (* Convert an extended foreign field element into tuple of 4 field limbs *)
  val to_extended_limbs : 'f t -> 'f * 'f * 'f * 'f

  (* Convert a foreign field element into tuple of 3 field limbs *)
  val to_limbs : 'f t -> 'f * 'f * 'f

  (* Convert a compact foreign field element into tuple of 2 field limbs *)
  val to_compact_limbs : 'f t -> 'f * 'f

  (* Convert foreign field element into Bignum_biguint *)
  val to_bignum_bigint :
    'f. (module Snark_intf.Run with type field = 'f) -> 'f t -> Bignum_bigint.t
end = struct
  type 'f t = 'f * 'f * 'f * 'f

  let of_extended_limbs x = x

  let of_limbs (type f) (module Circuit : Snark_intf.Run with type field = f)
      (limb0, limb1, limb2) =
    of_extended_limbs (limb0, limb1, limb2, Circuit.Field.Constant.zero)

  let of_compact_limbs (type f)
      (module Circuit : Snark_intf.Run with type field = f) (limb0, limb1) =
    of_extended_limbs
      (limb0, limb1, Circuit.Field.Constant.zero, Circuit.Field.Constant.zero)

  let of_bignum_bigint (type f)
      (module Circuit : Snark_intf.Run with type field = f) bigint =
    assert (bigint <= binary_modulus) ;
    let limb123, limb0 = Common.bignum_bigint_div_rem bigint two_to_limb in
    let limb23, limb1 = Common.bignum_bigint_div_rem limb123 two_to_limb in
    let limb3, limb2 = Common.bignum_bigint_div_rem limb23 two_to_limb in
    let limb0 = Common.bignum_bigint_to_field (module Circuit) limb0 in
    let limb1 = Common.bignum_bigint_to_field (module Circuit) limb1 in
    let limb2 = Common.bignum_bigint_to_field (module Circuit) limb2 in
    let limb3 = Common.bignum_bigint_to_field (module Circuit) limb3 in
    of_extended_limbs (limb0, limb1, limb2, limb3)

  let to_extended_limbs x = x

  let to_limbs foreign_field_element =
    let limb0, limb1, limb2, _limb3 = to_extended_limbs foreign_field_element in
    (limb0, limb1, limb2)

  let to_compact_limbs foreign_field_element =
    let limb0, limb1, _limb2, _limb3 =
      to_extended_limbs foreign_field_element
    in
    (limb0, limb1)

  let to_bignum_bigint (type f)
      (module Circuit : Snark_intf.Run with type field = f)
      foreign_field_element =
    let limb0, limb1, limb2, limb3 = to_extended_limbs foreign_field_element in
    let limb0 = Common.field_to_bignum_bigint (module Circuit) limb0 in
    let limb1 = Common.field_to_bignum_bigint (module Circuit) limb1 in
    let limb2 = Common.field_to_bignum_bigint (module Circuit) limb2 in
    let limb3 = Common.field_to_bignum_bigint (module Circuit) limb3 in
    Bignum_bigint.(
      limb0 + (two_to_limb * limb1) + (two_to_2limb * limb2)
      + (two_to_3limb * limb3))
end

let foreign_field_mul (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (left_input : Circuit.Field.t Foreign_field_element.t)
    (_right_input : Circuit.Field.t Foreign_field_element.t)
    (_foreign_modulus : Circuit.Field.t Foreign_field_element.t) =
  let _left_input0, _left_input1, _left_input2, _left_input3 =
    Foreign_field_element.to_extended_limbs left_input
  in
  ()

(* type compact_type = |

   type standard = |

   type extended = |

   type ('limb_value, 'limb_type) limb =
     | Compact : 'f * 'f -> ('f, compact_type) limb
     | Standard : 'f * 'f * 'f -> ('f, standard) limb
     | Extended : 'f * 'f * 'f * 'f -> ('f, extended) limb

   type 'a my_specific_limb = (int, 'a) limb

   let fst : type b. b my_specific_limb -> int = function
     | Compact (a, _) ->
         a
     | Standard (a, _, _) ->
         a
     | Extended (a, _, _, _) ->
         a
   ;;

   fst (Compact (1, 1))

   type 'a limb' = Compact of 'a | O of int

   let foo (Compact x) = x;;

   foo (O 1)

   type 'f compact_limb = 'f * 'f

   type 'f standard_limb = 'f * 'f * 'f

   type 'f extended_limb = 'f * 'f * 'f * 'f

   type 'a limb =
     | Compact of 'a * 'a (\* -> 'a limb *\)
     | Standard of 'a standard_limb (\* -> 'a limb *\)
     | Extended of 'a extended_limb (\* -> 'a limb *\)

   let fst = function
     | Compact (a, _) | Standard (a, _, _) | Extended (a, _, _, _) ->
         a
   type compact_type = |

   type standard = |

   type extended = |

   type ('limb_value, 'limb_type) limb =
     | Compact : 'f * 'f -> ('f, compact_type) limb
     | Standard : 'f * 'f * 'f -> ('f, standard) limb
     | Extended : 'f * 'f * 'f * 'f -> ('f, extended) limb

   type 'a my_specific_limb = (int, 'a) limb

   let fst : type b. b my_specific_limb -> int = function
     | Compact (a, _) ->
         a
     | Standard (a, _, _) ->
         a
     | Extended (a, _, _, _) ->
         a
   ;;

   fst (Compact (1, 1))

   type 'a limb' = Compact of 'a | O of int

   let foo (Compact x) = x;;

   foo (O 1)

   type 'f compact_limb = 'f * 'f

   type 'f standard_limb = 'f * 'f * 'f

   type 'f extended_limb = 'f * 'f * 'f * 'f

   type 'a limb =
     | Compact of 'a * 'a (\* -> 'a limb *\)
     | Standard of 'a standard_limb (\* -> 'a limb *\)
     | Extended of 'a extended_limb (\* -> 'a limb *\)

   let fst = function
     | Compact (a, _) | Standard (a, _, _) | Extended (a, _, _, _) ->
         a

   (\* Foreign_field_element type - foreign field elemenet over a generic field 'f
    *   It has 3 possible configurations:
    *     - Extended mode : 4 limbs of L-bits each, used by bound addition (i.e. Matthew's trick)
    *     - Normal mode : 3 limbs of L-bits each
    *     - Compact mode : 2 limbs where the lowest of 2L bits and the highest is L bits *\)
   module Foreign_field_element : sig
     type 'f t

     (\* Create foreign field element from 4 limbs of 88 bits *\)
     val of_extended_limbs : ('f, extended) limb -> 'f t

     (\* Create foreign field element from 3 limbs of 88 bits *\)
     val of_limbs :
       'f.
       (module Snark_intf.Run with type field = 'f) -> ('f, standard) limb -> 'f t

     (\* Create foreign field element from 2 limbs: lowest of 2L bits and highest of L bits *\)
     val of_compact_limbs :
       'f.
          (module Snark_intf.Run with type field = 'f)
       -> ('f, compact_type) limb
       -> 'f t

     (\* Create foreign field element from biguint <= binary_modulus *\)
     val of_bignum_bigint :
       'f. (module Snark_intf.Run with type field = 'f) -> Bignum_bigint.t -> 'f t

     (\* Convert an extended foreign field element into tuple of 4 field limbs *\)
     val to_extended_limbs : 'f t -> ('f, extended) limb

     (\* Convert a foreign field element into tuple of 3 field limbs *\)
     val to_limbs : 'f t -> ('f, standard) limb

     (\* Convert a compact_type foreign field element into tuple of 2 field limbs *\)
     val to_compact_limbs : 'f t -> ('f, compact_type) limb

     (\* Convert foreign field element into Bignum_biguint *\)
     val to_bignum_bigint :
       'f. (module Snark_intf.Run with type field = 'f) -> 'f t -> Bignum_bigint.t
   end = struct
     type 'f t = ('f, extended) limb

     let of_extended_limbs x = x

     let of_limbs (type f) (module Circuit : Snark_intf.Run with type field = f)
         (Standard (limb0, limb1, limb2)) =
       of_extended_limbs (limb0, limb1, limb2, Circuit.Field.Constant.zero)

     let of_compact_limbs (type f)
         (module Circuit : Snark_intf.Run with type field = f)
         (Compact (limb0, limb1)) =
       of_extended_limbs
         (Extended
            (limb0, limb1, Circuit.Field.Constant.zero, Circuit.Field.Constant.zero)
         )

     let of_bignum_bigint (type f)
         (module Circuit : Snark_intf.Run with type field = f) bigint =
       assert (bigint <= binary_modulus) ;
       let limb123, limb0 = Common.bignum_bigint_div_rem bigint two_to_limb in
       let limb23, limb1 = Common.bignum_bigint_div_rem limb123 two_to_limb in
       let limb3, limb2 = Common.bignum_bigint_div_rem limb23 two_to_limb in
       let limb0 = Common.bignum_bigint_to_field (module Circuit) limb0 in
       let limb1 = Common.bignum_bigint_to_field (module Circuit) limb1 in
       let limb2 = Common.bignum_bigint_to_field (module Circuit) limb2 in
       let limb3 = Common.bignum_bigint_to_field (module Circuit) limb3 in
       of_extended_limbs (Extended (limb0, limb1, limb2, limb3))

     let to_extended_limbs x = x

     let to_limbs (Extended (limb0, limb1, limb2, _limb3)) =
       Standard (limb0, limb1, limb2)

     let to_compact_limbs (Extended (limb0, limb1, _limb2, _limb3)) =
       Compact (limb0, limb1)

     let to_bignum_bigint (type f)
         (module Circuit : Snark_intf.Run with type field = f)
         foreign_field_element =
       let limb0, limb1, limb2, limb3 = foreign_field_element in
       let limb0 = Common.field_to_bignum_bigint (module Circuit) limb0 in
       let limb1 = Common.field_to_bignum_bigint (module Circuit) limb1 in
       let limb2 = Common.field_to_bignum_bigint (module Circuit) limb2 in
       let limb3 = Common.field_to_bignum_bigint (module Circuit) limb3 in
       Bignum_bigint.(
         limb0 + (two_to_limb * limb1) + (two_to_2limb * limb2)
         + (two_to_3limb * limb3))
   end

   let foreign_field_mul (type f)
       (module Circuit : Snark_intf.Run with type field = f)
       (left_input : f Foreign_field_element.t)
       (_right_input : f Foreign_field_element.t)
       (_foreign_modulus : f Foreign_field_element.t) =
     let _left_input0, _left_input1, _left_input2, _left_input3 =
       Foreign_field_element.to_extended_limbs left_input
     in
     () *)
