module Util = struct
  let rev_concat l =
    let rec go acc l =
      match l with
      | [] ->
          acc
      | [] :: l ->
          go acc l
      | (x :: xs) :: l ->
          go (x :: acc) (xs :: l)
    in
    go [] l
end

let unit_to_representatives = lazy [()]

let bool_to_representatives = lazy [false]

let int_to_representatives = lazy [0]

let string_to_representatives = lazy [""]

let char_to_representatives = lazy [' ']

let bytes_to_representatives = lazy [Bytes.empty]

let int32_to_representatives = lazy [0l]

let int64_to_representatives = lazy [0L]

let nativeint_to_representatives = lazy [0n]

let list_to_representatives _ = lazy [[]]

let option_to_representatives _ = lazy [None]

let array_to_representatives _ = lazy [[||]]
