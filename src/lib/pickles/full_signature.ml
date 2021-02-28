open Pickles_types

type ('max_width, 'num_rules, 'maxes) t =
  { padded: ((int, 'num_rules) Vector.t, 'max_width) Vector.t
  ; maxes:
      (module Hlist.Maxes.S with type length = 'max_width and type ns = 'maxes)
  }
