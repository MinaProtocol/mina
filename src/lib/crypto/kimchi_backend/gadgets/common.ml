(* Common gadget helpers *)

open Core_kernel

(* pad_upto - Pad a list with a value until it reaches a given length *)
let pad_upto ~length ~value list =
  let len = List.length list in
  assert (len <= length) ;
  let padding = List.init (length - len) ~f:(fun _ -> value) in
  list @ padding

(* field_bits_le_to_field - Create a field element from contiguous bits of another
 *
 *   Inputs:
 *     field_element: source field element
 *     start:         zero-indexed starting bit offset (or -1 to denote the last bit)
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
 *       lsb          msb
 *)
let field_bits_le_to_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : Circuit.Field.t) (start : int) (stop : int) :
    Circuit.Field.t =
  let open Circuit in
  (* Check range is valid *)
  if stop <> -1 && stop <= start then
    invalid_arg "stop offset must be greater than start offset" ;

  (* Create field element *)
  exists Field.typ ~compute:(fun () ->
      (* Convert field element to bits (boolean list) *)
      let bits =
        Field.Constant.unpack @@ As_prover.read Field.typ field_element
      in
      if stop > List.length bits then
        invalid_arg "stop must be less than bit-length" ;

      let stop = if stop = -1 then List.length bits else stop in
      (* Convert bits range (boolean list) to field element *)
      Field.Constant.project @@ List.slice bits start stop )

(* Create field element from base10 string *)
let field_from_base10 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (base10 : string) =
  let open Circuit in
  exists Field.typ ~compute:(fun () -> Field.Constant.of_string base10)

let%test_unit "helper field_bits_le_to_field" =
  Printf.printf "field_bits_le_to_field test\n" ;
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* TODO: lazy? Initialize the SRS cache. *)
  let () = Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] in
  let _proof_keypair, _proof =
    Runner.generate_and_verify_proof (fun () ->
        let open Runner.Impl in
        (* Test value *)
        let field_element =
          exists Field.typ ~compute:(fun () ->
              Field.Constant.of_string
                "25138500177533925254565157548260087092526215225485178888176592492127995051965" )
        in

        (* Define a couple shorthand helpers *)
        let bits_le_to_field = field_bits_le_to_field (module Runner.Impl) in
        let from_base10 = field_from_base10 (module Runner.Impl) in

        (* Test extracting all bits as field element *)
        Field.Assert.equal (bits_le_to_field field_element 0 (-1)) field_element ;

        (* Test extracting 1st bit as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 0 1)
          (from_base10 "1") ;

        (* Test extracting last bit as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 254 255)
          (from_base10 "0") ;

        (* Test extracting first 12 bits as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 0 12)
          (from_base10 "4029") ;

        (* Test extracting third 16 bits as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 32 48)
          (from_base10 "15384") ;

        (* Test extracting 1st 4 bits as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 0 4)
          (from_base10 "13") ;

        (* Test extracting 5th 4 bits as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 20 24)
          (from_base10 "1") ;

        (* Test extracting first 88 bits as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 0 88)
          (from_base10 "155123280218940970272309181") ;

        (* Test extracting second 88 bits as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 88 176)
          (from_base10 "293068737190883252403551981") ;

        (* Test extracting last crumb as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 254 255)
          (from_base10 "0") ;

        (* Test extracting 2nd to last crumb as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 252 254)
          (from_base10 "3") ;

        (* Test extracting 3rd to last crumb as field element *)
        Field.Assert.equal
          (bits_le_to_field field_element 250 252)
          (from_base10 "1") ;

        (* Assert litttle-endian order *)
        Field.Assert.equal
          (field_bits_le_to_field
             (module Runner.Impl)
             (from_base10 "18446744073709551616" (* 2^64 *))
             64 65 )
          (from_base10 "1") ;

        (* Test invalid range is denied *)
        assert (
          Bool.equal
            ( try
                let _x = bits_le_to_field field_element 2 2 in
                true
              with _ -> false )
            false ) ;

        (* Test invalid range is denied *)
        assert (
          Bool.equal
            ( try
                let _x = bits_le_to_field field_element 2 1 in
                true
              with _ -> false )
            false ) ;

        (* Padding *)
        Boolean.Assert.is_true (Field.equal field_element field_element) )
  in
  ()
