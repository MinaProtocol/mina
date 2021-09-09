open Pickles_types

type ('max_width, 'branches, 'maxes) t =
  { padded: ((int, 'branches) Vector.t, 'max_width) Vector.t
  ; maxes:
      (module Hlist.Maxes.S with type length = 'max_width and type ns = 'maxes)
  }
