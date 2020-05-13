module Params = struct
  open Fp

  let a = zero

  let b = of_int 7
end

include Curve.Make (Fp) (Fq) (Params) (Snarky_bn382.G)
