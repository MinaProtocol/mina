(* Common gadget helpers *)

open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

(* Conventions used in this interface
 *     1. Functions prefixed with "as_prover_" only happen during proving
 *        and not while creating the constraint system
 *          * These functions are called twice (once during creation of
 *            constraint system and once during proving).  Inside the definition
 *            of these functions, whatever resides within the exists is not executed
 *            during constraint system creation, though there could be some
 *            code outside the exists (such as error checking code) that is
 *            run during the creation of the constraint system.
 *     2. Functions suffixed with "_as_prover" can only be called outside
 *        the circuit.  Specifically, this means within an exists, within
*         an as_prover or in an "as_prover_" prefixed function)
 *)

(* Convert cvar field element (i.e. Field.t) to field *)
let cvar_field_to_field_as_prover (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : Circuit.Field.t) : f =
  Circuit.As_prover.read Circuit.Field.typ field_element

(* Convert field element to a cvar field element *)
let field_to_cvar_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : f) : Circuit.Field.t =
  Circuit.Field.constant field_element

(* field_bits_le_to_field - Create a field element from contiguous bits of another
 *
 *   Inputs:
 *     field_element: source field element
 *     start:         zero-indexed starting bit offset
 *     stop:          zero-indexed stopping bit index (or -1 to denote the last bit)
 *
 *   Output:
 *     New field element created from bits [start, stop) of field_element input,
 *     placed into the lowest possible bit position, like so
 *
 *        start     stop
 *             \   /
 *       [......xxx.....] field_element
 *       [xxx...........] output
 *       lsb          msb *)
let field_bits_le_to_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : f) (start : int) (stop : int) : f =
  let open Circuit in
  (* Check range is valid *)
  if stop <> -1 && stop <= start then
    invalid_arg "stop offset must be greater than start offset" ;

  (* Create field element *)
  let bits = Field.Constant.unpack field_element in
  if stop > List.length bits then
    invalid_arg "stop must be less than bit-length" ;

  let stop = if stop = -1 then List.length bits else stop in
  (* Convert bits range (boolean list) to field element *)
  Field.Constant.project @@ List.slice bits start stop

(* Create cvar field element from contiguous bits of another
     See field_bits_le_to_field for more information *)
let as_prover_cvar_field_bits_le_to_cvar_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : Circuit.Field.t) (start : int) (stop : int) :
    Circuit.Field.t =
  let open Circuit in
  (* Check range is valid - for exception handling we need to repeat this check
   *                        so it happens outside exists *)
  if stop <> -1 && stop <= start then
    invalid_arg "stop offset must be greater than start offset" ;
  exists Field.typ ~compute:(fun () ->
      field_bits_le_to_field
        (module Circuit)
        (cvar_field_to_field_as_prover (module Circuit) field_element)
        start stop )

(* Create field element from base10 string *)
let field_of_base10 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (base10 : string) =
  let open Circuit in
  Field.Constant.of_string base10

(* Create cvar field element from base10 string *)
let as_prover_cvar_field_of_base10 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (base10 : string) =
  let open Circuit in
  exists Field.typ ~compute:(fun () -> field_of_base10 (module Circuit) base10)

(* Convert field element to bigint *)
let field_to_bignum_bigint (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : f) : Bignum_bigint.t =
  (* Bigint doesn't have bigint operators defined for it, so we must use Bignum_bigint *)
  Circuit.Bigint.(to_bignum_bigint (of_field field_element))

(* Convert bigint to field element *)
let bignum_bigint_to_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f =
  Circuit.Bigint.(to_field (of_bignum_bigint bigint))

(* Foreign field element limb size: 2^88 *)
let two_to_limb = Bignum_bigint.(pow (of_int 2) (of_int 88))

(* Returns (quotient, remainder) such that numerator = quotient * denominator + remainder
 * where quotient, remainder \in [0, denominator) *)
let bignum_bigint_div_rem (numerator : Bignum_bigint.t)
    (denominator : Bignum_bigint.t) : Bignum_bigint.t * Bignum_bigint.t =
  let quotient = Bignum_bigint.(numerator / denominator) in
  let remainder = Bignum_bigint.(numerator - (denominator * quotient)) in
  (quotient, remainder)

(* Negative test helper *)
let is_error (func : unit -> _) = Result.is_error (Or_error.try_with func)

let%test_unit "helper field_bits_le_to_field" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  let _proof_keypair, _proof =
    Runner.generate_and_verify_proof (fun () ->
        let open Runner.Impl in
        (* Test value *)
        let field_element =
          exists Field.typ ~compute:(fun () ->
              Field.Constant.of_string
                "25138500177533925254565157548260087092526215225485178888176592492127995051965" )
        in

        let of_bits =
          as_prover_cvar_field_bits_le_to_cvar_field (module Runner.Impl)
        in
        let of_base10 = as_prover_cvar_field_of_base10 (module Runner.Impl) in

        (* Test extracting all bits as field element *)
        Field.Assert.equal (of_bits field_element 0 (-1)) field_element ;

        (* Test extracting 1st bit as field element *)
        Field.Assert.equal (of_bits field_element 0 1) (of_base10 "1") ;

        (* Test extracting last bit as field element *)
        Field.Assert.equal (of_bits field_element 254 255) (of_base10 "0") ;

        (* Test extracting first 12 bits as field element *)
        Field.Assert.equal (of_bits field_element 0 12) (of_base10 "4029") ;

        (* Test extracting third 16 bits as field element *)
        Field.Assert.equal (of_bits field_element 32 48) (of_base10 "15384") ;

        (* Test extracting 1st 4 bits as field element *)
        Field.Assert.equal (of_bits field_element 0 4) (of_base10 "13") ;

        (* Test extracting 5th 4 bits as field element *)
        Field.Assert.equal (of_bits field_element 20 24) (of_base10 "1") ;

        (* Test extracting first 88 bits as field element *)
        Field.Assert.equal
          (of_bits field_element 0 88)
          (of_base10 "155123280218940970272309181") ;

        (* Test extracting second 88 bits as field element *)
        Field.Assert.equal
          (of_bits field_element 88 176)
          (of_base10 "293068737190883252403551981") ;

        (* Test extracting last crumb as field element *)
        Field.Assert.equal (of_bits field_element 254 255) (of_base10 "0") ;

        (* Test extracting 2nd to last crumb as field element *)
        Field.Assert.equal (of_bits field_element 252 254) (of_base10 "3") ;

        (* Test extracting 3rd to last crumb as field element *)
        Field.Assert.equal (of_bits field_element 250 252) (of_base10 "1") ;

        (* Assert litttle-endian order *)
        Field.Assert.equal
          (of_bits (of_base10 "18446744073709551616" (* 2^64 *)) 64 65)
          (of_base10 "1") ;

        (* Test invalid range is denied *)
        assert (is_error (fun () -> of_bits field_element 2 2)) ;
        assert (is_error (fun () -> of_bits field_element 2 1)) ;

        (* Padding *)
        Boolean.Assert.is_true (Field.equal field_element field_element) )
  in
  ()
