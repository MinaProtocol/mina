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

let list_to_representatives _ = lazy [[]]

let option_to_representatives _ = lazy [None]
