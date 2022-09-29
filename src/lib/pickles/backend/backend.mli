module Tick : sig
  include module type of Kimchi_backend.Pasta.Vesta_based_plonk

  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end

module Tock : sig
  include module type of Kimchi_backend.Pasta.Pallas_based_plonk

  module Inner_curve = Kimchi_backend.Pasta.Pasta.Vesta
end
