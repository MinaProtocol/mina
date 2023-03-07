(* Common gadget helpers *)

open Core_kernel

(* field_bits_to_field - Create a field element from contiguous bits of another
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
 *       [...........xxx] output
 *       msb          lsb
 *)
let field_bits_to_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_element : Circuit.Field.t) (start : int) (stop : int) =
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
      let stop = if stop = -1 then List.length bits - 1 else stop in
      (* Convert bits range (boolean list) to field element *)
      Field.Constant.project @@ List.take (List.drop bits start) (stop - start) )

(* Create field element from base10 string *)
let field_from_base10 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (base10 : string) =
  let open Circuit in
  exists Field.typ ~compute:(fun () -> Field.Constant.of_string base10)

let%test_unit "helper field_bits_to_field" =
  Printf.printf "field_bits_to_field test\n" ;
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

        (* Test extracting all bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 0 (-1))
          field_element ;

        (* Test extracting 1st bit as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 0 1)
          (field_from_base10 (module Runner.Impl) "1") ;

        (* Test extracting last bit as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 255 256)
          (field_from_base10 (module Runner.Impl) "0") ;

        (* Test extracting first 12 bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 0 12)
          (field_from_base10 (module Runner.Impl) "4029") ;

        (* Test extracting third 16 bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 32 48)
          (field_from_base10 (module Runner.Impl) "15384") ;

        (* Test extracting 1st 4 bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 0 4)
          (field_from_base10 (module Runner.Impl) "13") ;

        (* Test extracting 5th 4 bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 20 24)
          (field_from_base10 (module Runner.Impl) "1") ;

        (* Test extracting first 88 bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 0 88)
          (field_from_base10 (module Runner.Impl) "155123280218940970272309181") ;

        (* Test extracting second 88 bits as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 88 176)
          (field_from_base10 (module Runner.Impl) "293068737190883252403551981") ;

        (* Test extracting last crumb as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 254 256)
          (field_from_base10 (module Runner.Impl) "0") ;

        (* Test extracting 2nd to last crumb as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 252 254)
          (field_from_base10 (module Runner.Impl) "3") ;

        (* Test extracting 3rd to last crumb as field element *)
        Field.Assert.equal
          (field_bits_to_field (module Runner.Impl) field_element 250 252)
          (field_from_base10 (module Runner.Impl) "1") ;

        (* Test invalid range is denied *)
        assert (
          Bool.equal
            ( try
                let _x =
                  field_bits_to_field (module Runner.Impl) field_element 2 2
                in
                true
              with _ -> false )
            false ) ;

        (* Test invalid range is denied *)
        assert (
          Bool.equal
            ( try
                let _x =
                  field_bits_to_field (module Runner.Impl) field_element 2 1
                in
                true
              with _ -> false )
            false ) ;

        (* Padding *)
        Boolean.Assert.is_true (Field.equal field_element field_element) )
  in
  ()
