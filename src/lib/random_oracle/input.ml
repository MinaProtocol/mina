open Core_kernel

type ('field, 'bool) t =
  {field_elements: 'field array; bitstrings: 'bool list array}

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
    else (rev_fields, bits)
  in
  let packed_bits =
    let packed_field_elements, remaining_bits, remaining_length =
      Array.fold bitstrings ~init:([], [], 0)
        ~f:(fun (acc, bits, n) bitstring ->
          let n = n + List.length bitstring in
          let bits = bits @ bitstring in
          let acc, bits = pack_full_fields acc bits n in
          (acc, bits, n) )
    in
    if remaining_length = 0 then packed_field_elements
    else pack remaining_bits :: packed_field_elements
  in
  Array.append field_elements (Array.of_list_rev packed_bits)

let to_bits ~unpack {field_elements; bitstrings} =
  let field_bits = Array.map ~f:unpack field_elements in
  List.concat @@ Array.to_list @@ Array.append field_bits bitstrings
