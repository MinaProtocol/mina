let () = Pickles.Backend.Tock.Keypair.set_urs_info Cache_dir.cache

let () = Pickles.Backend.Tick.Keypair.set_urs_info Cache_dir.cache

module Tock = struct
  module Full = Pickles.Impls.Wrap
  module Run = Pickles.Impls.Wrap

  let group_map_params () = Lazy.force Group_map_params.params

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Pickles.Backend.Tock.Inner_curve
end

module Tick = struct
  module Full = Pickles.Impls.Step
  module Run = Pickles.Impls.Step

  let group_map_params =
    Group_map.Params.create
      (module Pickles.Backend.Tock.Field)
      Pickles.Backend.Tock.Inner_curve.Params.{a; b}

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Pickles.Backend.Tick.Inner_curve
end
