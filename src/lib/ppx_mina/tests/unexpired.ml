(* date in the far future *)

[%%expires_after "25250101"]

(* ppx used inside internal module *)

module M = struct
  type t = int

  [%%expires_after "22001109"]

  let bar = "bar"
end
