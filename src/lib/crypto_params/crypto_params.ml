module Tock = struct
  module Full = Pickles.Impls.Dlog_based
  module Run = Pickles.Impls.Dlog_based

  let group_map_params =
    Group_map.Params.create
      (module Zexe_backend.Fp)
      Zexe_backend.G.Params.{a; b}

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Zexe_backend.G1
end

module Tick = struct
  module Full = Pickles.Impls.Pairing_based
  module Run = Pickles.Impls.Pairing_based

  let group_map_params =
    Group_map.Params.create
      (module Zexe_backend.Fq)
      Zexe_backend.G1.Params.{a; b}

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Zexe_backend.G
end
