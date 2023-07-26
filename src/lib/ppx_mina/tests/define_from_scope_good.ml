module Outer = struct
  let x = 42

  let y = "This is a string"

  let z = (x, y)

  let q = (x, y, z)

  module Inner = struct
    [%%define_from_scope x, y, z, q]
  end
end

let x, y, z, q = Outer.Inner.(x, y, z, q)
