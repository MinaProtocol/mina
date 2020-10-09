open Core_kernel
open Snarky_bn382
open Zexe_backend_common

module Rounds = struct
  open Pickles_types.Nat

  module Wrap : Add.Intf_transparent = N17

  module Step : Add.Intf_transparent = N18
end

module Bigint256 =
  Zexe_backend_common.Bigint.Make
    (Bigint256)
    (struct
      let length_in_bytes = 32
    end)

module Fp = Field.Make (struct
  module Bigint = Bigint256
  include Snarky_bn382.Tweedle.Fp
end)

module Fq = Field.Make (struct
  module Bigint = Bigint256
  include Snarky_bn382.Tweedle.Fq
end)

module Dee = struct
  module Params = struct
    open Fq

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fq) (Fp) (Params) (Snarky_bn382.Tweedle.Dee.Curve)
end

module Dum = struct
  module Params = struct
    open Fp

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fp) (Fq) (Params) (Snarky_bn382.Tweedle.Dum.Curve)
end

module Fq_poly_comm = Zexe_backend_common.Poly_comm.Make (struct
  module Curve = Dum
  module Base_field = Fp
  module Backend = Snarky_bn382.Tweedle.Dum.Field_poly_comm
end)

module Fp_poly_comm = Zexe_backend_common.Poly_comm.Make (struct
  module Curve = Dee
  module Base_field = Fq
  module Backend = Snarky_bn382.Tweedle.Dee.Field_poly_comm
end)
