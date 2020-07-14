module Util = struct
  let rev_concat l =
    let rec rev_concat acc l =
      match l with
      | [] ->
          acc
      | [] :: l ->
          rev_concat acc l
      | (x :: xs) :: l ->
          rev_concat (x :: acc) (xs :: l)
    in
    rev_concat [] l
end

let unit_to_representatives = lazy [()]

let bool_to_representatives = lazy [false]

let int_to_representatives = lazy [0]

let string_to_representatives = lazy [""]

let char_to_representatives = lazy [' ']

let list_to_representatives _ = lazy [[]]

let option_to_representatives _ = lazy [None]
