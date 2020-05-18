module Tock = struct
  module Full = Pickles.Impls.Dlog_based
  module Run = Pickles.Impls.Dlog_based

  let group_map_params =
    Group_map.Params.create
      (module Snarky_bn382_backend.Fp)
      Snarky_bn382_backend.G.Params.{a; b}

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Snarky_bn382_backend.G1
end

module Tick = struct
  module Full = Pickles.Impls.Pairing_based
  module Run = Pickles.Impls.Pairing_based

  let group_map_params =
    Group_map.Params.create
      (module Snarky_bn382_backend.Fq)
      Snarky_bn382_backend.G1.Params.{a;b}

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Snarky_bn382_backend.G
end
