(* ppx used inside internal module *)

module Foo = struct
  type t = int

  [%%expires_after "22001109"]

  let bar = "bar"
end
