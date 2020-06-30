module Rounds = Zexe_backend.Tweedle.Dee_based.Rounds

module Tick = struct
  include Zexe_backend.Tweedle.Dum_based
  module Inner_curve = Zexe_backend.Tweedle.Dee
end

module Tock = struct
  include Zexe_backend.Tweedle.Dee_based
  module Inner_curve = Zexe_backend.Tweedle.Dum
end
