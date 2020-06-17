module Params = struct
  open Fq

  let a = zero

  let b = of_int 14
end

include Curve.Make (Fq) (Fp) (Params) (Snarky_bn382.G1)
