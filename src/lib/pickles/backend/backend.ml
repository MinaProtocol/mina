module Tick = struct
  include Zexe_backend.Tweedle.Dum_based_plonk
  module Inner_curve = Zexe_backend.Tweedle.Dee
end

module Tock = struct
  include Zexe_backend.Tweedle.Dee_based_plonk
  module Inner_curve = Zexe_backend.Tweedle.Dum
end
