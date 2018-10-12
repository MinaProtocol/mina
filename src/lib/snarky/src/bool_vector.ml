open Ctypes

include Vector.Make (struct
  let prefix = "camlsnark_bool_vector"

  type elt = bool

  let typ = bool

  let schedule_delete _ = ()
end)
