module M1 = struct
  let x = 42

  let y = "This is a string"

  let z = (x, y)

  let q = (x, y, z)
end

module M2 = struct
  [%%define_locally M1.(x, y, z)]

  [%%define_locally M1.(q)]

  let _ = x

  let _ = y

  let _ = z

  let _ = q
end
