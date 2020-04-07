open Core_kernel

type ('field, 'bool) t =
  {field_elements: 'field array; bitstrings: 'bool list array}
[@@deriving sexp]

let append t1 t2 =
  { field_elements= Array.append t1.field_elements t2.field_elements
  ; bitstrings= Array.append t1.bitstrings t2.bitstrings }

let field_elements x = {field_elements= x; bitstrings= [||]}

let field x = {field_elements= [|x|]; bitstrings= [||]}

let bitstring x = {field_elements= [||]; bitstrings= [|x|]}

let bitstrings x = {field_elements= [||]; bitstrings= x}

let pack_to_fields ~size_in_bits ~pack {field_elements; bitstrings} =
  let max_size = size_in_bits - 1 in
  let rec pack_full_fields rev_fields bits length =
    if length >= max_size then
      let field_bits, bits = List.split_n bits max_size in
      pack_full_fields (pack field_bits :: rev_fields) bits (length - max_size)
    else (rev_fields, bits, length)
  in
  let packed_bits =
    let packed_field_elements, remaining_bits, remaining_length =
      Array.fold bitstrings ~init:([], [], 0)
        ~f:(fun (acc, bits, n) bitstring ->
          let n = n + List.length bitstring in
          let bits = bits @ bitstring in
          let acc, bits, n = pack_full_fields acc bits n in
          (acc, bits, n) )
    in
    if remaining_length = 0 then packed_field_elements
    else pack remaining_bits :: packed_field_elements
  in
  Array.append field_elements (Array.of_list_rev packed_bits)

let to_bits ~unpack {field_elements; bitstrings} =
  let field_bits = Array.map ~f:unpack field_elements in
  List.concat @@ Array.to_list @@ Array.append field_bits bitstrings

let%test_module "random_oracle input" =
  ( module struct
    let gen_input =
      let open Quickcheck.Generator in
      let open Let_syntax in
      let%bind size_in_bits = Int.gen_incl 2 3000 in
      let%bind field_elements =
        (* Treat a field as a list of bools of length [size_in_bits]. *)
        list (list_with_length size_in_bits bool)
      in
      let%map bitstrings = list (list bool) in
      ( size_in_bits
      , { field_elements= Array.of_list field_elements
        ; bitstrings= Array.of_list bitstrings } )

    let%test_unit "data is preserved by to_bits" =
      Quickcheck.test ~trials:300 gen_input ~f:(fun (size_in_bits, input) ->
          let bits = to_bits ~unpack:Fn.id input in
          (* Fields are accumulated at the front, check them first. *)
          let bitstring_bits =
            Array.fold ~init:bits input.field_elements ~f:(fun bits field ->
                (* The next chunk of [size_in_bits] bits is for the field
                   element.
                *)
                let field_bits, rest = List.split_n bits size_in_bits in
                assert (field_bits = field) ;
                rest )
          in
          (* Bits come after. *)
          let remaining_bits =
            Array.fold ~init:bitstring_bits input.bitstrings
              ~f:(fun bits bitstring ->
                (* The next bits match the bitstring. *)
                let bitstring_bits, rest =
                  List.split_n bits (List.length bitstring)
                in
                assert (bitstring_bits = bitstring) ;
                rest )
          in
          (* All bits should have been consumed. *)
          assert (List.is_empty remaining_bits) )

    let%test_unit "data is preserved by pack_to_fields" =
      Quickcheck.test ~trials:300 gen_input ~f:(fun (size_in_bits, input) ->
          let fields = pack_to_fields ~size_in_bits ~pack:Fn.id input in
          (* Fields are accumulated at the front, check them first. *)
          let fields = Array.to_list fields in
          let bitstring_fields =
            Array.fold ~init:fields input.field_elements
              ~f:(fun fields input_field ->
                (* The next field element should be the literal field element
                   passed in.
                *)
                match fields with
                | [] ->
                    failwith "Too few field elements"
                | field :: rest ->
                    assert (field = input_field) ;
                    rest )
          in
          (* Check that the remaining fields have the correct size. *)
          let final_field_idx = List.length bitstring_fields - 1 in
          List.iteri bitstring_fields ~f:(fun i field_bits ->
              if i < final_field_idx then
                (* This field should be densely packed, but should contain
                   fewer bits than the maximum field element to ensure that it
                   doesn't overflow, so we expect [size_in_bits - 1] bits for
                   maximum safe density.
                *)
                assert (List.length field_bits = size_in_bits - 1)
              else (
                (* This field will be comprised of the remaining bits, up to a
                   maximum of [size_in_bits - 1]. It should not be empty.
                *)
                assert (not (List.is_empty field_bits)) ;
                assert (List.length field_bits < size_in_bits) ) ) ;
          let rec go input_bitstrings packed_fields =
            match (input_bitstrings, packed_fields) with
            | [], [] ->
                (* We have consumed all bitstrings and fields in parallel, with
                   no bits left over. Success.
                *)
                ()
            | [] :: input_bitstrings, packed_fields
            | input_bitstrings, [] :: packed_fields ->
                (* We have consumed the whole of an input bitstring or the whole
                   of a packed field, move onto the next one.
                *)
                go input_bitstrings packed_fields
            | ( (bi :: input_bitstring) :: input_bitstrings
              , (bp :: packed_field) :: packed_fields ) ->
                (* Consume the next bit from the next input bitstring, and the
                   next bit from the next packed field. They must match.
                *)
                assert (bi = bp) ;
                go
                  (input_bitstring :: input_bitstrings)
                  (packed_field :: packed_fields)
            | [], _ ->
                failwith "Packed fields contain more bits than were provided"
            | _, [] ->
                failwith
                  "There are input bits that were not present in the packed \
                   fields"
          in
          (* Check that the bits match between the input bitstring and the
             remaining fields.
          *)
          go (Array.to_list input.bitstrings) bitstring_fields )
  end )
