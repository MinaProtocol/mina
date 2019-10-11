  type (_, _) t = Nop : 'k -> ('k, _) t

  let map (Nop k) ~f = Nop (f k)

