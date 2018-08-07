open Core
open Impl
module M = Snarky.Knapsack.Make (Impl)

let dimension = 1

type var = Field.Checked.t list

type t = Field.t list

let typ = Typ.(list ~length:dimension field)

let to_bits xs = List.concat_map ~f:Field.unpack xs

let var_to_bits xs =
  Checked.map ~f:List.concat
    (Checked.all
       (List.map xs
          ~f:(Field.Checked.choose_preimage_var ~length:Field.size_in_bits)))

let knapsack = M.create ~dimension ~max_input_length:1000

let assert_equal xs ys =
  Checked.all_unit (List.map2_exn ~f:Field.Checked.Assert.equal xs ys)

let hash bs = M.hash_to_field knapsack bs

let hash_var bs = M.Checked.hash_to_field knapsack bs
