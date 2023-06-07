(* Common gadget helpers *)

open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

let tests_enabled = true

let tuple3_of_array array =
  match array with [| a1; a2; a3 |] -> (a1, a2, a3) | _ -> assert false

let tuple4_of_array array =
  match array with
  | [| a1; a2; a3; a4 |] ->
      (a1, a2, a3, a4)
  | _ ->
      assert false

(* Foreign field element limb size *)
let limb_bits = 88

(* Foreign field element limb size 2^L where L=88 *)
let two_to_limb = Bignum_bigint.(pow (of_int 2) (of_int limb_bits))

(* 2^3L *)
let two_to_3limb = Bignum_bigint.(pow two_to_limb (of_int 3))

(* Length of Bignum_bigint.t in bits *)
let bignum_bigint_bit_length (bigint : Bignum_bigint.t) : int =
  if Bignum_bigint.(equal bigint zero) then 1
  else Z.log2 (Bignum_bigint.to_zarith_bigint bigint) + 1

(* Conventions used in this interface
 *     1. Functions prefixed with "as_prover_" only happen during proving
 *        and not during circuit creation
 *          * These functions are called twice (once during creation of
 *            the circuit and once during proving).  Inside the definition
 *            of these functions, whatever resides within the exists is not executed
 *            during circuit creation, though there could be some
 *            code outside the exists (such as error checking code) that is
 *            run during the creation of the circuit.
 *          * The value returned by exists depends on what mode it is called in
 *              * In circuit generation mode it allocates a cvar without any backing memory
 *              * In proof generation mode it allocates a cvar with backing memory to store
 *                the values associated with the cvar. The prover can then access these
 *                with As_prover.read.
 *     2. Functions suffixed with "_as_prover" can only be called outside
 *        the circuit. Specifically, this means within an exists, within
 *        an as_prover or in an "as_prover_" prefixed function)
 *)

(* Convert cvar field element (i.e. Field.t) to field *)
let cvar_field_to_field_as_prover (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : Circuit.Field.t) : f =
  Circuit.As_prover.read Circuit.Field.typ field_element

(* Convert cvar boolean element (i.e. Boolean.t) to field *)
let cvar_bool_to_bool_as_prover (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bool : Circuit.Boolean.var) : bool =
  Circuit.As_prover.read Circuit.Boolean.typ bool

(* Combines bits of two cvars with a given boolean function and returns the resulting field element *)
let cvar_field_bits_combine_as_prover (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t)
    (bfun : bool -> bool -> bool) : f =
  let open Circuit in
  let list1 =
    Field.Constant.unpack
    @@ cvar_field_to_field_as_prover (module Circuit)
    @@ input1
  in
  let list2 =
    Field.Constant.unpack
    @@ cvar_field_to_field_as_prover (module Circuit)
    @@ input2
  in
  Field.Constant.project @@ List.map2_exn list1 list2 ~f:bfun

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

(* Returns (quotient, remainder) such that numerator = quotient * denominator + remainder
 * where quotient, remainder \in [0, denominator) *)
let bignum_bigint_div_rem (numerator : Bignum_bigint.t)
    (denominator : Bignum_bigint.t) : Bignum_bigint.t * Bignum_bigint.t =
  let quotient = Bignum_bigint.(numerator / denominator) in
  let remainder = Bignum_bigint.(numerator - (denominator * quotient)) in
  (quotient, remainder)

(* Bignum_bigint to bytes *)
let bignum_bigint_unpack_bytes (bignum : Bignum_bigint.t) : string =
  Z.to_bits @@ Bignum_bigint.to_zarith_bigint bignum

(* Bignum_bigint to bool list *)
let bignum_bigint_unpack ?(remove_trailing = false) (bignum : Bignum_bigint.t) :
    bool list =
  (* Helper to remove trailing false *)
  let remove_trailing_false (lst : bool list) =
    let rev = List.rev lst in
    let rec remove_leading_false_rec lst =
      match lst with
      | [] ->
          []
      | hd :: tl ->
          if hd then hd :: tl else remove_leading_false_rec tl
    in
    List.rev @@ remove_leading_false_rec rev
  in

  (* Convert biguint to bitstring *)
  let bitstr = Z.to_bits @@ Bignum_bigint.to_zarith_bigint bignum in
  (* Convert bitstring to list of bool *)
  let bits =
    List.init
      (8 * String.length bitstr)
      ~f:(fun i ->
        let c = Char.to_int bitstr.[i / 8] in
        let j = i mod 8 in
        if Int.((c lsr j) land 1 = 1) then true else false )
  in
  if remove_trailing then remove_trailing_false bits else bits

let bignum_bigint_unpack_as (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(remove_trailing = false) (bignum : Bignum_bigint.t)
    (typ : (Circuit.Boolean.var, bool) Circuit.Typ.t) : Circuit.Boolean.var list
    =
  let open Circuit in
  (* printf "scalar = %s\n" @@ Bignum_bigint.to_string bignum ;
     printf "length = %d\n" @@ bignum_bigint_bit_length bignum ; *)
  exists
    (Typ.list ~length:(bignum_bigint_bit_length bignum) typ)
    ~compute:(fun () -> bignum_bigint_unpack ~remove_trailing bignum)

let bignum_bigint_unpack_as_vars (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(remove_trailing = false) (bignum : Bignum_bigint.t) :
    Circuit.Boolean.var list =
  bignum_bigint_unpack_as
    (module Circuit)
    ~remove_trailing bignum Circuit.Boolean.typ

let bignum_bigint_unpack_as_unchecked_vars (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(remove_trailing = false) (bignum : Bignum_bigint.t) :
    Circuit.Boolean.var list =
  bignum_bigint_unpack_as
    (module Circuit)
    ~remove_trailing bignum Circuit.Boolean.typ_unchecked

(* Bignum_bigint to constatnts Boolean.var list (without creating boolean constraints) *)
let bignum_bigint_unpack_as_unchecked_consts (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(remove_trailing = false) (bignum : Bignum_bigint.t) :
    Circuit.Boolean.var list =
  let open Circuit in
  (* TODO: Change to  Boolean.var_of_value bool   .... Boolean.var_of_t *)
  List.map (bignum_bigint_unpack ~remove_trailing bignum) ~f:(fun bool ->
      if bool then Boolean.true_ else Boolean.false_ )

(* Bignum_bigint to hex *)
let bignum_bigint_to_hex (bignum : Bignum_bigint.t) : string =
  Z.format "%x" @@ Bignum_bigint.to_zarith_bigint bignum

(* Create Bignum_bigint.t from binary string *)
let bignum_bigint_of_bin (bin : string) : Bignum_bigint.t =
  Bignum_bigint.of_zarith_bigint @@ Z.of_bits bin

(* Bignum_bigint.t of hex *)
let bignum_bigint_of_hex (hex : string) : Bignum_bigint.t =
  Bignum_bigint.of_zarith_bigint @@ Z.of_string_base 16 hex

(* Convert cvar field element (i.e. Field.t) to Bignum_bigint.t *)
let cvar_field_to_bignum_bigint_as_prover (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : Circuit.Field.t) : Bignum_bigint.t =
  let open Circuit in
  field_to_bignum_bigint (module Circuit)
  @@ As_prover.read Field.typ field_element

(* Compute modular square root using Tonelli-Shanks algorithm
 *   See https://en.wikipedia.org/wiki/Tonelli%E2%80%93Shanks_algorithm
 *)
let bignum_bigint_sqrt_mod (x : Bignum_bigint.t) (modulus : Bignum_bigint.t) :
    Bignum_bigint.t =
  let open Z in
  let x = Bignum_bigint.to_zarith_bigint x in
  let modulus = Bignum_bigint.to_zarith_bigint modulus in

  (* Useful helpers and shorthands *)
  let two = of_int 2 in
  let mod_minus_1 = pred modulus in
  let pow_mod base exp = powm base exp modulus in

  (* Euler's criterion *)
  let legendre x = pow_mod x (mod_minus_1 / two) in

  if not (equal (legendre x) one) then
    (* t = 0: x is quadratic residue iff x^{(modulus - 1)/2} == 1 *)
    Bignum_bigint.zero
  else
    (* Solve: modulus - 1 = Q * 2^S for S *)
    let s = of_int @@ trailing_zeros mod_minus_1 in
    if equal s one then
      (* Q = (modulus - 1)/2 and r = x^{(Q + 1)/2} *)
      Bignum_bigint.of_zarith_bigint
      @@ pow_mod x (((mod_minus_1 / two) + one) / two)
    else
      (* Solve: modulus - 1 = Q * 2^S for Q by shifting away zeros *)
      let q = mod_minus_1 asr to_int s in

      (* Search for z in Z/pZ which is a quadratic non-residue *)
      let z =
        let rec find_non_square z =
          if equal (legendre z) mod_minus_1 then z
          else find_non_square @@ (z + one)
        in
        find_non_square two
      in

      (* Solving loop *)
      let rec loop m c t r =
        if equal t one then r
        else
          (* Use repeated squaring to find the least 0 < i < M s.t. t^{2^i} = 1 *)
          let rec find_least_i n i =
            if equal n one || geq i m then i
            else find_least_i (n * n mod modulus) (i + one)
          in
          let i = find_least_i t zero in

          (* b <- c^{2^{M - i}} *)
          let b = pow_mod c (pow_mod two (m - i - one)) in
          (* M <- i *)
          let m = i in
          (* c <- b^2 *)
          let c = b * b mod modulus in
          (* t <- tb^2 *)
          let t = t * c in
          (* R <- Rb *)
          let r = r * b in

          (* Recurse *)
          loop m c t r
      in

      (* M <- S *)
      let m = s in
      (* c <- Z^Q *)
      let c = pow_mod z q in
      (* t <- x^Q *)
      let t = pow_mod x ((q + one) / two) in
      (* R <- n^{(Q + 1)/2} *)
      let r = pow_mod x q in

      Bignum_bigint.of_zarith_bigint @@ loop m c t r

(* Compute square root of Bignum_bigint value x *)
let bignum_biguint_sqrt (x : Bignum_bigint.t) : Bignum_bigint.t =
  Bignum_bigint.of_zarith_bigint @@ Z.sqrt @@ Bignum_bigint.to_zarith_bigint x

(* Compute the inverse of Bignum_bigint value x with modulus *)
let bignum_bigint_inverse (x : Bignum_bigint.t) (modulus : Bignum_bigint.t) :
    Bignum_bigint.t =
  let x = Bignum_bigint.to_zarith_bigint x in
  let modulus = Bignum_bigint.to_zarith_bigint modulus in
  Bignum_bigint.of_zarith_bigint @@ Z.invert x modulus

(* Field to hex *)
let field_to_hex (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : f) : string =
  bignum_bigint_to_hex @@ field_to_bignum_bigint (module Circuit) field_element

(* Field of hex *)
let field_of_hex (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (hex : string) : f =
  bignum_bigint_to_field (module Circuit) @@ bignum_bigint_of_hex hex

(* Negative test helper *)
let is_error (func : unit -> _) = Result.is_error (Or_error.try_with func)

(*********)
(* Tests *)
(*********)

let%test_unit "helper field_bits_le_to_field" =
  ( if tests_enabled then
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          let of_bits =
            as_prover_cvar_field_bits_le_to_cvar_field (module Runner.Impl)
          in
          let of_base10 = as_prover_cvar_field_of_base10 (module Runner.Impl) in

          (* Test value *)
          let field_element =
            of_base10
              "25138500177533925254565157548260087092526215225485178888176592492127995051965"
          in

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
    () ) ;
  ()
