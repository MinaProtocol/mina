(* Someday: Use Int64.t *)
include Incrementer.Make(struct let byte_length = 8 end)

