module T = Nat.Make32 ()

include T
include Codable.Make_of_int (T)
