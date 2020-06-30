open Core_kernel
open Snarky_bn382
open Zexe_backend_common

module Bigint384 =
  Zexe_backend_common.Bigint.Make
    (Bigint384)
    (struct
      let length_in_bytes = 48
    end)

module Fp = Field.Make (struct
  module Bigint = Bigint384
  include Snarky_bn382.Fp
end)

module Fq = Field.Make (struct
  module Bigint = Bigint384
  include Snarky_bn382.Fq
end)

module G1 = struct
  module Params = struct
    open Fq

    let a = zero

    let b = of_int 14
  end

  include Curve.Make (Fq) (Fp) (Params) (G1)
end

module G = struct
  module Params = struct
    open Fp

    let a = zero

    let b = of_int 7
  end

  include Curve.Make (Fp) (Fq) (Params) (G)
end

module Fq_poly_comm = Zexe_backend_common.Poly_comm.Make (struct
  module Curve = G
  module Base_field = Fp
  module Backend = Snarky_bn382.Fq_poly_comm
end)
