open Core_kernel

type ('prev_var, 'prev_value) t = 
  ('prev_var * 'prev_value) Type_equal.Id.t
