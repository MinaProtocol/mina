module Rounds = Zexe_backend.Bn382.Dlog_based.Rounds

module Tick = struct
  include Zexe_backend.Bn382.Pairing_based
  module Inner_curve = Zexe_backend.Bn382.G
end

module Tock = struct
  include Zexe_backend.Bn382.Dlog_based
  module Inner_curve = Zexe_backend.Bn382.G1
end
