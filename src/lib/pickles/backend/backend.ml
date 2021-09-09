module Tick = struct
  include Zexe_backend.Pasta.Vesta_based_plonk
  module Inner_curve = Zexe_backend.Pasta.Pallas
end

module Tock = struct
  include Zexe_backend.Pasta.Pallas_based_plonk
  module Inner_curve = Zexe_backend.Pasta.Vesta
end
