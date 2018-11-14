module T = Nat.Make32 ()

include T
include Jsonable.Make_from_int (T)
