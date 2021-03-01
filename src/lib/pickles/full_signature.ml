open Pickles_types

type ('max_num_parents, 'num_rules, 'maxes) t =
  { prev_num_parentss_per_slot:
      ((int, 'num_rules) Vector.t, 'max_num_parents) Vector.t
  ; maxes:
      (module Hlist.Maxes.S
         with type length = 'max_num_parents
          and type ns = 'maxes) }
