type ('k, 'v, 'cmpS, 'cmpM) t = ('k, ('v, 'cmpS) Core.Set.t, 'cmpM) Core.Map.t

val remove_exn :
  ('k, 'v, 'cmpS, 'cmpM) t -> 'k -> 'v -> ('k, 'v, 'cmpS, 'cmpM) t

val insert :
     ('v, 'cmpS) Core.Set.comparator
  -> ('k, 'v, 'cmpS, 'cmpM) t
  -> 'k
  -> 'v
  -> ('k, 'v, 'cmpS, 'cmpM) t
