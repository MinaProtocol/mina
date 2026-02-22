module Tick = struct
  include Kimchi_backend.Pasta.Vesta_based_plonk
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end

module Tock = struct
  include Kimchi_backend.Pasta.Pallas_based_plonk
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Vesta
end
