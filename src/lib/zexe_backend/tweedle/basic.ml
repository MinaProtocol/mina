open Core_kernel
open Marlin_plonk_bindings
open Zexe_backend_common

module Rounds = struct
  open Pickles_types.Nat

  module Wrap : Add.Intf_transparent = N17

  module Step : Add.Intf_transparent = N18
end

module Bigint256 =
  Zexe_backend_common.Bigint.Make
    (Bigint_256)
    (struct
      let length_in_bytes = 32
    end)

module Fp = Field.Make (struct
  module Bigint = Bigint256
  include Tweedle_fp
  module Vector = Tweedle_fp_vector
end)

module Fq = Field.Make (struct
  module Bigint = Bigint256
  include Tweedle_fq
  module Vector = Tweedle_fq_vector
end)

module Dee = struct
  module Params = struct
    open Fq

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fq) (Fp) (Params) (Tweedle_dee)
end

module Dum = struct
  module Params = struct
    open Fp

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fp) (Fq) (Params) (Tweedle_dum)
end

module Fq_poly_comm = Zexe_backend_common.Poly_comm.Make (struct
  module Curve = Dum
  module Base_field = Fp

  module Backend = struct
    include Tweedle_fq_urs.Poly_comm

    let shifted ({shifted; _} : t) = shifted

    let unshifted ({unshifted; _} : t) = unshifted

    let make unshifted shifted : t = {shifted; unshifted}
  end
end)

module Fp_poly_comm = Zexe_backend_common.Poly_comm.Make (struct
  module Curve = Dee
  module Base_field = Fq

  module Backend = struct
    include Tweedle_fp_urs.Poly_comm

    let shifted ({shifted; _} : t) = shifted

    let unshifted ({unshifted; _} : t) = unshifted

    let make unshifted shifted : t = {shifted; unshifted}
  end
end)
