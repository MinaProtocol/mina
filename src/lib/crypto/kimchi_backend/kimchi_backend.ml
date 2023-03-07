module Kimchi_backend_common = struct
  module Field = Kimchi_backend_common.Field
  module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
end

module Field = Kimchi_backend_common.Field

module Pasta = struct
  module Basic = Kimchi_pasta.Basic
  module Pallas_based_plonk = Kimchi_pasta.Pallas_based_plonk
  module Pasta = Kimchi_pasta.Pasta
  module Vesta_based_plonk = Kimchi_pasta.Vesta_based_plonk
end

(* The following is mostly unused, but we do this to test that we can instantiate snarky with the backend here (instead of failing later) *)

(* TODO: there's actually a tests.ml file doing this, delete this *)

module Impls = struct
  module Tick = struct
    include Pasta.Vesta_based_plonk
    module Inner_curve = Pasta.Pasta.Pallas
  end

  module Tock = struct
    include Pasta.Pallas_based_plonk
    module Inner_curve = Pasta.Pasta.Vesta
  end

  module Step_monad = Snarky_backendless.Snark.Make (Tick)
  module Wrap_monad = Snarky_backendless.Snark.Make (Tock)
  module Step = Snarky_backendless.Snark.Run.Make (Tick)
  module Wrap = Snarky_backendless.Snark.Run.Make (Tock)
end
