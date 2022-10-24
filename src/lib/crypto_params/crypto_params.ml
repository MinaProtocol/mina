let () = Pickles.Backend.Wrap.Keypair.set_urs_info Cache_dir.cache

let () = Pickles.Backend.Step.Keypair.set_urs_info Cache_dir.cache

module Wrap = struct
  module Full = Pickles.Impls.Wrap
  module Run = Pickles.Impls.Wrap

  let group_map_params () = Lazy.force Group_map_params.params

  include Full.Internal_Basic
  module Number = Snarky_backendless.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky_backendless.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Pickles.Backend.Wrap.Inner_curve
end

module Step = struct
  module Full = Pickles.Impls.Step
  module Run = Pickles.Impls.Step

  let group_map_params =
    Group_map.Params.create
      (module Pickles.Backend.Wrap.Field)
      Pickles.Backend.Wrap.Inner_curve.Params.{ a; b }

  include Full.Internal_Basic
  module Number = Snarky_backendless.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky_backendless.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Pickles.Backend.Step.Inner_curve
end
