module Step = struct
  include Kimchi_backend.Pasta.Vesta_based_plonk
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end

module Wrap = struct
  include Kimchi_backend.Pasta.Pallas_based_plonk
  module Inner_curve = Kimchi_backend.Pasta.Pasta.Vesta
end
