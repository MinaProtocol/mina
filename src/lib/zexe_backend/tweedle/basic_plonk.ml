open Core_kernel
open Snarky_bn382
open Zexe_backend_common

module Rounds = struct
  open Pickles_types.Nat

  module Wrap : Add.Intf_transparent = N15

  module Step : Add.Intf_transparent = N15
end

module Bigint256 =
  Zexe_backend_common.Bigint.Make
    (Bigint256)
    (struct
      let length_in_bytes = 32
    end)

module Fp = Field_plonk.Make (struct
  module Bigint = Bigint256
  include Snarky_bn382.Tweedle.Fp_plonk
end)

module Fq = Field_plonk.Make (struct
  module Bigint = Bigint256
  include Snarky_bn382.Tweedle.Fq_plonk
end)

module Dee = struct
  module Params = struct
    open Fq

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fq) (Fp) (Params) (Snarky_bn382.Tweedle.Dee_plonk.Curve)
end

module Dum = struct
  module Params = struct
    open Fp

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fp) (Fq) (Params) (Snarky_bn382.Tweedle.Dum_plonk.Curve)
end

module Fq_poly_comm = Zexe_backend_common.Plonk_poly_comm.Make (struct
  module Curve = Dum
  module Base_field = Fp
  module Backend = Snarky_bn382.Tweedle.Dum_plonk.Plonk.Field_poly_comm
end)

module Fp_poly_comm = Zexe_backend_common.Plonk_poly_comm.Make (struct
  module Curve = Dee
  module Base_field = Fq
  module Backend = Snarky_bn382.Tweedle.Dee_plonk.Plonk.Field_poly_comm
end)
