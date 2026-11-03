let naive_num_bits n =
  let rec go k =
    match Int.pow 2 k with
    | max_value_k_bits ->
        if n < max_value_k_bits then k else go (k + 1)
    | exception Invalid_argument _ ->
        (* [Invalid_argument] represents an overflow, which is certainly bigger
           than any given value.
        *)
        k
  in
  go 0

let test_num_bits () =
  Quickcheck.test (Int.gen_uniform_incl 0 Int.max_value) ~f:(fun n ->
      [%test_eq: int] (Pickles_types.Pcs_batch.num_bits n) (naive_num_bits n) )

let tests =
  let open Alcotest in
  [ ("PCS batch", [ test_case "test num bits" `Quick test_num_bits ]) ]
