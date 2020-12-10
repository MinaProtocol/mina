(* ppx used inside internal module *)

module Foo = struct
  type t = int

  [%%expires_after "20181111"]

  let bar = "bar"
end
