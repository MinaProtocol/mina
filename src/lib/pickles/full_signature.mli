type ('max_width, 'branches, 'maxes) t =
  { padded :
      ( (int, 'branches) Pickles_types.Vector.t
      , 'max_width )
      Pickles_types.Vector.t
  ; maxes :
      (module Pickles_types.Hlist.Maxes.S
         with type length = 'max_width
          and type ns = 'maxes )
  }
