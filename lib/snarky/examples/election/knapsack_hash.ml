open Core
open Impl

module M = Snarky.Knapsack.Make(Impl)
let dimension = 1

type var = Cvar.t list
type t = Field.t list
let typ = Typ.(list ~length:dimension field)

let to_bits xs = List.concat_map ~f:Field.unpack xs
let var_to_bits xs =
  Checked.map ~f:List.concat
    (Checked.all
      (List.map xs ~f:(Checked.choose_preimage ~length:Field.size_in_bits)))

let knapsack = M.create ~dimension ~max_input_length:1000

let assert_equal xs ys = Checked.all_ignore (List.map2_exn ~f:assert_equal xs ys)

let hash bs = M.hash_to_field knapsack bs
let hash_var bs = M.Checked.hash_to_field knapsack bs
